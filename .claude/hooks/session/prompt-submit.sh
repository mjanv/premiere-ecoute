#!/bin/bash
# AIDEV-NOTE: UserPromptSubmit hook - injects SESSION.md into Claude's context on claude/ branches

cd "$CLAUDE_PROJECT_DIR" || exit 0

BRANCH=$(git branch --show-current 2>/dev/null)
[[ "$BRANCH" == claude/* ]] || exit 0

SESSION_FILE="$CLAUDE_PROJECT_DIR/SESSION.md"
[[ -f "$SESSION_FILE" ]] || exit 0

CONTENT=$(cat "$SESSION_FILE")

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "Current session memory (SESSION.md):\n\n$CONTENT"
  }
}
EOF
