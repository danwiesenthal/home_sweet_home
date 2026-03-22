---
name: recall
description: Load and summarize what the human user said in recent prior conversations so they don't have to repeat themselves. Use proactively at conversation start or when the user references prior work.
argument-hint: [num-sessions]
model: sonnet
context: fork
allowed-tools: Bash, Read, Grep, Glob
---

# Recall Prior Human Messages

Your job is to extract what the human user actually said in recent prior conversations in this project, then distill it into a concise briefing so the orchestrator (and thus the user) doesn't have to repeat themselves.

## What to extract

Focus exclusively on **what the human said** - their requests, decisions, feedback, corrections, goals, and unfinished work. Ignore assistant responses, tool outputs, and system messages.

## How to extract

Determine how many sessions to read:
- If `$ARGUMENTS` is a number, use that
- Otherwise, default to 3

Then run:

```bash
python3 ${CLAUDE_SKILL_DIR}/extract_messages.py --sessions <N> --skip-session ${CLAUDE_SESSION_ID}
```

The script reads JSONL files from `~/.claude/projects/` for the current working directory, filters out system noise, and outputs only genuine human messages with full content (no truncation).

If the output is very large (more than a few sessions of heavy conversation), you have plenty of context to work with. Read it all carefully.

## How to summarize

After reading the extracted messages, produce a structured briefing with these sections:

### Active Goals
What is the user currently trying to accomplish? What's the big picture?

### Recent Requests
Specific things the user asked for that may still be in progress or recently completed. List them concretely.

### Decisions Made
Choices the user explicitly made (e.g., "use private repo first", "don't focus on implementation details like claude-p").

### Corrections & Preferences
Things the user pushed back on or corrected. These are especially important - they represent things the user does NOT want repeated.

### Unfinished Work
Anything that was in progress or mentioned as a next step but may not be done yet.

## Output format

Return the briefing as structured text. Be concise but specific - but DO NOT leave out important details just for brevity. Quote the user's words when the exact phrasing matters (especially for corrections and preferences). Do not editorialize or add your own opinions.

If a session had very few messages or was just a quick one-off, note that briefly rather than inflating it.
