# developersDevelopers

A lean, opinionated Claude Code plugin. Replaces `obra/superpowers`.

Built around one principle: **confirm only when ambiguous.** No mandatory entry skill, no skill cascade, no rubber-stamp approval gates.

## Install

```bash
/plugin marketplace add vrennat/developersDevelopers
/plugin install developersDevelopers@vrennat
```

Uninstall `obra/superpowers` first — they collide on slash command names.

## First-time setup

In any project where you want to use this workflow:

```
/init
```

It creates `docs/specs/` and `docs/plans/`, detects any legacy `docs/superpowers/` paths from obra, and prints copy-paste commands for migration, CLAUDE.md, and hook templates. Idempotent — safe to re-run.

## Inventory

**Slash commands:**
- `/init` — bootstrap a project for this workflow (run once per repo)
- `/brainstorm <description>` — idea → spec doc at `docs/specs/`
- `/impl <input>` — workhorse. Spec file, ticket ID, or freeform description → executed work.
- `/research <question>` — measurable experimentation loop
- `/plan <input>` (opt-in) — spec → written plan when you want one
- `/tdd <description>` (opt-in) — strict RED-GREEN-REFACTOR scaffold

**Auto-trigger skills:**
- `onboarding` — surfaces `/init` when a user mentions installing, configuring, or migrating
- `systematic-debugging` — fires on observed errors/test failures
- `verification-before-completion` — fires before any "done/fixed/passing" claim

**Subagents:**
- `fast-impl` (haiku) — execute clear tasks
- `validator` (haiku) — typecheck + tests
- `brutal-code-reviewer` (sonnet) — review for risky/architectural changes
- `debug-genius` (sonnet) — deep bug investigation

**Templates** (in `templates/`, opt-in `cp` into your project):
- `hooks/auto-format.sh`, `hooks/console-log-warn.sh`, `hooks/git-sync-pre-edit.sh`
- `AGENTS.md` for non-Claude agent workflows

## The core rule

Two-axis assessment: **clarity** (clear/ambiguous) and **complexity** (1 / 2-3 / >3 files).

Clarity decides whether to *ask*. Complexity decides how to *route*. Never confuse the two.

A complex task with one obvious approach: just do it via team. A simple task with two reasonable approaches: one batched question, then proceed.

## Contributing

When adding a skill, command, or agent, run `./scripts/lint-content.sh` before committing. It enforces:

- Length caps: skills ≤ 80 lines, commands ≤ 150 lines, agents ≤ 60 lines
- Required frontmatter: `name:` and `description:`
- No graphviz dot blocks. No "EXTREMELY IMPORTANT/MUST/NEVER" repeated more than once per file.

Required structure for skills/agents:

```markdown
---
name: <slug>
description: <one specific sentence>
---

# <Title>

<one paragraph>

## Procedure

1. <step>
2. <step>

## Example

<one short example>
```

No skill references another skill by name in its body. Each skill is a leaf — chaining is the user's job.

## Spec

See `docs/specs/2026-04-27-developersDevelopers-design.md`.
