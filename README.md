# dotfiles

pre-requisites:


##installation:

# flaky one-liner:
```sudo apt-get install software-properties-common -y && sudo add-apt-repository ppa:neovim-ppa/unstable && sudo apt-get update && sudo apt-get install neovim -y && sudo apt-get install python-dev python-pip -y && sudo apt-get install tmux -y && sudo apt-get install stow -y && cd && git clone --recurse-submodules https://github.com/griffinaddison/dotfiles.git ~/.dotfiles && cd ~/.dotfiles && stow . ```

# flaky one-liner (w/o sudo):
```apt-get install software-properties-common -y && add-apt-repository ppa:neovim-ppa/unstable && apt-get update && apt-get install neovim -y && apt-get install python3-dev python3-pip -y && apt-get install tmux -y && apt-get install stow -y && cd && git clone --recurse-submodules https://github.com/griffinaddison/dotfiles.git ~/.dotfiles && cd ~/.dotfiles && stow . ```


# flaky one-liner (config only):
```sudo apt-get install stow -y && cd && git clone --recurse-submodules https://github.com/griffinaddison/dotfiles.git ~/.dotfiles && cd ~/.dotfiles && stow . ```
