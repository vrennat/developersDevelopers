# developersDevelopers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the developersDevelopers Claude Code plugin per `docs/superpowers/specs/2026-04-27-developersDevelopers-design.md`.

**Architecture:** Standard Claude Code plugin layout (`.claude-plugin/plugin.json` + `commands/`, `skills/`, `agents/`, `templates/` at repo root). No runtime code — content files only. A bash lint script encodes the structural rules from spec section 4 (length caps, frontmatter, banned phrases) and runs before each commit.

**Tech Stack:** Markdown with YAML frontmatter, Bash for templates and lint, Claude Code plugin format.

**Spec reference:** `docs/superpowers/specs/2026-04-27-developersDevelopers-design.md`

---

## Phase A — Foundation

### Task 1: Lint script and gitignore

**Files:**
- Create: `.gitignore`
- Create: `scripts/lint-content.sh`

The lint script encodes spec section 4 rules: length caps (skills 80, commands 150, agents 60), required frontmatter (`name:`, `description:`), and banned patterns (graphviz dot blocks, EXTREMELY/MUST/NEVER repeated more than once).

- [ ] **Step 1: Write `.gitignore`**

```
.DS_Store
node_modules/
*.log
.env
.env.local
```

- [ ] **Step 2: Write `scripts/lint-content.sh`**

```bash
#!/usr/bin/env bash
# Lints plugin content files against rules from
# docs/superpowers/specs/2026-04-27-developersDevelopers-design.md (section 4)
set -euo pipefail

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
```

- [ ] **Step 3: Make executable and run on empty content tree**

```bash
chmod +x scripts/lint-content.sh
./scripts/lint-content.sh
```
Expected output: `Lint passed`

- [ ] **Step 4: Verify lint catches a bad file**

```bash
mkdir -p skills/test-bad
echo "no frontmatter" > skills/test-bad/SKILL.md
./scripts/lint-content.sh || echo "lint correctly failed"
rm -rf skills/test-bad
./scripts/lint-content.sh
```
Expected: first run prints `FAIL: skills/test-bad/SKILL.md missing YAML frontmatter` then exits non-zero. Final run prints `Lint passed`.

- [ ] **Step 5: Commit**

```bash
git add .gitignore scripts/lint-content.sh
git commit -m "chore: add content lint script and gitignore"
```

---

### Task 2: Plugin manifest

**Files:**
- Create: `.claude-plugin/plugin.json`

Format matches obra/superpowers (verified in `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/.claude-plugin/plugin.json`).

- [ ] **Step 1: Write `.claude-plugin/plugin.json`**

```json
{
  "name": "developersDevelopers",
  "description": "Lean, opinionated workflow plugin for Claude Code. Replaces obra/superpowers with confirm-only-when-ambiguous routing.",
  "version": "0.1.0",
  "author": {
    "name": "vrennat",
    "email": "tannervass@gmail.com"
  },
  "homepage": "https://github.com/vrennat/developersDevelopers",
  "repository": "https://github.com/vrennat/developersDevelopers",
  "license": "MIT",
  "keywords": ["workflow", "skills", "lean", "personal"]
}
```

- [ ] **Step 2: Verify JSON is valid**

```bash
python3 -m json.tool < .claude-plugin/plugin.json > /dev/null && echo "valid JSON"
```
Expected: `valid JSON`

- [ ] **Step 3: Commit**

```bash
git add .claude-plugin/plugin.json
git commit -m "feat: add plugin manifest"
```

---

### Task 3: README

**Files:**
- Create: `README.md`

