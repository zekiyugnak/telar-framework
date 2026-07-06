---
name: "review-plan"
description: "Adversarial review of an implementation plan with 3 fresh-instance reviewers. PASS means the plan is fit to execute; FAIL means the plan has blocking defects. Max 3 iterations then human escalation."
source_type: "command"
source_file: "commands/review-plan.md"
---

# review-plan

Migrated from `commands/review-plan.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- In Codex, this skill is the replacement for the Claude slash command `/tl-telar:review-plan`; invoke it as `$review-plan` or through `@tl-telar`.
- Do not require Claude slash-command dispatch or Claude-only environment setup before following the workflow.
- When the original command says to load `skills/orchestration/<name>`, load the generated Codex skill at `../orchestration-<name>/SKILL.md` first. The original source copy also exists under `../../source/skills/orchestration/<name>/SKILL.md` for exact Telar-source references.


# /tl-telar:review-plan

Runs the Plan Review Gate (orchestrated mode) on an implementation plan.

## Behavior

1. Set the orchestrated-mode trigger: this command places the workflow under §1.1 of the orchestration master design. Sub-skills loaded from here may invoke their Orchestrated Mode sections.
2. Resolve the plan file:
   - `--plan-file <path>` if given.
   - Otherwise `--latest` (the default).
   - If neither produces a real file, abort with a helpful error.
3. Load `skills/orchestration/plan-review-gate` and follow its step-by-step procedure.
4. Print the aggregated verdict and (on FAIL) the blockers list with revision guidance.

## Usage examples

```
/tl-telar:review-plan
/tl-telar:review-plan --latest
/tl-telar:review-plan --plan-file docs/plans/login-flow.md
/tl-telar:review-plan --iteration 2
```

## What this command does NOT do

- Does NOT auto-revise the plan. It cites failures; the human or orchestrator addresses them.
- Does NOT loop iterations on its own. Each invocation runs one pass.
- Does NOT change any file other than emitting state to the conversation. Standalone use is read-only with respect to the repo.

## Integration with the orchestrator

When the `orchestrator` agent (sub-spec 2) is operational, it invokes the same skill internally with its own iteration tracking via `.tl-telar/context/execution-state.md`. This command remains useful for ad-hoc reviews and as a debugging tool when the orchestrator is not in use.
