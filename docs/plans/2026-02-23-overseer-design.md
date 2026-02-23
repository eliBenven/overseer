# Overseer — Autonomous Quality Gate Plugin for Claude Code

## Problem

Claude Code is blind. It writes code but never looks at what it produced. It declares "done" when it means "I wrote the code." The verification loop — checking CI, running tests, visually evaluating the output, judging quality — falls on the human every time. This doesn't scale.

## Solution

A Claude Code plugin with one job: after you say "build X," it builds, looks at what it built with actual eyes, critiques against your quality standards, iterates until satisfied, deploys, and verifies the live result. You walk away.

## Architecture

### Single Orchestrator, Three Phases

One orchestrator agent runs three phases in sequence:

**Phase 1 — Functional.**
Build, typecheck, test, deploy to preview. Playwright opens every route, checks for console errors, 404s, crashes. Binary pass/fail. Loops until clean.

**Phase 2 — Quality.**
Screenshots every key view (desktop + mobile). Sends to vision model with the project's quality rubric. Gets back structured scores (layout: 7/10, typography: 5/10, spacing: 8/10, etc.) and specific critiques. Fixes the lowest-scoring areas. Re-screenshots. Loops until all scores hit the rubric's threshold.

**Phase 3 — Ambition.**
Same vision model, different prompt: "What's the one thing that would make someone screenshot this and share it?" Gets back a single creative push. Implements it. Re-evaluates. One push per loop, max 3 rounds. Prevents generic slop without spiraling into random flashy effects.

### The Rubric (Configurable Per-Project)

Each project gets a `.claude/overseer/rubric.yml` that defines what "good" means for THAT project. The rubric is where taste lives — persisted across sessions, specific to context.

```yaml
type: frontend
thresholds:
  functional: pass
  quality: 8
  ambition: 7

quality_criteria:
  - "Layout should feel intentional, not auto-generated"
  - "Typography should have personality — not default Inter/system"
  - "Color palette must be cohesive with clear hierarchy"
  - "Must have micro-interactions on buttons and links"
  - "Mobile must look designed-for-mobile, not just responsive"

ambition_criteria:
  - "At least one moment that makes someone pause"
  - "Something technically impressive visible above the fold"
  - "Copy should be specific to this brand, not generic"

anti_patterns:
  - "Generic Tailwind card grids"
  - "Stock photo hero sections"
  - "Default shadcn components with no customization"
  - "Cookie-cutter SaaS layouts"
```

For backend/CLI projects, the rubric adapts:

```yaml
type: cli
quality_criteria:
  - "Help text should be clear and complete"
  - "Error messages should tell the user what to do next"
  - "Output should be structured and colorized"
ambition_criteria:
  - "Should feel delightful to use, not just functional"
```

### Plugin Structure

```
overseer/
├── plugin.json                    — Plugin manifest
├── agents/
│   └── orchestrator.md            — The single brain: 3-phase quality pipeline
├── skills/
│   ├── overseer.md                — /overseer "build me X"
│   ├── init.md                    — /overseer-init (generate rubric)
│   └── status.md                  — /overseer-status (dashboard)
├── hooks/
│   ├── stop.md                    — Intercepts premature "done" claims
│   └── session-start.md           — Loads persistent state + pending items
├── commands/
│   └── sweep.md                   — /sweep all tracked repos
└── defaults/
    ├── rubric-frontend.yml        — Default rubric for frontend projects
    ├── rubric-backend.yml         — Default rubric for backend projects
    └── rubric-cli.yml             — Default rubric for CLI tools
```

### Tools Used (All Already Installed)

- **Playwright plugin** — render pages, take screenshots
- **Gemini MCP** — vision model for screenshot evaluation
- **Vercel plugin** — deploy previews and production
- **Slack/Notion plugins** — report results with visual proof
- **gh CLI** — check CI, open PRs, close issues

### Persistent State

`.claude/overseer/state.json` tracks:
- Last session summary (what was done, what's pending)
- Per-repo health (CI status, last deploy, quality scores)
- Rubric score history (is quality trending up or down?)

Loaded by `session-start` hook so Claude Code never starts from zero.

## Key Design Decisions

1. **Single orchestrator, not multiple agents.** Three separate agents add latency and create fuzzy boundary disputes. One agent with three phases is faster and clearer.

2. **Rubric-driven, not persona-driven.** "Be visionary" is vague. A rubric with specific criteria and anti-patterns is actionable and project-specific.

3. **Max iteration caps per phase.** Phase 1: loop until green (hard requirement). Phase 2: max 5 rounds. Phase 3: max 3 rounds. Prevents infinite loops.

4. **Vision model for evaluation, not just code analysis.** The core innovation. Claude Code gets actual eyes via Playwright screenshots + Gemini/Claude vision. This is what makes it genuinely different from running tests.

## Success Criteria

1. Given "build me a landing page for X," Overseer produces a deployed, visually verified result without human intervention.
2. The quality rubric prevents generic AI slop — output should be visually distinguishable from default Tailwind templates.
3. Cross-session state works — closing and reopening Claude Code resumes where you left off.
4. The stop hook catches premature "done" claims and forces verification.
