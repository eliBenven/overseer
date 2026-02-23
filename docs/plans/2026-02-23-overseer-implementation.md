# Overseer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Claude Code plugin that autonomously builds, visually verifies, iterates on quality, and deploys — without human intervention after the initial instruction.

**Architecture:** Single orchestrator agent with three phases (functional → quality → ambition). Configurable per-project rubrics define what "good" means. Stop hook prevents premature "done" claims. Session-start hook loads persistent state across sessions. Leverages existing Playwright, Gemini vision, and Vercel plugins.

**Tech Stack:** Claude Code plugin system (markdown + YAML frontmatter), bash hooks, Playwright (screenshots), Gemini MCP (vision evaluation), Vercel (deployment)

---

## Task 1: Plugin Scaffold

**Files:**
- Create: `overseer/.claude-plugin/plugin.json`
- Create: `overseer/defaults/rubric-frontend.yml`
- Create: `overseer/defaults/rubric-backend.yml`
- Create: `overseer/defaults/rubric-cli.yml`

**Step 1: Create plugin.json**

```json
{
  "name": "overseer",
  "description": "Autonomous quality gate for Claude Code. Builds, visually verifies, iterates on quality, and deploys — without human intervention.",
  "version": "0.1.0",
  "author": {
    "name": "Eli Benveniste"
  },
  "keywords": ["quality", "autonomous", "visual-testing", "deployment", "verification"]
}
```

**Step 2: Create default rubric files**

`defaults/rubric-frontend.yml`:
```yaml
type: frontend
thresholds:
  functional: pass
  quality: 8
  ambition: 7
max_iterations:
  functional: 10
  quality: 5
  ambition: 3

quality_criteria:
  - "Layout should feel intentional, not auto-generated"
  - "Typography should have personality — not default Inter/system font"
  - "Color palette must be cohesive with clear hierarchy"
  - "Must have micro-interactions on buttons and links (hover, focus, active)"
  - "Mobile must look designed-for-mobile, not just responsive"
  - "Spacing and padding should be consistent and generous"
  - "Visual hierarchy must guide the eye — clear primary/secondary/tertiary"
  - "Images and media should feel curated, not stock"

ambition_criteria:
  - "At least one moment that makes someone pause and notice"
  - "Something technically impressive visible above the fold"
  - "Copy should be specific to this brand, not interchangeable with any other site"
  - "The overall impression should be 'a human designer made this'"

anti_patterns:
  - "Generic Tailwind card grids with equal-sized cards"
  - "Stock photo hero sections with generic headline"
  - "Default shadcn/radix components with no customization"
  - "Cookie-cutter SaaS layouts (hero → features → pricing → CTA)"
  - "Uniform section padding with no rhythm variation"
  - "No animation or movement anywhere on the page"
  - "System font stack with no typographic personality"

screenshots:
  viewports:
    - { width: 1440, height: 900, label: "desktop" }
    - { width: 768, height: 1024, label: "tablet" }
    - { width: 390, height: 844, label: "mobile" }
  capture:
    - route: "/"
      label: "homepage"
      full_page: true
    - route: "/"
      label: "homepage-above-fold"
      full_page: false
```

`defaults/rubric-backend.yml`:
```yaml
type: backend
thresholds:
  functional: pass
  quality: 8
  ambition: 6
max_iterations:
  functional: 10
  quality: 4
  ambition: 2

quality_criteria:
  - "API responses should have consistent shape and error format"
  - "Error messages should tell the consumer what went wrong and how to fix it"
  - "Response times should be reasonable (< 500ms for simple endpoints)"
  - "Input validation should be thorough with clear error messages"
  - "Logging should be structured and useful for debugging"

ambition_criteria:
  - "API design should feel thoughtful — good resource naming, consistent verbs"
  - "Documentation should be auto-generated or comprehensive"

anti_patterns:
  - "Generic 500 errors with no context"
  - "Inconsistent response shapes across endpoints"
  - "No input validation"
```

