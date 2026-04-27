#!/usr/bin/env bash
# Lints plugin content files against rules from
# docs/specs/2026-04-27-developersDevelopers-design.md (section 4)
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || true
if [[ -z "$repo_root" ]]; then
  echo "Must run from inside a git repo" >&2
  exit 1
fi
cd "$repo_root"

errors=0

check_length() {
  local file="$1" cap="$2" lines
  lines=$(wc -l < "$file" | tr -d ' ')
  if (( lines > cap )); then
    echo "FAIL: $file is $lines lines (cap: $cap)"
    errors=$((errors + 1))
  fi
}

check_frontmatter() {
  local file="$1"
  if ! head -1 "$file" | grep -q '^---$'; then
    echo "FAIL: $file missing YAML frontmatter"
    errors=$((errors + 1))
    return
  fi
  grep -q '^name: ' "$file" || { echo "FAIL: $file missing 'name:'"; errors=$((errors + 1)); }
  grep -q '^description: ' "$file" || { echo "FAIL: $file missing 'description:'"; errors=$((errors + 1)); }
}

check_banned() {
  local file="$1"
  if grep -q '```dot' "$file"; then
    echo "FAIL: $file contains forbidden graphviz dot block"
    errors=$((errors + 1))
  fi
  local count
  count=$(grep -cE 'EXTREMELY (IMPORTANT|CRITICAL)|^\*?\*?MUST |^\*?\*?NEVER ' "$file" 2>/dev/null || true)
  if (( count > 1 )); then
    echo "FAIL: $file uses EXTREMELY/MUST/NEVER $count times (cap: 1)"
    errors=$((errors + 1))
  fi
}

for f in skills/*/SKILL.md; do
  [[ -f "$f" ]] || continue
  check_length "$f" 80; check_frontmatter "$f"; check_banned "$f"
done
for f in commands/*.md; do
  [[ -f "$f" ]] || continue
  check_length "$f" 150; check_frontmatter "$f"; check_banned "$f"
done
for f in agents/*.md; do
  [[ -f "$f" ]] || continue
  check_length "$f" 60; check_frontmatter "$f"; check_banned "$f"
done

if (( errors > 0 )); then
  echo; echo "Lint failed with $errors error(s)"; exit 1
fi
echo "Lint passed"
