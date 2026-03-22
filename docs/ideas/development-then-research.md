# Development then Research (D&R)

## Concept

A reframing of the R&D loop. What if the default order is: act first, observe what happened, then adjust?

1. **Develop**: Take an action. Write the code, make the change, build the thing.
2. **Observe**: See what happened. Run tests, check behavior, read error output.
3. **Research** (if needed): Gather additional information from elsewhere — docs, web, other codebases — to inform the next iteration.

The bias is toward action when the action is cheap and reversible. Try the thing, see how it went, course-correct. This is the opposite of the failure mode where an agent imagines what should work, edits files based on that imagination, and declares itself done without ever running anything.

## When this applies

This works for iterative development where you can always revert. It's less appropriate when a wrong action is expensive (deploying to production, sending notifications, irreversible data changes). In those cases, research-then-develop is still the right call.

The point isn't "never research first." It's that for most coding tasks, the fastest path to a working solution runs through actually running the code, not theorizing about it.