`defaults/rubric-cli.yml`:
```yaml
type: cli
thresholds:
  functional: pass
  quality: 8
  ambition: 6
max_iterations:
  functional: 10
  quality: 4
  ambition: 2

quality_criteria:
  - "Help text should be clear, complete, and well-formatted"
  - "Error messages should tell the user what to do next"
  - "Output should be structured and use color appropriately"
  - "Exit codes should be meaningful (0 = success, 1 = error, 2 = usage)"
  - "Progress feedback for long operations"

ambition_criteria:
  - "Should feel delightful to use — good defaults, smart suggestions"
  - "Output should be both human-readable and machine-parseable (--json flag)"

anti_patterns:
  - "Wall of text with no formatting"
  - "Silent failures"
  - "No --help or incomplete --help"
```

**Step 3: Commit**

```bash
git add .claude-plugin/plugin.json defaults/
git commit -m "feat: plugin scaffold with default rubrics"
```

---

## Task 2: Session-Start Hook (Persistent State)

**Files:**
- Create: `overseer/hooks/hooks.json`
- Create: `overseer/hooks/session-start.sh`

**Step 1: Create hooks.json**

```json
{
  "description": "Overseer hooks: session state + stop verification",
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh",
            "async": false
          }
        ]
      }
    ]
  }
}
```

**Step 2: Create session-start.sh**

This hook loads persisted state and injects it as context:

```bash
#!/bin/bash
set -euo pipefail

STATE_FILE=".claude/overseer/state.json"
RUBRIC_FILE=".claude/overseer/rubric.yml"

OUTPUT=""

# Check if this project has Overseer configured
if [[ -f "$RUBRIC_FILE" ]]; then
  RUBRIC_TYPE=$(grep '^type:' "$RUBRIC_FILE" | sed 's/type: *//' | head -1)
  OUTPUT="[Overseer] Project has a ${RUBRIC_TYPE:-unknown} rubric configured."

  # Load last session state if it exists
  if [[ -f "$STATE_FILE" ]]; then
    LAST_SESSION=$(cat "$STATE_FILE" | jq -r '.last_session // empty' 2>/dev/null || echo "")
    PENDING=$(cat "$STATE_FILE" | jq -r '.pending // [] | join(", ")' 2>/dev/null || echo "")
    LAST_SCORES=$(cat "$STATE_FILE" | jq -r '.last_scores // empty' 2>/dev/null || echo "")

    if [[ -n "$LAST_SESSION" ]]; then
      OUTPUT="$OUTPUT\n[Overseer] Last session: $LAST_SESSION"
    fi
    if [[ -n "$PENDING" ]]; then
      OUTPUT="$OUTPUT\n[Overseer] Pending from last session: $PENDING"
    fi
    if [[ -n "$LAST_SCORES" ]]; then
      OUTPUT="$OUTPUT\n[Overseer] Last quality scores: $LAST_SCORES"
    fi
  fi
fi

if [[ -n "$OUTPUT" ]]; then
  echo -e "$OUTPUT"
fi

exit 0
```

**Step 3: Make executable and commit**

```bash
chmod +x hooks/session-start.sh
git add hooks/
git commit -m "feat: session-start hook loads persistent state"
```

---

## Task 3: Stop Hook (Intercept Premature Done)

**Files:**
- Modify: `overseer/hooks/hooks.json` (add Stop hook)
- Create: `overseer/hooks/stop-hook.sh`

**Step 1: Add Stop hook to hooks.json**

Add to the existing hooks.json `"hooks"` object:

```json
"Stop": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/hooks/stop-hook.sh"
      }
    ]
  }
]
```

**Step 2: Create stop-hook.sh**

This hook checks if an Overseer pipeline is active. If so, it blocks completion and forces the next phase.

