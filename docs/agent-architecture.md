# Agent Architecture

## Orchestrator and agents

The system has one primary orchestrator agent and multiple specialized agents. The orchestrator is the agent the human developer interacts with directly. It:

- Receives instructions from the developer (often via voice/dictation)
- Breaks work into tasks and delegates to specialized agents
- Synthesizes results from multiple agents
- Makes decisions about resource allocation (which models, how many agents, what priority)
- Maintains the task stack as the authoritative record of project state

Specialized agents handle specific domains: testing, security review, architecture analysis, research, code generation. They receive well-defined tasks, produce outputs, and report back to the orchestrator.

### Arbitrary depth

The goal is that agents should be able to spawn sub-agents, which can spawn their own sub-agents, forming an arbitrarily deep tree. Current tooling has limitations here (e.g., Claude Code's subagent depth limit of 1), but the system should be designed for the general case. Workarounds exist (headless CLI invocations, separate processes), and the tooling will improve.

The principle: don't design the architecture around a temporary platform limitation. Design for the ideal, implement workarounds where needed, and document which parts are workarounds.

### Intelligence as a parameter

A "security reviewer" agent and a "code generator" agent are role definitions. The model powering them (and its capability level) is a separate parameter. The same role might be powered by:

- A small local model for quick, low-stakes checks
- A mid-tier cloud model for standard work
- A top-tier model for complex reasoning tasks

This separation means you define roles once and choose the intelligence level at invocation time based on the task's complexity, cost sensitivity, and latency requirements.


## Model routing

Different tasks have different requirements for model capability, latency, cost, and privacy.

### Local vs. cloud

Some tasks should run on local models:
- Stack management (reading/writing/validating task state)
- Quick lookups and simple transformations
- Tasks involving private data that shouldn't leave the machine

Other tasks benefit from cloud models:
- Complex reasoning and architectural decisions
- Synthesis across large codebases
- Tasks where quality matters more than cost

A routing layer (e.g., LiteLLM or similar proxy) sits between agents and models, directing requests to the appropriate backend. Agents specify their requirements; the router fulfills them.

### Hardware awareness

The system should be aware of available hardware (local GPU/unified memory, cloud API quotas) and schedule work accordingly. A machine with 128GB unified memory can run larger local models than one with 64GB. The scheduling system should adapt to what's available rather than hardcoding model choices.

### Cost awareness

Cloud API calls cost money. The system should:
- Track spending per agent and per task
- Allow budget limits (don't bother the developer for every penny, but don't run away either)
- Prefer local models when they're sufficient for the task
- Batch async work to take advantage of lower-cost time windows when available


## Scheduling

Agents need to run at different frequencies and priorities.

### Priority levels

Borrowing from OS scheduling:

- **Kernel-level**: Stack management, tool self-healing. Must always work. Runs on fast, reliable infrastructure.
- **High priority**: The synchronous conversation with the developer. Low latency required.
- **Normal priority**: Active development tasks, test execution, CI monitoring.
- **Background**: Security reviews, performance analysis, code quality sweeps. Run when resources are available.

### Periodic tasks

Some work should happen on a schedule rather than on-demand:
- Security reviews (configurable frequency -- daily, weekly, per N commits)
- Architecture quality checks
- Task stack review by a "PM" agent to ensure the project is on track
- Engineering summaries for the developer

The scheduling mechanism should be configurable: register a task with a desired frequency, and the system runs it when the interval elapses. The specific thresholds (how often to run PM reviews, how to ramp the frequency) are configurable per project.

### Parallel execution

Multiple agents should be able to work concurrently on independent tasks. Key considerations:
- Tasks should be genuinely independent (no shared mutable state beyond the task file)
- The orchestrator manages task assignment to avoid conflicts
- Results are synthesized after parallel work completes
- When sampling multiple approaches to a problem, ensure the agents explore genuinely different paths (not N copies of the same approach)


## Agent roles

These are example roles, not a fixed list. Projects should define the roles they need.

- **Orchestrator**: The developer's primary interface. Manages all other agents.
- **Investigator**: Deep codebase exploration and research. Parallelizes information gathering.
- **Test writer/runner**: Creates and executes tests. Multiple testing strategies (unit, integration, end-to-end, agentic simulation).
- **Security reviewer**: Periodic security audits. Dependency scanning, code review for vulnerabilities.
- **Architecture reviewer**: Checks for leaky abstractions, encapsulation violations, code quality.
- **PM/Progress reviewer**: Periodic review of the task stack. Are we on track? Are priorities right? Any blocked tasks?
- **Researcher**: Web search and synthesis for technical decisions. Gathers information agents need.
- **Performance analyst**: Profiling, benchmarking, identifying bottlenecks. Only when there's evidence of a performance need.


## Inter-agent communication

Agents communicate through shared files, not direct messaging. The task file is the primary coordination mechanism. An agent needing work from another agent type creates a task in the backlog tagged for that role. The orchestrator (or scheduler) assigns it.

This is intentionally simple. Direct agent-to-agent communication introduces complexity (message passing, synchronization, deadlocks). File-based communication through the task system is slower but more predictable, auditable, and debuggable.

For cases where faster communication is needed, agents can write to designated output files that other agents monitor. But the task system remains the source of truth for what work has been requested and completed.
