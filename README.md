# dotfiles

Config for zsh, tmux, neovim, ghostty, kitty, skhd and kanata. Works on macOS
and Debian/Ubuntu.

## Install

```bash
git clone https://github.com/griffinaddison/dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh
```

`install.sh` just runs the two halves in order. Either works on its own:

```bash
~/.dotfiles/install-deps.sh    # packages, plus the optional components below
~/.dotfiles/install-config.sh  # stow the dotfiles (needs stow)
```

On macOS, `install-deps.sh` installs Homebrew first if it isn't there.

### Straight from the internet

```bash
curl -fsSL https://raw.githubusercontent.com/griffinaddison/dotfiles/main/remote-install.sh | sh
```

That clones the repo and gives you a menu. To skip the menu:

```bash
curl -fsSL https://raw.githubusercontent.com/griffinaddison/dotfiles/main/remote-install.sh \
  | sh -s -- -y --ghostty --kanata
```

| Flag | Effect |
| --- | --- |
| `-y` | Don't prompt for anything |
| `--ghostty` | Also install Ghostty (needs `-y`) |
| `--kanata` | Also install kanata (needs `-y`) |
| `--config-only` | Only stow the dotfiles |
| `--deps-only` | Only install packages |

## Optional components

`install-deps.sh` asks about both of these. Answer `y`, or pass the flags above.

### Ghostty

Installs the nightly. macOS gets the `.dmg`, Linux gets an AppImage and a
desktop entry.

### kanata

Caps Lock becomes Esc on tap and Ctrl on hold. Holding Space gives you arrows on
`hjkl` and media keys on the number row. The top-left key becomes backtick.

The Mac and Linux configs differ, because only Mac has an `fn` key. They live in
`.config/kanata/mac/` and `.config/kanata/linux/`, and `install-config.sh` links
the right one to `~/.config/kanata/kanata.kbd`.

Linux is fully automatic: build with cargo, install a systemd unit, start it.

macOS can't be. kanata types through Karabiner's DriverKit driver, and macOS
only lets a human approve a driver extension or grant Input Monitoring.
`install-deps.sh` does everything else, then prints exactly what to click. It
takes a few minutes and needs your password.

Two macOS things that will bite you later:

- **kanata and the driver speak a versioned protocol**, and each kanata release
  supports exactly one driver version. `VHID_VERSION` in `install-deps.sh` is
  pinned next to the kanata version it was checked against, and the script warns
  if brew installs a different one. Symptom of a bad pin: kanata takes the
  keyboard, then logs `connect_failed asio.system:2` forever. Nothing says
  "wrong version".
- **`brew upgrade kanata` breaks it.** macOS pins the resolved
  `Cellar/kanata/<version>/bin/kanata` path for the Input Monitoring and
  Accessibility grants, so both go stale on upgrade. `sudo brew services` also
  takes root ownership of those paths, so the upgrade itself needs `sudo rm`
  first. And the driver pin probably changes too. Treat it as a real task.

Useful once it's running:

```bash
sudo brew services restart kanata          # after editing the config
tail -f /opt/homebrew/var/log/kanata.log
sudo brew services stop kanata             # if the keyboard goes weird
```

kanata also force-quits on `lctl+spc+esc`. Those are physical keys as kanata
sees them, so "esc" means the top-left key.

---

### Flaky one-liner
```bash
sudo apt-get install -y build-essential gcc make cmake lua5.4 liblua5.4-dev clangd-12 wget && pip install pyright && curl -fsSL https://raw.githubusercontent.com/mklement0/n-install/stable/bin/n-install | bash -s 22 && curl -LO https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep_14.1.0-1_amd64.deb && sudo dpkg -i ripgrep_14.1.0-1_amd64.deb && cd ~ && wget https://luarocks.org/releases/luarocks-3.11.1.tar.gz && tar zxpf luarocks-3.11.1.tar.gz && cd luarocks-3.11.1 && ./configure && make && sudo make install && sudo luarocks install luasocket && sudo apt-get install software-properties-common -y && sudo add-apt-repository -y ppa:neovim-ppa/unstable && sudo apt-get update && sudo apt-get install neovim -y && sudo apt-get install tmux -y && git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm && sudo apt-get install stow -y && cd && git clone --recurse-submodules https://github.com/griffinaddison/dotfiles.git ~/.dotfiles && cd ~/.dotfiles && stow .
```

