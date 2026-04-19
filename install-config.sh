#!/usr/bin/env bash
set -e

DOTFILES_DIR="$HOME/.dotfiles"

# Clone if not exists
if [[ ! -d "$DOTFILES_DIR" ]]; then
    git clone --recurse-submodules https://github.com/griffinaddison/dotfiles.git "$DOTFILES_DIR"
fi

cd "$DOTFILES_DIR"
git submodule update --init --recursive
stow --adopt .
git checkout -- .

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

# Symlink the OS-specific kanata config to ~/.config/kanata/kanata.kbd
# (kanata configs diverge: Mac has `fn`, Linux does not)
if [[ "$OSTYPE" == darwin* ]]; then
    KANATA_VARIANT="mac"
else
    KANATA_VARIANT="linux"
fi
KANATA_SRC="$DOTFILES_DIR/.config/kanata/$KANATA_VARIANT/kanata.kbd"
KANATA_DST="$HOME/.config/kanata/kanata.kbd"
if [[ -f "$KANATA_SRC" ]]; then
    mkdir -p "$(dirname "$KANATA_DST")"
    ln -sfn "$KANATA_SRC" "$KANATA_DST"
    echo "Kanata config linked: $KANATA_DST -> $KANATA_SRC"
fi

# Set Claude Code to vim mode
CLAUDE_JSON="$HOME/.claude.json"
if [[ -f "$CLAUDE_JSON" ]]; then
    jq '.editorMode = "vim"' "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp" && mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
else
    echo '{"editorMode":"vim"}' > "$CLAUDE_JSON"
fi
echo "Claude Code vim mode set"

echo "Config installed!"
