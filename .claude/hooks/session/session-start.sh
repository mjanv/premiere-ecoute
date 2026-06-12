#!/bin/bash
# AIDEV-NOTE: SessionStart hook - creates SESSION.md memory file for claude/ branches

cd "$CLAUDE_PROJECT_DIR" || exit 0

BRANCH=$(git branch --show-current 2>/dev/null)
[[ "$BRANCH" == claude/* ]] || exit 0

SESSION_FILE="$CLAUDE_PROJECT_DIR/SESSION.md"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M")

cat > "$SESSION_FILE" <<EOF
# Session — $BRANCH — $TIMESTAMP
EOF

echo "SESSION.md created for branch $BRANCH"
