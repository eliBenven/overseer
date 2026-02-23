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
