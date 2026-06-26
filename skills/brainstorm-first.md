---
id: brainstorm-first
category: skill
impact: CRITICAL
impactDescription: Prevents architectural rework by enforcing research and analysis before implementation
tags: [brainstorm, research, discovery, architecture, planning, pre-implementation, requirements]
capabilities:
  - Enforce discovery phase before any code generation
  - Produce RESEARCH.md artifact with structured analysis
  - Read REQUIREMENTS.md as input to focus technical analysis
  - Platform and architecture option comparison
  - Risk assessment with mitigation strategies
  - Requirements-architecture impact analysis
  - Quality gate ensuring RESEARCH.md exists before implementation
useWhen:
  - After REQUIREMENTS.md is produced (or confirmed to exist)
  - Starting a new feature or app from scratch
  - Evaluating architecture options for a complex feature
  - Choosing between state management approaches
  - Deciding on backend or third-party service integration
  - Any implementation where jumping to code risks rework
---

# Brainstorm First

Enforces a structured technical discovery phase before implementation. Reads `REQUIREMENTS.md` (produced by `requirements-gather`) as input and produces `RESEARCH.md` — the technical architecture decisions document.

**Responsibility boundary:**
- `requirements-gather` → answers *what* to build (REQUIREMENTS.md)
- `brainstorm-first` → answers *how* to build it technically (RESEARCH.md)

## Prerequisites

Before invoking this skill, `REQUIREMENTS.md` must exist. If it does not:
1. Stop
2. Invoke `requirements-gather` skill first
3. Return here once REQUIREMENTS.md is complete

---

## Step 1: Read REQUIREMENTS.md

Load and parse REQUIREMENTS.md:
- Extract platform decision (if pre-decided)
- Extract backend decision (if pre-decided)
- Extract feature scope and phases
- Extract monetization and tier structure
- Extract user roles
- Note any Open Items that affect architecture

If REQUIREMENTS.md was produced in **Document-Driven Mode**, honour all pre-decided choices — do not re-open comparisons for areas already decided.

---

## Step 2: Requirements-Architecture Impact Analysis

For each functional requirement (F-x), assess its architectural implications:

```markdown
## Requirements-Architecture Impact

| Requirement | Architectural Implication | Affects |
|-------------|--------------------------|--------|
| F-1: Auth (email + social) | Auth provider choice, token storage, refresh logic | Backend, state, security |
| F-7: Real-time calendar sync | WebSocket or Supabase Realtime, conflict resolution | Backend, state, offline |
| F-12: Offline shopping list | Local-first storage, sync strategy | Architecture pattern |
| F-15: Push notifications | Push service, deep link routing | CI/CD, navigation |
```

This analysis drives the option comparisons below. Only deliberate on areas that REQUIREMENTS.md has not already decided.

---

## Step 3: RESEARCH.md Template

```markdown
# Research: [App/Feature Name]

## Source
**Requirements:** REQUIREMENTS.md v[X]
**Mode:** Standard | Document-Driven (pre-decided choices honoured)
**Date:** [date]

## Requirements Summary
[2–3 sentence summary of what REQUIREMENTS.md defines, for context]

## Requirements-Architecture Impact
[Table from Step 2]

## Platform Analysis
[Only if not pre-decided in REQUIREMENTS.md]

### React Native
- **Pros:** [for this specific feature scope]
- **Cons:**
- **Key libraries:**
- **Risk:**

### Flutter
- **Pros:**
- **Cons:**
- **Key packages:**
- **Risk:**

### Recommendation
[Which platform and why, tied to REQUIREMENTS.md feature scope]

> ℹ️ **Pre-decided:** If REQUIREMENTS.md already specifies the platform, note it here and skip comparison.

## Architecture Options
[Option A / Option B comparison — only for areas not decided in REQUIREMENTS.md]

## State Management
[Comparison or pre-decided note]

## Backend Options
[Comparison or pre-decided note]

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation | Source |
|------|-----------|--------|------------|--------|
| [Risk from REQUIREMENTS.md Open Items] | | | | Requirements |
| [Technical risk identified during analysis] | | | | Analysis |

## Decision Summary
- **Platform:** [Choice] *(from requirements / decided here)*
- **Architecture:** [Choice]
- **State management:** [Choice]
- **Backend:** [Choice]
- **Key risks:** [Top 2–3]
```

---

## Quality Gate

RESEARCH.md must exist and contain all required sections before implementation begins:

- **If REQUIREMENTS.md is missing**: stop — invoke `requirements-gather` first
- **If RESEARCH.md is missing**: produce it now
- **If RESEARCH.md is incomplete**: fill in missing sections
- **If both exist and are complete**: proceed to `plan-and-track`

---

## Lightweight Mode

For small features (< 1 day of work):

```markdown
# Research: [Feature Name]

## Requirements reference
[F-x from REQUIREMENTS.md this addresses]

## Approach
[Chosen approach with 1-sentence rationale tied to existing architecture]

## Risks
- [Top risk and mitigation]

## Decision: Proceed with [approach]
```

---

## Verification

1. REQUIREMENTS.md was read before producing RESEARCH.md
2. No decisions from REQUIREMENTS.md were re-opened unnecessarily
3. All F-x requirements with architectural implications are addressed
4. Decision Summary contains explicit choices for platform, architecture, state management, and backend
5. Risk Assessment includes at least 2 risks with mitigations

## References

- Input: `skills/requirements-gather.md` (produces REQUIREMENTS.md)
- Resources: `resources/decision-trees/`
- Next step: `skills/plan-and-track.md`

---

## Orchestrated Mode (additive)

> **Trigger condition (binding).** The behavior in this section applies if and only if at least one of:
> 1. The current command is `/tl-telar:orchestrate`, `/tl-telar:review-design`, or `/tl-telar:review-plan`.
> 2. The environment contains `TL_TELAR_ORCHESTRATED=1`.
> 3. The user explicitly invoked this skill with text like "use orchestrated mode" / "with design review gate".
>
> If NONE of these hold, this section is dormant. Continue with the legacy behavior above (flow straight to plan-and-track).

### Handoff to Design Review Gate

When in orchestrated mode, after the brainstorming session produces a committed `RESEARCH.md` (or `docs/plans/*-design.md`):

1. STOP. Do NOT proceed directly to plan-and-track.
2. RUN the Design Review Gate: load `skills/orchestration/design-review-gate` and pass the design doc path.
3. Wait for the gate verdict.
4. On APPROVED: proceed to plan-and-track with the design doc as input.
5. On NEEDS_REVISION (iterations < 3): user revises design doc, re-run the gate.
6. On 3rd-iteration NEEDS_REVISION: escalate to user (Override / Defer / Cancel).

### Why the gate fires here

Catching scope ambiguity, architecture drift, security gaps, and platform-convention violations at design time is ~10× cheaper than catching them at code review. The 6-reviewer parallel gate adds ~1-2 minutes wall time and 6 Task() spawns of cost in exchange for substantially higher quality plans downstream.

### Bypass

Users who want to skip the gate intentionally (e.g., quick prototyping) can:
- Run `/tl-telar:add-feature <feature>` instead of `/tl-telar:orchestrate` — legacy command doesn't fire the gate.
- Explicitly tell the orchestrator "skip design review for this iteration" — orchestrator records the bypass in execution-state.md with a justification.
