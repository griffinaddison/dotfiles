#!/bin/bash
# Post-save hook for tmux-resurrect: rewrites claude panes to include --resume
# Called by resurrect after saving, receives state file path as $1
#
# Bash 3.2 compatible (macOS default /bin/bash) — no associative arrays.
# Uses a tmp mapping file instead, and BSD-portable shell utilities.

state_file="$1"
[ -z "$state_file" ] || [ ! -f "$state_file" ] && exit 0

# Quick check: any claude panes to process?
grep -q $'\t:claude$' "$state_file" || exit 0

breadcrumb_dir="$HOME/.cache/claude-tmux"
claude_projects="$HOME/.claude/projects"
log_file="$breadcrumb_dir/resurrect-save.log"
mkdir -p "$breadcrumb_dir"

ts="$(date '+%Y-%m-%dT%H:%M:%S')"
log() { printf '%s %s\n' "$ts" "$*" >> "$log_file"; }

# Project dir → claude-projects-style slug ("/Users/x/dyna/1" → "-Users-x-dyna-1")
slugify() { echo "$1" | sed 's|[/.]|-|g'; }

# Latest .jsonl in a project dir (portable across macOS BSD find / GNU find).
latest_jsonl() {
    local dir="$1"
    [ -d "$dir" ] || return 0
    # ls -t: newest first; filter via shell glob. Suppress "no match" noise.
    ( cd "$dir" && ls -t *.jsonl 2>/dev/null | head -1 )
}

# Mapping file: one line per (session, window, pane, resume_id) to rewrite.
mapping_file="$(mktemp)"
# Count file: how many panes need fallback per project_dir (to gate method 2).
need_fallback_file="$(mktemp)"
trap 'rm -f "$mapping_file" "$need_fallback_file"' EXIT

# First pass: figure out for each :claude pane what its preferred resume_id is.
# Track which panes have NO breadcrumb (candidates for method-2 fallback).
while IFS=$'\t' read -r _ session_name window_index _ _ pane_index _ dir _ _ _; do
    clean_dir="${dir#:}"
    pane_target="${session_name}:${window_index}.${pane_index}"
    pane_id="$(tmux display-message -t "$pane_target" -p '#{pane_id}' 2>/dev/null)"

    resume_id=""
    method=""

    # Method 1: breadcrumb file keyed by current pane_id (e.g. %5 → pane-5)
    if [ -n "$pane_id" ]; then
        breadcrumb_file="$breadcrumb_dir/${pane_id//%/pane-}"
        if [ -f "$breadcrumb_file" ]; then
            resume_id="$(cat "$breadcrumb_file")"
            method="breadcrumb"
        fi
    fi

    if [ -z "$resume_id" ]; then
        # Defer method-2 to a second pass; record this pane as needing fallback
        # and count panes per project dir so we can gate "ambiguous" cases.
        printf '%s\t%s\t%s\t%s\n' "$session_name" "$window_index" "$pane_index" "$clean_dir" \
            >> "$need_fallback_file"
        log "DEFER  $pane_target (pane=${pane_id:-?}) - no breadcrumb, dir=$clean_dir"
        continue
    fi

    # Validate the session jsonl actually exists somewhere
    session_ok=false
    if [ -n "$clean_dir" ]; then
        project_dir="$claude_projects/$(slugify "$clean_dir")"
        [ -f "$project_dir/${resume_id}.jsonl" ] && session_ok=true
    fi
    if [ "$session_ok" = false ]; then
        # Wider search in case the dir slug didn't match (e.g. weird path chars)
        if find "$claude_projects" -maxdepth 2 -name "${resume_id}.jsonl" 2>/dev/null | grep -q .; then
            session_ok=true
        fi
    fi

    if [ "$session_ok" = true ]; then
        printf '%s\t%s\t%s\t%s\n' "$session_name" "$window_index" "$pane_index" "$resume_id" \
            >> "$mapping_file"
        log "REWRITE $pane_target (pane=$pane_id, $method) -> $resume_id"
    else
        log "SKIP   $pane_target (pane=$pane_id, $method) - resume_id=$resume_id has no jsonl on disk"
    fi
