# Agent Definitions

Subagent definitions for this setup.

These templates follow the Claude Code agent definition format (markdown with YAML frontmatter), but the concepts are tool-agnostic. Adapt the format if using a different agent framework.

## Contents

- `web-searcher.md` -- Lightweight information retrieval
- `research-orchestrator.md` -- Comprehensive research with synthesis
- `meta-strategist.md` -- Agent orchestration advisor

## Installation (Claude Code)

Copy agent definitions to `~/.claude/agents/` (user-wide) or `.claude/agents/` (project-specific).

## Writing new agents

See `../../docs/agent-instructions.md` for guidelines on writing effective agent definitions.