The README is the single contributor + user reference. It documents install, the inventory, the "confirm only when ambiguous" rule, and the skill-writing rules from spec section 4 (so contributors don't drift back into obra-style bloat).

- [ ] **Step 1: Write `README.md`**

````markdown
# developersDevelopers

A lean, opinionated Claude Code plugin. Replaces `obra/superpowers`.

Built around one principle: **confirm only when ambiguous.** No mandatory entry skill, no skill cascade, no rubber-stamp approval gates.

## Install

```bash
/plugin marketplace add vrennat/developersDevelopers
/plugin install developersDevelopers@vrennat
```

Uninstall `obra/superpowers` first — they collide on slash command names.

## Inventory

**Slash commands:**
- `/brainstorm <description>` — idea → spec doc at `docs/superpowers/specs/`
- `/impl <input>` — workhorse. Spec file, ticket ID, or freeform description → executed work.
- `/research <question>` — measurable experimentation loop
- `/plan <input>` (opt-in) — spec → written plan when you want one
- `/tdd <description>` (opt-in) — strict RED-GREEN-REFACTOR scaffold

**Auto-trigger skills:**
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

See `docs/superpowers/specs/2026-04-27-developersDevelopers-design.md`.
````

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README"
```

---

## Phase B — Subagents

Subagents are loaded by `/impl` based on complexity routing. Each agent file ≤ 60 lines.

### Task 4: fast-impl agent

**Files:**
- Create: `agents/fast-impl.md`

- [ ] **Step 1: Write `agents/fast-impl.md`**

```markdown
---
name: fast-impl
description: Use for quick, straightforward implementation of well-defined tasks. Executes clear instructions without deliberation or second-guessing. Ideal for boilerplate, clearly specified functions, mechanical edits across files. Do NOT use for tasks requiring architectural decisions or judgment about approach.
tools: Glob, Grep, Read, Edit, Write, Bash
model: haiku
color: cyan
---

You are a fast implementation agent. Execute clear tasks quickly and correctly.

## Principles

- Execute, don't deliberate. Implement what's requested.
- Minimal code. Just enough to meet requirements.
- No gold-plating. Don't add features, refactoring, or comments beyond scope.

## Procedure

1. Read target file(s)
2. Implement exactly what's requested
3. Verify with the project's typecheck/lint command if available
4. Report: what was done, which files were modified

## Anti-patterns

- Reading the entire codebase "for context"
- Suggesting alternative implementations
- Adding defensive code not requested
- Writing tests unless specifically asked
```

- [ ] **Step 2: Lint**

```bash
./scripts/lint-content.sh
```
Expected: `Lint passed`

- [ ] **Step 3: Commit**

```bash
git add agents/fast-impl.md
git commit -m "feat: add fast-impl subagent"
```

---

### Task 5: validator agent

**Files:**
- Create: `agents/validator.md`

- [ ] **Step 1: Write `agents/validator.md`**

```markdown
---
name: validator
description: Run quality gates after implementation. Typecheck, tests, lint. Verify requirements are met and check for obvious issues. Fast and mechanical. Use after fast-impl completes work, before any code review.
tools: Bash, Glob, Grep, Read
model: haiku
color: yellow
---

You are a fast validation agent. Run quality gates and verify requirements. Gate, not critic.

## Procedure

1. Run the project's typecheck command (`bun run check`, `pnpm typecheck`, `npm run typecheck`, etc. — discover from `package.json` scripts).
2. Run tests if test command exists.
3. Run lint if lint command exists.
4. Check for obvious issues: missing imports, unused variables, console.log statements, runtime errors in output.
5. Verify each stated requirement is implemented and wired up.

## Output format

```
Typecheck: PASS / FAIL
Tests:     PASS / FAIL  (skipped if no tests)
Lint:      PASS / FAIL  (skipped if no lint)
Requirements: X/Y met
Issues:    [list or "None"]
Verdict:   READY FOR REVIEW / NEEDS FIXES
```

Don't do deep code review, architectural feedback, or style opinions. That's brutal-code-reviewer's job.
```

- [ ] **Step 2: Lint and commit**

```bash
./scripts/lint-content.sh
git add agents/validator.md
git commit -m "feat: add validator subagent"
```

---

### Task 6: brutal-code-reviewer agent

**Files:**
- Create: `agents/brutal-code-reviewer.md`

- [ ] **Step 1: Write `agents/brutal-code-reviewer.md`**

```markdown
---
name: brutal-code-reviewer
description: Thorough code review for risky or architectural changes. Use when /impl touches >5 files, security-sensitive code, or shared infrastructure. Identifies real problems; does not nitpick style.
tools: Glob, Grep, Read, Bash
model: sonnet
color: red
---

You review code with technical rigor. Find real problems. Don't nitpick.

## Procedure

1. Read the changes (`git diff` against the base branch, or files listed in the prompt).
2. Read enough surrounding code to understand context.
3. Identify issues, sorted by severity:
   - **Blocking:** correctness bugs, security issues, broken invariants, data loss risks
   - **Significant:** missing error handling at boundaries, unhandled edge cases, race conditions
   - **Worth addressing:** unclear naming, dead code, missed reuse opportunities
4. For each issue, cite file and line. Explain *why* it's a problem and what to do.
5. Flag anything you'd want to verify with the author.

## Output format

```
Verdict: APPROVED / APPROVED WITH CHANGES / BLOCKED

Blocking issues:
- file:line — description and fix

Significant issues:
- file:line — description and fix

Worth addressing:
- file:line — description

Questions for author:
- ...
```

## Out of scope

Style preferences, alternative architectures, refactor suggestions unrelated to the change.
```

- [ ] **Step 2: Lint and commit**

```bash
./scripts/lint-content.sh
git add agents/brutal-code-reviewer.md
git commit -m "feat: add brutal-code-reviewer subagent"
```

---

### Task 7: debug-genius agent

**Files:**
- Create: `agents/debug-genius.md`

- [ ] **Step 1: Write `agents/debug-genius.md`**

```markdown
---
name: debug-genius
description: Deep bug investigation when validator fails or behavior is unexplained. Forms hypotheses, runs minimal experiments to verify, identifies root cause. Use when fast-impl's first attempt didn't work and the cause is not obvious.
tools: Glob, Grep, Read, Bash, Edit
model: sonnet
color: magenta
---

You investigate bugs by hypothesis and experiment. Find the root cause, not a symptom.

## Procedure

1. Read the failure evidence (test output, error message, unexpected behavior).
2. State the observed vs expected in one sentence each.
3. Form 1-3 hypotheses ranked by likelihood.
4. For the top hypothesis, design the smallest experiment that proves or disproves it (a print, a one-line edit, a focused test). Run it.
5. Update or replace hypotheses based on the result. Repeat until root cause is identified.
6. Report: root cause, evidence, recommended fix. Do NOT apply the fix — that's fast-impl's job.

## Anti-patterns

- Guessing without evidence
- "Let me try this and see" without a hypothesis
- Reading 10 files before forming a hypothesis
- Reporting symptoms as causes
```

- [ ] **Step 2: Lint and commit**

```bash
./scripts/lint-content.sh
git add agents/debug-genius.md
git commit -m "feat: add debug-genius subagent"
```

---

## Phase C — Auto-trigger skills

### Task 8: systematic-debugging skill

**Files:**
- Create: `skills/systematic-debugging/SKILL.md`

- [ ] **Step 1: Write `skills/systematic-debugging/SKILL.md`**

```markdown
---
name: systematic-debugging
description: Use when Claude observes a real error, test failure, or unexpected runtime output during execution. Forms hypothesis, runs minimal experiment, iterates to root cause before any fix.
---

# Systematic Debugging

Fires when execution produces a real failure: a test error, a stack trace, a non-zero exit code, or output that contradicts the expected behavior. Does NOT fire when the user mentions a bug abstractly without evidence on screen.

## Procedure

1. State observed vs expected in one sentence each.
2. Form 1-3 hypotheses ranked by likelihood.
3. Design the smallest experiment that proves or disproves the top hypothesis (a print, a one-line edit, a focused test).
4. Run the experiment. Capture the output.
5. Update or replace hypotheses based on the result. Repeat from step 3 until root cause is identified.
6. State the root cause and the proposed fix. Hand off to `/impl` or direct implementation.

## Example

```
Observed: `bun run check` reports `TS2339: Property 'roomId' does not exist on type 'GameState'.`
Expected: typecheck passes after the new prop was added.

Hypothesis 1 (likely): roomId was added to ServerState but not propagated to GameState.
Experiment: grep for `interface GameState` to see the actual definition.

Result: GameState extends ClientState, not ServerState. roomId lives on ServerState.

Root cause: prop placement on the wrong type in the layered state hierarchy.
Fix: move roomId to a shared base interface.
```
```

- [ ] **Step 2: Lint and commit**

```bash
./scripts/lint-content.sh
git add skills/systematic-debugging/SKILL.md
git commit -m "feat: add systematic-debugging skill"
```

---

### Task 9: verification-before-completion skill

**Files:**
- Create: `skills/verification-before-completion/SKILL.md`

- [ ] **Step 1: Write `skills/verification-before-completion/SKILL.md`**

```markdown
---
name: verification-before-completion
description: Use when about to claim work is complete, fixed, passing, or ready. Requires running the verification command and showing its output before any success claim.
---

# Verification Before Completion

Fires when Claude is about to claim "done", "fixed", "passing", "ready", or any equivalent. Before any such claim, evidence must be produced.

## Procedure

1. Identify the relevant verification command (typecheck, test, build, lint — whichever matches the claim).
2. Run it. Capture the output.
3. Pass: include the output verbatim in the response, then make the claim.
4. Fail: do NOT claim done. Surface the failure. Continue work.

## Example

Bad: "Tests are passing now."

Good:
```
$ bun run test:run
✓ src/lib/foo.test.ts (12)
Test Files  1 passed (1)
     Tests  12 passed (12)
```
Tests pass.
```

- [ ] **Step 2: Lint and commit**

```bash
./scripts/lint-content.sh
git add skills/verification-before-completion/SKILL.md
git commit -m "feat: add verification-before-completion skill"
```

---

## Phase D — Slash commands

### Task 10: /brainstorm command

**Files:**
- Create: `commands/brainstorm.md`

- [ ] **Step 1: Write `commands/brainstorm.md`**

```markdown
---
name: brainstorm
description: Idea -> spec doc. Lean: clarifying questions only when ambiguous, default to recommendation, no per-section approval gates. Output to docs/superpowers/specs/.
---

# /brainstorm

Turn an idea into a written spec. Lean version: confirm only when there is genuine ambiguity. Default to your strongest recommendation; do not pause for "approve this section?" gates.

## Procedure

1. Read the user's idea. Skim project context (recent commits, existing docs in `docs/superpowers/`, top-level CLAUDE.md).
2. Identify any **genuinely ambiguous** points: 2+ approaches with real tradeoffs, missing requirements, or scope decisions only the user can make. If none, skip to step 4.
3. Ask all genuinely-ambiguous points in ONE batched message (numbered list). Wait for response. Do not ask one-at-a-time unless the next question depends on the prior answer.
4. Draft the spec internally:
   - Overview, goals, non-goals
   - Architecture / approach (your recommended path; mention alternatives only if you genuinely think the user might want one)
   - Open questions for implementation (resolved with defaults, not TBDs)
   - Acceptance criteria
5. Write the spec to `docs/superpowers/specs/YYYY-MM-DD-<slug>-design.md`. Today's date, lowercase-dashed slug.
6. Commit it: `docs: initial design spec for <slug>`.
7. Tell the user where it is. Do NOT auto-trigger `/impl` or `/plan`.

## Rules

- "Approve this section?" gates are forbidden. The whole spec is one artifact for review at the end, not five.
- Recommend, don't ask "what do you think?" — make the call, justify it in one sentence.
- "Open questions" must have a default decision next to them, not "TBD".
- If the spec covers >1 independent subsystem, decompose. Each subsystem gets its own spec.

## Anti-patterns

- Asking the user to pick between two equivalent options. If equivalent, pick one.
- Writing a 500-line spec for a 50-line feature.
- Asking permission to start writing.
```

- [ ] **Step 2: Lint and commit**

```bash
./scripts/lint-content.sh
git add commands/brainstorm.md
git commit -m "feat: add /brainstorm command"
```

---

### Task 11: /impl command (workhorse)

**Files:**
- Create: `commands/impl.md`

- [ ] **Step 1: Write `commands/impl.md`**

```markdown
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
```

- [ ] **Step 2: Lint and commit**

```bash
./scripts/lint-content.sh
git add commands/impl.md
git commit -m "feat: add /impl workhorse command"
```

---

### Task 12: /plan command

**Files:**
- Create: `commands/plan.md`

- [ ] **Step 1: Write `commands/plan.md`**

```markdown
---
name: plan
description: Spec -> written implementation plan. Opt-in. Use only when you want to review a plan before executing. Most work skips this and goes straight to /impl.
---

# /plan

Generate an explicit implementation plan from a spec. Output: `docs/superpowers/plans/YYYY-MM-DD-<slug>.md`.

Use this when you want a written plan you can review before any code is touched. For most work, `/impl` handles planning inline and saves you a round-trip.

## Procedure

1. Read the input spec or freeform description.
2. Map the file structure: which files are created vs modified, and what each is responsible for.
3. Decompose into atomic tasks. Each task = one file or one logical unit (2-5 minutes of work). Each task ends with a commit.
4. For each task, write:
   - Files (create / modify with line ranges)
   - Steps as a checkbox list (`- [ ]`)
   - Complete code blocks for any code change (no placeholders, no "implement similar to task N")
   - The exact commands to run with expected output
5. Self-review: spec coverage (every requirement has a task), placeholder scan, type/name consistency across tasks.
6. Write the plan to `docs/superpowers/plans/YYYY-MM-DD-<slug>.md`.
7. Commit: `docs: implementation plan for <slug>`.
8. Report path. Do NOT auto-execute.

## Rules

- No placeholders. No "TBD" / "TODO" / "implement later" / "add appropriate error handling".
- No "see Task N" cross-references. Repeat the code if needed.
- Each task is self-contained and committable independently.

## When NOT to use

- The work is simple-to-medium and clear: just `/impl` directly, no plan needed.
- The user said "just build it": skip the plan.
```

- [ ] **Step 2: Lint and commit**

```bash
./scripts/lint-content.sh
git add commands/plan.md
git commit -m "feat: add /plan command"
```

---

### Task 13: /research command

**Files:**
- Create: `commands/research.md`

- [ ] **Step 1: Write `commands/research.md`**

```markdown
---
name: research
description: Measurable experimentation loop. Sets up .lab/ directory and runs THINK -> TEST -> REFLECT iterations. Use for A/B decisions, perf tuning, prompt engineering, or any question with a measurable outcome.
---

# /research

Autonomous experimentation for tasks with measurable outcomes. Use when you can quantify success: a benchmark, an accuracy score, a latency number, an A/B comparison.

## Procedure

1. Restate the question and the success metric in one sentence each.
2. Create `.lab/<slug>/` if it doesn't exist. This is the experiment workspace.
3. **THINK:** form a hypothesis. Write it to `.lab/<slug>/hypothesis.md` with: claim, predicted measurement, smallest experiment that would prove or disprove it.
4. **TEST:** run the experiment. Capture inputs, outputs, and the raw measurement to `.lab/<slug>/runs/<timestamp>.md`.
5. **REFLECT:** compare measurement to prediction. Was the hypothesis confirmed, refuted, or unclear (variance too high)? Write to `.lab/<slug>/reflections.md`.
6. If unclear: run more samples until variance is acceptable. Report sample size and confidence.
7. Iterate from THINK with a refined or replacement hypothesis until the question is answered.
8. Final report: `.lab/<slug>/conclusion.md` with the answer, the evidence, and the variance.

## Rules

- Never report a benchmark without sample size and variance.
- If the result could plausibly be noise, say so. Don't rerun fishing for a better number.
- Keep raw run data on disk; don't delete it.

## When NOT to use

- The answer is already known and just needs implementation: skip to `/impl`.
- The question is qualitative (taste, style): brainstorming, not research.
- Pure reading research: just read.
```

- [ ] **Step 2: Lint and commit**

```bash
./scripts/lint-content.sh
git add commands/research.md
git commit -m "feat: add /research command"
```

---

### Task 14: /tdd command

**Files:**
- Create: `commands/tdd.md`

- [ ] **Step 1: Write `commands/tdd.md`**

```markdown
---
name: tdd
description: Strict RED-GREEN-REFACTOR scaffold. Opt-in. Use when you want full TDD discipline. Not an always-on behavior.
---

# /tdd

Test-driven development loop. RED -> GREEN -> REFACTOR.

Opt-in only. The plugin does NOT auto-enforce TDD on every implementation. Use this when you want the discipline.

## Procedure

1. **SCAFFOLD:** define the interface. Types, function signature, throw `Not implemented`. Commit.
2. **RED:** write the failing test(s). Cover happy path, edge cases (empty/null/max), error conditions. Run tests; verify they FAIL for the right reason.
3. **GREEN:** write the minimum code to pass. No gold-plating. Run tests; verify PASS.
4. **REFACTOR:** improve naming, extract helpers, reduce complexity. Run tests after each change; must stay green.
5. **REPEAT:** next behavior or scenario, back to RED.

Commit after each phase that produces working state (after GREEN, after REFACTOR). Don't commit RED — the test is failing.

## Rules

- Test FIRST. No exceptions in this command.
- Verify the test fails before implementing. A test that "passes" before you implement is testing the wrong thing.
- Refactor only when green. Tests are your safety net.
- Test behavior, not implementation. Don't mock everything; prefer integration tests where reasonable.

## Coverage targets

- General code: 80%+
- Critical paths (state mutations, financial logic, validation): 100%

## When NOT to use

- Quick spike or throwaway script: just write it.
- Exploring a library: write a scratch file, no tests needed.
- Bug fix where reproduction is the test: regression test then fix is fine, but you don't need the full RED-GREEN-REFACTOR ceremony.
```

- [ ] **Step 2: Lint and commit**

```bash
./scripts/lint-content.sh
git add commands/tdd.md
git commit -m "feat: add /tdd command"
```

---

## Phase E — Templates

Templates are opt-in. Users `cp` them into their own project. They are NOT auto-installed.

### Task 15: auto-format hook template

**Files:**
- Create: `templates/hooks/auto-format.sh`

- [ ] **Step 1: Write `templates/hooks/auto-format.sh`**

```bash
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
```

- [ ] **Step 2: Make executable and commit**

```bash
chmod +x templates/hooks/auto-format.sh
git add templates/hooks/auto-format.sh
git commit -m "feat: add auto-format hook template"
```

---

### Task 16: console-log-warn hook template

**Files:**
- Create: `templates/hooks/console-log-warn.sh`

- [ ] **Step 1: Write `templates/hooks/console-log-warn.sh`**

```bash
#!/usr/bin/env bash
# PostToolUse hook: warn when an Edit introduces console.log to a JS/TS/Svelte file.
# Install: PostToolUse hook with matcher tool == "Edit" && tool_input.file_path matches "\\.(ts|tsx|js|jsx|svelte)$"
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""')

if [ -n "$file_path" ] && [ -f "$file_path" ]; then
  console_logs=$(grep -n "console\\.log" "$file_path" 2>/dev/null || true)
  if [ -n "$console_logs" ]; then
    echo "[Hook] WARNING: console.log found in $file_path" >&2
    echo "$console_logs" | head -5 >&2
    echo "[Hook] Remove console.log before committing" >&2
  fi
fi

echo "$input"
```

- [ ] **Step 2: Make executable and commit**

```bash
chmod +x templates/hooks/console-log-warn.sh
git add templates/hooks/console-log-warn.sh
git commit -m "feat: add console-log-warn hook template"
```

---

### Task 17: git-sync-pre-edit hook template

**Files:**
- Create: `templates/hooks/git-sync-pre-edit.sh`

- [ ] **Step 1: Write `templates/hooks/git-sync-pre-edit.sh`**

```bash
#!/usr/bin/env bash
# PreToolUse hook: block edits if local main is behind origin/main.
# Install: PreToolUse hook with matcher (tool == "Edit" || tool == "Write")
set -euo pipefail

current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ "$current_branch" != "main" && "$current_branch" != "master" ]]; then
  exit 0
