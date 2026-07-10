#!/usr/bin/env bash
# Copy stdin to the system clipboard by writing an OSC 52 escape straight to
# the terminal (ghostty), bypassing tmux's set-clipboard/Ms detection — which
# is unreliable on this Linux box because the xterm-ghostty terminfo ships
# without the Ms capability. ghostty handles OSC 52 itself, so this works the
# same on Linux and macOS.
#
# Usage (from tmux copy-pipe): osc52-copy.sh #{client_tty}
# tmux expands #{client_tty} to the attached terminal, e.g. /dev/pts/1.

tty="${1:-/dev/tty}"
b64=$(base64 | tr -d '\n')
# OSC 52: ESC ] 52 ; c ; <base64> BEL  -> set the "clipboard" (c) selection.
printf '\033]52;c;%s\007' "$b64" > "$tty"
