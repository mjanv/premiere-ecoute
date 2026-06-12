#!/bin/bash
# AIDEV-NOTE: SessionStart hook — cloud DB/deps setup + SESSION.md for claude/* branches

cd "$CLAUDE_PROJECT_DIR" || exit 0

# Cloud-only: start PostgreSQL and prepare the test database
if [ "$CLAUDE_CODE_REMOTE" = "true" ]; then
  echo "==> Starting PostgreSQL..."
  service postgresql start || true

  echo "==> Setting postgres password..."
  su -c "psql -c \"ALTER USER postgres PASSWORD 'postgres';\" 2>/dev/null || true" postgres

  echo "==> Installing Mix dependencies..."
  mix deps.get

  echo "==> Setting up test database..."
  MIX_ENV=test mix ecto.setup || true

  echo "==> Cloud setup complete."
fi

# SESSION.md for claude/* branches (local and cloud)
BRANCH=$(git branch --show-current 2>/dev/null)
[[ "$BRANCH" == claude/* ]] || exit 0

SESSION_FILE="$CLAUDE_PROJECT_DIR/SESSION.md"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M")

cat > "$SESSION_FILE" <<EOF
# Session — $BRANCH — $TIMESTAMP
EOF

echo "SESSION.md created for branch $BRANCH"
