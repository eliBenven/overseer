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
