export RASPBIAN_ROOTFS=$HOME/raspberrypi/rootfs
export PATH=/opt/cross-pi-gcc/bin:$PATH
export RASPBERRY_VERSION=4
export PATH="/opt/homebrew/opt/llvm/bin:$PATH"

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
#
#
#

alias gs="git status"
alias gd="git diff"
alias gc="git commit -m"
alias gps="git push"
alias ga="git add"

# Run neofetch on terminal startup
neofetch

# Go paths
[ -d ~/go ] && export GOPATH=$HOME/go
[ "$GOPATH" ] && [ -d "$GOPATH/bin" ] && PATH="$PATH:$GOPATH/bin"

if [ -d /opt/homebrew/opt/go/libexec ]
then
  export GOROOT=/opt/homebrew/opt/go/libexec
else
  if [ -d /opt/homebrew/opt/go ]
  then
    export GOROOT=/opt/homebrew/opt/go
  else
    [ -d /usr/local/go ] && export GOROOT=/usr/local/go
  fi
fi
[ -d ${GOROOT}/bin ] && {
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
eval "$(/opt/homebrew/bin/brew shellenv)"
set -o vi
export KEYTIMEOUT=1 #faster esc apparently

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

alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
export PATH="$HOME/.local/bin:$PATH"
