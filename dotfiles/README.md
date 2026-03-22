# Dotfiles and Local Environment

Personal development environment configuration. These are preferences, not requirements of the semantic stack. Use what works for you.

## Contents

- `zshrc` -- Oh-My-Zsh configuration with pyenv, git, and macOS plugins
- `danwiesenthal.zsh-theme` -- Custom zsh prompt (based on Steve Losh's extravagant prompt)
- `batcharge.py` -- Battery charge indicator for the prompt's right side
- `gitconfig` -- Git user config, LFS, default branch
- `tool-preferences.md` -- Notes on preferred tools and why

## Installation

These files go in your home directory (with a leading dot):

```bash
cp zshrc ~/.zshrc
cp danwiesenthal.zsh-theme ~/.oh-my-zsh/custom/themes/
cp batcharge.py ~/.batcharge.py && chmod +x ~/.batcharge.py
cp gitconfig ~/.gitconfig
```

Edit paths and usernames to match your setup before using.
