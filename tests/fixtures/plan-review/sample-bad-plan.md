# Sample Bad Plan (Intentionally Broken — Test Fixture)

> This fixture deliberately violates rubric rules from
> resources/rubrics/orchestration/plan-review-rubric-adversarial.md.
> The Plan Review Gate MUST catch each violation. Used to verify the
> rubric is actually enforced by reviewers, not just documented.

**Goal:** Add a new validation script to this plugin.

**Original user request:** "Add a script that validates CHANGELOG.md
formatting."

## Tasks

### Task 1: Create the validator
- Create `scripts/validate-changelog.js`.
- Also add a one-shot helper `scripts/internal/changelog-line-parser.js`
  used only by this validator [violates C3 — premature abstraction
  for single consumer].
- Use Windows path: `scripts\internal\helper.js` [violates A5 — wrong
  path separator on a unix-conventioned repo].

### Task 2: Install dependency
- Install `npm-package-that-does-not-exist-xyz123` [violates A3 — fictional
  dependency cannot be installed].

### Task 3: Wire validator into CI
- Update `scripts/ci/validate-all.sh` (this file does not exist in the
  repo) [violates A1 — referenced file doesn't exist and the plan
  doesn't create it].
- Depends on Task 7's output [violates A2 — Task 7 is not defined; circular
  or impossible dependency].

### Task 4: Tests
- "Write tests for the above." [violates A6 — no actual test code].

### Task 5: Refactor unrelated validator
- Rewrite `scripts/validate-skills.js` for cleanliness while we're here
  [violates C2 — refactor outside stated change area without
  user-requested justification].

## Expected reviewer findings

| Reviewer | Verdict | Expected rule IDs |
|---|---|---|
| Feasibility | FAIL | A1, A2, A3, A5, A6 |
| Completeness | FAIL | B2 (DoD missing), B3 (no code blocks), B5 (no error/empty UX — N/A for a script, but rubric criterion B2 still applies) |
| Scope-Alignment | FAIL | C2, C3 |
