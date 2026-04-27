#!/usr/bin/env bash
# PostToolUse hook: run prettier and eslint on TS/JS/Svelte/CSS/JSON/MD edits.
# Install: copy this script and reference it from .claude/settings.json under
# hooks.PostToolUse with matcher (tool == "Edit" || tool == "Write")
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""')

if [ -n "$file_path" ] && [ -f "$file_path" ]; then
  if [[ "$file_path" =~ \.(ts|tsx|js|jsx|svelte|json|css|md)$ ]]; then
    bunx prettier --write "$file_path" 2>&1 | sed 's/^/[Prettier] /' >&2
  fi
  if [[ "$file_path" =~ \.(ts|tsx|js|jsx|svelte)$ ]]; then
    bunx eslint --fix "$file_path" 2>&1 | sed 's/^/[ESLint] /' >&2
  fi
fi

echo "$input"
