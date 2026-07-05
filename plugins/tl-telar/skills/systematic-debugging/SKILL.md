---
name: "systematic-debugging"
description: "Root-cause-first debugging methodology for mobile development. No fixes without investigation."
source_type: "skill"
source_file: "skills/systematic-debugging.md"
---

# systematic-debugging

Migrated from `skills/systematic-debugging.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Systematic Debugging

Root-cause-first debugging methodology for mobile development. No fixes without investigation.

## Problem

When something breaks, the instinct is to guess at a fix and try it immediately. This leads to fix-churn: a cycle of quick patches that mask symptoms without addressing the root cause. Each failed fix wastes time, introduces complexity, and can create new bugs. In mobile development, this is especially costly because build-deploy-verify cycles are slow.

## Solution

### Phase 1: Root Cause Investigation

Before changing any code, gather evidence:

1. **Read the error completely** — full stack trace, not just the first line
2. **Reproduce consistently** — if you can't reproduce it, you can't verify a fix
3. **Check recent changes** — `git diff` and `git log` since the last known-good state
4. **Gather platform-specific evidence**:
   - React Native: Metro bundler output, `npx react-native log-ios` / `log-android`
   - Flutter: `flutter run` console output, `flutter analyze`
   - iOS: Xcode build logs, device console (`xcrun simctl spawn booted log stream`)
   - Android: `adb logcat` filtered to app process
5. **Trace data flow backward** — from the error point back to the data source
6. **Check environment** — run `scripts/project-detect.sh` to confirm framework, deps, versions

### Phase 2: Pattern Analysis

1. **Find working examples** — search the codebase for similar functionality that works
2. **Compare against references** — check platform docs, library docs, existing patterns
3. **Identify differences** — what's different between the working case and the broken case?
4. **Understand dependencies** — is this a version mismatch, missing peer dep, or config issue?

### Phase 3: Hypothesis & Testing

1. **Form a single hypothesis** — "The error occurs because X"
2. **Test minimally** — change one variable at a time
3. **Verify the hypothesis** — does the change fix the symptom AND explain the root cause?
4. **If the fix doesn't work** — revert it completely, form a new hypothesis
5. **After 3 failed hypotheses** — STOP. Re-examine assumptions. Consider:
   - Is this an architecture issue, not a bug?
   - Are you debugging the wrong layer?
   - Do you need more information before continuing?

### Phase 4: Implementation

1. **Write a failing test case** — that reproduces the root cause (when possible)
2. **Implement a single fix** — addressing the root cause, not the symptom
3. **Verify the fix** — run the test, check on simulator, confirm the error is gone
4. **Check for regressions** — run the full test suite

## Iron Law

**NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.**

If you cannot explain *why* the bug exists, you are not ready to fix it.

## Red Flags

Stop and reconsider if you catch yourself thinking:

- "Let me just try this quick fix..."
- "This probably just needs a restart..."
- "I'll add a try/catch and move on..."
- "It works on my machine, probably a simulator issue..."
- "Let me just suppress this warning..."

Each of these is a signal that you're skipping investigation.

## Mobile-Specific Additions

- **Simulator state**: boot a clean simulator (`scripts/sim-control.sh boot`) to rule out stale state
- **Hot reload artifacts**: do a full rebuild (`npx expo start --clear` / `flutter clean && flutter run`) before concluding it's a code bug
- **Platform divergence**: if it works on iOS but not Android (or vice versa), the root cause is almost always platform-specific API behavior, not your logic

## Verification

1. Root cause is identified and documented before any code change
2. Fix addresses the root cause, not a symptom
3. A test exists that would catch this regression (when feasible)
4. Full test suite passes after the fix

## References

- Workflow integration: slots into `plan-and-track` for bugfix plans
- Verification: pairs with `verification-before-completion` for confirming fixes
- Build loop: referenced by `iterative-build-loop` when build steps fail
