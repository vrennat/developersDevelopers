---
name: impl
description: Workhorse command. Spec file, ticket ID, or freeform description -> classified, routed, executed work. Confirms only when ambiguous. Auto-detects Linear MCP for ticket flows.
---

# /impl

Execute work. Input is one of:

- Path to spec file: `/impl docs/superpowers/specs/foo.md`
- Ticket ID: `/impl ERT-1234` (uses Linear MCP if available)
- Freeform: `/impl "make banner sticky on mobile"`
- `--dry-run` flag: print the assessment and stop

## Procedure

1. **Parse input.** If it matches `[A-Z]+-\d+` and Linear MCP tools (`mcp__plugin_linear_linear__*` or `mcp__claude_ai_Linear__*`) are available, fetch the ticket. If it's a path, read the spec. Otherwise treat as freeform.

2. **Classify clarity AND complexity.**
   - Clarity: clear (one obvious approach) or ambiguous (2+ approaches with real tradeoffs, OR missing requirement, OR multi-cause bug).
   - Complexity: simple (1 file, <50 LOC), medium (2-3 files), complex (>3 files).
   - Print one line: `Clarity: clear/ambiguous | Complexity: simple/medium/complex`.

3. **Branch on clarity.**
   - Ambiguous: ask all open questions in ONE batched numbered list. Wait. Then proceed.
   - Clear: proceed silently.

4. **If `--dry-run`:** print the planned routing and stop.

5. **If Linear ticket:** update status to "In Progress" via Linear MCP.

6. **Branch on complexity.**
   - Simple: implement directly in main session.
   - Medium: spawn 1-2 `fast-impl` agents in parallel via the Agent tool. Then dispatch `validator`.
   - Complex: `TeamCreate` with name like `impl-<slug>`. Decompose into atomic tasks via `TaskCreate` (one per file, with paths and acceptance criteria, plus `blockedBy` dependencies). Spawn `fast-impl` teammates. Monitor via `SendMessage`. On completion: `TeamDelete`, then dispatch `validator`. If change touches >5 files OR security-sensitive code OR shared infrastructure: also dispatch `brutal-code-reviewer`.

7. **On `validator` failure:** dispatch `debug-genius` for diagnosis, then `fast-impl` for fix using debug-genius's output. Max 3 retry cycles before surfacing to user.

8. **Final step:** the `verification-before-completion` skill auto-fires before claiming done. Run the verification command and paste output verbatim.

9. **If Linear ticket:** update status to "In Review".

10. **Report:**
```
Files modified: <list>
Verdict: <validator output>
Next: test locally; commit when ready.
```

## Rules

- "Ambiguous" is strict: 2+ real-tradeoff approaches, missing requirement, or multi-cause bug. NOT "I'd like to confirm this." NOT "this is non-trivial." NOT "this touches many files" (that's complexity).
- Do NOT auto-commit work. Do NOT auto-create PRs. The user decides.
- The escape hatch from `~/.claude/CLAUDE.md` (destructive git, network side effects, money) always confirms regardless of clarity.

## Examples

Clear + simple: `/impl "card backs render larger than fronts"` -> classify -> direct fix to one CSS rule -> validator -> done.

Ambiguous + medium: `/impl "add card sorting to hand"` -> ONE batched question (sort by? UI?) -> on answer, spawn 1-2 fast-impl, validator, done.

Clear + complex: `/impl ERT-1234` (refactor rules engine for layered effects, ticket has design) -> TeamCreate, decompose, fast-impl teammates, validator, brutal-code-reviewer (touches >5 files), done.
