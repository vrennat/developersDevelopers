---
name: onboarding
description: Use when user mentions installing, configuring, or starting a project with developersDevelopers, or asks how to migrate from obra/superpowers. Surfaces the /init bootstrap command.
---

# Onboarding

Fires when the user is starting fresh with this plugin or migrating from obra/superpowers.

## Procedure

1. Tell the user to run `/init` in their project root. It:
   - Creates `docs/specs/` and `docs/plans/` if missing.
   - Detects legacy `docs/superpowers/specs/` and `docs/superpowers/plans/` from obra and prints `git mv` commands to migrate.
   - Prints a CLAUDE.md snippet to consider and hook-template copy commands.
   - Is idempotent — safe to re-run.
2. After `/init`, point them at the plugin README for the full inventory of slash commands and skills.

## Example

User: "I just installed developersDevelopers, what now?"
Response: "Run `/init` in your project root — it bootstraps `docs/specs/` and `docs/plans/`, prints any migration steps if you have legacy obra paths, and shows the next moves."
