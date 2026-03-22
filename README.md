# Percolate Stack

A development environment framework for agentic coding. This repo captures a way of working with AI coding agents -- not just dotfiles, but a complete environment: task management, agent coordination, dev containers, voice interaction, and the conventions that tie them together.

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

See `docs/` for the ideas. See `semantic_stack/` for the implementation. See `devcontainer/` for running agents in containers with full Docker access.

## Status

Work in progress. Established March 2026.
