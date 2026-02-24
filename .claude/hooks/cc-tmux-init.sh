#!/bin/bash
# Sets tmux window name when Claude Code starts: cc dir (branch)

[ -z "$TMUX" ] && exit 0

# Get current window name
current=$(tmux display-message -p '#{window_name}')

# Don't touch windows that already have cc prefix (preserves existing name)
[[ "$current" == cc\ * ]] && exit 0

# Only rename default shell windows - custom names are left alone (opt-out)
case "$current" in
    zsh|bash|fish|sh|ksh|tcsh|csh|dash) ;;
    *) exit 0 ;;
esac

# Get short directory name (e.g., "dyna/1" from worktree path)
dir=$(basename "$PWD")
parent=$(basename "$(dirname "$PWD")")

# Use parent/dir format if parent isn't home
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

# Set window name: cc dir (branch)
if [ -n "$branch" ]; then
    tmux rename-window "cc ${short_dir} (${branch})" 2>/dev/null
else
    tmux rename-window "cc ${short_dir}" 2>/dev/null
fi

exit 0
