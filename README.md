# home_sweet_home

This is how I like to work with AI coding agents.

Think of it as a modern take on dotfiles -- except instead of just shell config and editor settings, it includes patterns for working with multiple agents, structured task tracking, and dev container setups. Some of it is working tooling, some of it is documented thinking about where this kind of development is headed.

The organizing metaphor is a "semantic operating system": treat the dev environment the way an OS treats hardware, but at the level of language and meaning -- files as working memory, git commits as clock cycles, agents as processes.

This is opinionated and personal. It reflects how one developer likes to work. The patterns are general enough to adapt, but I'm not trying to build a product here -- just a place to capture and refine my own setup.

## What's in here

- **`docs/`** -- The ideas: vision, agent architecture, task management design, voice interaction, dev containers, and a handful of exploratory concepts that aren't fleshed out yet
- **`semantic_stack/`** -- The implementation: a three-file JSON task system with a semantic linter, git hooks, and agent role definitions
- **`devcontainer/`** -- Docker-in-Docker configuration so agents can run containers, test multi-service apps, and generally do everything a human developer can do
- **`dotfiles/`** -- Shell config, editor settings, tool preferences, Claude Code status line and skills

## Status

Work in progress. The documentation and core tooling are in place. The voice pipeline, model routing layer, and full containerized stack are future work. `semantic_stack/tasks/tasks_icebox.json` has the list of ideas queued up.

Initial version published March 22, 2026.
