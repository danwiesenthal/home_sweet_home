# Writing Agent Instructions

## The AGENTS.md standard

AGENTS.md is an open standard (Linux Foundation, 60K+ projects) for providing instructions to AI coding agents. Claude Code, Cursor, Codex, GitHub Copilot, Windsurf, and others all read it. Using AGENTS.md keeps your instructions tool-agnostic.

Place an `AGENTS.md` at the root of your repository. Agents will read it when starting work in that directory. Child directories can have their own `AGENTS.md` for directory-specific instructions.

### What goes in AGENTS.md

- What the project is (enough context for an agent to orient itself)
- Key principles and conventions (the "how we work here" rules)
- Build, test, and lint commands
- Documentation structure pointers
- Things agents should never do

Keep it concise. AGENTS.md is loaded into the agent's context window on every session start. Under 200 lines is a good target.

### What does NOT go in AGENTS.md

- Full architecture docs (point to them instead)
- Task state (that lives in the task files)
- Historical decisions (commit history and docs have those)
- Anything that changes frequently (it's not a scratchpad)

## Tool-specific extensions

Some tools support additional instruction files with features beyond what AGENTS.md offers.

### Claude Code: CLAUDE.md

Claude Code reads both `AGENTS.md` and `CLAUDE.md`. CLAUDE.md adds:
- `@import` syntax to pull in other files
- Path-specific rules via `.claude/rules/` with YAML frontmatter
- Hierarchical loading (walks up the directory tree, loads all CLAUDE.md files)

If you need these features, use CLAUDE.md alongside AGENTS.md. CLAUDE.md takes precedence for Claude Code; other tools still read AGENTS.md.

### Cursor: .cursorrules

Cursor reads `AGENTS.md`, `CLAUDE.md`, and `.cursorrules`. The `.cursor/rules/` directory supports path-specific rules.

## Subagent definitions

When an orchestrator can spawn specialized subagents, each subagent needs a definition that covers:

1. **Role**: What this agent does (one sentence)
2. **Tools**: What capabilities the agent has (search, file read, file write, bash, etc.)
3. **Operating protocol**: How it should approach its work (search strategy, output format, quality standards)
4. **Output requirements**: What the caller expects back (raw data, synthesized report, code changes, etc.)

Focus on what the agent does, not where it sits in a hierarchy. Agent communication patterns (teams, direct spawning, message passing) are evolving quickly — the role definition should be stable regardless of how agents are composed.

### Example roles

Starting points, not a fixed set. Define the roles your project needs.

**Web searcher** (lightweight model): Fast information retrieval. Runs searches, returns raw excerpts with source URLs. Does not analyze or synthesize. Useful when the orchestrator will do the thinking.

**Research orchestrator** (powerful model): Multi-source research with synthesis. Formulates search strategy, executes searches, cross-references sources, delivers structured reports. Use when you need a complete answer, not raw data.

**Meta-strategist** (powerful model): Advises on agent orchestration. Which agents to deploy, parallel vs. sequential, context window efficiency. A thinking partner for multi-agent decisions.

**Test runner** (lightweight model): Executes project tests and reports results. Reads project documentation to find the right test commands.

**Test writer**: Creates tests for code. Unit, integration, end-to-end.

**Architecture reviewer**: Reviews code for abstraction leaks, encapsulation violations, and architectural cleanliness.

### Model selection principle

The model powering an agent should match the task's reasoning requirements, not the agent's "importance":

- **Lightweight models** (e.g., Haiku): Information retrieval, test execution, simple transformations. Tasks where speed and cost matter more than deep reasoning.
- **Mid-tier models** (e.g., Sonnet): Most coding and analysis tasks. Good balance of capability and cost.
- **Powerful models** (e.g., Opus): Complex reasoning, synthesis across many sources, architectural decisions. Tasks where getting the answer right matters more than speed.

### Settings override pattern

For agent and tool configuration that varies between team and individual:

- `settings.json` is checked into git. It contains team-wide defaults: shared permissions, tool configurations, deny lists.
- `settings.local.json` is gitignored. It contains local overrides: personal API keys, machine-specific paths, individual preferences.

The local file overrides the shared file. This lets a team agree on baseline configuration while allowing each developer (or each machine) to customize without merge conflicts.

See `../semantic_stack/agents/` for template definitions.
