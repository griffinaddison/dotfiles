#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# Optional components
INSTALL_GHOSTTY=false
INSTALL_KANATA=false

if [[ -n "$DOTFILES_YES" ]]; then
    [[ -n "$DOTFILES_GHOSTTY" ]] && INSTALL_GHOSTTY=true
    [[ -n "$DOTFILES_KANATA" ]] && INSTALL_KANATA=true
else
    printf "\n=== Optional components ===\n"
    printf "Install Ghostty? [y/N]: "
    read -r ans < /dev/tty
    [[ "$ans" =~ ^[Yy] ]] && INSTALL_GHOSTTY=true

    printf "Install Kanata? [y/N]: "
    read -r ans < /dev/tty
    [[ "$ans" =~ ^[Yy] ]] && INSTALL_KANATA=true

    printf "\n"
fi

# Detect package manager
if [[ "$(uname)" == "Darwin" ]]; then
    PKG="brew"

    command -v brew &> /dev/null || load_brew || true

    # macOS ships no package manager, so install one
    if ! command -v brew &> /dev/null; then
        # brew needs the Xcode Command Line Tools (git, clang)
        if ! xcode-select -p &> /dev/null; then
            echo "Installing Xcode Command Line Tools..."
            xcode-select --install
            echo "Finish that install in the GUI, then re-run this script."
            exit 1
        fi

        echo "Installing Homebrew..."
        NONINTERACTIVE="$DOTFILES_YES" /bin/bash -c \
            "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        load_brew
    fi

    brew install \
        lua neovim tmux ripgrep stow jq \
        cmake node imagemagick luarocks

elif command -v apt-get &> /dev/null; then
    PKG="apt-get"
    SUDO=""
    [[ $EUID -ne 0 ]] && SUDO="sudo"

    $SUDO apt-get update
    $SUDO apt-get install -y \
        build-essential gcc make cmake \
        wget stow jq zsh \
        libevent-dev ncurses-dev bison pkg-config \
        software-properties-common \
        imagemagick luarocks

    # clangd - package name varies by distro
    $SUDO apt-get install -y clangd-12 2>/dev/null \
        || $SUDO apt-get install -y clangd 2>/dev/null \
        || echo "Warning: clangd not found, skipping (C++ LSP)"

    # neovim - AppImage to ~/bin (no sudo, no system-wide PPA)
    echo "Installing Neovim AppImage..."
    mkdir -p "$HOME/bin"
    ARCH=$(uname -m)
    [[ "$ARCH" == "aarch64" ]] && ARCH="arm64" || ARCH="x86_64"
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

else
    echo "Unsupported package manager"
    exit 1
fi

# n (node version manager) - skip on mac, skip if node/npm already available
if [[ "$(uname)" != "Darwin" ]] && ! command -v node &> /dev/null; then
    curl -fsSL https://raw.githubusercontent.com/mklement0/n-install/stable/bin/n-install | bash -s -- -y 22
    export N_PREFIX="$HOME/n"; [[ :$PATH: == *":$N_PREFIX/bin:"* ]] || PATH="$N_PREFIX/bin:$PATH"
fi

# pyright (via npm) - use local prefix if global is not writable
if npm install -g pyright 2>/dev/null; then
    :
else
    npm config set prefix "$HOME/.local"
    npm install -g pyright
fi

# tmux - build from source for latest version (need >= 3.3a for allow-passthrough)
if [[ "$PKG" == "apt-get" ]]; then
    TMUX_VERSION="3.5a"
    echo "Installing tmux ${TMUX_VERSION} from source..."
    curl -fsSL -o /tmp/tmux-${TMUX_VERSION}.tar.gz \
        "https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}/tmux-${TMUX_VERSION}.tar.gz"
    tar xzf /tmp/tmux-${TMUX_VERSION}.tar.gz -C /tmp
    (cd /tmp/tmux-${TMUX_VERSION} && ./configure --prefix="$HOME/.local" && make -j"$(nproc)" && make install)
    rm -rf /tmp/tmux-${TMUX_VERSION} /tmp/tmux-${TMUX_VERSION}.tar.gz
fi

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