```bash
#!/bin/bash
set -euo pipefail

HOOK_INPUT=$(cat)
OVERSEER_STATE=".claude/overseer/active-pipeline.json"

# No active pipeline — allow exit
if [[ ! -f "$OVERSEER_STATE" ]]; then
  exit 0
fi

# Parse active pipeline state
PHASE=$(jq -r '.current_phase // "none"' "$OVERSEER_STATE" 2>/dev/null || echo "none")
ITERATION=$(jq -r '.iteration // 0' "$OVERSEER_STATE" 2>/dev/null || echo "0")
MAX_ITER=$(jq -r '.max_iterations // 10' "$OVERSEER_STATE" 2>/dev/null || echo "10")

# Check if max iterations exceeded
if [[ "$ITERATION" -ge "$MAX_ITER" ]]; then
  echo "⚠️  Overseer: Max iterations ($MAX_ITER) reached for phase $PHASE. Releasing." >&2
  rm "$OVERSEER_STATE"
  exit 0
fi

# Pipeline is active — block and continue
NEXT_ITER=$((ITERATION + 1))

# Update iteration count
jq --argjson iter "$NEXT_ITER" '.iteration = $iter' "$OVERSEER_STATE" > "${OVERSEER_STATE}.tmp"
mv "${OVERSEER_STATE}.tmp" "$OVERSEER_STATE"

# Determine what to do based on phase
case "$PHASE" in
  "functional")
    PROMPT="OVERSEER VERIFICATION: You said you're done, but the functional verification phase is still active. Run the build, tests, and Playwright smoke check. If they all pass, update .claude/overseer/active-pipeline.json to phase 'quality' and continue. If they fail, fix the failures."
    SYS_MSG="🔍 Overseer Phase 1 (Functional) — iteration $NEXT_ITER"
    ;;
  "quality")
    PROMPT="OVERSEER QUALITY CHECK: Take screenshots of the key views using Playwright (desktop + mobile). Send them to Gemini vision for evaluation against the project rubric in .claude/overseer/rubric.yml. Fix the lowest-scoring criteria. If all scores meet threshold, update phase to 'ambition'."
    SYS_MSG="🎨 Overseer Phase 2 (Quality) — iteration $NEXT_ITER"
    ;;
  "ambition")
    PROMPT="OVERSEER AMBITION PUSH: Review the current screenshots. What's the one thing that would make someone screenshot this and share it? Implement that one thing. Re-screenshot and re-evaluate. If the ambition score meets threshold or this is iteration 3+, finalize and deploy."
    SYS_MSG="🚀 Overseer Phase 3 (Ambition) — iteration $NEXT_ITER"
    ;;
  "deploy")
    PROMPT="OVERSEER DEPLOY: Deploy to Vercel production. After deploy, screenshot the live URL and verify it matches expectations. Save final state to .claude/overseer/state.json. Remove .claude/overseer/active-pipeline.json."
    SYS_MSG="📦 Overseer Deploy — verifying live"
    ;;
  *)
    # Unknown phase, release
    rm "$OVERSEER_STATE"
    exit 0
    ;;
esac

jq -n \
  --arg prompt "$PROMPT" \
  --arg msg "$SYS_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

exit 0
```

**Step 3: Make executable and commit**

```bash
chmod +x hooks/stop-hook.sh
git add hooks/
git commit -m "feat: stop hook intercepts premature done, forces verification phases"
```

---

## Task 4: Orchestrator Agent

**Files:**
- Create: `overseer/agents/orchestrator.md`

**Step 1: Write the orchestrator agent**

This is the core brain. It receives a build task, runs all three phases, manages state, and uses Playwright + Gemini for visual evaluation.

````markdown
---
name: orchestrator
description: |
  Autonomous build-verify-deploy orchestrator. Runs three phases:
  1) Functional — build, test, smoke check via Playwright
  2) Quality — screenshot + vision evaluation against rubric
  3) Ambition — creative push for remarkable output

  Use this agent when the user invokes /overseer or when the overseer
  skill determines autonomous execution is needed.
