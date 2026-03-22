# Dotfiles and Local Environment

Personal development environment configuration. These are preferences, not requirements of the semantic stack. Use what works for you.

## Contents

- `zshrc` -- Oh-My-Zsh configuration with pyenv, git, and macOS plugins
- `danwiesenthal.zsh-theme` -- Custom zsh prompt (based on Steve Losh's extravagant prompt)
- `batcharge.py` -- Battery charge indicator for the prompt's right side
- `gitconfig` -- Git user config, LFS, default branch
- `cursor-settings.json` -- Cursor (VS Code-based) editor settings
- `tool-preferences.md` -- Notes on preferred tools and why
- `claude-code/settings.json` -- Claude Code global settings (model, permissions, status line)
- `claude-code/statusline-command.sh` -- Two-line status bar: model/context/git on line 1, plan usage with pacing markers, session tokens, cache hit rate, and cost on line 2
- `claude-code/skills/recall/` -- `/recall` skill: extracts what you said in prior conversations so you don't have to repeat yourself. Runs a Sonnet subagent that reads conversation JSONL logs, filters system noise, and returns a structured briefing of your goals, requests, decisions, and corrections

## Installation

These files go in your home directory (with a leading dot):

```bash
cp zshrc ~/.zshrc
cp danwiesenthal.zsh-theme ~/.oh-my-zsh/custom/themes/
cp batcharge.py ~/.batcharge.py && chmod +x ~/.batcharge.py
cp gitconfig ~/.gitconfig
cp claude-code/settings.json ~/.claude/settings.json
cp claude-code/statusline-command.sh ~/.claude/statusline-command.sh
cp -r claude-code/skills/recall ~/.claude/skills/recall

```

Also add `"autoCompactEnabled": false` to `~/.claude.json` to disable auto-compaction.

Edit paths and usernames to match your setup before using.
