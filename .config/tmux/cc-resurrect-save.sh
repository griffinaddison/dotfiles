#!/bin/bash
# Post-save hook for tmux-resurrect: rewrites claude panes to include --resume
# Called by resurrect after saving, receives state file path as $1

state_file="$1"
[ -z "$state_file" ] || [ ! -f "$state_file" ] && exit 0

# Quick check: any claude panes to process?
grep -q $'\t:claude$' "$state_file" || exit 0

breadcrumb_dir="$HOME/.cache/claude-tmux"
claude_projects="$HOME/.claude/projects"

# Process only pane lines ending with :claude, leave everything else untouched
# Collect replacements first, then apply with sed
declare -A replacements

while IFS=$'\t' read -r _ session_name window_index _ _ pane_index _ dir _ _ _; do
    # Strip colon prefix from dir field (resurrect format: :/path/to/dir)
    clean_dir="${dir#:}"

    # Look up pane ID via tmux
    pane_target="${session_name}:${window_index}.${pane_index}"
    pane_id=$(tmux display-message -t "$pane_target" -p '#{pane_id}' 2>/dev/null)

    resume_id=""

    # Method 1: breadcrumb file
    if [ -n "$pane_id" ]; then
        breadcrumb_file="$breadcrumb_dir/${pane_id//%/pane-}"
        if [ -f "$breadcrumb_file" ]; then
            resume_id=$(cat "$breadcrumb_file")
        fi
    fi

    # Method 2: fallback to most recent session in the project dir
    if [ -z "$resume_id" ] && [ -n "$clean_dir" ]; then
        project_path=$(echo "$clean_dir" | sed 's|[/.]|-|g')
        project_dir="$claude_projects/$project_path"
        if [ -d "$project_dir" ]; then
            latest=$(find "$project_dir" -maxdepth 1 -name '*.jsonl' -printf '%T@\t%f\n' 2>/dev/null | sort -rn | head -1 | cut -f2)
            if [ -n "$latest" ]; then
                resume_id="${latest%.jsonl}"
            fi
        fi
    fi

    # Validate the session file actually exists
    if [ -n "$resume_id" ]; then
        session_exists=false
        if [ -n "$clean_dir" ]; then
            project_path=$(echo "$clean_dir" | sed 's|[/.]|-|g')
            project_dir="$claude_projects/$project_path"
            [ -f "$project_dir/${resume_id}.jsonl" ] && session_exists=true
        fi
        if [ "$session_exists" = false ]; then
            found=$(find "$claude_projects" -maxdepth 2 -name "${resume_id}.jsonl" 2>/dev/null | head -1)
            [ -n "$found" ] && session_exists=true
        fi

        if [ "$session_exists" = true ]; then
            # Build a unique sed pattern for this specific pane line
            # Match on session:window_index + pane_index + dir to be precise
            replacements["${session_name}:${window_index}.${pane_index}"]="$resume_id"
        fi
    fi
done < <(grep $'\t:claude$' "$state_file")

# Apply all replacements to the state file
if [ ${#replacements[@]} -gt 0 ]; then
    tmp_file=$(mktemp)
    cp "$state_file" "$tmp_file"

    for pane_key in "${!replacements[@]}"; do
        rid="${replacements[$pane_key]}"
        IFS=':.' read -r sess win pane_idx <<< "$pane_key"
        # Replace :claude at end of line for matching pane lines
        # Match: pane<TAB>session<TAB>window<TAB>...<TAB>pane_idx<TAB>...<TAB>:claude$
        # Use awk for precise field matching
        awk -F'\t' -v OFS='\t' \
            -v s="$sess" -v w="$win" -v p="$pane_idx" -v rid="$rid" \
            '$1=="pane" && $2==s && $3==w && $6==p && $NF==":claude" {
                $NF = ":claude --resume " rid
            } {print}' "$tmp_file" > "${tmp_file}.new"
        mv "${tmp_file}.new" "$tmp_file"
    done

    mv "$tmp_file" "$state_file"
fi

# Clean up stale breadcrumbs (older than 24 hours)
if [ -d "$breadcrumb_dir" ]; then
    find "$breadcrumb_dir" -maxdepth 1 -name 'pane-*' -mmin +1440 -delete 2>/dev/null
fi

exit 0
