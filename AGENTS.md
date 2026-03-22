# Agent Instructions

This repo defines a development environment framework for agentic coding workflows. It's conventions, tools, and configs — not an application. If you're an agent working here, changes you make affect how agents work in projects that use this framework.

## Principles

- **One README per directory.** Information at one level, one time. Higher levels point down but don't duplicate.
- **Simple code.** No comprehension debt. If you can't follow it in one read, simplify it.
- **Task state is JSON on disk.** `semantic_stack/tasks/` has the structured task files. Not Jira, not GitHub Issues, not markdown checklists.
- **Commits are semantic.** Every commit message says *why*, not just what changed.
- **Agents get real tools.** Docker, networking, CI access — not just file editing.

## Conventions

- Don't auto-stage files. `git add` is a human review gate — the developer stages after reviewing diffs.
- No AI attribution in commits. No "Co-Authored-By: Claude" or "Generated with" footers.
- Comments should make sense in 6 months. Don't write comments relative to a diff ("moved this here", "removed the old version").
- Prefer structured data (JSON, TOML) over prose when machines need to read it.
- If a tool or instruction doesn't work, fix it immediately. Don't waste tokens relearning what the last agent already figured out.

## Where things are

- `docs/` — design philosophy, architecture, ideas
- `semantic_stack/tasks/` — active tasks, icebox, archive (all JSON)
- `semantic_stack/scripts/` — linter, git hooks
- `semantic_stack/agents/` — agent role templates
- `devcontainer/` — container configs for empowered agent environments
- `dotfiles/` — shell, editor, tool configuration
