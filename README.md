# Percolate Stack

A development environment framework for agentic coding. Not just dotfiles, but a complete environment: task management, agent coordination, dev containers, voice interaction, and the conventions that tie them together.

The core idea is a "semantic operating system" where:

- **Files on disk are working memory** -- human-readable text files that agents and humans both read and write
- **Git commits are clock cycles** -- every meaningful state change is captured as a commit
- **Agents are processes** -- orchestrated, scheduled, and coordinated like OS processes
- **The task stack is the call stack** -- a structured, linted, version-controlled record of what's being worked on

This is opinionated and personal. It reflects how one developer likes to work, but the patterns are general enough to adapt.

## Structure

```
docs/           Core concepts and philosophy
semantic_stack/ Task management system, scripts, agent definitions
devcontainer/   Docker-in-Docker setup for empowered agents
dotfiles/       Shell config, themes, tool preferences
```

## Getting started

Clone this repo on a fresh machine, run the bootstrap setup (or point an AI coding agent at it and let it set things up), and get a configured development environment. Public dotfiles, but for agentic coding environments rather than just shell config.

See `docs/` for the concepts. See `semantic_stack/` for the task management implementation. See `devcontainer/` for running agents in containers with full Docker access. See `dotfiles/` for shell and editor configuration.

## Status

Work in progress. The documentation and tooling structure are in place. The voice pipeline, model routing, and full containerized stack are ahead. See `semantic_stack/tasks/` for what's planned.

Established March 2026.
