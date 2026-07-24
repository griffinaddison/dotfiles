# === Cross-platform paths ===
export N_PREFIX="$HOME/n"
export PATH="$HOME/bin:$HOME/.local/bin:$N_PREFIX/bin:$PATH"

# === macOS-specific ===
if [[ "$(uname)" == "Darwin" ]]; then
    export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
    eval "$(/opt/homebrew/bin/brew shellenv)"
    alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"

    # Raspberry Pi cross-compilation
    export RASPBIAN_ROOTFS=$HOME/raspberrypi/rootfs
    export PATH="/opt/cross-pi-gcc/bin:$PATH"
    export RASPBERRY_VERSION=4
fi

# === nvm ===
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# === Go paths ===
[ -d ~/go ] && export GOPATH=$HOME/go
[ "$GOPATH" ] && [ -d "$GOPATH/bin" ] && PATH="$PATH:$GOPATH/bin"

if [ -d /opt/homebrew/opt/go/libexec ]; then
    export GOROOT=/opt/homebrew/opt/go/libexec
elif [ -d /opt/homebrew/opt/go ]; then
    export GOROOT=/opt/homebrew/opt/go
else
    [ -d /usr/local/go ] && export GOROOT=/usr/local/go
fi
[ -d "${GOROOT}/bin" ] && {
    if [ $(echo $PATH | grep -c ${GOROOT}/bin) -ne "1" ]; then
        PATH="$PATH:${GOROOT}/bin"
    fi
}
[ -d $HOME/go/bin ] && {
    if [ $(echo $PATH | grep -c $HOME/go/bin) -ne "1" ]; then
        PATH="$PATH:$HOME/go/bin"
    fi
}
export PATH

# === Docker CLI completions ===
fpath=(/Users/griffinaddison/.docker/completions $fpath)
autoload -Uz compinit
compinit

# === Google Cloud SDK ===
if [ -f '/Users/griffinaddison/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/griffinaddison/google-cloud-sdk/path.zsh.inc'; fi
if [ -f '/Users/griffinaddison/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/griffinaddison/google-cloud-sdk/completion.zsh.inc'; fi

# === Vi mode ===
set -o vi
export KEYTIMEOUT=5
bindkey -v '^?' backward-delete-char    # backspace past insert point
bindkey -v '^[[3~' delete-char          # delete key in insert mode
bindkey -v '^W' backward-kill-word      # ctrl-w: delete word past insert point
bindkey -v '^U' backward-kill-line      # ctrl-u: delete line past insert point
bindkey -v '^H' backward-delete-char    # ctrl-h (some terminals send this for backspace)
bindkey -v '^R' history-incremental-search-backward  # ctrl-r: search history

# Vim mode cursor shape (block=normal, beam=insert, like nvim)
function zle-keymap-select zle-line-init {
    case $KEYMAP in
        vicmd)      echo -ne '\e[2 q' ;;  # block cursor
        viins|main) echo -ne '\e[6 q' ;;  # beam cursor
    esac
}
zle -N zle-keymap-select
zle -N zle-line-init
# Reset to beam cursor when starting a new prompt
precmd() {
    echo -ne '\e[6 q'
    echo -ne "\e]2;$(hostname -s)\e\\"
}

# === Prompt: user@host:path$ (bash-style with colors) ===
PROMPT='%F{green}%n@%m%f:%F{cyan}%~%f$ '

# === Claude Code ===
export CLAUDE_CODE_NO_FLICKER=1

# === Additional tools ===
export PATH=/Users/griffinaddison/.opencode/bin:$PATH
export STM32_PRG_PATH=/Applications/STMicroelectronics/STM32Cube/STM32CubeProgrammer/STM32CubeProgrammer.app/Contents/MacOs/bin

# === ROS2 ===
export RCUTILS_COLORIZED_OUTPUT=1

