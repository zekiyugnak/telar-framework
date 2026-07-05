---
id: review-design
name: Design Review Gate (Collaborative)
description: 6-reviewer collaborative gate on a design doc. APPROVED iff all 6 (PM/Architect/Designer/Security-Design/CTO/Mobile-Platform) approve. Max 3 iterations then escalation.
category: command
usage: /tl-telar:review-design [--latest | --design-file <path>]
example: /tl-telar:review-design --design-file docs/plans/login-flow-design.md
arguments:
  - name: --latest
    description: Review the most recently modified design doc.
    optional: true
  - name: --design-file
    description: Path to the design doc. Overrides --latest.
    optional: true
---

# /tl-telar:review-design

Sets TL_TELAR_ORCHESTRATED=1. Loads `skills/orchestration/design-review-gate`. The skill spawns 6 fresh reviewers in parallel.

## When to use

- After brainstorming → RESEARCH.md commit, before drafting an implementation plan.
- Mid-design when you want a sanity check before investing more in the design.
- Standalone: any time you have a design doc and want adversarial scrutiny.

## When NOT to use

- For trivial single-file changes that don't merit a design doc. The plan-review-gate (sub-spec 1) is enough.
- When you're already mid-implementation. Design review fires pre-plan.

## What this command does NOT do

- Does NOT auto-revise the design doc. Reports findings; human revises.
- Does NOT loop. Each invocation = one pass.
- Does NOT enforce the gate outcome on legacy commands. `/tl-telar:create-app` etc. continue to operate without a design-review gate unless the user explicitly invokes this command.
