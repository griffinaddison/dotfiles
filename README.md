# dotfiles

pre-requisites:


##installation:

# flaky one-liner:
```sudo apt-get install software-properties-common && sudo add-apt-repository ppa:neovim-ppa/unstable && sudo apt-get update && sudo apt-get install neovim && sudo apt-get install python-dev python-pip python3-dev python3-pip  && sudo apt-get install tmux && sudo apt-get install stow -y && cd && git clone --recurse-submodules https://github.com/griffinaddison/dotfiles.git ~/.dotfiles && cd ~/.dotfiles && stow . ```

# flaky one-liner (w/o sudo):
```apt-get install software-properties-common && add-apt-repository ppa:neovim-ppa/unstable && apt-get update && apt-get install neovim && apt-get install python-dev python-pip python3-dev python3-pip  && apt-get install tmux && apt-get install stow -y && cd && git clone --recurse-submodules https://github.com/griffinaddison/dotfiles.git ~/.dotfiles && cd ~/.dotfiles && stow . ```


# flaky one-liner (config only):
```sudo apt-get install stow -y && cd && git clone --recurse-submodules https://github.com/griffinaddison/dotfiles.git ~/.dotfiles && cd ~/.dotfiles && stow . ```