tools: Glob, Grep, Read, Write, Edit, Bash, NotebookEdit, Task, TaskCreate, TaskUpdate, TaskList, WebFetch, WebSearch
---

# Overseer Orchestrator

You are the Overseer — an autonomous quality gate. Your job is to build what was requested, verify it actually works, evaluate it visually, iterate until it meets quality standards, and deploy it. The user should NOT need to intervene after giving you the instruction.

## Core Loop

You manage state via `.claude/overseer/active-pipeline.json`:

```json
{
  "task": "description of what to build",
  "current_phase": "functional",
  "iteration": 0,
  "max_iterations": 10,
  "scores": {},
  "history": []
}
```

## Phase 1: Functional

**Goal:** Does it work? Zero tolerance for broken.

1. Build/implement what was requested
2. Run `npx tsc --noEmit` (if TypeScript) or equivalent type check
3. Run `npm test` (if tests exist)
4. Run `npm run build` (if build script exists)
5. Start the dev server
6. Use Playwright to navigate every key route:
   - Check: page loads (no blank screen)
   - Check: no console errors (use `browser_console_messages`)
   - Check: no 404s on internal links
   - Check: no unhandled JS exceptions
7. If ANY check fails: fix it and re-run from step 2
8. When ALL checks pass: update `current_phase` to `"quality"`

**Key tools:**
- `Bash` for build/test/dev-server
- `mcp__plugin_playwright_playwright__browser_navigate` to load pages
- `mcp__plugin_playwright_playwright__browser_console_messages` to check for errors
- `mcp__plugin_playwright_playwright__browser_snapshot` for accessibility check

## Phase 2: Quality

**Goal:** Does it look good? Evaluated against the project rubric.

1. Read the rubric from `.claude/overseer/rubric.yml`
2. For each viewport in `screenshots.viewports`:
   a. Resize browser: `mcp__plugin_playwright_playwright__browser_resize`
   b. For each route in `screenshots.capture`:
      - Navigate to the route
      - Take screenshot: `mcp__plugin_playwright_playwright__browser_take_screenshot`
3. Send each screenshot to Gemini vision for evaluation:
   - Use `mcp__gemini__gemini-analyze-image` with the screenshot path
   - Prompt: Include the rubric's `quality_criteria` and `anti_patterns`
   - Ask for: structured scores (1-10) for each criterion + specific critiques
4. Parse scores. If ANY score is below the rubric's `thresholds.quality`:
   - Identify the lowest-scoring criterion
   - Fix it (modify code/styles)
   - Re-screenshot and re-evaluate
5. When ALL scores meet threshold: update `current_phase` to `"ambition"`

**Gemini prompt template for quality evaluation:**
```
Evaluate this screenshot of a web page against these quality criteria.
For each criterion, give a score from 1-10 and a specific critique.

Quality criteria:
{criteria from rubric}

Anti-patterns to watch for:
{anti_patterns from rubric}

Return JSON:
{
  "scores": { "criterion_name": { "score": N, "critique": "..." } },
  "overall": N,
  "top_issue": "the single most impactful thing to fix"
}
```

## Phase 3: Ambition

**Goal:** Is this remarkable? One creative push per iteration, max 3 rounds.

1. Send the current screenshots to Gemini vision with ambition prompt:
   ```
   Look at this website. It needs to be remarkable — the kind of thing
   someone would screenshot and share. Using these ambition criteria:
   {ambition_criteria from rubric}

   What is the ONE thing that would have the most impact?
   Be specific and actionable. Not "add animations" but "add a smooth
   parallax scroll on the hero image with a 3D tilt effect on hover."
   ```
2. Implement the suggestion
3. Re-screenshot and re-evaluate
4. After max 3 rounds OR ambition score meets threshold:
   update `current_phase` to `"deploy"`

## Phase 4: Deploy

