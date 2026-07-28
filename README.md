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
