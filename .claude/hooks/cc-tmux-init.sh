#!/bin/bash
# Sets initial tmux window name when Claude Code starts

[ -z "$TMUX" ] && exit 0

# Get current window name
current=$(tmux display-message -p '#{window_name}')

# Don't touch windows that already have cc prefix (preserves existing summary)
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

# Set window name with cc prefix
tmux rename-window "cc ${short_dir}" 2>/dev/null

exit 0
