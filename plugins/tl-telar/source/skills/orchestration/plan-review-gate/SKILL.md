---
id: plan-review-gate
category: skill
impact: HIGH
impactDescription: Catches plan-level defects (feasibility, completeness, scope drift) before implementation begins, preventing the most expensive class of mid-execution rework
tags: [orchestration, review-gate, plan-review, adversarial, multi-agent]
capabilities:
  - Spawn 3 fresh-instance adversarial reviewers in parallel via Task tool
  - Aggregate per-reviewer JSON verdicts into a single overall PASS/FAIL
  - Enforce max-3-iteration limit with structured escalation to human
  - Cite blocker findings with file:line evidence and rubric rule IDs
  - Surface mobile-specific advisories (M1-M4) without blocking the gate
useWhen:
  - User invokes /tl-telar:review-plan (standalone)
  - Orchestrator agent reaches the post-planning gate in its workflow
  - User explicitly requests adversarial plan review
  - After a plan is written and the user wants a quality gate
---

# Plan Review Gate

## Trigger condition (binding)

This skill is invoked only via:

1. `/tl-telar:review-plan [--latest | --plan-file <path>]` (the slash command sets `TL_TELAR_ORCHESTRATED=1`).
2. The `mobile-orchestrator` agent's workflow after plan drafting (sub-spec 2; not yet present at sub-spec 1 ship).
3. Explicit user request such as "run the plan review gate on this plan".

This skill is NEVER auto-triggered from legacy mobile commands (`/tl-telar:create-app`, `/tl-telar:add-feature`, `/tl-telar:review-code`). See master design §1.1.

## What this skill does

Runs an adversarial review gate against an implementation plan (typically `PLAN.md`). The gate consists of:

1. **Spawn 3 fresh `Task()` subagents in parallel** — one each for Feasibility, Completeness, Scope-Alignment. See `references/reviewer-prompts.md` for the exact prompts.
2. **Aggregate verdicts** — collect 3 JSON verdicts matching `references/verdict-schema.md`. Compute `overall_verdict`: PASS iff all 3 reviewers returned PASS, FAIL otherwise.
3. **On FAIL**: present aggregated blockers to the user. User revises the plan (you may help the planner with revisions but DO NOT pre-judge the next pass). Then spawn **3 NEW** `Task()` instances. Maximum 3 iterations (initial + 2 retries).
4. **On 3rd-iteration FAIL**: produce an escalation report with the iteration history table and offer Override / Revise-with-help / Simplify / Cancel options.
5. **On PASS**: emit a passing-verdict summary and (if invoked by the orchestrator) hand control back. If invoked standalone, print the summary to the user.

## Inputs

| Input | Source |
|---|---|
| Plan text | `--plan-file <path>`, or `--latest` resolves to the most recently modified `PLAN.md` under the project root, or the orchestrator passes the path. |
| Original user request | The user's brief that produced the plan. Required for the Scope-Alignment reviewer. If unknown, prompt the user before spawning reviewers. |
| Iteration counter | Starts at 1. Incremented on each retry. |

## Outputs

- A printed aggregated verdict summary (markdown).
- If invoked by orchestrator: returns `{ overall_verdict, iteration, blocking_reviewers, all_blockers, all_advisories, max_iterations_reached }`.
- If invoked standalone: prints the same JSON aggregated verdict followed by a human-readable summary.

## Execution substrate (prefer-workflow-else-prompt)

This gate has **two interchangeable execution paths that MUST emit the identical aggregated verdict object** (Step 3). The prose path below is the canonical fallback and the single source of truth for reviewer prompts and the schema (`references/reviewer-prompts.md`, `references/verdict-schema.md`). An optional deterministic **Workflow** path accelerates the fan-out without changing the contract.

Before Step 1, resolve the path with the **tested gating resolver** — do NOT hand-reason the flag/capability logic (it is fail-closed and matrix-tested in `tests/workflow/cc-features.test.sh`):

