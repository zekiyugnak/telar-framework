---
name: "review-design"
description: "6-reviewer collaborative gate on a design doc. APPROVED iff all 6 (PM/Architect/Designer/Security-Design/CTO/Mobile-Platform) approve. Max 3 iterations then escalation."
source_type: "command"
source_file: "commands/review-design.md"
---

# review-design

Migrated from `commands/review-design.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- In Codex, this skill is the replacement for the Claude slash command `/tl-telar:review-design`; invoke it as `$review-design` or through `@tl-telar`.
- Do not require Claude slash-command dispatch or Claude-only environment setup before following the workflow.
- When the original command says to load `skills/orchestration/<name>`, load the generated Codex skill at `../orchestration-<name>/SKILL.md` first. The original source copy also exists under `../../source/skills/orchestration/<name>/SKILL.md` for exact Telar-source references.


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
