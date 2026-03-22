# Tool Preferences

Tools and applications that make up the local development environment. These are personal preferences -- the semantic stack itself is tool-agnostic where possible.

## Package management

**Homebrew** for macOS package management. Install via https://brew.sh.

Key packages: `pyenv`, `pyenv-virtualenv`, `node`, `gh` (GitHub CLI), `git`, `tmux`, `tree`, `pre-commit`.

## Container runtime

**OrbStack** instead of Docker Desktop. Lighter weight, starts faster, uses fewer resources. Install via https://orbstack.dev or `brew install orbstack`.

**Colima** as an alternative CLI-only Docker runtime. Works well if you don't need OrbStack's GUI.

Both are Docker-compatible. The percolate stack's container configurations work with either.

## Editor

**Cursor** (based on VS Code). Key settings:
- Python formatting: Black formatter, 88-char line length (Black's default)
- isort with Black profile
- Auto-format on save with unused import cleanup
- pytest enabled with auto-discovery on save
- Word wrap at 88 chars

## Python

**pyenv** + **pyenv-virtualenv** for Python version and environment management. Never install to the global Python.

**UV** for fast package management within projects. **Ruff** for linting and formatting. **ty** for type checking. All three from Astral.

## Voice input

**Super Whisper** for speech-to-text on macOS. Push-to-talk via Option+Space. Runs transcription models locally.

## AI tools

**Claude Code CLI** as the primary agentic coding tool. Configured with custom subagents (see `../semantic_stack/agents/`).

**LM Studio** for local model management and inference. Preferred over Ollama for its model management UI and inference server.

## System monitoring

**iStat Menus** for system resource monitoring (CPU, memory, network, disk).

## Terminal

**Terminal.app** (macOS built-in) with a custom theme. **tmux** for session management, though note the scrollback interaction with Terminal.app (hold Shift to scroll Terminal's buffer when inside tmux, or use tmux copy mode with Ctrl+B then `[`).

**cool-retro-term** for fun.
