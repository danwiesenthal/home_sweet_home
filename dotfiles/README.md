# Dotfiles and Local Environment

Personal development environment configuration. Opinionated, not required by the semantic stack itself.

## Contents

- `zshrc` -- Oh-My-Zsh config: plugins `(git macos zsh-autosuggestions zsh-syntax-highlighting)`, Python env vars, PATH additions
- `danwiesenthal.zsh-theme` -- Custom zsh prompt (based on Steve Losh's extravagant prompt); shows venv name from `$VIRTUAL_ENV`
- `batcharge.py` -- Battery charge indicator for the prompt's right side
- `gitconfig` -- Git user config, LFS filter, default branch `main`, Cursor as editor
- `cursor-settings.json` -- Cursor editor settings (auto-detect OS theme, ruff for Python, 88-char rulers)
- `cursor-extensions.txt` -- Canonical list of Cursor extensions; regenerate with `cursor --list-extensions`
- `Dan Terminal Theme.terminal` -- macOS Terminal.app profile
- `tool-preferences.md` -- Notes on preferred tools and why
- `claude-code/settings.json` -- Claude Code global settings (model, effort level, permissions, status line)
- `claude-code/CLAUDE.md` -- Global orchestration guide for Claude Code sessions
- `claude-code/statusline-command.sh` -- Two-line status bar: model/context/git on line 1; plan usage, session tokens, cache hit rate, cost on line 2
- `claude-code/skills/recall/` -- `/recall` skill: extracts what you said in prior conversations so you don't have to repeat yourself
- `claude-code/agents/` -- Custom agent definitions (web-searcher, research-orchestrator, test-runner, test-writer, architecture-cleanliness, meta-strategist)

## Fresh Mac setup

Assumes you have already installed: Xcode Command Line Tools (`xcode-select --install`), Homebrew, Oh My Zsh, Claude Code, and Cursor. Steps below pick up from there.

### 1. Install tools via brew

```bash
# Formulas
brew install node gh git tmux tree pre-commit uv ruff git-lfs

# Casks (GUI apps).
# Note: install istat-menus@6, NOT istat-menus (v7). v7's auto-updater will
# clobber a v6 install if both are present, even after renaming v7's .app.
brew install --cask orbstack lm-studio superwhisper istat-menus@6 bettertouchtool vivid-app

# Initialize git-lfs (one-time, system-wide)
git lfs install
```

### 2. Install Python via uv (replaces pyenv)

```bash
uv python install --default 3.13   # installs python/python3/python3.13 shims in ~/.local/bin
uv tool install ty                 # Astral's type checker
```

### 3. Oh My Zsh custom plugins

```bash
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
```

### 4. Copy dotfiles into place

```bash
# Shell
cp zshrc ~/.zshrc
cp danwiesenthal.zsh-theme ~/.oh-my-zsh/custom/themes/
cp batcharge.py ~/.batcharge.py && chmod +x ~/.batcharge.py
cp gitconfig ~/.gitconfig

# Cursor
cp cursor-settings.json "$HOME/Library/Application Support/Cursor/User/settings.json"

# Claude Code
mkdir -p ~/.claude/skills
cp claude-code/settings.json ~/.claude/settings.json
cp claude-code/CLAUDE.md ~/.claude/CLAUDE.md
cp claude-code/statusline-command.sh ~/.claude/statusline-command.sh && chmod +x ~/.claude/statusline-command.sh
cp -R claude-code/skills/recall ~/.claude/skills/recall
cp -R claude-code/agents ~/.claude/agents

# Disable Claude Code auto-compaction (separate file, preserves other keys)
python3 -c "import json, pathlib; p=pathlib.Path.home()/'.claude.json'; d=json.loads(p.read_text()) if p.exists() else {}; d['autoCompactEnabled']=False; p.write_text(json.dumps(d, indent=2)+'\n')"
```

### 5. Cursor extensions

The canonical list lives in `cursor-extensions.txt`. Install all:

```bash
xargs -n1 cursor --install-extension < cursor-extensions.txt
```

After adding or removing extensions in Cursor, regenerate the file:

```bash
cursor --list-extensions > cursor-extensions.txt
# then hand-trim to just the explicitly-wanted ones (Cursor auto-pulls some as deps, e.g. ms-python.python brings cursorpyright + debugpy; anysphere.remote-ssh ships with Cursor by default)
```

### 6. macOS Terminal theme

```bash
open "Dan Terminal Theme.terminal"   # imports into Terminal.app; then set as default profile
```

### 7. Authenticate GitHub CLI

```bash
gh auth login   # prefer HTTPS + token; adds credentials for git push too
```

## Manual / app-specific steps

- **OrbStack** -- Launch once to finish daemon setup.
- **SuperWhisper** -- Grant mic + accessibility permissions; bind push-to-talk (Option+Space). Custom modes/vocab/settings live at `~/Documents/superwhisper/`; sync them from the separate `superwhisper_config` repo (symlink or copy the `superwhisper/` subdir).
- **iStat Menus 6** -- Enter license; import settings:
  ```bash
  open -a "iStat Menus" dotfiles/istat-menus/v6-settings.ismp
  ```
  iStat Menus opens to the import dialog; accept.

  Reference for the preferred menu bar layout (`dotfiles/istat-menus/menubar-layout.png`), in order left-to-right:

  1. Network: connected indicator
  2. Network: throughput (down/up numbers)
  3. Network: sparkline
  4. Disk: throughput
  5. Disk: sparkline
  6. Memory: pie graph
  7. GPU: processor history graph
  8. CPU: processor history graph
  9. Sensors: one of the fans (top) + total watts (bottom)
  10. LM Studio
  11. Vivid
  12. SuperWhisper
  13. Time Machine
  14. Sound
  15. Bluetooth
  16. Wi-Fi
  17. Battery (iStat Menus version, not the native macOS one — disable the system battery menu)
  18. Control Center toggle (the macOS one for expanded menus)
  19. Clock: 24-hour time, no day-of-week, no date, no flashing colon

  ![menu bar layout](istat-menus/menubar-layout.png)

  **Do not install iStat Menus 7.** v7's bundle ID and auto-updater conflict with v6 — even with v7 renamed in /Applications, v7's LaunchDaemons (`/Library/LaunchDaemons/com.bjango.istatmenus.installer.plist` etc.) will silently replace v6 in place. If you ever do install v7 by accident, full purge requires sudo:
  ```bash
  sudo launchctl bootout system/com.bjango.istatmenus.{daemon,installer,installerhelper} 2>/dev/null
  sudo rm -f /Library/LaunchDaemons/com.bjango.istatmenus.{daemon,installer,installerhelper}.plist
  sudo rm -rf "/Library/Application Support/iStat Menus 7"
  rm -rf "/Applications/iStat Menus.app"
  rm -rf "$(brew --prefix)/Caskroom/istat-menus@6"  # so brew will reinstall v6 cleanly
  brew install --cask istat-menus@6
  ```
- **BetterTouchTool** -- Grant accessibility permissions, then import the keyboard shortcuts preset and apply app-level preferences:
  ```bash
  open dotfiles/bettertouchtool/keyboard.bttpreset       # accept the import dialog
  dotfiles/bettertouchtool/apply-preferences.sh          # quit BTT first; relaunch after
  ```
  Triggers (keyboard shortcuts) live in the `.bttpreset` JSON; app-level prefs (snapping behavior, etc.) live in `com.hegenberg.BetterTouchTool.plist` and are managed via the script. Raw app data is at `~/Library/Application Support/BetterTouchTool/` (SQLite DB — don't copy between machines raw).
- **Vivid** -- Launch once, enter license (or trial). Config lives inside the app; no repo-trackable file surfaced yet.
- **Cursor** -- `Cmd+Shift+P → Developer: Reload Window` if SynthWave '84 doesn't apply after first launch.
- **Terminal.app** -- Set "Dan Terminal Theme" as default profile after importing (Settings → Profiles → Default).

## Configs not yet tracked in this repo

The following app configs require manual export from a known-good machine. When you have them, drop them into the listed location and wire up into `Installation` above:

- **Vivid** settings → TBD (investigate preferences plist location after first configured run)
- **App licenses** (BTT, SuperWhisper, Vivid, iStat Menus v6) → kept out of repo; retrieve from your password manager and paste at first launch.

## Rationale

See `tool-preferences.md` for why these specific tools. Key opinions:

- **uv + ruff + ty** (Astral) is the modern Python triumvirate. No pyenv, no pip, no black, no isort.
- **Claude Code** as the primary agentic tool; Cursor as the editor.
- **Speech-to-text first**: SuperWhisper push-to-talk, transcription is local.
