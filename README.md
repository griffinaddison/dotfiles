# dotfiles

pre-requisites:


##installation:

# flaky one-liner (please don't laugh):
```sudo apt-get install -y build-essential gcc make cmake lua5.4 liblua5.4-dev clangd-12 wget  && curl -fsSL https://raw.githubusercontent.com/mklement0/n-install/stable/bin/n-install | bash -s 22 && curl -LO https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep_14.1.0-1_amd64.deb && sudo dpkg -i ripgrep_14.1.0-1_amd64.deb && cd ~ && wget https://luarocks.org/releases/luarocks-3.11.1.tar.gz && tar zxpf luarocks-3.11.1.tar.gz && cd luarocks-3.11.1 && ./configure && make && sudo make install && sudo luarocks install luasocket && sudo apt-get install software-properties-common -y && sudo add-apt-repository -y ppa:neovim-ppa/unstable && sudo apt-get update && sudo apt-get install neovim -y && sudo apt-get install python-dev python-pip -y && sudo apt-get install tmux -y && sudo apt-get install stow -y && cd && git clone --recurse-submodules https://github.com/griffinaddison/dotfiles.git ~/.dotfiles && cd ~/.dotfiles && stow . ```

# flaky one-liner (w/o sudo):
``` apt-get install -y build-essential gcc make cmake lua5.4 liblua5.4-dev clangd-12 wget && curl -fsSL https://raw.githubusercontent.com/mklement0/n-install/stable/bin/n-install | bash -s 22 && curl -LO https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep_14.1.0-1_amd64.deb &&  dpkg -i ripgrep_14.1.0-1_amd64.deb && cd ~ && wget https://luarocks.org/releases/luarocks-3.11.1.tar.gz && tar zxpf luarocks-3.11.1.tar.gz && cd luarocks-3.11.1 && ./configure && make &&  make install &&  luarocks install luasocket &&  apt-get install software-properties-common -y &&  add-apt-repository -y ppa:neovim-ppa/unstable &&  apt-get update &&  apt-get install neovim -y &&  apt-get install python-dev python-pip -y &&  apt-get install tmux -y &&  apt-get install stow -y && cd && git clone --recurse-submodules https://github.com/griffinaddison/dotfiles.git ~/.dotfiles && cd ~/.dotfiles && stow . ```


# flaky one-liner (config only):
```sudo apt-get install stow -y && cd && git clone --recurse-submodules https://github.com/griffinaddison/dotfiles.git ~/.dotfiles && cd ~/.dotfiles && stow . ```