1. **Determine the one thing only you can see:** whether **you (the top-level session) actually have the `Workflow` tool** available. Call this `wf` = `true`/`false`.
2. **Resolve the decision.** Run:
   ```bash
   bash "$PLUGIN_ROOT/scripts/tl-telar-cc-features.sh" decision dynamic_workflows \
     --workflow-available <wf> --worktree-supported false
   ```
   It reads `cc_features.dynamic_workflows.{enabled,on_unavailable}` from the consumer's `.tl-telar/external-tools.yaml` (default `enabled: true` when the key/file is absent) and returns one word:
   - `active` → **Workflow path** (step 3).
   - `fallback` → **prose path** (Step 1 onward) — either disabled by config, or the tool is unavailable under `on_unavailable: warn_and_proceed`. Print one line (`Plan gate: running prose path`) and proceed.
   - `blocked` (exit 3) → `on_unavailable: block` with the tool unavailable. STOP and report the missing capability + how to downgrade (`set cc_features.dynamic_workflows.enabled: false`).
   Fail-closed is enforced by the resolver: `active` requires `wf=true` exactly; never assume the tool exists because the flag is set.
3. **Workflow path.** Invoke the workflow script `workflow/plan-review.mjs` (co-located with this skill) via the `Workflow` tool with `args: { planText, userRequest, iteration }`. It runs the 3 reviewers via `parallel()` with schema-validated verdicts and **returns the exact aggregated object of Step 3** — consume it as if the prose path produced it, then continue at Step 4a/4b/4c. The workflow runs ONE pass; iteration management, escalation, and the human gate stay here in the skill/orchestrator layer (see "Iteration management"). Do NOT let the workflow prompt the user.

Everything from Step 1 to Step 3 below is the **prose fallback**. Steps 4a/4b/4c (presentation, iteration, escalation) are path-independent and always run here.

## Step-by-step procedure

### Step 0: Resolve inputs

- Parse `--plan-file` argument. If absent and `--latest` set, run:
  ```bash
  find . -name PLAN.md -not -path '*/node_modules/*' -not -path '*/.tl-telar/*' \
    -printf '%T@ %p\n' 2>/dev/null \
    | sort -nr | head -1 | cut -d' ' -f2
  ```
  If no PLAN.md found, abort with "No PLAN.md found. Use --plan-file to specify."
- Read plan text. If file is empty or has fewer than 50 non-whitespace characters, abort with "Plan appears empty or stub."
- Resolve user request: check current conversation context for "Original request:" markers; if absent, ask the user.
- Set `iteration = 1`.

### Step 1: Spawn 3 fresh Task() subagents IN PARALLEL

> Requires a **top-level caller** — `/tl-telar:review-plan` or the main-session orchestrator (see `agents/mobile-orchestrator.md` → "Execution context"). A Claude Code subagent has no `Task` tool and cannot run this gate; never let a spawned subagent invoke this skill, and never substitute a single inline review pass for the 3 fresh reviewers.

Use the Task tool three times in a single response (parallel dispatch). For each:

- **Subagent type**: `general-purpose`
- **Description**: `Plan review — <role>` where role ∈ {Feasibility, Completeness, Scope-Alignment}.
- **Prompt**: Template from `references/reviewer-prompts.md` for the corresponding role, with `{{userRequest}}`, `{{planText}}`, `{{iteration}}` substituted.

**Critical invariant**: each Task() is a fresh instance. NEVER reuse an `agentId` from a previous iteration via `SendMessage`. NEVER include prior reviewers' findings in a new spawn. The skill prompt enforces this verbatim.

### Step 2: Wait for all 3 verdicts

Collect the JSON responses from each Task(). Parse each as a verdict object per `references/verdict-schema.md`.

If any reviewer's response is malformed (not parseable JSON, or missing required fields):
- Re-prompt that single reviewer (still a fresh Task()) once with "Your previous response was malformed. Respond with valid JSON only matching the schema in `references/verdict-schema.md`." If second attempt also fails, mark that reviewer FAIL with synthetic blocker `{ "rule": "X1-malformed-response", "summary": "Reviewer returned unparseable response twice.", "evidence": [] }`.

### Step 3: Aggregate

Build the aggregated verdict object:

```json
{
  "overall_verdict": "<PASS if all 3 reviewers PASS, else FAIL>",
  "iteration": <current iteration>,
  "blocking_reviewers": [<reviewer names with FAIL verdict>],
  "all_blockers": [<concatenate every blocker from every FAIL reviewer>],
  "all_advisories": [<concatenate every advisory from all 3 reviewers, dedup by (rule, file, line)>],
  "max_iterations_reached": <iteration >= 3>
}
```

### Step 4a: If PASS

Print to user:

```markdown
## Plan Review Gate — PASS (iteration N)

All 3 adversarial reviewers passed.

### Advisories (non-blocking, please consider)
- [<role>] M1: <summary> — <file>:<line>
...
```

Return to caller (orchestrator) or end (standalone).

### Step 4b: If FAIL and iteration < 3

Print to user:

```markdown
## Plan Review Gate — FAIL (iteration N of 3)

Blocking reviewers: <list>

### Blockers
1. [<reviewer>] <rule>: <summary>
   - Evidence: <file>:<line> — `<snippet>`
   - Explanation: <explanation>
...

### Advisories (non-blocking)
...

### Next step
Revise PLAN.md addressing each blocker. The reviewer's "Why" gives the rule;
you may either fix the underlying issue or include a rebuttal in the plan
text (with cited reasoning). After revision, re-run /tl-telar:review-plan
or let the orchestrator spawn 3 NEW reviewers.
```

If invoked by orchestrator: return the aggregated verdict so the orchestrator can decide.
If invoked standalone: stop here and await user revision + next invocation. Do NOT auto-loop.

### Step 4c: If FAIL and iteration ≥ 3 (escalation)

Print to user:

```markdown
## Plan Review Gate — ESCALATION (3 iterations exhausted)

The plan failed 3 successive adversarial review passes.

### Iteration history

| Iter | Blocking reviewers | Blocker count |
|------|---------------------|---------------|
| 1    | <list>              | N             |
| 2    | <list>              | N             |
| 3    | <list>              | N             |

### Latest blockers (iteration 3)
<full blocker list from iteration 3>

### Decision required
1. **Override** — proceed despite findings. You take responsibility for the cited risks.
2. **Revise-with-help** — let me (the assistant) help you address blockers one by one before re-running the gate.
3. **Simplify** — reduce the plan's scope to a subset that the gate can pass.
4. **Cancel** — stop the workflow.

Please choose 1/2/3/4.
```

Wait for user choice. Return decision to caller.

## Iteration management

- The skill does NOT auto-loop. It returns control after each iteration result so the user (or orchestrator) decides.
- The orchestrator (sub-spec 2) re-invokes the skill with `iteration + 1` after revising the plan. It is responsible for tracking iteration count in `.tl-telar/context/execution-state.md`.
- Standalone invocation (`/tl-telar:review-plan`) does not track iteration across invocations. Each `/tl-telar:review-plan` call defaults to `iteration = 1`. To continue an in-flight iteration, the user can pass `--iteration N`.

## Anti-patterns (do NOT do these)

1. **Reusing a reviewer Task() on retry.** Spawning the same reviewer twice via SendMessage is forbidden. Anchoring bias defeats the gate's purpose.
2. **Inlining prior findings into the new spawn prompt.** Each spawn sees only the plan + original request. Never paste prior blockers into a fresh reviewer.
3. **Auto-fixing FAILs in this skill.** This skill is a referee. It does not edit the plan. The orchestrator or user does that.
4. **Soft-pass on partial PASS.** Even one FAIL reviewer means overall FAIL. There is no "2 out of 3 passed, good enough".
5. **Hard-failing on missing `.tl-telar-thresholds.json`.** That file is delivered in sub-spec 3 and may not exist when this skill is first used. Treat missing thresholds as advisory M4, never blocker.

## Tests / conformance

Run `node scripts/validate-skills.js` to validate all skills (the validator does not accept a path argument; it scans the entire `skills/` directory and will pick up this skill among the rest). Run `node scripts/validate-rubrics.js` to validate the rubric file. Run `bash scripts/check-sidecar-routing.sh` to assert legacy `/tl-telar:review-code` does not load this skill or any future orchestration sidecar.