fi

git fetch origin "$current_branch" --quiet 2>/dev/null || exit 0
behind=$(git rev-list --count "HEAD..origin/$current_branch" 2>/dev/null || echo "0")

if (( behind > 0 )); then
  echo "[Hook] BLOCKED: local $current_branch is $behind commit(s) behind origin/$current_branch" >&2
  echo "[Hook] Run: git pull --rebase origin $current_branch" >&2
  exit 1
fi
```

- [ ] **Step 2: Make executable and commit**

```bash
chmod +x templates/hooks/git-sync-pre-edit.sh
git add templates/hooks/git-sync-pre-edit.sh
git commit -m "feat: add git-sync-pre-edit hook template"
```

---

### Task 18: AGENTS.md template

**Files:**
- Create: `templates/AGENTS.md`

- [ ] **Step 1: Write `templates/AGENTS.md`**

````markdown
# Agent Instructions

This file is read by non-Claude agents (Cursor, Codex). Claude Code reads `CLAUDE.md`.

## Issue tracking

This project tracks work in **<TICKET-SYSTEM>** (e.g., Linear workspace `<workspace>`, project `<project>`, prefix `<PREFIX>-`).

**Rules:**

- If your task references a `<PREFIX>-XXXX` ticket, work on that ticket. Do not create a new one.
- If you cannot find the ticket, ask. Do not invent a parallel record in another tracker.
- Comment progress on the ticket itself, not in a side tracker.

## Branch & push policy

You are almost certainly **not** the repo owner. Default behavior:

1. Work on a feature branch — never commit directly to `main`.
2. Branch naming: `<your-handle>/<prefix>-<ticket-number>-<short-slug>`.
3. Open a PR against `main` when work is ready. Reference the ticket in the PR body.
4. Do not push to `main` directly. Do not force-push. Do not use `--no-verify`.

The only exception is the repo owner, who may push straight to `main` per their own workflow rules.

## Before you start

1. Confirm you're in the right repo: `git remote get-url origin`. If unexpected, stop and ask.
2. Run `git config user.email`. If missing or set to `*@*.local`, ask the human to set their git identity before committing.
3. Read `CLAUDE.md` for technical/architecture context. The patterns there apply to all agents.

## What "done" looks like

A task is done when:

1. The change is committed on a feature branch with a conventional-commit message.
2. The project's typecheck and lint commands pass locally.
3. A PR is open against `main` with the ticket referenced.
4. The PR body summarizes **what** changed and **how to test**.

Do not claim a task complete before the PR exists. Do not push the branch and stop.
````

- [ ] **Step 2: Commit**

```bash
git add templates/AGENTS.md
git commit -m "feat: add AGENTS.md template"
```

---

## Phase F — Integration smoke test

### Task 19: Smoke-test the plugin locally

**Files:** none created; verifies installed plugin.

- [ ] **Step 1: Final lint pass over all content**

```bash
./scripts/lint-content.sh
```
Expected: `Lint passed`

- [ ] **Step 2: Verify directory structure matches spec**

```bash
find . -type f \( -name "*.md" -o -name "*.json" -o -name "*.sh" \) \
  -not -path "./.git/*" -not -path "./docs/*" | sort