done < <(grep $'\t:claude$' "$state_file")

# Second pass: method-2 fallback for panes WITHOUT a breadcrumb.
# Only apply if exactly ONE pane in that project_dir needs a fallback —
# otherwise the same .jsonl would be assigned to multiple panes, which is wrong.
if [ -s "$need_fallback_file" ]; then
    # Build "dir → count" from the deferred list
    awk -F'\t' '{c[$4]++} END {for (d in c) print c[d] "\t" d}' "$need_fallback_file" \
        | while IFS=$'\t' read -r count dir; do
            if [ "$count" -ne 1 ] || [ -z "$dir" ]; then
                # Log skip for each pane in this ambiguous dir
                awk -F'\t' -v d="$dir" '$4 == d' "$need_fallback_file" \
                    | while IFS=$'\t' read -r sess win pane _; do
                        log "SKIP   ${sess}:${win}.${pane} - method-2 ambiguous (${count} panes need fallback in dir=$dir)"
                    done
                continue
            fi
            # Exactly one pane needs fallback in this dir — try latest_jsonl
            project_dir="$claude_projects/$(slugify "$dir")"
            latest="$(latest_jsonl "$project_dir")"
            if [ -z "$latest" ]; then
                awk -F'\t' -v d="$dir" '$4 == d' "$need_fallback_file" \
                    | while IFS=$'\t' read -r sess win pane _; do
                        log "SKIP   ${sess}:${win}.${pane} - method-2 no .jsonl in $project_dir"
                    done
                continue
            fi
            resume_id="${latest%.jsonl}"
            # Apply to the single deferred pane in this dir
            awk -F'\t' -v d="$dir" '$4 == d' "$need_fallback_file" \
                | while IFS=$'\t' read -r sess win pane _; do
                    printf '%s\t%s\t%s\t%s\n' "$sess" "$win" "$pane" "$resume_id" \
                        >> "$mapping_file"
                    log "REWRITE ${sess}:${win}.${pane} (latest-jsonl) -> $resume_id"
                done
        done
fi

# Apply all replacements via a single awk pass over the state file.
if [ -s "$mapping_file" ]; then
    tmp_file="$(mktemp)"
    awk -F'\t' -v OFS='\t' -v mapfile="$mapping_file" '
        BEGIN {
            while ((getline line < mapfile) > 0) {
                n = split(line, f, "\t")
                key = f[1] "|" f[2] "|" f[3]
                resume[key] = f[4]
            }
            close(mapfile)
        }
        $1 == "pane" && $NF == ":claude" {
            key = $2 "|" $3 "|" $6
            if (key in resume) {
                $NF = ":claude --resume " resume[key]
            }
        }
        { print }
    ' "$state_file" > "$tmp_file"
    mv "$tmp_file" "$state_file"
fi

# Clean up stale breadcrumbs (older than 24h), but only for dead panes —
# smart-split.sh reads breadcrumbs to fork the live pane's claude session.
if [ -d "$breadcrumb_dir" ]; then
    live_panes="$(tmux list-panes -a -F '#{pane_id}' 2>/dev/null | tr -d '%')"
    find "$breadcrumb_dir" -maxdepth 1 -name 'pane-*' -mmin +1440 2>/dev/null \
        | while read -r breadcrumb_file; do
            pane_number="${breadcrumb_file##*pane-}"
            echo "$live_panes" | grep -qx "$pane_number" || rm -f "$breadcrumb_file"
        done
fi

# Trim log to last 1000 lines so it doesn't grow forever.
if [ -f "$log_file" ] && [ "$(wc -l < "$log_file" 2>/dev/null)" -gt 2000 ]; then
    tail -n 1000 "$log_file" > "${log_file}.trim" && mv "${log_file}.trim" "$log_file"
fi

exit 0
