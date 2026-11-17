# Run only at the first real prompt, after .zshrc has defined the agent wrappers.
# No restore in zsh -ic commands, nested shells, tmux, or agent tool processes.
if [[ -n $REX_SESSION && -n $REX_BLOCK && -z $TMUX && -z $CLAUDECODE ]]; then
    autoload -Uz add-zsh-hook
    _rex_claude_restore_once() {
        add-zsh-hook -d precmd _rex_claude_restore_once
        [[ -t 0 && -t 1 && $REX_CLAUDE_AUTORESTORE != 0 && $REX_AUTORESTORE != 0 ]] || return 0
        python3 "$HOME/.config/rex/claude-session.py" restore $$
    }
    add-zsh-hook precmd _rex_claude_restore_once
fi

rex-claude-resume() {
    python3 "$HOME/.config/rex/claude-session.py" retry $$
}

# General name; keep rex-claude-resume for existing muscle memory.
rex-pane-resume() { rex-claude-resume; }

# A shared Codex daemon has the environment of the first pane that started it.
# Keep hooks local to this Rex pane, preserving existing aliases/permission flags.
if [[ -n $REX_SESSION && -n $REX_BLOCK && ${aliases[codex]-} != *--no-daemon* ]]; then
    alias codex="${aliases[codex]:-codex} --no-daemon"
fi
