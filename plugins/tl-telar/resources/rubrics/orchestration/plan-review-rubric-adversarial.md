# Plan Review Rubric — Adversarial

## Purpose

Used by the 3 fresh-instance reviewers in `skills/orchestration/plan-review-gate/` to evaluate an implementation plan (PLAN.md) for blocking defects before execution begins. The reviewer's job is to **find failures**, not to approve or suggest improvements. A plan that survives this gate has been adversarially probed by three independent inspectors.

## Reviewer mode

**Adversarial.** This rubric is binary PASS/FAIL. There is no "needs minor changes" middle state. Either the plan is fit to execute or it is not.

The rubric is loaded by three distinct reviewer roles in parallel: Feasibility, Completeness, and Scope-Alignment. Each reviewer applies the relevant section of this rubric to their role.

Reviewers are **fresh `Task()` instances** with no prior context. They see only the plan text, the original user request, and this rubric. They never see other reviewers' findings.

## Evaluation criteria

### A. Feasibility (assigned reviewer: Feasibility)

A plan FAILS feasibility review if any of:

- A1. A referenced file path or directory doesn't exist in the repo (and the plan doesn't explicitly create it earlier in the dependency order).
- A2. The task dependency order is impossible — a task depends on output produced only by a later task.
- A3. A claimed external dependency (SDK, API, library) is not installed or installable on the supported platforms (RN/Expo/Flutter as relevant).
- A4. A platform-specific instruction is given for a platform not in the project (e.g., an Android-specific step in an iOS-only project).
- A5. A command in the plan won't execute on the user's likely shell/OS (paths use Windows backslashes when project is mac/linux, etc.).
- A6. A "test" step has no actual test code — only prose like "write tests for the above".

Feasibility reviewer ignores correctness of *what* the plan does. Only *can it physically be done*.

### B. Completeness (assigned reviewer: Completeness)

A plan FAILS completeness review if any of:

- B1. A requirement from REQUIREMENTS.md (F-x or UI-x identifier) is not covered by any task.
- B2. A task's Definition of Done (DoD) is missing or unverifiable (e.g., "DoD: works correctly" — what does correctly mean?).
- B3. A task creates a new file but doesn't specify what's in it (no code block / no API surface description).
- B4. An edge case mentioned in the original user request is not addressed by any task.
- B5. Error states or empty/loading/failure UX are not covered for any new screen.
- B6. A rollback path is missing for migrations or destructive changes.

Completeness reviewer doesn't judge feasibility. Only *did the plan forget anything the user asked for*.

### C. Scope & Alignment (assigned reviewer: Scope-Alignment)

A plan FAILS scope-alignment review if any of:

- C1. The plan introduces a feature, screen, or capability not in the user's original request.
- C2. The plan rewrites or refactors code outside the stated change area without justification tied to the user request.
- C3. The plan introduces a new abstraction (helper, hook, util module) used by exactly one consumer (premature abstraction).
- C4. The plan adds dependencies (new packages, new services) the user didn't ask for, beyond what the requested feature strictly requires.
- C5. The plan changes platform conventions (style, navigation, state mgmt) without an explicit user-approved rationale.

Scope-Alignment reviewer doesn't judge feasibility or completeness. Only *did the plan stay inside the lines the user drew*.

### Mobile-specific advisories (cross-cutting)

These do NOT auto-FAIL the gate but reviewers MUST flag them as cited findings if they apply:

- M1. Plan touches UI but omits accessibility (touch target, contrast, screen-reader label) consideration for the changed screens.
- M2. Plan touches state but doesn't say which state-management approach (Redux/Zustand/Provider/Riverpod/MobX/...) the new state lives in.
- M3. Plan touches release config (`.env`, `app.json`, `Info.plist`, `AndroidManifest.xml`, signing) without explaining the rollout strategy.
- M4. Plan references `.tl-telar-thresholds.json` thresholds but the file doesn't exist yet — this is non-blocking in MVP (see master design §2.5.1 and sub-spec 1 acceptance criterion #1) but the reviewer notes it for the user.

A finding under M1–M4 must appear in the verdict's `advisories` array, NOT `blockers`.

## Verdict format

Each reviewer returns a single JSON object matching `references/verdict-schema.md`. No prose outside the JSON. Reviewers do not propose fixes — they cite findings.
