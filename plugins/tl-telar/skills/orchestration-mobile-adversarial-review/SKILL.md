---
name: "orchestration-mobile-adversarial-review"
description: "Takes a `role` ∈ {accessibility, performance, store-compliance} and a WU context (spec, DoD, fileScope, diff) and produces a `Task()` spawn prompt that instructs a fresh subagent to apply the corresponding per-domain rub"
source_type: "orchestration"
source_file: "skills/orchestration/mobile-adversarial-review.md"
---

# orchestration-mobile-adversarial-review

Migrated from `skills/orchestration/mobile-adversarial-review.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- **Codex subagent gate — probe, then use or degrade (fail-closed; never fake).** Claude `Task()` calls map to Codex subagent spawns. Before EVERY multi-reviewer gate: (1) PROBE whether the current Codex surface exposes an agent-spawn tool. (2) If YES → spawn the resolver-selected reviewers as fresh, parallel Codex agent roles; preserve each role, its own rubric, and the freshness rule (no reviewer sees another's verdict or a prior iteration), then close each subagent handle before the next iteration so long runs do not exhaust the local subagent thread limit. (3) If NO → emit a literal `DEGRADED: full multi-reviewer gate unavailable on this Codex surface` line and STOP the gate. Recommend re-running on a Claude Code host or a Codex build that exposes subagent spawning. NEVER substitute a single inline self-review for the independent multi-reviewer gate, and never silently continue as if the gate passed.
- **Stack-aware roster (parity with the Claude path).** Derive the reviewer roster from `scripts/tl-telar-reviewer-roster.js` (packaged at this plugin root) against the WU `file_scope` — do NOT hardcode a mobile roster. It returns the domain-correct Security/BackendCorrectness/FrontendUX/Accessibility/Performance reviewers, each with its own rubric path, for mobile, web, backend-data, and rust changes alike.
- Treat Claude `Workflow` tool references as unavailable in Codex unless an explicit equivalent tool is present. Use the documented prose fallback path by default.
- Treat `TL_TELAR_ORCHESTRATED=1` as a workflow mode marker in Codex. Do not require a literal Claude slash command to set it.
- Do not pass scheduler `--isolate` merely because Codex is running. Use `--isolate` only after a concrete Codex worktree isolation and merge-back mechanism has been verified for the run; otherwise keep disjoint file-scope serialization.


# Mobile Adversarial Review (Specialist Spawn Template)

## Trigger condition (binding)

This skill is loaded only via:

1. `skills/orchestration/adversarial-code-review` when it determines a conditional specialist reviewer (a11y / perf / store-compliance) must fire.
2. Direct user request to adversarially review a single domain (rare; advanced use).

This skill is NEVER auto-triggered from legacy mobile commands. The mobile specialist agents (`mobile-accessibility-expert`, `mobile-performance-optimizer`, `mobile-security-specialist`) continue to operate in their default collaborative mode when invoked via `/tl-telar:audit-*` commands.

## What this skill does

Takes a `role` ∈ {accessibility, performance, store-compliance} and a WU context (spec, DoD, fileScope, diff) and produces a `Task()` spawn prompt that instructs a fresh subagent to apply the corresponding per-domain rubric in Adversarial mode.

> This template is consumed by `adversarial-code-review`, which does the actual `Task()` spawn — so it inherits that skill's **top-level (main-session) caller** requirement (a subagent has no `Task` tool; see `agents/mobile-orchestrator.md` → "Execution context").

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
