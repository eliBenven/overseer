---
description: "Emergency stop: cancel the active Overseer pipeline and release the stop hook"
argument-hint: "[--force]"
---

# Abort Overseer Pipeline

Immediately cancel the active Overseer pipeline so the stop hook releases control.

## Process

1. Check if `.claude/overseer/active-pipeline.json` exists
   - If not: "No active Overseer pipeline to abort."

2. Read the current state for reporting:
   - Current phase
   - Iteration count
   - Any scores collected

3. Save a partial state to `.claude/overseer/state.json`:
   ```json
   {
     "last_session": "Aborted during [phase] at iteration [N]",
     "last_scores": { ... },
     "pending": ["Pipeline was aborted — resume with /overseer"],
     "aborted_at": "ISO timestamp"
   }
   ```

4. Remove `.claude/overseer/active-pipeline.json`

5. Confirm: "Overseer pipeline aborted. The stop hook will no longer block. Use /overseer to restart."