# kanata
if $INSTALL_KANATA && [[ "$(uname)" == "Darwin" ]]; then
    echo "Installing Kanata..."

    brew install kanata

    # kanata drives a virtual keyboard provided by Karabiner's DriverKit
    # extension. They speak a versioned protocol and pqrs changes it between
    # minor releases, so each kanata release supports exactly one driver
    # version. Get this wrong and kanata looks for a socket name the driver
    # never creates, then logs "connect_failed asio.system:2" forever.
    #
    # Read the pin off the docs for the kanata version you actually have, NOT
    # off main:
    #   https://github.com/jtroo/kanata/blob/v1.12.0/docs/setup-macos.md
    # kanata 1.12.0 wants 6.2.0. main wants 8.0.0. They are not interchangeable.
    KANATA_PINNED_FOR="1.12.0"
    VHID_VERSION="6.2.0"

    VHID_APP="/Applications/.Karabiner-VirtualHIDDevice-Manager.app"
    VHID_MANAGER="$VHID_APP/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager"

    KANATA_HAVE="$(kanata --version 2>/dev/null | awk '{print $2}')"
    if [[ "$KANATA_HAVE" != "$KANATA_PINNED_FOR" ]]; then
        echo
        echo "WARNING: driver $VHID_VERSION was verified against kanata $KANATA_PINNED_FOR,"
        echo "         but brew installed kanata ${KANATA_HAVE:-unknown}."
        echo "         Check that release's docs/setup-macos.md for its driver version"
        echo "         and update VHID_VERSION and KANATA_PINNED_FOR together."
        echo
    fi

    # Compare against what's installed, so a wrong version gets corrected
    # instead of skipped
    VHID_HAVE=""
    if [[ -f "$VHID_APP/Contents/Info.plist" ]]; then
        VHID_HAVE="$(defaults read "$VHID_APP/Contents/Info.plist" CFBundleVersion 2>/dev/null || true)"
    fi

    if [[ "$VHID_HAVE" != "$VHID_VERSION" ]]; then
        echo "Installing Karabiner-DriverKit-VirtualHIDDevice ${VHID_VERSION} (have: ${VHID_HAVE:-none})..."

        # Retire the old extension first or macOS keeps the old one loaded
        if [[ -x "$VHID_MANAGER" ]]; then
            sudo "$VHID_MANAGER" deactivate 2>/dev/null || true
        fi

        curl -fsSL -o /tmp/karabiner-vhid.pkg \
            "https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases/download/v${VHID_VERSION}/Karabiner-DriverKit-VirtualHIDDevice-${VHID_VERSION}.pkg"
        sudo installer -pkg /tmp/karabiner-vhid.pkg -target /
        rm /tmp/karabiner-vhid.pkg
    fi

    # Registers the driver extension with macOS. You still have to approve it
    # by hand in System Settings; this just makes it show up there.
    sudo "$VHID_MANAGER" forceActivate

    # Run the driver's daemon at boot. Karabiner Elements would do this, but we
    # only installed the standalone driver.
    VHID_PLIST="/Library/LaunchDaemons/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist"
    sudo cp "$SCRIPT_DIR/.config/kanata/mac/karabiner-vhid-daemon.plist" "$VHID_PLIST"
    sudo chown root:wheel "$VHID_PLIST"
    sudo launchctl bootout "system/org.pqrs.Karabiner-VirtualHIDDevice-Daemon" 2>/dev/null || true
    sudo launchctl bootstrap system "$VHID_PLIST"

    # sudo resets PATH, so hand it absolute paths
    BREW_BIN="$(command -v brew)"
    KANATA_BIN="$(command -v kanata)"

    # Pops the Input Monitoring and Accessibility dialogs. Older kanata builds
    # lack the flag, so don't let it kill the script.
    sudo "$KANATA_BIN" --macos-request-permissions 2>/dev/null || true

    # brew's formula already runs kanata as root against
    # ~/.config/kanata/kanata.kbd, which is where install-config.sh links the
    # mac config. So there's nothing to configure here.
    #
    # Only start it if the driver extension is approved and the config exists.
    # Starting it early just crash-loops until you finish the GUI steps.
    if systemextensionsctl list 2>/dev/null \
        | grep -q "org.pqrs.Karabiner-DriverKit-VirtualHIDDevice.*\[activated enabled\]" \
        && [[ -e "$HOME/.config/kanata/kanata.kbd" ]]; then
        sudo "$BREW_BIN" services restart kanata
        echo "Kanata installed and started!"
    else
        cat <<'KANATA_TODO'

Kanata is installed but not running yet. Two things need a human:

  1. Approve the driver extension.
     System Settings > General > Login Items & Extensions > Driver Extensions
     Turn on: org.pqrs.Karabiner-DriverKit-VirtualHIDDevice
     Jump there: open "x-apple.systempreferences:com.apple.ExtensionsPreferences"

  2. Grant kanata Input Monitoring and Accessibility. It needs BOTH, and it
     only complains about one at a time, so expect two rounds.
     System Settings > Privacy & Security > Input Monitoring
     System Settings > Privacy & Security > Accessibility
     kanata usually isn't listed. Click +, press cmd-shift-g, and enter:
       /opt/homebrew/bin/kanata
     Jump there:
       open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
       open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

Then start it:

  sudo brew services start kanata

Check that it worked:

  sudo launchctl list | grep -E 'kanata|org.pqrs'
  tail -f "$(brew --prefix)/var/log/kanata.log"

Two ways this breaks later:

  "connect_failed asio.system:2" repeating forever means the driver version
  doesn't match kanata's. See VHID_VERSION in install-deps.sh.

  After "brew upgrade kanata" the permissions go stale, because macOS pins the
  resolved path (.../Cellar/kanata/<version>/bin/kanata) and the version is in
  it. Remove kanata from both Privacy panes and re-add it.

KANATA_TODO
    fi

elif $INSTALL_KANATA && command -v apt-get &> /dev/null; then
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
    chsh -s "$(which zsh)" || echo "Warning: chsh failed (you can run zsh manually or set it in tmux.conf)"
fi

echo "Dependencies installed!"
