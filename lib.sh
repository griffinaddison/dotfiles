#!/usr/bin/env bash
# Shared helpers for the install scripts.

# Put brew on PATH if it's installed but this shell doesn't know about it yet.
# Apple Silicon puts it in /opt/homebrew, Intel in /usr/local.
#
# Every install-*.sh runs as its own process, so a PATH change in one does not
# reach the others. Each script that needs brew has to call this itself.
load_brew() {
    local b
    for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [[ -x "$b" ]]; then
            eval "$("$b" shellenv)"
            return 0
        fi
    done
    return 1
}
