# developersDevelopers — Design Spec

**Date:** 2026-04-27
**Status:** Draft (pending implementation plan)
**Owner:** vrennat
**Repo:** github.com/vrennat/developersDevelopers

## Overview

A personal, opinionated Claude Code plugin that replaces obra/superpowers. Captures the "lean superpowers" pattern proven in `~/Developer/ertai`: explicit slash commands, no mandatory entry skill, no skill cascade, "confirm only when ambiguous" routing.

## Why

obra/superpowers ships ~15+ skills with mandatory entry-point cascade and approval gates after every brainstorm/plan/implementation phase. In practice, ~19/20 of those gates are rubber-stamps — overhead masquerading as collaboration. This plugin keeps the *output quality* of that workflow while removing the gates whose override rate doesn't justify their cost.

Constraints:

- Personal but shareable (Gary at `~/Developer/gary` may use it)
- Must NOT bake in stack-specific defaults (those stay in user CLAUDE.md)
- Must replace obra/superpowers entirely (no coexistence)

## Goals (v1)

1. Three workhorse slash commands: `/brainstorm`, `/impl`, `/research`
2. Two opt-in slash commands: `/plan`, `/tdd`
3. Two auto-trigger discipline skills: `systematic-debugging`, `verification-before-completion`
4. Four pre-built subagents: `fast-impl`, `validator`, `brutal-code-reviewer`, `debug-genius`
5. Opt-in templates for hooks and AGENTS.md
6. Total surface ≤ 11 user-facing primitives (5 commands + 2 skills + 4 agents)
7. Each `SKILL.md` ≤ 80 lines; each command ≤ 150 lines; each agent ≤ 60 lines

## Non-goals (v1)

- Stack-specific helpers (SvelteKit/Cloudflare/bun): user CLAUDE.md responsibility
- Git workflow as plugin (`/ship`, `/pr`): stays in user `~/.claude/` for now
- Autonomous loop (`/loop`/`/ralph`): deferred
- Linear/ticket-system commands as required: `/impl` auto-detects Linear MCP, falls back to plain spec input
- Coexistence with obra/superpowers
- Per-folder CLAUDE.md generator
- Worktree helpers / parallel session orchestration

## Architecture

Standard Claude Code plugin format. Single repo at `github.com/vrennat/developersDevelopers`.

```
developersDevelopers/
├── .claude-plugin/
│   └── plugin.json
├── commands/
│   ├── brainstorm.md
│   ├── impl.md
│   ├── plan.md
│   ├── research.md
│   └── tdd.md
├── skills/
│   ├── systematic-debugging/SKILL.md
│   └── verification-before-completion/SKILL.md
├── agents/
│   ├── fast-impl.md
│   ├── validator.md
│   ├── brutal-code-reviewer.md
│   └── debug-genius.md
├── templates/
│   ├── hooks/
│   │   ├── auto-format.sh
│   │   ├── console-log-warn.sh
│   │   └── git-sync-pre-edit.sh
│   └── AGENTS.md
└── README.md
```

**Distribution:**

```bash
/plugin marketplace add vrennat/developersDevelopers
/plugin install developersDevelopers@vrennat
```

## Core principle: "confirm only when ambiguous"

Every command and skill follows a two-axis assessment:

- **Clarity** (clear / ambiguous): is there one obvious approach, or are there 2+ valid approaches with real tradeoffs? Decides whether to *ask*.
- **Complexity** (simple / medium / complex): file count + LOC bounds (1 / 2-3 / >3). Decides how to *route execution*.

**The rule:**

> Clarity decides whether to ask. Complexity decides how to route. Never confuse the two.

A complex task with one obvious approach is executed silently via team. A simple task with two reasonable approaches gets one batched question.

**"Ambiguous" definition (strict):**

- 2+ approaches with real tradeoffs (modal vs inline, server vs client, sync vs async)
- A genuinely missing requirement (sort by what? button or shortcut?)
- A bug with multiple plausible causes

**"Ambiguous" does NOT mean:**