```
Expected output (order-independent):
```
./.claude-plugin/plugin.json
./README.md
./agents/brutal-code-reviewer.md
./agents/debug-genius.md
./agents/fast-impl.md
./agents/validator.md
./commands/brainstorm.md
./commands/impl.md
./commands/plan.md
./commands/research.md
./commands/tdd.md
./scripts/lint-content.sh
./skills/systematic-debugging/SKILL.md
./skills/verification-before-completion/SKILL.md
./templates/AGENTS.md
./templates/hooks/auto-format.sh
./templates/hooks/console-log-warn.sh
./templates/hooks/git-sync-pre-edit.sh
```

That's 18 files. Plus `.gitignore` and the spec/plan in `docs/`.

- [ ] **Step 3: Verify primitive count matches spec acceptance criteria**

```bash
echo "Commands: $(ls commands/*.md | wc -l | tr -d ' ')"
echo "Skills:   $(ls skills/*/SKILL.md | wc -l | tr -d ' ')"
echo "Agents:   $(ls agents/*.md | wc -l | tr -d ' ')"
```
Expected: `Commands: 5`, `Skills: 2`, `Agents: 4`. Total: 11 user-facing primitives. Matches spec acceptance criteria.

- [ ] **Step 4: Verify plugin.json is valid**

```bash
python3 -m json.tool < .claude-plugin/plugin.json > /dev/null && echo "valid"
```
Expected: `valid`

- [ ] **Step 5: Tag v0.1.0**

```bash
git tag -a v0.1.0 -m "v0.1.0 — initial release"
git log --oneline | head -25
```
Expected: ~21 commits visible (1 spec + 1 plan + 19 task commits).

- [ ] **Step 6: Manual install test (deferred to user)**

Push to `github.com/vrennat/developersDevelopers`, then on a fresh shell:

```
/plugin marketplace add vrennat/developersDevelopers
/plugin install developersDevelopers@vrennat
```

Then in a Claude Code session, verify:
- `/brainstorm "test"` produces a spec at `docs/superpowers/specs/`
- `/impl --dry-run "fix typo in README"` prints clarity + complexity classification
- `systematic-debugging` skill appears in the available-skills list

This step is the user's call when they're ready to publish.

---

## Self-Review

**Spec coverage:**
- 5 slash commands: Tasks 10-14 ✓
- 2 auto-skills: Tasks 8-9 ✓
- 4 subagents: Tasks 4-7 ✓
- 3 hook templates + AGENTS.md: Tasks 15-18 ✓
- plugin.json: Task 2 ✓
- README: Task 3 ✓
- Lint enforcing length caps + frontmatter + banned patterns: Task 1 ✓
- Output paths matching obra convention: covered in `/brainstorm` and `/plan` content ✓
- Linear MCP detection: covered in `/impl` content ✓
- Acceptance criteria (≤11 primitives, install in <60s): Task 19 verifies ✓

**Placeholder scan:** No "TBD" / "TODO" / "fill in later" anywhere. AGENTS.md template uses `<TICKET-SYSTEM>` and `<PREFIX>` as explicit user-fill markers, which is correct (it's a template, not source).

**Type/name consistency:**
- Skill name slugs (`systematic-debugging`, `verification-before-completion`) consistent across spec, README, and SKILL.md frontmatter.
- Agent names (`fast-impl`, `validator`, `brutal-code-reviewer`, `debug-genius`) consistent across spec, README, agent files, and `/impl` references.
- Command names (`brainstorm`, `impl`, `plan`, `research`, `tdd`) consistent.

No issues found.