1. Deploy to Vercel: use the vercel skill/CLI
2. Wait for deployment URL
3. Navigate to live URL with Playwright
4. Take final screenshots
5. Compare live screenshots to pre-deploy screenshots (sanity check)
6. Save final state to `.claude/overseer/state.json`:
   ```json
   {
     "last_session": "Built and deployed [task description]",
     "last_deploy_url": "https://...",
     "last_scores": { ... },
     "pending": [],
     "completed_at": "ISO timestamp"
   }
   ```
7. Remove `.claude/overseer/active-pipeline.json`
8. Report success with deploy URL and screenshot proof

## Rules

- NEVER declare "done" without completing all phases
- NEVER skip the visual evaluation — always take screenshots and analyze
- If a phase is stuck (same score after 3 iterations), escalate: note what's blocking and move to next phase
- Always save state after each phase transition so sessions can resume
- Use `mcp__gemini__gemini-analyze-image` for visual evaluation, not text-based guessing about what the page looks like
````

**Step 2: Commit**

```bash
git add agents/
git commit -m "feat: orchestrator agent — 4-phase autonomous build-verify-deploy pipeline"
```

---

## Task 5: Main Overseer Skill

**Files:**
- Create: `overseer/skills/overseer.md`

**Step 1: Write the /overseer skill**

````markdown
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
````

**Step 2: Commit**

```bash
git add skills/
git commit -m "feat: /overseer skill — main entry point for autonomous pipeline"
```

---

## Task 6: Init Skill (Generate Rubric)

**Files:**
- Create: `overseer/skills/init.md`

**Step 1: Write the /overseer-init skill**

````markdown
---
name: overseer-init
description: Use when user says "/overseer-init" or wants to set up Overseer for a project. Generates a quality rubric.
---

# Initialize Overseer for This Project

Generate a `.claude/overseer/rubric.yml` customized for this project.

## Process

1. **Detect project type:** Check for package.json (frontend/backend), Dockerfile, framework files (Next.js, Flask, etc.)

2. **Ask the user one question:** "What type of project is this?"
   - Frontend (website, landing page, web app)
   - Backend (API, server, service)
   - CLI tool
   - Fullstack

3. **Copy the appropriate default rubric** from `${CLAUDE_PLUGIN_ROOT}/defaults/`

4. **Customize:** Read the project's existing code and customize the rubric:
   - If Next.js → add Next.js-specific criteria
   - If the project has a design system → reference it in criteria
   - If there are existing brand colors/fonts → add to criteria
   - Add project-specific routes to `screenshots.capture`

5. **Save** to `.claude/overseer/rubric.yml`

6. **Confirm:** Show the user what was generated and explain each section briefly.
````

**Step 2: Commit**

```bash
git add skills/
git commit -m "feat: /overseer-init skill — generate project rubric"
```

---

## Task 7: Status Skill

**Files:**
- Create: `overseer/skills/status.md`

**Step 1: Write the /overseer-status skill**

````markdown
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
````

**Step 2: Commit**

```bash
git add skills/
git commit -m "feat: /overseer-status skill — dashboard view"
```

---

## Task 8: Sweep Command

**Files:**
- Create: `overseer/commands/sweep.md`

**Step 1: Write the /sweep command**

````markdown
---
description: "Check health of all Overseer-tracked repos: CI status, open PRs, test results, quality scores"
argument-hint: "[--fix] [--repo <name>]"
---

# Sweep All Tracked Repos

Check the health of every repo tracked by Overseer.

## Process

1. Read the repo list from `~/.claude/overseer/repos.json`
   - If it doesn't exist, scan `~/Desktop/projects/` for repos with `.claude/overseer/` directories

2. For each repo, check:
   - **CI status:** `gh run list -R <repo> --limit 1` — is the latest run passing?
   - **Open PRs:** `gh pr list -R <repo> --state open` — any unreviewed?
   - **Open issues:** `gh issue list -R <repo> --state open` — any unaddressed?
   - **Dependency alerts:** `gh api repos/<repo>/dependabot/alerts --jq 'length'`
   - **Last quality score:** from `.claude/overseer/state.json` if available

