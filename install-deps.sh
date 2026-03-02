#!/usr/bin/env bash
set -e

# Optional components
INSTALL_GHOSTTY=false
INSTALL_KANATA=false

printf "\n=== Optional components ===\n"
printf "Install Ghostty? [y/N]: "
read -r ans < /dev/tty
[[ "$ans" =~ ^[Yy] ]] && INSTALL_GHOSTTY=true

printf "Install Kanata? [y/N]: "
read -r ans < /dev/tty
[[ "$ans" =~ ^[Yy] ]] && INSTALL_KANATA=true

printf "\n"

# Detect package manager
if command -v apt-get &> /dev/null; then
    PKG="apt-get"
    SUDO=""
    [[ $EUID -ne 0 ]] && SUDO="sudo"

    $SUDO apt-get update
    $SUDO apt-get install -y \
        build-essential gcc make cmake \
        wget stow tmux jq zsh \
        software-properties-common

    # clangd - package name varies by distro
    $SUDO apt-get install -y clangd-12 2>/dev/null \
        || $SUDO apt-get install -y clangd 2>/dev/null \
        || echo "Warning: clangd not found, skipping (C++ LSP)"

    # neovim - AppImage to ~/bin (no sudo, no system-wide PPA)
    echo "Installing Neovim AppImage..."
    mkdir -p "$HOME/bin"
    ARCH=$(uname -m)
    curl -fsSL -o "$HOME/bin/nvim" \
        "https://github.com/neovim/neovim/releases/download/stable/nvim-linux-${ARCH}.appimage"
    chmod +x "$HOME/bin/nvim"

    # ripgrep
    if [ "$(dpkg --print-architecture)" = "amd64" ]; then
        curl -LO https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep_14.1.0-1_amd64.deb
        $SUDO dpkg -i ripgrep_14.1.0-1_amd64.deb
        rm ripgrep_14.1.0-1_amd64.deb
    else
        curl -LO https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep-14.1.0-aarch64-unknown-linux-gnu.tar.gz
        tar xzf ripgrep-14.1.0-aarch64-unknown-linux-gnu.tar.gz
        $SUDO cp ripgrep-14.1.0-aarch64-unknown-linux-gnu/rg /usr/local/bin/
        rm -rf ripgrep-14.1.0-aarch64-unknown-linux-gnu ripgrep-14.1.0-aarch64-unknown-linux-gnu.tar.gz
    fi

elif command -v brew &> /dev/null; then
    brew install \
        lua neovim tmux ripgrep stow jq \
        cmake node
else
    echo "Unsupported package manager"
    exit 1
fi

# n (node version manager) - skip on mac, skip if node/npm already available
if [[ "$(uname)" != "Darwin" ]] && ! command -v node &> /dev/null; then
    curl -fsSL https://raw.githubusercontent.com/mklement0/n-install/stable/bin/n-install | bash -s -- -y 22
    export N_PREFIX="$HOME/n"; [[ :$PATH: == *":$N_PREFIX/bin:"* ]] || PATH="$N_PREFIX/bin:$PATH"
fi

# pyright (via npm)
npm install -g pyright

# tmux plugin manager - included as submodule in .config/tmux/plugins/tpm

# ghostty
if $INSTALL_GHOSTTY; then
echo "Installing Ghostty nightly..."
if [[ "$(uname)" == "Darwin" ]]; then
    # macOS - from GitHub releases
    [[ -d /Applications/Ghostty.app ]] && rm -rf /Applications/Ghostty.app

    GHOSTTY_DMG="/tmp/ghostty.dmg"
    curl -fsSL -o "$GHOSTTY_DMG" -L "https://github.com/ghostty-org/ghostty/releases/download/tip/Ghostty.dmg"

    hdiutil attach "$GHOSTTY_DMG" -quiet
    cp -R /Volumes/Ghostty/Ghostty.app /Applications/
    hdiutil detach /Volumes/Ghostty -quiet
    rm "$GHOSTTY_DMG"
elif command -v apt-get &> /dev/null; then
    # Linux - AppImage (works on all distros including Ubuntu 22.04)
    [[ -f /usr/local/bin/ghostty ]] && $SUDO rm /usr/local/bin/ghostty

    ARCH=$(uname -m)
    GHOSTTY_URL=$(curl -fsSL "https://api.github.com/repos/pkgforge-dev/ghostty-appimage/releases/latest" \
        | grep "browser_download_url.*${ARCH}.AppImage\"" | cut -d '"' -f 4)

    curl -fsSL -o /tmp/ghostty.AppImage -L "$GHOSTTY_URL"
    chmod +x /tmp/ghostty.AppImage
    $SUDO mv /tmp/ghostty.AppImage /usr/local/bin/ghostty

    # Desktop entry
    $SUDO mkdir -p /usr/share/icons/hicolor/256x256/apps
    $SUDO curl -fsSL -o /usr/share/icons/hicolor/256x256/apps/ghostty.png \
        "https://raw.githubusercontent.com/ghostty-org/ghostty/main/images/icons/icon_256.png"

    $SUDO tee /usr/share/applications/ghostty.desktop > /dev/null <<DESKTOP
[Desktop Entry]
Name=Ghostty
Comment=Fast, feature-rich terminal emulator
Exec=/usr/local/bin/ghostty
Icon=ghostty
Terminal=false
Type=Application
Categories=System;TerminalEmulator;
DESKTOP
fi
echo "Ghostty nightly installed!"
fi # INSTALL_GHOSTTY

# kanata (Linux only)
if $INSTALL_KANATA && command -v apt-get &> /dev/null; then
    echo "Installing Kanata..."

    # Install Rust if needed
    if ! command -v cargo &> /dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    fi

    # Build and install kanata via cargo
    cargo install kanata
    $SUDO cp "$HOME/.cargo/bin/kanata" /usr/local/bin/

    # Copy Linux-specific config
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    $SUDO mkdir -p /etc/kanata
    $SUDO cp "$SCRIPT_DIR/.config/kanata/linux/kanata.kbd" /etc/kanata/

    # Install and enable systemd service
    $SUDO cp "$SCRIPT_DIR/.config/kanata/linux/kanata.service" /etc/systemd/system/
    $SUDO systemctl daemon-reload
    $SUDO systemctl enable kanata
    $SUDO systemctl start kanata

    echo "Kanata installed and started!"
fi

# Set zsh as default shell
if command -v zsh &> /dev/null && [ "$SHELL" != "$(which zsh)" ]; then
    echo "Setting zsh as default shell..."
    chsh -s "$(which zsh)"
fi

echo "Dependencies installed!"