# Kill the ROS 2 daemon, every ROS/DDS process, and stale DDS shared memory.
# Use it when nodes hang, discovery goes stale, or `ros2` commands act haunted.
ros2_nuke() {
    echo "ros2_nuke: stopping daemon"
    ros2 daemon stop 2>/dev/null
    echo "ros2_nuke: killing ROS/DDS processes"
    pkill -9 -f '(_ros2_daemon|ros2cli|rmw_|fastdds|fast_discovery|discovery_server|rviz2|robot_state_publisher|component_container|controller_manager|mujoco_ros2|ros_gz|gzserver|gzclient)' 2>/dev/null
    echo "ros2_nuke: clearing DDS shared memory"
    rm -rf /dev/shm/fastrtps_* /dev/shm/sem.fastrtps_* /dev/shm/fast_datasharing_* /dev/shm/*fastdds* /dev/shm/sem.*fastdds* 2>/dev/null
    ros2 daemon start 2>/dev/null
    echo "ros2_nuke: done"
}
alias ros_nuke='ros2_nuke'

# === Aliases & functions (merged in from ~/.aliases) ===
# Directory navigation
alias up='cd ..'
alias upp='cd ../..'
alias uppp='cd ../../..'
alias upppp='cd ../../../..'
alias uppppp='cd ../../../../..'
alias upppppp='cd ../../../../../..'
alias uppppppp='cd ../../../../../../..'

# Set tmux pane title to hostname
if [ -n "$TMUX" ]; then
    PROMPT_COMMAND='echo -ne "\e]2;$(hostname -s)\e\\"'
fi

# Wrap ssh to update tmux pane title with remote hostname
ssh() {
    local host="${@: -1}"
    host="${host##*@}"
    printf '\e]2;SSH: %s\e\\' "$host"
    if [ -n "$TMUX" ]; then
        tmux set pane-active-border-style fg=colour226
        tmux set -p pane-border-style fg=colour58
    fi
    command ssh "$@"
    printf '\e]2;%s\e\\' "$(hostname -s)"
    if [ -n "$TMUX" ]; then
        tmux set pane-active-border-style fg=colour70
        tmux set -p pane-border-style fg=colour22
    fi
}

# Dotfiles
dotpull() {
    cd ~/.dotfiles \
        && git fetch --all \
        && git reset --hard origin/main \
        ; stow --adopt . \
        && git checkout -- . \
        ; _dotpull_link_kanata \
        ; [ -d ~/.config/tmux/plugins/tpm ] \
            || git clone --depth 1 https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm \
        ; tmux source-file ~/.config/tmux/tmux.conf 2>/dev/null \
        ; ~/.config/tmux/plugins/tpm/bin/install_plugins 2>/dev/null
    cd -
}

# Symlink OS-specific kanata config (mac has `fn`, linux does not)
_dotpull_link_kanata() {
    local variant
    if [[ "$OSTYPE" == darwin* ]]; then
        variant="mac"
    else
        variant="linux"
    fi
    local src="$HOME/.dotfiles/.config/kanata/$variant/kanata.kbd"
    local dst="$HOME/.config/kanata/kanata.kbd"
    [ -f "$src" ] || return 0
    mkdir -p "$(dirname "$dst")"
    ln -sfn "$src" "$dst"
}

# Git
alias gs='git status'
alias gc='git commit -m'
alias gd='git diff'
alias gl='git log'
alias gpl='git pull'
alias gf='git fetch'
alias gps='git push'
alias ga='git add'
alias gck='git checkout'
alias gg='git log --graph --oneline --decorate'

# Slurm
alias sq='squeue -p a3mega -o "%.10i %.15u %.8T %.10M %.5D %.5C %.20N" --sort=S'

# Claude Code
alias claude-discord-danger='claude --dangerously-skip-permissions --channels plugin:discord@claude-plugins-official'



alias quickstart_mac="HOST_MACHINE_HOSTNAME=sim-robot-001 USE_CPP_RECORDER=true ./quick_start.sh --dev --vr-on-mac --no-tailscale --no-stain-detection"
