# Run only at the first real prompt, after .zshrc has defined the Claude wrapper.
# No restore in zsh -ic commands, nested shells, tmux, or agent tool processes.
if [[ -n $REX_SESSION && -n $REX_BLOCK && -z $TMUX && -z $CLAUDECODE ]]; then
    autoload -Uz add-zsh-hook
    _rex_claude_restore_once() {
        add-zsh-hook -d precmd _rex_claude_restore_once
        [[ -t 0 && -t 1 && $REX_CLAUDE_AUTORESTORE != 0 ]] || return 0
        python3 "$HOME/.config/rex/claude-session.py" restore $$
    }
    add-zsh-hook precmd _rex_claude_restore_once
fi

rex-claude-resume() {
    python3 "$HOME/.config/rex/claude-session.py" retry $$
}
