# Agent Instructions

This file provides guidance to AI coding agents working in this repository. It follows the open AGENTS.md standard and is read by Claude Code, Cursor, Codex, Copilot, and other tools.

## What this repo is

This is a development environment framework -- not an application. It defines conventions, tools, and configurations for agentic coding workflows. Changes here affect how agents operate in projects that adopt this framework.

## Key principles

- One README per directory. Information lives at one level of abstraction, one time. Higher levels point down to children for details but do not duplicate them.
- Code simplicity over cleverness. No comprehension debt. A developer should understand the code they're working with.
- Task state lives in `semantic_stack/tasks/` as structured JSON files, not in any tool-specific format.
- Every meaningful state change gets a git commit with a message that captures the semantic meaning of the change.
- Agents should be empowered to operate -- they need Docker, networking, CI access, not just file editing.

## Working conventions

- Do not auto-stage files. `git add` is a human review gate.
- No AI attribution in commit messages.
- Write durable comments that make sense in 6 months, not ephemeral ones relative to a diff.
- Prefer structured data (JSON, TOML) over unstructured prose for machine-readable state.
- When a tool doesn't work as expected, fix the instructions immediately so future agents don't waste tokens relearning.

## Documentation structure

Each directory has exactly one README.md that introduces what's in that directory. For deeper detail, follow the pointers to child directories. Do not duplicate information across levels.

See `docs/` for the full philosophy and design documents.
