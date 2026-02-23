#!/bin/bash
set -euo pipefail

# jq is required for parsing pipeline state
if ! command -v jq &>/dev/null; then
  echo "[Overseer] Error: jq is not installed. Install it with 'brew install jq' or 'apt-get install jq'. Releasing stop hook." >&2
  exit 0
fi

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
