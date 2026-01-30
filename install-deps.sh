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

# pyright
pip install pyright

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

# tmux plugin manager
[[ ! -d ~/.tmux/plugins/tpm ]] && \
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# ghostty (macOS only)
if [[ "$(uname)" == "Darwin" ]]; then
    echo "Installing Ghostty nightly..."

    # Remove existing installation
    [[ -d /Applications/Ghostty.app ]] && rm -rf /Applications/Ghostty.app

    # Download and install latest nightly
    GHOSTTY_DMG="/tmp/ghostty.dmg"
    curl -fsSL -o "$GHOSTTY_DMG" "https://release.files.ghostty.org/tip/macos/Ghostty.dmg"

    # Mount, copy, unmount
    hdiutil attach "$GHOSTTY_DMG" -quiet
    cp -R /Volumes/Ghostty/Ghostty.app /Applications/
    hdiutil detach /Volumes/Ghostty -quiet
    rm "$GHOSTTY_DMG"

    echo "Ghostty nightly installed!"
fi

echo "Dependencies installed!"
