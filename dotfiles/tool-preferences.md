# Tool Preferences

Tools and applications that make up the local development environment. These are personal preferences -- the semantic stack itself is tool-agnostic where possible.

## Package management

**Homebrew** for macOS package management. Install via https://brew.sh.

Key formulas: `node`, `gh` (GitHub CLI), `git`, `tmux`, `tree`, `pre-commit`, `uv`, `ruff`.

## Container runtime

**OrbStack** instead of Docker Desktop. Lighter weight, starts faster, uses fewer resources. Install via https://orbstack.dev or `brew install orbstack`.

**Colima** as an alternative CLI-only Docker runtime. Works well if you don't need OrbStack's GUI.

Both are Docker-compatible. The semantic stack's container configurations work with either.

## Editor

**Cursor** (based on VS Code). Key settings:
- Python formatting: Ruff (black-compatible output, 88-char line length by default)
- Ruff handles import sorting too (isort-compatible with black profile)
- Auto-format on save + organize imports + fix-all on save
- pytest enabled with auto-discovery on save
- Word wrap at 88 chars

Cursor extensions: `charliermarsh.ruff`, `stkb.rewrap`, Pylance (auto-pulled as `ms-python.python` / `anysphere.cursorpyright`).

## Python

**uv** for everything Python — version management, virtualenvs, package installs, project runners. Replaces pyenv + pyenv-virtualenv + pip + virtualenv + pip-tools. Never install to the global Python.

- `uv python install --default 3.13` — installs Python and puts `python`/`python3` shims in `~/.local/bin`
- `uv init` / `uv venv` / `uv run` — per-project environments
- `uv tool install <cli>` — global CLI tools in isolated envs

**Ruff** for linting, formatting, and import sorting — supersedes black and isort (drop-in formatter; import sorting is isort-equivalent with black profile). **ty** for type checking.

The modern Python triumvirate: **uv + ruff + ty** (all from Astral). Install ty as a uv tool: `uv tool install ty`.

## Voice input

**Super Whisper** for speech-to-text on macOS. Push-to-talk via Option+Space. Runs transcription models locally.

## Input and window management

**BetterTouchTool** for custom trackpad gestures, keyboard shortcuts, and window snapping. Install via `brew install --cask bettertouchtool`.

## AI tools

**Claude Code CLI** as the primary agentic coding tool. Configured with custom subagents (see `../semantic_stack/agents/`).

**LM Studio** for local model management and inference. Preferred over Ollama for its model management UI and inference server.

## System monitoring

**iStat Menus** for system resource monitoring (CPU, memory, network, disk).

## Display

**Vivid** (getvivid.app) to unlock full panel brightness on macOS (reaches HDR-level brightness on non-HDR content). Install via `brew install --cask vivid-app`.

## Terminal

**Terminal.app** (macOS built-in) with a custom theme. **tmux** for session management, though note the scrollback interaction with Terminal.app (hold Shift to scroll Terminal's buffer when inside tmux, or use tmux copy mode with Ctrl+B then `[`).

**cool-retro-term** for fun.
