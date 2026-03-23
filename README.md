# Percolate Stack

This is how I like to work with AI coding agents.

It's a collection of conventions, tools, and ideas for agentic software development -- things like structured task management, agent orchestration patterns, dev container setups, and voice-first interaction. Some of it is working tooling, some of it is documented thinking about where this kind of development is headed.

The organizing metaphor is a "semantic operating system": treat your development environment the way an OS treats hardware, but at the level of language and meaning rather than bytes and registers.

- **Files on disk are working memory** -- human-readable text that agents and humans both read and write
- **Git commits are clock cycles** -- every meaningful state change is a commit with a message that says why
- **Agents are processes** -- scheduled, prioritized, and coordinated
- **The task stack is the call stack** -- structured JSON, linted and version-controlled

This is opinionated and personal. It reflects how one developer likes to work. The patterns are general enough to adapt, but I'm not trying to build a product here -- just trying to capture and refine my own setup.

## What's in here

- **`docs/`** -- The ideas: vision, agent architecture, task management design, voice interaction, dev containers, and a handful of exploratory concepts that aren't fleshed out yet
- **`semantic_stack/`** -- The implementation: a three-file JSON task system with a semantic linter, git hooks, and agent role definitions
- **`devcontainer/`** -- Docker-in-Docker configuration so agents can run containers, test multi-service apps, and generally do everything a human developer can do
- **`dotfiles/`** -- Shell config, editor settings, tool preferences, Claude Code status line and skills

## Status

Work in progress. The documentation and core tooling are in place. The voice pipeline, model routing layer, and full containerized stack are future work. `semantic_stack/tasks/tasks_icebox.json` has the list of ideas queued up.

Initial version published March 22, 2026.
