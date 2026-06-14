# developersDevelopers

A workflow plugin for Claude Code. Replaces `obra/superpowers` with a leaner version that doesn't ask you to approve every paragraph it writes.

If you've used `obra/superpowers` and noticed you say "yes, do that" 19 out of 20 times, this is for you.

## What you get

```
/brainstorm "live spectator mode"   → idea becomes a spec at docs/specs/
/impl ERT-1234                      → ticket gets read, classified, executed
/impl docs/specs/foo-design.md      → spec gets routed and built
/research "is option A faster?"     → measurable experiment loop
```

`/impl` is the workhorse. It assesses every task on three axes — clarity, complexity, and stakes — and **only asks you a question when there's genuine ambiguity**, not after every section of every plan. Touches one file? Direct edit. Touches five? Spawns subagents in parallel — after a deliberate second look at the approach, not just the first pattern that looks right. Touches auth or money? An independent `adversarial-reviewer` tries to break it first. Bug with a real error? Pulls in `debug-genius`. You decide nothing routine; the plugin decides nothing ambiguous.

## Install

```
/plugin marketplace add vrennat/developersDevelopers
/plugin install developersDevelopers@vrennat
```

**Uninstall `obra/superpowers` first** — they collide on slash command names.

## First-time setup (per project)

```
/bootstrap
```

Creates `docs/specs/` and `docs/plans/`, detects legacy `docs/superpowers/` paths, prints copy-paste commands for migration, CLAUDE.md, and hooks. Idempotent.

## Inventory

### Slash commands

| Command | Use |
|---|---|
| `/impl <input>` | The default. Spec file, ticket ID, or freeform description → executed work. |
| `/brainstorm <idea>` | Idea → spec doc at `docs/specs/`. |
| `/research <question>` | Measurable experiment loop (THINK → TEST → REFLECT). |
| `/plan <input>` | *(opt-in)* Spec → written plan when you want one to review first. |
| `/tdd <description>` | *(opt-in)* Strict RED-GREEN-REFACTOR scaffold. |
| `/bootstrap` | Run once per project. |

### Subagents (used by `/impl`)

- `fast-impl` (haiku) — execute clear tasks
- `validator` (haiku) — typecheck + tests
- `brutal-code-reviewer` (sonnet) — routine review for risky/architectural changes
- `adversarial-reviewer` (sonnet) — independent break-it pass on high-stakes changes (auth, money, data, security, privacy)
- `debug-genius` (sonnet) — deep bug investigation

### Auto-trigger skills

You don't invoke these — they fire on signals.

- `systematic-debugging` — fires on observed errors/test failures
- `verification-before-completion` — fires before any "done/fixed/passing" claim
- `onboarding` — surfaces `/bootstrap` for new installs and obra/superpowers migrations

### Dual-mode skills

- `plan-hunter` — tournament-style planning (4 lenses → 4 judges → synthesis) for substantive multi-week plans. Invoke with `/plan-hunter <idea>`, or it fires on open-ended planning asks.

### Templates (opt-in `cp` from `templates/`)

- `hooks/git-sync-pre-edit.sh` — block edits when local main is behind origin (catches parallel-session divergence)
- `settings.example.json` — pre-wired `.claude/settings.json` for the hook above
- `AGENTS.md` — for non-Claude agents (Cursor, Codex)

## The design rule

**Clarity decides whether to ask. Complexity decides how to route. Stakes decides how hard to verify. Never confuse the three.**

| Task | Clarity | Complexity | Stakes | Behavior |
|---|---|---|---|---|
| Card backs render larger than fronts; fix it | clear | 1 file | normal | Just do it. |
| Add card sorting to hand | ambiguous (sort by? UI?) | 2-3 files | normal | One batched question, then proceed. |
| Refactor rules engine for layered effects | clear (architecture documented) | >3 files | normal | Just do it via subagent team. |
| Fix the JWT expiry check | clear | 1 file | high | Just do it, then an independent `adversarial-reviewer` pass. |

"Many files touched" is complexity, not ambiguity. "Non-trivial implementation" is complexity, not ambiguity. "Touches auth/money/data" is stakes — it forces a verification pass even on a one-file change. "I'd like CYA approval" is the rubber-stamp anti-pattern this plugin exists to kill.

**Escape hatch:** destructive ops (force-push, deploys, money) always confirm. Those are blast-radius gates, not ambiguity gates.

## Contributing

Run `./scripts/lint-content.sh` before committing, or wire it to run on every push with `git config core.hooksPath .githooks`. It enforces the structural rules:

- **Version bump guard:** if `commands/`, `skills/`, `agents/`, or `templates/` changed since the last release tag, `plugin.json` must carry a new version (and match `marketplace.json`) — otherwise installs never see the change
- **Length caps:** skills ≤ 80 lines, commands ≤ 150 lines, agents ≤ 60 lines
- **Frontmatter:** `name:` and `description:` required; description must be specific enough that no two skills match the same prompt — trigger and skip conditions belong there, length is secondary
- **No graphviz dot blocks. No `EXTREMELY IMPORTANT/MUST/NEVER` repeated more than once per file.**
- **No skill references another skill by name in its body** — each skill is a leaf; chaining is the user's job

## License

MIT — see [LICENSE](LICENSE).
