---
name: "resume"
description: "Explicit recovery from an in-progress orchestrated plan. Loads the 3 state files, primes KB, asks the user to confirm resume position. Honors the recovery skill's binding sentinel check."
source_type: "command"
source_file: "commands/resume.md"
---

# resume

Migrated from `commands/resume.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- In Codex, this skill is the replacement for the Claude slash command `/tl-telar:resume`; invoke it as `$resume` or through `@tl-telar`.
- Do not require Claude slash-command dispatch or Claude-only environment setup before following the workflow.
- When the original command says to load `skills/orchestration/<name>`, load the generated Codex skill at `../orchestration-<name>/SKILL.md` first. The original source copy also exists under `../../source/skills/orchestration/<name>/SKILL.md` for exact Telar-source references.


# /tl-telar:resume

Sets the orchestrated-mode trigger and loads `skills/orchestration/recovery`. The recovery skill detects the in-progress sentinel, reads state, primes KB, prompts the user for Resume / Start fresh / Inspect.

## When to use

- You compacted a session mid-orchestrate.
- You're returning to a project after a break and want to pick up where you left off.
- SessionStart hook told you there's an in-progress plan.

## When NOT to use

- You don't have an in-progress plan. (Recovery will tell you and exit.)
- You want to start a brand-new feature. Use `/tl-telar:orchestrate <task>` instead.
