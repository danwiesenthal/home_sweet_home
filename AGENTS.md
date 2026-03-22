# Agent Instructions

This repo defines a development environment framework for agentic coding workflows. It's conventions, tools, and configs — not an application. If you're an agent working here, changes you make affect how agents work in projects that use this framework.

## Input

User input likely comes from a speech-to-text dictation pipeline. Expect transcription errors: homophones, missing punctuation, run-on sentences, duplicated phrases. Interpret intent, not literal text. Common mishearings: "cloud"/"Claude", "claw"/"claude", "to do"/"todo". Only ask for clarification when the meaning is genuinely ambiguous.

## Principles

- **One README per directory.** Information at one level, one time. Higher levels point down but don't duplicate.
- **Simple code.** No comprehension debt. If you can't follow it in one read, simplify it.
- **Task state is JSON on disk.** `semantic_stack/tasks/` has the structured task files. Not Jira, not GitHub Issues, not markdown checklists.
- **Commits are semantic.** Every commit message says *why*, not just what changed.
- **Agents get real tools.** Docker, networking, CI access — not just file editing.
- **Time is the bottleneck, not tokens.** In synchronous sessions, use subagents aggressively. Parallelize independent work. Run slow operations in the background. The human is waiting — broaden the work rather than serialize it.
- **Preserve context.** Delegate verbose operations (web searches, test output, large file reads) to subagents. They return summarized results. The orchestrator's context stays clean for the work that matters.

## Conventions

- Don't auto-stage files. `git add` is a human review gate — the developer stages after reviewing diffs.
- No AI attribution in commits. No "Co-Authored-By: Claude" or "Generated with" footers.
- Comments should make sense in 6 months. Don't write comments relative to a diff ("moved this here", "removed the old version").
- Documentation should read as natural prose. Avoid obvious AI writing patterns: no "delve", no "it's important to note", no emoji, no excessive bolding/italics, no formulaic structure.
- Prefer structured data (JSON, TOML) over prose when machines need to read it.
- If a tool or instruction doesn't work, fix it immediately. Don't waste tokens relearning what the last agent already figured out.
- Don't give time estimates. Describe relative complexity instead ("bigger change" vs "straightforward"). Duration predictions are not meaningful for agentic work.
- Do what was asked. If you can't do exactly what was requested, say so and explain why. Never silently substitute an approximation.
- When searching the web, always include the current month and year in queries to avoid stale results.

## Conversation history on disk

All conversation turns are logged as JSONL under `~/.claude/projects/`. Each session gets a `<session-id>.jsonl` file. User messages have `role: "human"`. Use this to recall what the user said earlier — in this session or a recent one. Spawn a subagent to read the file and extract user messages. The user should never have to repeat themselves.

## Where things are

- `docs/` — design philosophy, architecture, ideas
- `semantic_stack/tasks/` — active tasks, icebox, archive (all JSON)
- `semantic_stack/scripts/` — linter, git hooks
- `semantic_stack/agents/` — agent role templates
- `devcontainer/` — container configs for empowered agent environments
- `dotfiles/` — shell, editor, tool configuration
