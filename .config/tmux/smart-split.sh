#!/bin/bash
# Smart split that preserves SSH sessions (like VSCode terminal)
# Usage: smart-split.sh <direction>
# direction: -h (horizontal), -hb (horizontal before), -v (vertical), -vb (vertical before)

direction="$1"

# Get the current pane's command and PID
pane_cmd=$(tmux display-message -p '#{pane_current_command}')
pane_pid=$(tmux display-message -p '#{pane_pid}')

# Check if we're in an SSH or mosh session
if [[ "$pane_cmd" == "ssh" || "$pane_cmd" == "mosh" || "$pane_cmd" == "mosh-client" ]]; then
    # Get the full command from the process
    # Try to get child process first (in case shell spawned ssh)
    ssh_cmd=$(ps -o args= -p "$pane_pid" 2>/dev/null)

    if [[ -n "$ssh_cmd" && ("$ssh_cmd" == ssh* || "$ssh_cmd" == mosh*) ]]; then
        # Wrap in shell so exiting SSH doesn't close the pane
        tmux split-window $direction "sh -c '$ssh_cmd; exec \$SHELL'"
        exit 0
    fi
fi

# Check if a child process is SSH (e.g., bash -> ssh)
child_pids=$(pgrep -P "$pane_pid" 2>/dev/null)
for child_pid in $child_pids; do
    child_cmd=$(ps -o args= -p "$child_pid" 2>/dev/null)
    if [[ "$child_cmd" == ssh* || "$child_cmd" == mosh* ]]; then
        # Wrap in shell so exiting SSH doesn't close the pane
        tmux split-window $direction "sh -c '$child_cmd; exec \$SHELL'"
        exit 0
    fi
done

# Default: split with current path
tmux split-window $direction -c "#{pane_current_path}"
