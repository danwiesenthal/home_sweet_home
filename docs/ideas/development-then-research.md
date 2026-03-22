# Development then Research (D&R)

## Concept

A reframing of the traditional R&D (Research and Development) loop. In many agentic workflows, the natural order is:

1. **Develop**: Take an action. Write the code, make the change, build the thing.
2. **Research**: Observe the results. Run tests, check behavior, gather feedback.

This maps naturally to the agent loop: execute a task, then validate whether it worked. Testing is a form of research. CI results are research data.

## When this applies

This framing works well for iterative development where the cost of trying something is low (you can always revert). It's less appropriate when the cost of a wrong action is high -- in those cases, researching first (gathering information, reading documentation, understanding the system) before acting is still the right call.

The point is not "never research before developing." It's that the bias should be toward action when the action is cheap and reversible, with observation and course correction afterward.
