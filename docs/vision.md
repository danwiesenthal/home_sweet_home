# The Semantic Operating System

## The core metaphor

Traditional operating systems manage hardware resources through abstractions: processes, memory, filesystems, scheduling. The percolate stack applies this thinking to agentic software development.

The central idea is that a development environment with multiple AI agents needs the same kinds of primitives an OS provides -- working memory, a clock, process management, and a scheduler -- but implemented at a semantic level where the "instructions" are natural language and the "state" is human-readable text.

### Files are working memory

The working state of a project lives in text files on disk. Agents and humans both read and write these files. They are the shared memory space. Unlike a database or API-mediated state, files are:

- Directly inspectable by humans
- Naturally version-controlled via git
- Readable by any agent regardless of tooling
- Editable with any text editor

Structured formats (JSON, TOML) are preferred for machine-readable state. Markdown is used for documentation and instructions. The key constraint: the files on disk must always reflect the true current state of the project.

The I/O itself is low bandwidth -- agents read and write text files, one at a time, through a relatively narrow pipe. But natural language as an instruction set has high semantic bandwidth. A single sentence can capture a complex architectural decision. A paragraph can redirect an entire work stream. The system works despite primitive file-based I/O because the expressiveness of the language compensates for the narrowness of the channel. Precision in language matters here: we want to minimize ambiguity and maximize the semantic content per token written to disk.

### Git commits are clock cycles

Every meaningful state change is captured as a git commit. The commit message describes the semantic meaning of what changed, not just which files were touched. This creates an auditable, replayable history of the project's evolution.

"Meaningful" is the operative word. Not every file save needs a commit. But when something qualitatively changes in the system -- a task moves from backlog to current, an architectural decision is made, a feature is completed -- that change must be committed with a message that captures why.

### Agents are processes

AI coding agents are the processes running in this OS. They:

- Have defined roles and capabilities
- Operate at different priority levels
- Can run concurrently on different tasks
- Need to be scheduled, monitored, and occasionally terminated
- Communicate through shared state (files) rather than direct IPC

The orchestrator (the agent a human developer converses with directly) is analogous to the kernel -- it manages all other processes and has the highest priority.

### The task stack is the call stack

A structured task file (`tasks.json`) tracks what's being worked on, what's queued, and what's been completed. Like a call stack, it represents the current execution state. Unlike a simple todo list, it supports:

- Dependencies between tasks (forming a DAG, not a linear list)
- Different task states with well-defined transitions
- Semantic validation via linting (not just structural checks)
- Periodic review by a "PM" agent at configurable intervals

See [task-management.md](task-management.md) for the full system design.


## Core design principles

### Code simplicity over cleverness

The goal is code that a developer can read and understand without extensive archaeology. No comprehension debt. If a clever optimization makes the code harder to follow, it's not worth it unless there's a measured performance need.

This applies doubly to the percolate stack itself: the conventions and tools should be straightforward and explainable.

### Tool self-healing

When an agent encounters a tool or workflow that doesn't work as expected, the correct response is to:

1. Investigate the root cause
2. Fix the issue
3. Update the instructions so future agents don't waste tokens relearning

This is a high-priority operation. Broken tooling that silently wastes agent time is worse than a broken feature, because it compounds across every future task.

### One README per directory

Every directory has exactly one `README.md` that introduces what's in that directory. It provides enough context for a developer (human or agent) to understand what they're looking at and where to go for more detail.

Information lives at one level of abstraction. A parent README points to its children for details but does not duplicate their content. A child README does not repeat context available in its parent. This prevents the drift and contradictions that come from maintaining the same information in multiple places.

### Empowered agents

Agents should have the same capabilities a human developer has. This means:

- Running Docker and Docker Compose to test multi-service applications
- Accessing CI/CD systems to monitor test results
- Reading and writing to any file in the project
- Making git commits and managing branches
- Accessing external services through well-defined interfaces (MCP servers, APIs)

If an agent can't do something a human developer would do, that's a gap in the environment setup, not a limitation to accept.

### Structured state, semantic validation

Agent-readable state (tasks, configuration, progress) should be in structured formats that can be programmatically validated. But validation goes beyond schema checking -- semantic linting verifies that the state makes sense (e.g., a task marked "completed" should have a completion date, dependencies should reference real tasks, descriptions should be substantive).

Git hooks enforce this validation at commit time. The goal is catching mistakes early, not burdening agents with bureaucracy.


## Documentation principles

Documentation in this system follows a tree structure mirroring the directory hierarchy.

Each piece of information appears once, at the appropriate level of abstraction. If you need a summary, go up. If you need details, go down. This structure is maintained actively -- when content is added, it should be placed at the right level and referenced (not duplicated) from other levels.

The danger with AI-assisted development is volume: agents can generate text quickly, and without discipline, the result is duplicated information everywhere that drifts out of sync. The one-README-per-directory rule and the no-duplication principle are specifically designed to counter this.
