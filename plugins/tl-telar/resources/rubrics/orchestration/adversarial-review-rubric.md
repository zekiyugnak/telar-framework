# Adversarial Code Review Rubric (Generic)

## Purpose

The base rubric consulted by Phase 3 of `skills/orchestration/orchestrated-execution/` (the 4-phase loop) when reviewing a Work Unit's diff. Spawned reviewers operate in **Adversarial Mode**: they FIND FAILURES, never propose improvements. Used for the always-on "Adversarial Code Reviewer" role; per-domain rubrics extend this for mobile-security, a11y, performance.

## Reviewer mode

**Adversarial.** Binary PASS/FAIL with cited evidence. No "minor changes" middle state. A reviewer that returns FAIL must cite a rule ID from the criteria below.

Reviewers are **fresh `Task()` instances** with no prior context (master design §1.1, sub-spec 1's plan-review-gate established the discipline). They see only the WU spec, DoD items, file scope, and git diff. They never see other reviewers' findings or prior iteration findings.

## Evaluation criteria

### G. Generic correctness (every reviewer applies these)

- G1. Does the diff implement the WU's stated DoD items? Each DoD checkbox MUST map to a concrete code change. Missing → FAIL.
- G2. Does the diff stay within the WU's declared `fileScope`? Touching a file outside scope → FAIL (master design §2.5.1 file-scope enforcement).
- G3. Are there unhandled error paths in the new code (try/catch absent on async I/O, network calls, file I/O, JSON.parse)? → FAIL.
- G4. Are there obvious correctness bugs (off-by-one, wrong operator, swapped args, dead branch always taken)? → FAIL.
- G5. Are new public-API names misleading or inconsistent with surrounding code? → FAIL.
- G6. Did the implementer add comments that describe WHAT instead of WHY when the WHAT is non-obvious from the code? Pure WHAT comments on obvious code are noise but not FAIL. WHAT comments hiding a non-obvious WHY → FAIL.
- G7. Did the implementer leave debug artifacts (console.log, print(), TODO without ticket reference, commented-out code) in the diff? → FAIL.
- G8. Did the implementer add tests that don't actually verify behavior (asserting a mocked return value, snapshot tests without rendered output)? → FAIL.

## Verdict format

Reviewers return a single JSON object matching the sub-spec 1 verdict schema (`skills/orchestration/plan-review-gate/references/verdict-schema.md`) with `reviewer: "adversarial-code"` and rule IDs from G1-G8 (or per-domain rubric IDs for specialist reviewers).