### Claude conversations in Rex after a reboot

Rex's configuration lives in `.config/rex/init.lua`. Rex restores layouts, but
currently starts fresh shells instead of restoring the programs inside them.
The Claude hooks in `.claude/settings.json` and the first-prompt hook sourced
by `.zshrc` restore the conversation associated with each pane.

`SessionStart` and `UserPromptSubmit` save the exact conversation ID, working
directory and auth mode under `${XDG_STATE_HOME:-~/.local/state}/rex/claude-panes`.
Records are private, atomically replaced and flushed to disk; no credentials or
conversation text are copied. Rex host, session and block IDs keep panes separate.
When a pane's original zsh starts under a new Rex server instance, it resumes
that ID once. Ordinary nested shells and agent subprocesses do not restore it.

Intentional exits, logout and conversation switches deactivate the old mapping;
the next SessionStart records the replacement. Crashes and shutdown exits stay
recoverable. A failed launch leaves a shell instead of retrying endlessly.
Use `rex-claude-resume` in that pane to retry. Set `REX_CLAUDE_AUTORESTORE=0`
before opening a shell to disable automatic restoration.

Requires zsh, Python 3 and Rex on PATH, and the usual dotfile symlinks. API sessions
use the `claude` function from your `.zshrc`; subscription/default sessions use
`command claude`. Authentication remains machine-local. Existing running sessions
are saved on their next prompt submission; newly started/resumed sessions are
saved immediately. State is local to each machine and is not committed to git.

This restores saved conversations, not interrupted shell jobs, subagents,
terminal scrollback, or external connections. A reboot can still lose transcript
writes that Claude had not flushed. No server restart is needed to install it.

Validation: `python3 -m unittest discover -s tests -p test_rex_claude.py`.
References: [Rex restart behavior](https://www.superlogical.com/rex/docs/linux/upgrading)
and [Claude session hooks](https://code.claude.com/docs/en/hooks#sessionstart).

### Codex and Neovim recovery in Rex

The same per-pane recovery now covers Codex and Neovim. The most recently
checkpointed app owns the pane's record; old Claude mappings remain compatible.
The helper keeps its original `claude-session.py` filename and `claude-panes`
state directory to preserve those existing records. Use `rex-pane-resume` to
retry any app, or set `REX_AUTORESTORE=0` to disable automatic restoration.

Codex hooks in `.codex/hooks.json` save the exact thread ID at session start and
prompt submission. Recovery runs `codex resume <id>` through your normal zsh
configuration with `--no-daemon` inside Rex. The shared daemon inherits stale
pane environment variables, so hooks also verify that they descend from the
pane’s foreground Codex process before recording anything. Existing running
shared-daemon sessions need reopening for new thread switches to be tracked;
their current thread can be seeded without interrupting them.
Codex requires new hooks to be reviewed in `/hooks` on each
machine; trust only the three recovery commands after reviewing them. Trust
records are machine-local and are not committed. Codex's `SessionEnd` currently
reports only `other`, so a delivered end event disables recovery; abrupt power
loss leaves the last record available. No prompts are automatically submitted.
See the [Codex hooks reference](https://learn.chatgpt.com/docs/hooks).

Neovim checkpoints its tabs, splits, files, folds and cursor positions every
five seconds, on focus loss and after writes. Modified regular buffers,
including unnamed drafts, are saved separately in the private pane record.
Recovery brings them back as modified buffers without overwriting files on disk.
It uses `nvim -n` to avoid a stale swap file blocking unattended startup; existing
swap files are left intact for manual recovery. The last few seconds of edits
can be lost. Terminal jobs, plugin UI state and undo history aren't checkpointed.
Normal `:q`/`:qa` exits disable reopening; fatal exits leave the checkpoint active.

Test both helpers and actual Neovim save/recovery with:
`python3 -m unittest discover -s tests -p 'test_rex_*.py'`.
The Neovim test expects the dotfiles installed at their usual symlink locations.
