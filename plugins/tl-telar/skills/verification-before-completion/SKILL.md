---
name: "verification-before-completion"
description: "Hard gate: no claiming \"done\" without fresh evidence."
source_type: "skill"
source_file: "skills/verification-before-completion.md"
---

# verification-before-completion

Migrated from `skills/verification-before-completion.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


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
