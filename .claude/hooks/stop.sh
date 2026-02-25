#!/bin/bash
# AIDEV-NOTE: Stop hook - on first invocation asks Claude to update SESSION.md;
#             on second invocation (stop_hook_active=true) runs mix test and auto-commits.

cd "$CLAUDE_PROJECT_DIR" || exit 0

BRANCH=$(git branch --show-current 2>/dev/null)
[[ "$BRANCH" == claude/* ]] || exit 0

INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')

if [[ "$STOP_HOOK_ACTIVE" == "false" ]]; then
  # First invocation: ask Claude to update SESSION.md before finishing
  cat <<EOF
{
  "decision": "block",
  "reason": "Before finishing, update SESSION.md with a concise engineering note about what was done this turn: decisions made, solutions chosen, problems encountered, current state. Be brief and factual. Then you may stop.",
  "suppressOutput": true
}
EOF
  exit 0
fi

# Second invocation (stop_hook_active=true): run tests and commit

# --- Run mix test ---
mix test 2>&1

# --- Auto-commit tracked changes only (exclude compiled artifacts) ---
# Stage only tracked files to avoid committing _build, deps, etc.
if ! git diff --quiet; then
  git add -u
  TIMESTAMP=$(date +"%Y-%m-%d %H:%M")
  git commit -m "chore: auto-checkpoint [$TIMESTAMP]"
  echo "Auto-committed changes on $BRANCH"
fi

exit 0
