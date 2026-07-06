---
id: review-plan
name: Plan Review Gate (Adversarial)
description: Adversarial review of an implementation plan with 3 fresh-instance reviewers. PASS means the plan is fit to execute; FAIL means the plan has blocking defects. Max 3 iterations then human escalation.
category: command
usage: /tl-telar:review-plan [--latest | --plan-file <path>] [--iteration N]
example: /tl-telar:review-plan --plan-file docs/plans/login-flow.md
arguments:
  - name: --latest
    description: Review the most recently modified PLAN.md in the project (default if --plan-file omitted).
    optional: true
  - name: --plan-file
    description: Path to the plan file to review. Overrides --latest.
    optional: true
  - name: --iteration
    description: Iteration number (1-3). Defaults to 1. Use higher values when re-running after revision.
    optional: true
---

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
