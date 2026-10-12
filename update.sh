#!/usr/bin/env bash
set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

# Pull latest dotfiles repo
git pull --recurse-submodules

# Update all submodules to latest remote HEAD
git submodule update --remote --recursive

# Re-stow symlinks
stow .

echo "Dotfiles synced!"
