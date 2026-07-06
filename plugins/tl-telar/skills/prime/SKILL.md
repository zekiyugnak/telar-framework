---
name: "prime"
description: "Load relevant KB facts into current context. Wraps scripts/tl-telar-prime.sh."
source_type: "command"
source_file: "commands/prime.md"
---

# prime

Migrated from `commands/prime.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- In Codex, this skill is the replacement for the Claude slash command `/tl-telar:prime`; invoke it as `$prime` or through `@tl-telar`.
- Do not require Claude slash-command dispatch or Claude-only environment setup before following the workflow.
- When the original command says to load `skills/orchestration/<name>`, load the generated Codex skill at `../orchestration-<name>/SKILL.md` first. The original source copy also exists under `../../source/skills/orchestration/<name>/SKILL.md` for exact Telar-source references.


# /tl-telar:prime

Loads relevant KB facts from `.tl-telar/knowledge/*.jsonl` into conversation context. Wraps `scripts/tl-telar-prime.sh`.

## Behavior

1. Forward args to `scripts/tl-telar-prime.sh`.
2. Capture stdout (5 categories: MUST FOLLOW / GOTCHAS / PATTERNS / DECISIONS / API BEHAVIORS).
3. Present to user (or inject into agent context).

## When to use

- Start of any planning, implementation, review, or debugging task.
- After /tl-telar:resume (recovery already calls prime internally; explicit re-prime is rarely needed).

## When NOT to use

- Mid-implementation in a tight feedback loop. Re-priming pollutes context.
