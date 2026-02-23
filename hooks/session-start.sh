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
