# User Lens — What Would People Think?

> Imagined reactions from different user niches. Updated as real feedback comes in.
> Use this to pressure-test decisions and prioritize what to build next.

---

## Claude Code Subreddit (r/ClaudeCode)

### What they'd love
- **"Finally, someone made it not just write code but actually LOOK at what it made."** The vision-based evaluation loop is the hook. Most Claude Code users have felt the pain of "it said done but the page is blank."
- **"The stop hook is genius — it literally can't say it's done until it proves it."** Power users will immediately get why this matters.
- **"Rubrics are the right abstraction."** People who've tried to get Claude to have taste via system prompts will appreciate that a structured rubric with anti-patterns works better than "be creative."
- **"Cross-session state is huge."** Anyone who's closed a session and lost context will appreciate the session-start hook loading previous state.

### What they'd recommend
- **"Add a `--dry-run` mode that does everything except deploy."** Not everyone wants auto-deploy. Many will want to review before pushing live.
- **"Support custom vision models, not just Gemini."** Some users will want to use Claude's own vision or GPT-4o for evaluation.
- **"Add a `/overseer-rubric edit` command to tweak the rubric interactively."** Editing YAML files manually isn't ideal.
- **"Show me the screenshots inline in the terminal, not just save them."** People will want to see what the vision model is seeing.
- **"Make the rubric threshold configurable per-run, not just per-project."** "Just make it work" vs "make it perfect" modes.
- **"Add a `--skip-deploy` or `--phase functional-only` flag."** Not every project deploys to Vercel.

### What they'd criticize
- **"Why Vercel-only for deploy? What about Netlify, Cloudflare, Railway, fly.io?"** Hardcoding Vercel will be the #1 complaint from non-Vercel users.
- **"This requires Playwright AND Gemini plugins already installed — that's a lot of dependencies."** Setup friction. Need clear docs on prerequisites.
- **"What happens if Gemini vision gives inconsistent scores? You'll get infinite loops where it rates 7, you fix, it rates 6."** Score stability is a real concern.
- **"The stop hook hijacking my session is scary. What if I want to stop?"** Need a clear escape hatch (maybe `/overseer-abort`).
- **"Does this work for anything other than web frontends?"** Backend/CLI rubrics exist but the vision loop is clearly frontend-first.

### What they'd hate
- **"It auto-deploys without asking me???"** The autonomous deploy is polarizing. Some love it, some will refuse to install the plugin because of it.
- **"I can't customize the phases or skip one."** Rigidity in the pipeline will frustrate power users.
- **"jq is a dependency for the hooks? Not everyone has jq installed."** Valid — the bash hooks assume jq is available.

---

## Indie Hackers / Solo Devs

### Reaction
- **"This is exactly what I need — I'm a solo dev and I'm my own QA."** The target audience gets it immediately.
- **"But I don't want to deploy every time. Sometimes I just want the quality check."** Need phase-only modes.
- **"Can it work with my existing CI/CD?"** They'll want GitHub Actions integration, not just local.

---

## Design-Focused Devs

### Reaction
- **"The anti-patterns list is chef's kiss. Finally someone called out generic Tailwind card grids."** Design-conscious devs will love the opinionated rubric.
- **"But a vision model scoring design 1-10 is... questionable. Design is subjective."** The scoring will be controversial. Some will trust it, others won't.
- **"I want to plug in my own design system tokens as criteria."** Customization of the rubric is critical for this audience.

---

## Enterprise / Team Devs

### Reaction
- **"Cool concept but no way this passes our security review — a stop hook that blocks exit?"** Enterprise will be skeptical of the autonomous nature.
- **"We need this to integrate with our PR review workflow, not just deploy."** They want PR-level quality gates, not deploy-level.
- **"Where are the tests for the plugin itself?"** Fair point — need unit tests for hooks at minimum.

---

## Prioritized Action Items (from this analysis)

1. **Add `/overseer-abort` command** — escape hatch for the stop hook (HIGH — trust issue)
2. **Add `--skip-deploy` flag** to the overseer skill (HIGH — adoption blocker)
3. **Make deploy provider configurable** — not just Vercel (MEDIUM — expand audience)
4. **Add `jq` check in hooks** with helpful error message if missing (MEDIUM — setup friction)
5. **Add `--dry-run` mode** (MEDIUM — safety net)
6. **Support phase-only runs** like `/overseer --phase quality` (LOW — power user feature)
7. **Add plugin self-tests** (LOW — enterprise trust)
