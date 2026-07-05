---
id: verification-before-completion
category: skill
impact: HIGH
impactDescription: Prevents false completion claims by requiring fresh evidence before declaring any task done
tags: [verification, evidence, completion, quality, testing, simulator, done-criteria]
capabilities:
  - Hard gate on completion claims without evidence
  - Fresh evidence requirement (no stale results)
  - Command output verification
  - Simulator behavior confirmation
  - Integration with review-gates and iterative-build-loop
useWhen:
  - About to claim a task, fix, or feature is done
  - Before entering review gates
  - After implementing a fix for a bug
  - Before committing code that is supposed to pass tests
  - Ending a build loop session
---

# Verification Before Completion

Hard gate: no claiming "done" without fresh evidence.

## Problem

It is easy to assume code works after writing it. Phrases like "should work", "probably passes", "I believe this will fix it" are not evidence. Stale test results from before a change do not verify the change. Skipping verification leads to broken merges, failed releases, and eroded trust in the development process.

## Solution

### The Rule

Do not use any of these phrases without fresh verification evidence:
- "done"
- "fixed"
- "works"
- "tests pass"
- "build succeeds"
- "ready for review"

### What Counts as Evidence

- **Command output** showing pass: `npm test` output with all tests green, `flutter test` with 0 failures
- **Build output** showing success: `npx expo export` or `flutter build` completing without errors
- **Simulator behavior** confirmed: screenshot or description of observed behavior matching expected behavior
- **Exit code** checked: command exited with code 0

### What Does NOT Count as Evidence

- "Should work" — not verified
- "Probably fixed" — not verified
- "I believe this will pass" — not verified
- "Tests were passing before my change" — stale evidence
- "It worked last time I ran it" — stale evidence
- "The logic looks correct" — code review is not runtime verification

### Verification Protocol

1. **Run the actual command** — `npm test`, `flutter test`, build command, etc.
2. **Read the output** — confirm pass/fail status from the actual output
3. **Check exit code** — ensure the command succeeded
4. **For UI changes** — verify on simulator using `scripts/sim-control.sh`
5. **For fixes** — confirm the specific error/failure no longer occurs

### Integration Points

This skill slots into the workflow at these points:
- After `iterative-build-loop` step completion — before writing the baton
- Before `review-gates` Stage 1 — spec compliance evidence must be fresh
- Before `review-gates` Stage 2 — code quality claims must be verified
- Before `mobile-commit-convention` — commit message claims ("fix", "feat") must be verified
- After `systematic-debugging` Phase 4 — fix verification

## Verification

1. Every "done" claim in a session is backed by a command output or screenshot
2. No stale evidence accepted (must be from after the latest code change)
3. Build and test commands are actually run, not assumed to pass

## References

- Used by: `skills/iterative-build-loop.md`, `skills/review-gates.md`
- Pairs with: `skills/systematic-debugging.md` (verifying fixes)
- Commands: `commands/add-feature.md`, `commands/review-code.md`, `commands/release-app.md`
