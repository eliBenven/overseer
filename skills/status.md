---
name: overseer-status
description: Use when user says "/overseer-status" or wants to see the current state of Overseer across projects.
---

# Overseer Status

Show the current state of Overseer.

## For Current Project

1. Check if `.claude/overseer/rubric.yml` exists → show rubric summary
2. Check if `.claude/overseer/active-pipeline.json` exists → show active pipeline phase + iteration
3. Check if `.claude/overseer/state.json` exists → show last session summary, scores, pending items

## Cross-Repo Status

If the user asks for status across all projects:

1. Read `~/.claude/overseer/repos.json` (list of tracked repo paths)
2. For each repo path:
   - Check for `.claude/overseer/state.json`
   - Report: last session, last scores, pending items, last deploy URL
3. Present as a table:

```
| Repo                      | Last Session      | Quality | Deploy URL          | Pending |
|---------------------------|-------------------|---------|---------------------|---------|
| site-audit                | Added CI + tests  | 9/10    | —                   | None    |
| answerlab-web             | Hero redesign     | 7/10    | answerlab.vercel.app| 2 items |
```
