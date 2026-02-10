#!/usr/bin/env bash
set -e

DOTFILES_DIR="$HOME/.dotfiles"

# Clone if not exists
if [[ ! -d "$DOTFILES_DIR" ]]; then
    git clone --recurse-submodules https://github.com/griffinaddison/dotfiles.git "$DOTFILES_DIR"
fi

cd "$DOTFILES_DIR"
git submodule update --init --recursive
stow .

# Add aliases sourcing to shell rc file
ALIAS_SOURCE='[ -f ~/.aliases ] && source ~/.aliases'

# Detect shell rc file
if [[ "$OSTYPE" == darwin* ]]; then
    SHELL_RC="$HOME/.zshrc"
else
    SHELL_RC="$HOME/.bashrc"
fi

# Add source line if not already present
if [[ -f "$SHELL_RC" ]] && ! grep -qF '~/.aliases' "$SHELL_RC"; then
    echo "" >> "$SHELL_RC"
    echo "# Load custom aliases" >> "$SHELL_RC"
    echo "$ALIAS_SOURCE" >> "$SHELL_RC"
    echo "Added aliases sourcing to $SHELL_RC"
elif [[ ! -f "$SHELL_RC" ]]; then
    echo "# Load custom aliases" > "$SHELL_RC"
    echo "$ALIAS_SOURCE" >> "$SHELL_RC"
    echo "Created $SHELL_RC with aliases sourcing"
else
    echo "Aliases already sourced in $SHELL_RC"
fi

# Install Ghostty terminfo so tmux works over SSH from Ghostty
if [[ -f "$DOTFILES_DIR/ghostty.terminfo" ]]; then
    tic -x "$DOTFILES_DIR/ghostty.terminfo"
    echo "Ghostty terminfo installed"
fi

echo "Config installed!"
