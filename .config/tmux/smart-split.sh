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

# Check if the pane is running nvim — open the active buffer's file in a new nvim.
# nvim >= 0.10 splits into a TUI client + `nvim --embed` server; the RPC socket is
# named after the embed pid (older single-process nvims use the TUI pid). ps needs
# -A because the embed server has no controlling terminal.
if [[ "$pane_cmd" == "nvim" ]]; then
    nvim_bin="/opt/homebrew/bin/nvim"
    [[ -x "$nvim_bin" ]] || nvim_bin=$(command -v nvim)
    tui_pid=$(ps -A -o pid=,ppid=,comm= | awk -v p="$pane_pid" '$2 == p && $3 ~ /nvim$/ {print $1; exit}')
    embed_pid=$(ps -A -o pid=,ppid=,comm= | awk -v p="$tui_pid" '$2 == p && $3 ~ /nvim$/ {print $1; exit}')
    tmpdir=$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null || echo "${TMPDIR:-/tmp}/")
    sock=""
    for nvim_pid in $embed_pid $tui_pid; do
        sock=$(find "${tmpdir}nvim.${USER:-$(whoami)}" -name "nvim.${nvim_pid}.0" 2>/dev/null | head -1)
        [[ -n "$sock" ]] && break
    done
    current_file=""
    if [[ -n "$sock" ]]; then
        current_file=$("$nvim_bin" --server "$sock" --remote-expr 'expand("%:p")' 2>/dev/null)
    fi
    if [[ -n "$current_file" && -e "$current_file" ]]; then
        tmux split-window $direction -c "#{pane_current_path}" "$(printf '%q %q' "$nvim_bin" "$current_file")"
    else
        tmux split-window $direction -c "#{pane_current_path}" "$nvim_bin"
    fi
    exit 0
fi

# Check if the pane is running Claude Code. The claude launcher is a symlink to a
# versioned binary, so tmux reports the command as the version string (e.g. "2.1.170").
# Forked panes run claude under an `sh -c` wrapper with no job control, so tmux
# reports "sh"/"bash" instead — for those, look for a claude child of the pane shell.
is_claude_pane=false
if [[ "$pane_cmd" == "claude" || "$pane_cmd" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
    is_claude_pane=true
else
    while read -r child_comm; do
        child_base="${child_comm##*/}"
        if [[ "$child_base" == "claude" || "$child_base" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
            is_claude_pane=true
            break
        fi
    done < <(ps -A -o ppid=,comm= | awk -v p="$pane_pid" '$1 == p {print $2}')
fi

if [[ "$is_claude_pane" == true ]]; then
    # The cc-tmux-init.sh SessionStart hook records each pane's session id in
    # ~/.cache/claude-tmux/pane-<N>. Use it to fork the exact conversation in this
    # pane; fall back to the most recent session in the directory if no breadcrumb.
    pane_id=$(tmux display-message -p '#{pane_id}')
    breadcrumb="$HOME/.cache/claude-tmux/${pane_id//%/pane-}"
    session_id=""
    if [[ -r "$breadcrumb" ]]; then
        session_id=$(<"$breadcrumb")
        [[ "$session_id" =~ ^[a-zA-Z0-9-]+$ ]] || session_id=""
    fi
    if [[ -n "$session_id" ]]; then
        fork_cmd="$HOME/.local/bin/claude --resume $session_id --fork-session"
    else
        fork_cmd="$HOME/.local/bin/claude --continue --fork-session"
    fi
    # Fork the conversation from the source pane; drop to a shell when claude exits
    tmux split-window $direction -c "#{pane_current_path}" "sh -c '$fork_cmd; exec \$SHELL'"
    exit 0
fi

# Default: split with current path
tmux split-window $direction -c "#{pane_current_path}"
