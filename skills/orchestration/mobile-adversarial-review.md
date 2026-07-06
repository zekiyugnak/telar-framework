---
id: mobile-adversarial-review
category: skill
impact: MEDIUM
impactDescription: Generic spawn template that adversarial-code-review uses to fire mobile specialist agents (accessibility, performance, store compliance) in Adversarial mode on demand.
tags: [orchestration, review-gate, adversarial, mobile-specialist]
capabilities:
  - Provide a uniform spawn prompt template for any mobile specialist agent in Adversarial mode
  - Inject the appropriate per-domain rubric path based on role
  - Return a JSON verdict matching the sub-spec 1 schema
useWhen:
  - Called internally by skills/orchestration/adversarial-code-review when a conditional specialist reviewer must fire
  - Not invoked directly by users
---

# Mobile Adversarial Review (Specialist Spawn Template)

## Trigger condition (binding)

This skill is loaded only via:

1. `skills/orchestration/adversarial-code-review` when it determines a conditional specialist reviewer (a11y / perf / store-compliance) must fire.
2. Direct user request to adversarially review a single domain (rare; advanced use).

This skill is NEVER auto-triggered from legacy mobile commands. The mobile specialist agents (`mobile-accessibility-expert`, `mobile-performance-optimizer`, `mobile-security-specialist`) continue to operate in their default collaborative mode when invoked via `/tl-telar:audit-*` commands.

## What this skill does

Takes a `role` ∈ {accessibility, performance, store-compliance} and a WU context (spec, DoD, fileScope, diff) and produces a `Task()` spawn prompt that instructs a fresh subagent to apply the corresponding per-domain rubric in Adversarial mode.

> This template is consumed by `adversarial-code-review`, which does the actual `Task()` spawn — so it inherits that skill's **top-level (main-session) caller** requirement (a subagent has no `Task` tool; see `agents/orchestrator.md` → "Execution context").

## Spawn prompt template

```text
Description: "Adversarial review (mobile-{{role}})"
Subagent type: general-purpose
Prompt:
  You are the MOBILE {{ROLE_UPPER}} ADVERSARIAL REVIEWER.

  Mode: Adversarial. Your job is to FIND FAILURES, not to approve. You have
  NO context from previous reviews.

  Read the rubric at: {{rubricPath}}

  Then read the diff and the WU spec. Apply criteria. Return a single JSON
  object matching skills/orchestration/plan-review-gate/references/verdict-schema.md
  with `reviewer: "mobile-{{role}}"`. No prose outside the JSON.

  ---
  WORK UNIT SPEC:
  {{wuSpec}}

  DoD ITEMS:
  {{dodList}}

  FILE SCOPE:
  {{fileScope}}

  DIFF UNDER REVIEW:
  {{diff}}

  ITERATION: {{iteration}}
  ---
```

## Role-to-rubric mapping

| `role` | `rubricPath` | `reviewer` field in verdict |
|---|---|---|
| `accessibility` | `resources/rubrics/orchestration/mobile-accessibility-adversarial-rubric.md` | `mobile-accessibility` |
| `performance` | `resources/rubrics/orchestration/mobile-performance-adversarial-rubric.md` | `mobile-performance` |
| `store-compliance` | `resources/rubrics/orchestration/store-compliance-adversarial-rubric.md` | `mobile-store-compliance` |

The `store-compliance` role activates when WU file scope touches release config (signing, `Info.plist`, `AndroidManifest.xml`, `app.json`, `eas.json`, store metadata files) OR when `/tl-telar:release-app` is the operating context.

## Anti-patterns

1. **Calling this skill outside the orchestration namespace flow.** Mobile specialists in their default `/tl-telar:audit-*` invocation should NOT route through this skill — they use their own collaborative-mode prompts.
2. **Substituting a different rubric for the requested role.** The role→rubric mapping is fixed.
3. **Inlining prior reviewer findings into the spawn prompt.** Fresh-instance discipline.

## Tests / conformance

Run `node scripts/validate-skills.js` (orchestration-namespace checks).
