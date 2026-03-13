#!/bin/bash
# Writes a pane->session breadcrumb for tmux-resurrect auto-resume

[ -z "$TMUX" ] && exit 0

# Read hook input JSON (must consume stdin before any exit)
hook_input=$(cat)

# Write pane->session breadcrumb for resurrect
session_id=$(echo "$hook_input" | grep -o '"session_id":"[^"]*"' | head -1 | sed 's/"session_id":"//;s/"//')
if [ -n "$session_id" ] && [ -n "$TMUX_PANE" ]; then
    breadcrumb_dir="$HOME/.cache/claude-tmux"
    mkdir -p "$breadcrumb_dir"
    echo "$session_id" > "$breadcrumb_dir/${TMUX_PANE//%/pane-}"
fi

exit 0
