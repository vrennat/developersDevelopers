---
name: init
description: Bootstrap a project to use developersDevelopers. Creates docs/specs and docs/plans, detects legacy obra/superpowers paths, prints copy-paste commands for migration and templates. Idempotent.
---

# /init

One-time project setup for the developersDevelopers workflow. Probes current state, creates missing directories, prints copy-paste commands for everything else.

Idempotent: safe to re-run. The only filesystem mutations are `mkdir docs/specs/` and `mkdir docs/plans/`. Migration moves, CLAUDE.md edits, and hook installs are printed, not executed — the user runs them when ready.

## Procedure

1. Verify cwd is a git repo: `git rev-parse --git-dir`. If not, stop and tell user to `git init` first.

2. Probe state:
   - `docs/specs/` — exists or absent
   - `docs/plans/` — exists or absent
   - `docs/superpowers/specs/` — legacy obra path
   - `docs/superpowers/plans/` — legacy obra path
   - `CLAUDE.md` at repo root
   - `.claude/settings.json` (for hook detection)

3. Create what's missing:
   - `mkdir -p docs/specs docs/plans` (always safe)

4. Print state report:

```
=== developersDevelopers /init ===
Repo:          <git remote get-url origin 2>/dev/null || echo "(no remote)">
docs/specs/    <created | already exists>
docs/plans/    <created | already exists>
Legacy paths:  <none | docs/superpowers/specs/ (N files), docs/superpowers/plans/ (N files)>
CLAUDE.md:     <present | missing>
Hooks:         <configured in .claude/settings.json | not configured>
=================================
```

5. **If legacy paths detected**, print migration commands (do NOT execute):

```
To migrate legacy obra/superpowers paths to the new convention:

  git mv docs/superpowers/specs/*.md docs/specs/ 2>/dev/null
  git mv docs/superpowers/plans/*.md docs/plans/ 2>/dev/null
  rm -rf docs/superpowers
  git add -A
  git commit -m "refactor: migrate spec/plan paths to docs/specs and docs/plans"

Review and run when ready.
```

6. **If CLAUDE.md is missing or doesn't reference this plugin**, print a snippet:

```
Consider adding to CLAUDE.md:

  ## Workflow
  This project uses developersDevelopers (github.com/vrennat/developersDevelopers).
  - /brainstorm <idea>  -> spec at docs/specs/
  - /impl <input>       -> classified, routed execution
  - /research <q>       -> measurable experiments
```

7. **Hook templates** (printed, not installed). Resolve plugin path dynamically:

```
To install hook templates:

  PLUGIN=$(ls -d ~/.claude/plugins/cache/vrennat/developersDevelopers/*/templates 2>/dev/null | sort -V | tail -1)
  mkdir -p .claude/hooks
  cp "$PLUGIN/hooks/"*.sh .claude/hooks/
  chmod +x .claude/hooks/*.sh

Then wire them up in .claude/settings.json. See $PLUGIN/../README.md for matchers.
```

8. **Final next steps:**

```
Setup complete. Try:
  /brainstorm "<your first idea>"
  /impl "<small fix>"

Run /init again any time — it's idempotent.
```

## Rules

- The ONLY filesystem mutation is `mkdir docs/specs docs/plans`. Everything else is printed for user execution.
- Never modify CLAUDE.md, .claude/settings.json, or any user config.
- Re-running on a set-up project produces the same report with all "already exists" lines.
- If `git rev-parse --git-dir` fails, stop with `git init` instruction. Don't proceed.

## Anti-patterns

- Auto-running the migration `git mv` commands. The user reviews first.
- Silently creating CLAUDE.md or settings.json. Both are user-owned.
- Failing on re-run because directories exist. Use `mkdir -p`.
