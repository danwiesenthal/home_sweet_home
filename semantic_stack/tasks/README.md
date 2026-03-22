# Task Management

## The three-file system

Task state is stored across three JSON files:

| File | Purpose |
|------|---------|
| `tasks.json` | Active work: current tasks, backlog, recent completions, and project context |
| `tasks_archive.json` | Completed tasks moved out of the active file to keep it focused |
| `tasks_icebox.json` | Ideas and future work that aren't queued yet |

The split exists for a practical reason: a single file grows unwieldy fast. Active context should be small enough that an agent can read it in one pass and understand the current state. Completed work and speculative ideas don't need to compete for that attention.

## Task flow

```
icebox --> backlog --> current --> completed --> archive
```

Tasks start as rough ideas in the icebox. When they're worth committing to, they move to the backlog in `tasks.json`. When work begins, they move to `current`. When done, they land in `completed`. Periodically, completed tasks get swept into the archive.

This is a one-way flow under normal conditions. A task can move backward (e.g., current back to backlog if priorities shift), but that should be an explicit decision, not drift.

## Why JSON, not prose

Anthropic's own research confirms what we've found in practice: LLMs are more reliable at reading and updating structured data than free-form text. JSON gives you:

- Predictable field names that agents can find without guessing
- Machine-parseable structure that enables validation and linting
- Diffs that are meaningful in version control
- A natural schema that constrains what agents can do (they fill in fields, not invent formats)

Prose task descriptions like "TODO: fix the thing" scattered across markdown files are invisible to automated tooling, hard to deduplicate, and easy to lose track of.

## Why not tool-specific task tracking

Tools like Cursor's `TodoWrite`, GitHub Issues, or Jira all have the same problem: they store state somewhere the other tools can't see it. `TodoWrite` state is invisible to humans and doesn't persist across sessions. GitHub Issues require API calls and internet access. Jira is Jira.

JSON files on disk are the universal interface. Every tool -- every agent, every editor, every shell script -- can read and write them. They version-control naturally. They diff cleanly. They're the filesystem as working memory.

## Task structure

Each task has at minimum:

- `id`: A short, kebab-case identifier (used in dependencies and references)
- `title`: Human-readable summary
- `description`: What needs to happen and why

Optional fields:

- `depends_on`: List of task IDs that must complete first (forms a DAG)
- `status`: Explicit status when needed beyond positional (which section it's in)
- `added_date`, `completed_date`: Timestamps for tracking
- `notes`: Implementation details, learnings, or context discovered during work

## Dependencies

Tasks can declare dependencies on other tasks via `depends_on`. This forms a directed acyclic graph (DAG), not a linear list. An agent picking work should check that a task's dependencies are satisfied before starting it.

The DAG is validated by `lint_tasks.py` -- cycles are caught, references to nonexistent tasks are flagged.

## Context block

`tasks.json` includes a `context` block for ambient state that doesn't belong to any single task but is needed by agents to orient themselves: active branches, environment details, key document pointers. This is the "where are we" that an agent reads before picking up work.

## Modification counter and review cycles

`tasks.json` tracks a `modification_count` in its meta block. Every commit that touches the task files increments this counter (enforced by a post-commit hook). At configurable thresholds, the system can trigger a review cycle -- a PM-oriented agent pass that checks for stale tasks, missing context, priority drift, and overall coherence.

The thresholds are configurable per project. Some teams want review every 10 modifications; others want it less frequently. The mechanism is the counter and the hook; the policy is up to you.

## Validation

`lint_tasks.py` validates both structure and semantics:

- **Structural**: Required fields present, valid JSON, no duplicate IDs, dependency references resolve
- **Semantic**: Descriptions aren't empty placeholders, completed tasks have dates, current tasks aren't stale

The pre-commit hook runs this automatically. See `../scripts/lint_tasks.py` for the implementation.
