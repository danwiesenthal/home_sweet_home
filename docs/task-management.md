# Task Management

## The problem

AI coding agents are stateless between sessions. They lose context, forget what was planned, and can't see what other agents have done. Most task tracking solutions make this worse:

- **Tool-specific formats** (Cursor TodoWrite, GitHub Issues) lock state into silos. One agent can't see another's todo list.
- **Prose-based tracking** (markdown checklists, progress logs) is ambiguous. Agents interpret free text inconsistently and have no reliable way to update it.
- **External systems** (Jira, Linear) require API access, credentials, and network connectivity that container-based agents may not have.

The filesystem is the one interface every tool shares. JSON on disk is the universal protocol.

## Design decisions

### Structured JSON over prose

LLMs handle structured data more reliably than free text. Given a JSON schema with defined fields, an agent fills in those fields predictably. Given a blank markdown file, it invents its own format every time.

JSON also enables machine validation. A linter can check that every task has an ID, that dependency references resolve, that completed tasks have dates. You can't lint a bullet list.

### Three-file separation

Task state lives in three files:

| File | Contents |
|------|----------|
| `tasks.json` | Active work: current, backlog, recently completed, and project context |
| `tasks_archive.json` | Completed tasks moved out of the active file |
| `tasks_icebox.json` | Ideas and future work not yet committed to |

The split serves a practical purpose: an agent reads the active file on every session start. That file needs to be small enough to parse quickly and understand in one pass. Historical completions and speculative ideas don't belong in the hot path.

The three files cover the full lifecycle without any single file growing unwieldy. A project with 200 completed tasks and 50 icebox ideas still has a focused, readable `tasks.json` with only the 5-15 tasks that matter right now.

### Git as the state machine

Every meaningful state change to the task files gets a git commit. This isn't just version control; it's the system's clock. Each commit is a discrete state transition with a timestamp, an author, and a message that captures why the change happened.

This gives you:

- **Full history**: `git log -- semantic_stack/tasks/` shows every state change
- **Blame tracking**: Who (or what agent) made each change and when
- **Rollback**: Bad state? Revert the commit
- **Collaboration**: Multiple agents can work on tasks if they're on different branches and merge cleanly

### Dependencies as a DAG

Tasks can declare `depends_on` as a list of task IDs. This forms a directed acyclic graph, not a linear queue. An agent checking for available work should look at tasks whose dependencies are all satisfied, not just the first item in the backlog.

The linter validates the DAG: it catches cycles, flags references to nonexistent tasks, and ensures the graph is well-formed.

### Modification counter and review cycles

The `modification_count` field in `tasks.json` meta is incremented by a post-commit hook every time a task file is committed. This counter serves as a trigger for periodic review.

At configurable thresholds (set in `review_thresholds`), the system can trigger a review cycle. The review is a higher-level pass -- not checking individual task correctness (the linter does that) but checking project coherence:

- Are there stale tasks that should be icebox'd or dropped?
- Has the context block drifted from reality?
- Are priorities still aligned with goals?
- Are there implicit dependencies that should be explicit?

The thresholds are configurable per project. One possible approach is Fibonacci-spaced intervals (review at 5, 13, 21 modifications), which front-loads reviews when a project is young and spaces them out as it matures. But any schedule that fits your workflow is fine -- the mechanism is the counter, not a specific policy.

A dedicated PM-oriented agent prompt can handle these reviews. The working agents focus on executing tasks; a periodic review agent focuses on the health of the task graph itself.

## Task lifecycle

```
icebox --> backlog --> current --> completed --> archive
```

### Icebox

Raw ideas. Low-commitment entries that capture something worth remembering. No format required beyond an ID and a description. Ideas live here until someone decides they're worth doing.

### Backlog

Committed work that hasn't started yet. Tasks here should have enough description that an agent can pick one up and start without asking questions. Dependencies should be declared.

### Current

Actively being worked on. Ideally 1-3 tasks -- anything more suggests unclear priorities. When an agent starts a session, it looks at `current` first.

### Completed

Recently finished work. Stays in `tasks.json` for a while so agents have context on what just happened. Periodically swept to the archive.

### Archive

Historical record. Grouped by phase or time period. Useful for understanding how the project evolved, but not read during normal operation.

## Task structure

Required fields:

- `id` -- Short, kebab-case identifier. Used in dependency references and must be unique across all three files.
- `description` -- What needs to happen and why. Should be specific enough for an agent to act on.

Common optional fields:

- `title` -- Human-readable summary (shorter than description)
- `depends_on` -- List of task IDs that must complete first
- `added_date`, `completed_date` -- ISO date strings
- `notes` -- Implementation details, learnings, or context discovered during work
- `status` -- Explicit status when position alone is ambiguous

The schema is intentionally open to extension. Unknown fields generate warnings, not errors.

## Context block

`tasks.json` includes a top-level `context` object for ambient project state:

```json
{
  "context": {
    "active_branch": "feature-x",
    "active_pr": 42,
    "environment": {
      "staging": "https://staging.example.com",
      "ci_status": "green"
    },
    "notes": "Waiting on API key from vendor before starting integration work"
  }
}
```

This is the "where are we" block. An agent reads it on session start to orient itself without needing to ask questions or explore the codebase.

## Validation

### Linter

`semantic_stack/scripts/lint_tasks.py` validates all three files:

**Structural checks** (errors -- must fix before committing):
- Valid JSON with correct top-level structure
- Required fields present on every task
- No duplicate task IDs across files
- Dependency references resolve to real tasks
- No cycles in the dependency graph
- Meta block present with expected fields

**Semantic checks** (warnings -- worth reviewing):
- Descriptions aren't empty placeholders
- Completed tasks have completion dates
- Modification counter is valid
- Review thresholds are sorted and positive

Run it directly:

```bash
python3 semantic_stack/scripts/lint_tasks.py
python3 semantic_stack/scripts/lint_tasks.py --strict  # warnings become errors
python3 semantic_stack/scripts/lint_tasks.py /path/to/tasks/  # explicit directory
```

### Git hooks

Two hooks enforce the system:

**pre-commit-tasks**: Runs `lint_tasks.py` when any `tasks/*.json` file is staged. Blocks the commit if structural errors are found. Skips entirely if no task files are staged, so it doesn't slow down unrelated commits.

**post-commit-tasks**: After a commit that includes task files, increments the `modification_count` and amends the commit with the updated counter. This keeps the counter accurate without requiring manual maintenance.

Install by symlinking into `.git/hooks/` or by calling these scripts from your existing hook chain:

```bash
# Direct symlink (if you don't have existing hooks)
ln -sf ../../semantic_stack/scripts/hooks/pre-commit-tasks .git/hooks/pre-commit
ln -sf ../../semantic_stack/scripts/hooks/post-commit-tasks .git/hooks/post-commit

# Or source from existing hooks
echo 'source "$REPO_ROOT/semantic_stack/scripts/hooks/pre-commit-tasks"' >> .git/hooks/pre-commit
```

## Why not GitHub Issues / Jira / Linear

These tools work for human project management. They fail for agent-driven workflows because:

1. **Access requirements**: Agents in containers may not have API tokens or network access to external services.
2. **Latency**: An API call to check task state adds seconds. Reading a local file takes milliseconds.
3. **Format mismatch**: These tools store rich objects with comments, labels, assignees, and workflows that are irrelevant noise for an agent that just needs to know what to do next.
4. **Sync complexity**: Keeping an external system in sync with local state is a distributed systems problem. Keeping a file in sync with git is `git pull`.

The task files can be synced to external tools if you want -- they're just JSON. But the files on disk are the source of truth.
