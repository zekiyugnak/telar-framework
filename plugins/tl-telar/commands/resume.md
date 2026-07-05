---
id: resume
name: Resume Orchestrated Plan
description: Explicit recovery from an in-progress orchestrated plan. Loads the 3 state files, primes KB, asks the user to confirm resume position. Honors the recovery skill's binding sentinel check.
category: command
usage: /tl-telar:resume
example: /tl-telar:resume
---

# /tl-telar:resume

Sets the orchestrated-mode trigger and loads `skills/orchestration/recovery`. The recovery skill detects the in-progress sentinel, reads state, primes KB, prompts the user for Resume / Start fresh / Inspect.

## When to use

- You compacted a session mid-orchestrate.
- You're returning to a project after a break and want to pick up where you left off.
- SessionStart hook told you there's an in-progress plan.

## When NOT to use

- You don't have an in-progress plan. (Recovery will tell you and exit.)
- You want to start a brand-new feature. Use `/tl-telar:orchestrate <task>` instead.