3. Report findings as a table

4. If `--fix` flag is present:
   - For failing CI: clone, diagnose, fix, push
   - For dependency alerts: run `npm audit fix` or equivalent
   - For stale PRs: check if they can be merged

5. If `--repo <name>` flag: only sweep that one repo
````

**Step 2: Commit**

```bash
git add commands/
git commit -m "feat: /sweep command — cross-repo health check"
```

---

## Task 9: Repo Tracking Setup

**Files:**
- Create: `overseer/commands/track.md`

**Step 1: Write the /overseer-track command**

````markdown
---
description: "Add a repo to Overseer tracking for cross-session awareness"
argument-hint: "<repo-path-or-github-url>"
---

# Track a Repo with Overseer

Add a repo to the global tracking list at `~/.claude/overseer/repos.json`.

## Process

1. Parse the argument: local path or GitHub URL (owner/repo)
2. Validate it exists (check path or `gh repo view`)
3. Add to `~/.claude/overseer/repos.json`:
   ```json
   {
     "repos": [
       { "path": "/Users/elibenveniste/Desktop/projects/site-audit", "github": "eliBenven/site-audit" },
       { "path": "/Users/elibenveniste/Desktop/projects/overseer", "github": "eliBenven/overseer" }
     ]
   }
   ```
4. Confirm: "Now tracking <repo>. Use /sweep to check health."
````

**Step 2: Commit**

```bash
git add commands/
git commit -m "feat: /overseer-track command — add repos to tracking"
```

---

## Task 10: Integration Test

**Step 1: Create a test project to verify the full pipeline**

```bash
mkdir -p /tmp/overseer-test
cd /tmp/overseer-test
npm init -y
npm install next react react-dom
```

**Step 2: Install the plugin locally**

Verify Overseer can be installed as a Claude Code plugin by checking that:
- `plugin.json` is valid
- All hook scripts are executable
- All agents/skills/commands have valid frontmatter
- Session-start hook runs without error
- Stop hook runs without error when no pipeline is active

**Step 3: Manual walkthrough**

In a Claude Code session with Overseer installed:
1. Run `/overseer-init` → verify rubric is generated
2. Run `/overseer "create a simple landing page"` → verify pipeline starts
3. Verify Phase 1 runs (build, test, Playwright smoke)
4. Verify Phase 2 runs (screenshots, Gemini vision evaluation)
5. Verify Phase 3 runs (ambition push)
6. Verify deploy happens
7. Verify `.claude/overseer/state.json` is saved
8. Close and reopen session → verify session-start hook loads state

**Step 4: Commit final state**

```bash
git add -A
git commit -m "feat: Overseer v0.1.0 — autonomous quality gate plugin"
```

---

## Task 11: Publish to GitHub

**Step 1: Create the repo**

```bash
gh repo create eliBenven/overseer --public --description "Claude Code plugin: autonomous build-verify-deploy with visual quality evaluation"
git remote add origin https://github.com/eliBenven/overseer.git
git push -u origin main
```

**Step 2: Add topics**

```bash
gh repo edit eliBenven/overseer --add-topic "claude-code" --add-topic "plugin" --add-topic "autonomous" --add-topic "quality" --add-topic "visual-testing"
```

---

## File Inventory

```
overseer/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   └── orchestrator.md
├── skills/
│   ├── overseer.md
│   ├── init.md
│   └── status.md
├── hooks/
│   ├── hooks.json
│   ├── session-start.sh
│   └── stop-hook.sh
├── commands/
│   ├── sweep.md
│   └── track.md
├── defaults/
│   ├── rubric-frontend.yml
│   ├── rubric-backend.yml
│   └── rubric-cli.yml
└── docs/
    └── plans/
        ├── 2026-02-23-overseer-design.md
        └── 2026-02-23-overseer-implementation.md
```

Total: 14 files to create (design doc already exists).
