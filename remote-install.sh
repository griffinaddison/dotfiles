#!/bin/sh
set -e

DOTFILES_REPO="https://github.com/griffinaddison/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"

printf "\n"
printf "=== Griffin's Dotfiles Installer ===\n"
printf "\n"
printf "1) Full install  (dependencies + config)\n"
printf "2) Config only   (clone/stow dotfiles)\n"
printf "3) Deps only     (install packages)\n"
printf "4) Cancel\n"
printf "\n"
printf "Choose [1-4]: "
read choice < /dev/tty

case "$choice" in
    1)
        printf "\n=== Full install ===\n"
        # Clone if not already present
        if [ ! -d "$DOTFILES_DIR" ]; then
            git clone --recurse-submodules "$DOTFILES_REPO" "$DOTFILES_DIR"
        fi
        bash "$DOTFILES_DIR/install.sh"
        ;;
    2)
        printf "\n=== Config only ===\n"
        if [ ! -d "$DOTFILES_DIR" ]; then
            git clone --recurse-submodules "$DOTFILES_REPO" "$DOTFILES_DIR"
        fi
        bash "$DOTFILES_DIR/install-config.sh"
        ;;
    3)
        printf "\n=== Deps only ===\n"
        if [ ! -d "$DOTFILES_DIR" ]; then
            git clone --recurse-submodules "$DOTFILES_REPO" "$DOTFILES_DIR"
        fi
        bash "$DOTFILES_DIR/install-deps.sh"
        ;;
    4|"")
        printf "Cancelled.\n"
        exit 0
        ;;
    *)
        printf "Invalid choice.\n"
        exit 1
        ;;
esac
