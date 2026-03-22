# Scheduling Patterns

## Fibonacci-based review cycles

One approach to scheduling periodic PM/review agent runs: use Fibonacci numbers as thresholds on a modification counter. After 3 modifications to the task file, trigger a PM review. Then after 5 more, then 8, then 13, etc. The increasing intervals reflect the idea that early in a project, more frequent check-ins are valuable, and as work stabilizes, less frequent reviews suffice.

This is just one possible schedule. The underlying system supports any configurable thresholds.

## Fizzbuzz scheduling

Different periodic tasks register at different frequencies. Every N cycles, check on task X. Every M cycles, run security review Y. The name comes from the analogy to the fizzbuzz pattern: different functions "fire" at different intervals, and sometimes multiple fire on the same cycle.

This could be implemented as a simple counter with registered callbacks, or as cron-like expressions, or as a priority queue with next-run timestamps.
