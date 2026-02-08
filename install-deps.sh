#!/usr/bin/env bash
set -e

# Detect package manager
if command -v apt-get &> /dev/null; then
    PKG="apt-get"
    SUDO=""
    [[ $EUID -ne 0 ]] && SUDO="sudo"

    $SUDO apt-get update
    $SUDO apt-get install -y \
        build-essential gcc make cmake \
        lua5.4 liblua5.4-dev \
        clangd-12 wget stow tmux \
        software-properties-common

    # neovim from unstable ppa
    $SUDO add-apt-repository -y ppa:neovim-ppa/unstable
    $SUDO apt-get update
    $SUDO apt-get install -y neovim

    # ripgrep
    curl -LO https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep_14.1.0-1_amd64.deb
    $SUDO dpkg -i ripgrep_14.1.0-1_amd64.deb
    rm ripgrep_14.1.0-1_amd64.deb

elif command -v brew &> /dev/null; then
    brew install \
        lua luarocks neovim tmux ripgrep stow \
        cmake node
else
    echo "Unsupported package manager"
    exit 1
fi

# pyright (via npm)
npm install -g pyright

# n (node version manager) - skip on mac
if [[ "$(uname)" != "Darwin" ]]; then
    curl -fsSL https://raw.githubusercontent.com/mklement0/n-install/stable/bin/n-install | bash -s -- -y 22
fi

# luarocks + luasocket
if command -v apt-get &> /dev/null; then
    cd /tmp
    wget https://luarocks.org/releases/luarocks-3.11.1.tar.gz
    tar zxpf luarocks-3.11.1.tar.gz
    cd luarocks-3.11.1
    ./configure && make && $SUDO make install
    $SUDO luarocks install luasocket
    cd && rm -rf /tmp/luarocks-3.11.1*
else
    luarocks install luasocket
fi

# tmux plugin manager - included as submodule in .config/tmux/plugins/tpm

# ghostty
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

# kanata (Linux only)
if command -v apt-get &> /dev/null; then
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
    $SUDO mkdir -p /etc/kanata
    $SUDO cp "$HOME/.config/kanata/linux/kanata.kbd" /etc/kanata/

    # Install and enable systemd service
    $SUDO cp "$HOME/.config/kanata/linux/kanata.service" /etc/systemd/system/
    $SUDO systemctl daemon-reload
    $SUDO systemctl enable kanata
    $SUDO systemctl start kanata

    echo "Kanata installed and started!"
fi

echo "Dependencies installed!"
