#!/bin/bash
# AIDEV-NOTE: PostToolUse hook - runs mix format on .ex/.exs files after Write/Edit/NotebookEdit

cd "$CLAUDE_PROJECT_DIR" || exit 0

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')

[[ "$FILE" == *.ex || "$FILE" == *.exs ]] || exit 0

mix format "$FILE"
