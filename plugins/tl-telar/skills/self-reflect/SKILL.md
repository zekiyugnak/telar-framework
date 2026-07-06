---
name: "self-reflect"
description: "Capture durable learnings from recent PRs + current conversation + optional config audit. User-approval gate on every candidate. Writes to .tl-telar/knowledge/*.jsonl."
source_type: "command"
source_file: "commands/self-reflect.md"
---

# self-reflect

Migrated from `commands/self-reflect.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- In Codex, this skill is the replacement for the Claude slash command `/tl-telar:self-reflect`; invoke it as `$self-reflect` or through `@tl-telar`.
- Do not require Claude slash-command dispatch or Claude-only environment setup before following the workflow.
- When the original command says to load `skills/orchestration/<name>`, load the generated Codex skill at `../orchestration-<name>/SKILL.md` first. The original source copy also exists under `../../source/skills/orchestration/<name>/SKILL.md` for exact Telar-source references.


# /tl-telar:self-reflect

Loads `skills/orchestration/self-reflect`. Runs Phase A (PR comments) + Phase B (conversation mining) + optionally Phase C (config audit). Every candidate goes through an explicit user-approval gate.

## When fires automatically

- `orchestrator` Step 7 (pre-PR) on multi-WU runs.
- Per-WU if `enforcement.self_reflect_per_wu: true` in `.tl-telar-thresholds.json`.

## When fires manually

- Explicit `/tl-telar:self-reflect` invocation.
- After a significant debugging session, before closing the conversation.
- Weekly retrospective.

## What this command does NOT do

- Does NOT auto-write facts without user approval (binding gate at Step 4 of the skill).
- Does NOT migrate old `.claude/skills/learned/*.md` files (manual migration documented but not run automatically).
- Does NOT commit the JSONL changes (per user's `ben yapacagim` git policy).
