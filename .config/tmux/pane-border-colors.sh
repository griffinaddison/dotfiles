#!/bin/sh
# Set per-pane inactive border colors based on whether pane runs ssh
tmux list-panes -F '#{pane_id} #{pane_current_command}' | while read id cmd; do
    if [ "$cmd" = "ssh" ]; then
        tmux set -p -t "$id" pane-border-style fg=colour58
    else
        tmux set -p -t "$id" pane-border-style fg=colour22
    fi
done
