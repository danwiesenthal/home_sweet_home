# Output Diversity for Parallel Agents

## The problem

When spawning N agents in parallel with the same instructions, you want genuinely different approaches, not N copies of the same work. LLMs with the same prompt tend to produce similar outputs, especially at low temperature.

## Possible approaches

### Token jittering via creative writing

Have each agent write a short creative piece (e.g., a haiku) at the start of its task. This injects different token sequences early in the generation, nudging subsequent output in different directions. The creative prompt could ask the agent to reflect on its attention, the task at hand, or anything that produces varied responses.

### Explicit role differentiation

Give each parallel agent a slightly different perspective or starting point. "Approach this as if you're debugging a production issue" vs. "Approach this as if you're reviewing a PR" vs. "Approach this as if you're writing a design doc."

### Temperature and sampling variation

If the model API supports it, use different temperature/top-p settings for different agents in the parallel batch.

The goal is that when 3 agents explore a problem, you get 3 qualitatively different paths, not 3 slight variations of the same path.