- Many files touched (that's complexity)
- Non-trivial implementation (still clear if approach is obvious)
- Preferred approval as CYA (the rubber-stamp anti-pattern)

**Examples:**

| Task | Clarity | Complexity | Behavior |
|---|---|---|---|
| Card backs render larger than fronts; fix it | clear | simple | Just do it. |
| Add card sorting to hand | ambiguous | medium | One batched question, then proceed. |
| Refactor rules engine for layered effects | clear | complex | Just do it via team. |
| Add dark mode | ambiguous | medium | One batched question. |

**Escape hatch:** the user CLAUDE.md "stop-and-confirm" gates (destructive git, network side effects, money) always confirm regardless of clarity. Those are blast-radius gates, not ambiguity gates.

## Slash commands

### `/brainstorm <description>`

Idea → spec doc. Lean version:

- Clarity-assessed clarifying questions: ask only when ambiguous
- Default to recommendation; do NOT pause for "approve this section" gates
- Output: `docs/specs/YYYY-MM-DD-<slug>-design.md`
- Commits the spec
- Returns control. Does NOT auto-trigger `/impl` or `/plan`.

Replaces `superpowers:brainstorming`.

### `/impl <input>`

Workhorse command. Input is one of:

- Path to a spec file (`/impl docs/specs/foo.md`)
- Linear ticket ID (`/impl ERT-1234`) — fetched via Linear MCP if installed
- Freeform description (`/impl "make banner sticky on mobile"`)

Internal flow:

1. Read input
2. Classify clarity + complexity
3. **Branch on clarity:** ambiguous → batched question, wait. Clear → proceed silently.
4. **Branch on complexity:**
   - Simple (1 file, <50 LOC): direct implementation by main session
   - Medium (2-3 files): 1-2 parallel `fast-impl` agents → `validator`
   - Complex (>3 files): `TeamCreate` + atomic task decomposition + `fast-impl` teammates with dependencies → `validator` → `brutal-code-reviewer` if change touches >5 files OR security-sensitive code OR shared infrastructure
5. `validator` runs typecheck + tests
6. On validator failure: `debug-genius` for diagnosis, then `fast-impl` for fix. Max 3 retry cycles before surfacing to user.
7. `verification-before-completion` skill auto-fires before final claim

**Linear MCP detection:** if `mcp__plugin_linear_linear__*` tools are available and input matches `[A-Z]+-\d+`, fetch the ticket and update its status (In Progress → In Review). If not, skip silently.

Replaces `superpowers:writing-plans` + `superpowers:executing-plans` + `superpowers:subagent-driven-development` + `superpowers:dispatching-parallel-agents`.

### `/plan <input>` (opt-in)

Spec → written plan doc. Only invoke when you genuinely want to review the plan before execution. Most work skips this and goes straight to `/impl`.

Output: `docs/plans/YYYY-MM-DD-<slug>.md`

Replaces `superpowers:writing-plans` for the rare case where written plans are wanted.

### `/research <question>`

Measurable experimentation loop. Sets up `.lab/` directory; runs THINK → TEST → REFLECT iterations. v1 ships its own minimal implementation in the lean style — does NOT depend on any external `researcher` skill.

### `/tdd <description>` (opt-in)

Strict RED-GREEN-REFACTOR scaffold. Only invoke when full TDD discipline is wanted. Not an always-on behavior.

## Auto-trigger skills

### `systematic-debugging`

Fires when Claude observes a real error, test failure, or unexpected runtime output during execution. NOT when the user mentions a bug abstractly.

Procedure:

1. Form hypothesis from observed evidence
2. Design minimal experiment to prove or disprove
3. Run experiment, capture output
4. Iterate until root cause is identified
5. Hand off to `/impl` or direct implementation for fix

### `verification-before-completion`

Fires when Claude is about to claim "done", "fixed", "passing", or "ready". Before any such claim, evidence must be produced.

Procedure:

1. Identify relevant verification command (typecheck, test, build, lint)
2. Run it; capture output
3. Pass: include output verbatim, then claim
4. Fail: do NOT claim done; surface failure

## Subagents

| Agent | Model | Purpose |
|---|---|---|
| `fast-impl` | haiku | Execute clear tasks; no deliberation, no gold-plating |
| `validator` | haiku | Run typecheck + tests; gate not critic; pass/fail report |
| `brutal-code-reviewer` | sonnet | Thorough review for risky/architectural changes |
| `debug-genius` | sonnet | Deep bug investigation when validator fails |

All agent files ≤ 60 lines.

## Templates (opt-in copy)

Not auto-installed. Available via documented `cp` from the plugin path or referenced in README.

- `templates/hooks/auto-format.sh` — Prettier + ESLint on edit (TS/JS/Svelte)
- `templates/hooks/console-log-warn.sh` — warn on `console.log` after edit
- `templates/hooks/git-sync-pre-edit.sh` — block edits if local main behind origin
- `templates/AGENTS.md` — for non-Claude agents (Cursor/Codex) workflow rules

## Skill content style (bloat rules)

**Length caps:**

| File | Cap | Why |
|---|---|---|
| `SKILL.md` | 80 lines | Loaded into context on fire; every line costs tokens |
| Slash command `.md` | 150 lines | Loaded on invocation only |
| Agent `.md` | 60 lines | Long agents are unfocused agents |

**Banned:**

- Graphviz dot blocks
- "Red flags" tables of rationalizations
- Long "anti-pattern" lectures
- Mandatory N-step checklists where most steps are obvious
- "EXTREMELY IMPORTANT" / "MUST" / "NEVER" repeated more than once per file
- Restating the description in the body
- Multi-paragraph examples when a 4-line snippet would do

**Required structure:**

```markdown
---
name: <slug>
description: <one specific sentence>
---

# <Title>

<one paragraph: what this is, when it fires>

## Procedure

1. <step>
2. <step>

## Example

<one short concrete example>
```

**Frontmatter discipline:** `description` is one sentence, specific enough to not match by accident, written from the firing condition's perspective.

**Forbidden chaining rule:** No skill references another skill by name in its body. No "after this, run X." Each skill is a leaf. Chaining is the user's job (one deliberate slash command).

## Compatibility

- **Replaces obra/superpowers:** user uninstalls `obra/superpowers` before installing this
- **Output paths:** `docs/specs/` and `docs/plans/` (project-local). Existing obra-convention files in other projects (e.g., `docs/superpowers/specs/` in ertai) remain in place; this plugin writes new files to the new convention.
- **Stack defaults remain in user CLAUDE.md / rules files** — plugin does NOT prescribe SvelteKit/Cloudflare/bun
- **No new MCP server requirements;** Linear MCP is optional and detected at runtime

## Deferred to v2

- `/ship` — commit + push + deploy (project-specific in ertai; needs generalization)
- `/breakdown` — epic decomposition into atomic tasks (Linear-coupled in ertai)
- `/loop` — generalized `/ralph`: autonomous loop with state file + compaction recovery
- `/ticket`, `/lookup-ticket`, `/pr` — ticket/PR helpers
- `/code-review` — formal review request flow
- Per-folder CLAUDE.md generator
- Worktree helpers / parallel session orchestration

## Open questions for implementation

These don't block the plan; they get resolved during implementation:

- **CLAUDE.md gate list** (destructive git, network side effects, money): referenced from plugin docs, not duplicated.
- **Versioning:** semver from 0.1.0; v1.0.0 ships when dogfooded for 2 weeks on Mulligan Labs without changes.
- **Marketplace publication path:** plugin marketplace add via raw repo URL (no separate marketplace repo for v1).

## Acceptance criteria for v1

- All 5 slash commands installed and functional on a fresh machine
- Both auto-skills fire on documented conditions and not otherwise (verified by manual smoke test)
- All 4 subagents present and dispatchable from `/impl`
- Templates copy cleanly into a new project via documented commands
- Plugin installs via marketplace on a fresh machine in < 60 seconds
- Total user-facing primitives: ≤ 11 (5 commands + 2 skills + 4 agents)
- Spec doc written with `/brainstorm` in <30 minutes by a user familiar with the conventions
