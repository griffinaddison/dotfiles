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

echo "Config installed!"
