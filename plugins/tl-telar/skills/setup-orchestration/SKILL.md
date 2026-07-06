---
name: "setup-orchestration"
description: "Interactive setup that detects framework (RN/Expo/Flutter), writes framework-aware .tl-telar-thresholds.json, creates .tl-telar/ skeleton, idempotently appends §2.7a hygiene block to .gitignore."
source_type: "command"
source_file: "commands/setup-orchestration.md"
---

# setup-orchestration

Migrated from `commands/setup-orchestration.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- In Codex, this skill is the replacement for the Claude slash command `/tl-telar:setup-orchestration`; invoke it as `$setup-orchestration` or through `@tl-telar`.
- Do not require Claude slash-command dispatch or Claude-only environment setup before following the workflow.
- When the original command says to load `skills/orchestration/<name>`, load the generated Codex skill at `../orchestration-<name>/SKILL.md` first. The original source copy also exists under `../../source/skills/orchestration/<name>/SKILL.md` for exact Telar-source references.


# /tl-telar:setup-orchestration

Runs `scripts/orchestration-setup.sh`. This is idempotent — re-running on a configured project leaves user-customized thresholds, project-profile, and existing gate scripts untouched; `.gitignore` is reconciled **per line** against the §2.7a required-ignore list (each missing entry is appended; existing entries are left in place; no duplicate marker is written). Re-runs after a plugin upgrade therefore pick up newly-required ignore entries (e.g. `wu-*-baseline.tsv`, `wu-*-changes.txt`) without manual edits.

## What it does

1. **Preflight**: refuses to run if invoked against the plugin install dir; verifies Node is installed (used for safe JSON emission). Fails fast with no file mutations on either error.
2. Detects framework from `pubspec.yaml` / `package.json` / Expo signals.
3. Creates `.tl-telar/{plans,context,temp,knowledge,context/evidence}` directory skeleton.
4. Copies `perf-smoke.sh` and `size-check.sh` into the consumer's `scripts/` (idempotent — existing files preserved so user customisations stick).
5. Writes `.tl-telar/project-profile.json` (setup sentinel; Node `JSON.stringify` for safe escaping).
6. Writes `.tl-telar-thresholds.json` with framework-aware coverage command (per master design §2.5.1). Existing user-customized thresholds are NOT overwritten — only the safe-no-op stub is replaced.
7. Per-line reconciles `.gitignore` against §2.7a (creates `.gitignore` if absent; appends marker comment if not yet present; appends each missing required-ignore line).
8. Announces what was detected and what defaults were applied.

## When to use

- First-time setup of a new project.
- Switching framework (rare; re-run will warn if thresholds are already customized).

## When NOT to use

- You've already customized `.tl-telar-thresholds.json`. The script preserves your customizations.

## Tests / conformance

Manual: run on a sample RN, Expo, and Flutter project. Verify the produced thresholds file has the right `coverage_command` and `coverage_strict: true` for each.
