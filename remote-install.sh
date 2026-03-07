#!/bin/sh
set -e

DOTFILES_REPO="https://github.com/griffinaddison/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"

# Parse flags
AUTO_YES=false
FLAG_GHOSTTY=false
FLAG_KANATA=false
FLAG_CONFIG_ONLY=false
FLAG_DEPS_ONLY=false

for arg in "$@"; do
    case "$arg" in
        -y)           AUTO_YES=true ;;
        --ghostty)    FLAG_GHOSTTY=true ;;
        --kanata)     FLAG_KANATA=true ;;
        --config-only) FLAG_CONFIG_ONLY=true ;;
        --deps-only)  FLAG_DEPS_ONLY=true ;;
        *) printf "Unknown flag: %s\n" "$arg"; exit 1 ;;
    esac
done

# Export env vars for install-deps.sh
if $AUTO_YES; then
    export DOTFILES_YES=1
    $FLAG_GHOSTTY && export DOTFILES_GHOSTTY=1
    $FLAG_KANATA && export DOTFILES_KANATA=1
fi

clone_if_needed() {
    if [ ! -d "$DOTFILES_DIR" ]; then
        git clone --recurse-submodules "$DOTFILES_REPO" "$DOTFILES_DIR"
    fi
}

if $AUTO_YES; then
    if $FLAG_CONFIG_ONLY; then
        printf "\n=== Config only (non-interactive) ===\n"
        clone_if_needed
        bash "$DOTFILES_DIR/install-config.sh"
    elif $FLAG_DEPS_ONLY; then
        printf "\n=== Deps only (non-interactive) ===\n"
        clone_if_needed
        bash "$DOTFILES_DIR/install-deps.sh"
    else
        printf "\n=== Full install (non-interactive) ===\n"
        clone_if_needed
        bash "$DOTFILES_DIR/install.sh"
    fi
else
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
            clone_if_needed
            bash "$DOTFILES_DIR/install.sh"
            ;;
        2)
            printf "\n=== Config only ===\n"
            clone_if_needed
            bash "$DOTFILES_DIR/install-config.sh"
            ;;
        3)
            printf "\n=== Deps only ===\n"
            clone_if_needed
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
fi
