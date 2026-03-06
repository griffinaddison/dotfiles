# === Cross-platform paths ===
export PATH="$HOME/bin:$HOME/.local/bin:$PATH"

# === macOS-specific ===
if [[ "$(uname)" == "Darwin" ]]; then
    export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
    eval "$(/opt/homebrew/bin/brew shellenv)"
    alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"

    # Raspberry Pi cross-compilation
    export RASPBIAN_ROOTFS=$HOME/raspberrypi/rootfs
    export PATH="/opt/cross-pi-gcc/bin:$PATH"
    export RASPBERRY_VERSION=4

    # >>> conda initialize >>>
    # !! Contents within this block are managed by 'conda init' !!
    __conda_setup="$('/Users/griffin/anaconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    else
        if [ -f "/Users/griffin/anaconda3/etc/profile.d/conda.sh" ]; then
            . "/Users/griffin/anaconda3/etc/profile.d/conda.sh"
        else
            export PATH="/Users/griffin/anaconda3/bin:$PATH"
        fi
    fi
    unset __conda_setup
    # <<< conda initialize <<<

    # neofetch on startup (macOS only)
    command -v neofetch &>/dev/null && neofetch
fi

# === nvm ===
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# === Navigation aliases ===
alias up="cd .."
alias upp="cd ../.."
alias uppp="cd ../../.."
alias upppp="cd ../../../.."
alias uppppp="cd ../../../../.."

# === Git aliases ===
alias gs="git status"
alias gps="git push"
alias gd="git diff"
alias gc="git commit -m"
alias ga="git add"
alias gg="git log --graph --oneline --all --pretty"
alias gl="git log"
alias gpl="git pull"
alias gf="git fetch"
alias gck="git checkout"

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
export KEYTIMEOUT=1

setopt PROMPT_SUBST
setopt TRANSIENT_RPROMPT

# Vim mode indicator in prompt
function zle-keymap-select zle-line-init {
    case $KEYMAP in
        vicmd)      VIM_MODE="%K{#8fb573}%F{black} NORMAL %f%k" ;;
        viins|main) VIM_MODE="%K{#56b6c2}%F{black} INSERT %f%k" ;;
    esac
    zle reset-prompt
}
zle -N zle-keymap-select
zle -N zle-line-init
RPROMPT='${VIM_MODE}'

# === Prompt: user@host:path$ (bash-style with colors) ===
PROMPT='%F{green}%n@%m%f:%F{cyan}%~%f$ '

# === Additional tools ===
export PATH=/Users/griffinaddison/.opencode/bin:$PATH
export STM32_PRG_PATH=/Applications/STMicroelectronics/STM32Cube/STM32CubeProgrammer/STM32CubeProgrammer.app/Contents/MacOs/bin

# Load custom aliases
[ -f ~/.aliases ] && source ~/.aliases
