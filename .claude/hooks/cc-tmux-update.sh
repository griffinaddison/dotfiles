#!/bin/bash
# Refreshes tmux window name with current dir + git branch (only for cc windows)

[ -z "$TMUX" ] && exit 0

# Read hook input (not used, but consume stdin)
cat > /dev/null

# Get current window name
current=$(tmux display-message -p '#{window_name}')

# Only update windows that start with "cc " (Claude Code windows)
[[ "$current" != cc\ * ]] && exit 0

# Get short directory name
dir=$(basename "$PWD")
parent=$(basename "$(dirname "$PWD")")

if [ "$parent" != "$(whoami)" ] && [ "$parent" != "~" ]; then
    short_dir="${parent}/${dir}"
else
    short_dir="$dir"
fi

# Get git branch
branch=""
if git rev-parse --is-inside-work-tree &>/dev/null; then
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
fi

# Update window name: cc dir (branch)
if [ -n "$branch" ]; then
    tmux rename-window "cc ${short_dir} (${branch})" 2>/dev/null
else
    tmux rename-window "cc ${short_dir}" 2>/dev/null
fi

exit 0
