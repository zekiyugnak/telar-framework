---
id: design-review-gate
category: skill
impact: HIGH
impactDescription: Pre-implementation collaborative review by 6 specialist reviewers. Catches scope ambiguity, architecture drift, UX inconsistency, threat-model gaps, strategic misfit, and platform-convention violations BEFORE plan drafting. Cheaper than catching them at code review.
tags: [orchestration, review-gate, collaborative, multi-agent, design-stage]
capabilities:
  - Spawn 6 fresh-instance collaborative reviewers in parallel via Task tool
  - Aggregate per-reviewer ReviewResult JSON into overall APPROVED/NEEDS_REVISION
  - Enforce max-3-iteration limit with structured escalation
  - Produce use_case_analysis (PM) and threat_model (Security-Design) as first-class outputs
  - Hand off APPROVED designs to the planning step
useWhen:
  - mobile-orchestrator reaches the post-RESEARCH.md / post-design-doc-commit handoff
  - /tl-telar:review-design invoked explicitly
  - brainstorm-first skill (under §1.1 orchestrated trigger) completes
---

# Design Review Gate

## Trigger condition (binding)

This skill is loaded only via:

1. The `mobile-orchestrator` agent's workflow after a RESEARCH.md or design doc commit.
2. `/tl-telar:review-design [--latest | --design-file <path>]` (sets TL_TELAR_ORCHESTRATED=1).
3. `skills/brainstorm-first.md`'s Orchestrated Mode section (sub-spec 6 augmentation, §1.1-gated).
4. Explicit user request such as "run the design review gate".

This skill is NEVER auto-triggered from legacy mobile commands. `/tl-telar:create-app`, `/tl-telar:add-feature` continue to use brainstorm-first → plan-and-track flow WITHOUT the design gate.

## What this skill does

For a given design doc (typically `RESEARCH.md` or `docs/plans/*-design.md`):

1. **Spawn 6 fresh `Task()` reviewers in parallel** (one tool-call batch via `Promise.all`-shape): PM, Architect, Designer, Security-Design, CTO, Mobile-Platform.
2. **Aggregate** per-reviewer `ReviewResult` JSON.
3. **Compute overall verdict**: APPROVED iff all 6 returned APPROVED; NEEDS_REVISION otherwise.
4. **On APPROVED**: hand control back to orchestrator (or user, if standalone). Emit a structured summary.
5. **On NEEDS_REVISION** (iteration < 3): present consolidated blockers/suggestions/questions to user. User revises design. Re-run all 6 FRESH (`iteration + 1`). Max 3 iterations.
6. **On 3rd-iteration NEEDS_REVISION**: escalation report with Override / Defer / Cancel.

## Step-by-step procedure

### Step 0: Resolve inputs

- Parse `--design-file <path>` or `--latest` (most recent design doc in `docs/plans/*-design.md` or `RESEARCH.md` at repo root).
- Read design doc text. If empty or stub: abort.
- Resolve `userRequest` from conversation context or prompt user.
- Set `iteration = 1`.

### Step 1: Spawn 6 reviewers in parallel

> Requires a **top-level caller** — `/tl-telar:review-design` or the main-session orchestrator (see `agents/mobile-orchestrator.md` → "Execution context"). A Claude Code subagent has no `Task` tool; never let a spawned subagent invoke this skill.

Single Task() batch call. Each:
- subagent_type: `general-purpose`
- description: `Design review — <role>`
- prompt: template from `references/reviewer-prompts.md` with `{{userRequest}}`, `{{designDoc}}`, `{{iteration}}` substituted.

### Step 2: Collect verdicts

Parse 6 JSON responses. Malformed → re-prompt that single reviewer once (fresh Task()). Second failure → synthetic NEEDS_REVISION with rule `X1-malformed-response`.

### Step 3: Aggregate

```json
{
  "overall_verdict": "<APPROVED if all 6 APPROVED, else NEEDS_REVISION>",
  "iteration": <current>,
  "blocking_reviewers": [<roles with NEEDS_REVISION>],
  "all_blockers": [<concatenated>],
  "all_suggestions": [<concatenated>],
  "all_questions": [<concatenated>],
  "use_case_analysis": <from PM reviewer if present>,
  "threat_model": <from Security-Design reviewer if present>,
  "max_iterations_reached": <iteration >= 3>
}
```

### Step 4a: APPROVED

```markdown
## Design Review Gate — APPROVED (iteration N)

All 6 reviewers approved. Use case + threat model summarized below.

### Use case (from PM)
- WHO: {{...}}
- WANTS: {{...}}
- SO THAT: {{...}}
- WHEN: {{...}}

### Threat model (from Security-Design)
- High risk: {{...}}
- Medium risk: {{...}}
- Mitigations required: {{...}}

### Suggestions (non-blocking; for the planner to consider)
- [<role>] {{...}}
```

Hand back to orchestrator or end (standalone).

### Step 4b: NEEDS_REVISION, iteration < 3

```markdown
## Design Review Gate — NEEDS_REVISION (iteration N of 3)

Blocking reviewers: <list>

### Blockers (must address before next iteration)
1. [<role>] <rule>: <summary>
   - Evidence: <file>:<line>
   - Explanation: <...>

### Suggestions (consider, but not blocking)
...

### Open questions
...

### Next step
Revise the design doc addressing each blocker. Re-run /tl-telar:review-design.
```

Return aggregated verdict. Do NOT auto-loop.

### Step 4c: NEEDS_REVISION, iteration ≥ 3 → escalation

```markdown
## Design Review Gate — ESCALATION (3 iterations exhausted)

Iteration history:
| Iter | Blocking reviewers | Blocker count |
|------|---------------------|---------------|
| 1    | ...                 | N             |
| 2    | ...                 | N             |
| 3    | ...                 | N             |

### Decision required
1. **Override** — proceed despite findings.
2. **Defer** — set this design aside and revisit later.
3. **Cancel** — abandon the feature.

Choose 1/2/3.
```

## Anti-patterns

1. **Reusing reviewer Task() instances.** Same as all gates — fresh every time.
2. **Inlining prior reviewer findings into a new spawn.** Each spawn sees only doc + request.
3. **Auto-approving on partial APPROVED.** All 6 must approve.
4. **Treating Security-Design or PM as optional.** Both are MANDATORY reviewers — their structured output (threat_model, use_case_analysis) is consumed downstream.
5. **Skipping the gate for "simple" designs.** If a brainstorming session committed RESEARCH.md and you're in orchestrated mode, the gate fires. Bypass requires explicit user override.

## Tests / conformance

Run `node scripts/validate-skills.js` (orchestration-namespace checks). Run `node scripts/validate-rubrics.js` (rubric exists and is well-formed).
