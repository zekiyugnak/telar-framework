# Epic: {{epic title}}
<!-- orchestrate-input: epic -->
<!-- schema: epic-input/v1 -->

> **How to use:** author ONE feature per epic, then run
> `/tl-telar:orchestrate --epic <path-to-this-file>`.
> Each `## Task` below maps **1:1 to a Work Unit (WU)**. The orchestrator does
> NOT draft a plan when `--epic` is given — it reviews this file directly
> (Plan Review Gate), then decomposes the Tasks into WUs.
> See the authoring guide in the plugin README ("Authoring inputs for orchestrate").

## Intent

{{2-3 sentences: the outcome this epic delivers and why it matters. REQUIRED —
the Plan Review Gate's Scope-Alignment reviewer reads this to judge whether the
tasks match the stated goal. A vague intent makes the gate fail on scope.}}

## Requirements & Decisions

- **Requirements:** {{F-x / UI-x references from REQUIREMENTS.md, or "n/a"}}
- **Key decisions / constraints:** {{links to RESEARCH.md / ADRs, or inline non-negotiables (libraries, patterns, perf budgets)}}
- **Depends on (other epics):** {{e.g., "E0 auth must ship first", or "none"}}

## Tasks

<!--
Each Task becomes exactly ONE Work Unit. Rules the gate + 4-phase loop enforce:
- Single responsibility — if the spec needs "and", split the task.
- Verifiable DoD — "works correctly" is NOT acceptable; each item must be
  checkable by a command or a human.
- file_scope is the ONLY set of paths the implementer may modify for that task.
  An out-of-scope edit FAILS validation.
- Parallel tasks (no deps between them) MUST have DISJOINT file_scope.
Fields mirror: skills/orchestration/orchestrated-execution/references/work-unit-schema.md
-->

### T1: {{task title}}

- **spec:** {{1-3 sentences, no conjunctions}}
- **dod:**
  - [ ] {{verifiable criterion}}
  - [ ] {{verifiable criterion}}
- **file_scope:**
  - {{path/to/file}}
  - {{path/to/test}}
- **deps:** []
- **checkpoint:** false   <!-- true ONLY when a human must validate: visual design sign-off, secrets/env, store metadata, security-sensitive defaults -->

### T2: {{task title}}

- **spec:** {{1-3 sentences}}
- **dod:**
  - [ ] {{verifiable criterion}}
- **file_scope:**
  - {{path/to/file}}
- **deps:** [T1]
- **checkpoint:** false

## Risks & Mitigations

<!-- Optional but recommended. The Feasibility reviewer reads these. -->

| Risk | Likelihood (L/M/H) | Impact (L/M/H) | Mitigation |
|------|--------------------|----------------|------------|
| {{risk}} | {{}} | {{}} | {{}} |

## Epic Acceptance Criteria

<!-- Epic-level "done". The orchestrator's final review checks these after every
     Task reaches COMMIT-READY. Distinct from per-Task `dod`. -->

- [ ] {{overall criterion}}
- [ ] {{overall criterion}}

## Amendment Log

| Date | Change | Triggered by |
|------|--------|--------------|
| {{ISO date}} | {{what changed}} | {{requirement update / review feedback}} |
