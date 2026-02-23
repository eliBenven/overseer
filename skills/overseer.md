---
name: overseer
description: Use when the user says "overseer", "/overseer", "build and ship", or wants autonomous build-verify-deploy. Launches the full autonomous pipeline.
---

# Overseer — Autonomous Build-Verify-Deploy

You've been asked to build something and ship it autonomously. Follow this process exactly.

## Step 1: Understand the Task

Read the user's request carefully. Determine:
- What type of project is this? (frontend, backend, cli, fullstack)
- What is the expected output? (website, API, CLI tool, etc.)
- Is there an existing codebase or is this from scratch?

## Step 2: Load or Create Rubric

Check if `.claude/overseer/rubric.yml` exists.

**If it exists:** Read it and confirm it matches the project type.

**If not:** Copy the appropriate default rubric:
- Frontend → `${CLAUDE_PLUGIN_ROOT}/defaults/rubric-frontend.yml`
- Backend → `${CLAUDE_PLUGIN_ROOT}/defaults/rubric-backend.yml`
- CLI → `${CLAUDE_PLUGIN_ROOT}/defaults/rubric-cli.yml`

Save to `.claude/overseer/rubric.yml`. Create the directory if needed.

## Step 3: Initialize Pipeline State

Create `.claude/overseer/active-pipeline.json`:
```json
{
  "task": "<user's request>",
  "current_phase": "functional",
  "iteration": 0,
  "max_iterations": 10,
  "scores": {},
  "history": []
}
```

## Step 4: Execute

Launch the `orchestrator` agent with the user's task. The orchestrator handles all four phases autonomously.

**CRITICAL:** The Stop hook will prevent premature exit. If you think you're done but the pipeline is still active, the hook will redirect you back to the current phase. Trust the process.

## Step 5: Report

When the pipeline completes (active-pipeline.json is removed), report:
- Deploy URL
- Final quality scores
- Screenshots of the live result
- What was pushed for ambition (the "remarkable" element)
