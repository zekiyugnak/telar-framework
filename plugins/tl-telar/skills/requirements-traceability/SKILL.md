---
name: "requirements-traceability"
description: "Builds and maintains a Requirements Traceability Matrix (RTM) that links every requirement in REQUIREMENTS.md to its implementation tasks, source files, and test cases."
source_type: "skill"
source_file: "skills/requirements-traceability.md"
---

# requirements-traceability

Migrated from `skills/requirements-traceability.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Requirements Traceability

Builds and maintains a Requirements Traceability Matrix (RTM) that links every requirement in REQUIREMENTS.md to its implementation tasks, source files, and test cases.

## Problem

Without explicit traceability, it is impossible to answer:
- "Is F-7 fully implemented?"
- "If I change this file, which requirements are affected?"
- "Which requirements have no tests?"
- "Are all Phase 1 requirements done?"

## Solution

### Step 1: Collect Inputs

Read:
1. `REQUIREMENTS.md` — extract all F-x and UI-x identifiers
2. `PLAN.md` — extract all tasks with their requirement references
3. Source files — scan for implementation files per feature
4. Test files — scan for test files per feature

### Step 2: Build RTM

Produce `TRACEABILITY.md`:

```markdown
# Requirements Traceability Matrix

**Last updated:** [date]
**Total requirements:** [N]
**Coverage:** [X]% (requirements with at least one task + test)

## Forward Traceability

| Requirement | Description | Tasks | Implementation Files | Test Files | Status |
|-------------|-------------|-------|---------------------|------------|--------|
| F-1 | Auth — email/password | T1, T2, T3 | `lib/features/auth/*` | `test/auth_test.dart` | ✅ Done |
| F-2 | Auth — Google OAuth | T4, T5 | `lib/features/auth/google_auth.dart` | `test/google_auth_test.dart` | ✅ Done |
| F-7 | Calendar view | T14–T22 | `lib/features/calendar/*` | `test/calendar_test.dart` | 🔄 In Progress |
| F-10 | Shopping list share | — | — | — | ⬜ Not Started |
| UI-3 | Settings screen | T30, T31 | `lib/screens/settings/*` | `test/settings_test.dart` | ✅ Done |

## Backward Traceability

| File | Requirements | Tasks |
|------|-------------|-------|
| `lib/features/auth/auth_repository.dart` | F-1, F-2, F-3 | T1–T5 |
| `lib/screens/calendar/calendar_screen.dart` | F-7, UI-5 | T14–T18 |

## Coverage Gaps

### Requirements with no tasks
- F-10: Shopping list share link — needs tasks in PLAN.md
- F-15: Notification preferences — needs tasks in PLAN.md

### Requirements with no tests
- F-7: Calendar view — implementation exists, tests missing
- UI-8: Onboarding screen — implementation exists, tests missing

### Requirements by phase coverage
| Phase | Total | Done | In Progress | Not Started |
|-------|-------|------|-------------|-------------|
| Phase 1 | 12 | 10 | 2 | 0 |
| Phase 2 | 8 | 0 | 0 | 8 |
| Phase 3 | 5 | 0 | 0 | 5 |
```

### Step 3: Status Definitions

| Status | Meaning |
|--------|---------|
| ✅ Done | All tasks complete, tests pass |
| 🔄 In Progress | At least one task started |
| 🔁 Rework | Requirement changed after implementation — needs rework |
| ⬜ Not Started | No tasks yet |
| 🚫 Blocked | Waiting on dependency or decision |

### Step 4: Impact Analysis (on change)

When a requirement is updated via `/tl-telar:update-requirement`, produce:

```markdown
## Impact Analysis: F-10 v1.1 (ADD share link)

### Directly affected
- Tasks: T14 (new), T15 (modify)
- Files: `lib/features/shopping/share_service.dart` (new), `lib/screens/shopping/shopping_screen.dart` (modify)
- Tests: `test/shopping_share_test.dart` (new)

### Indirectly affected
- F-6 (Shopping list base) — share is an extension; no changes needed
- UI-9 (Shopping screen) — layout update needed for share button

### Done tasks needing rework
- T12 (Shopping list screen) — needs share button added → status: rework
```

## Verification

1. Every F-x and UI-x in REQUIREMENTS.md appears in the RTM
2. Coverage gaps section is present and accurate
3. Phase coverage table reflects current PROGRESS.md status
4. Backward traceability covers all implementation files

## References

- Input: `REQUIREMENTS.md`, `PLAN.md`, `PROGRESS.md`
- Used by: `skills/review-gates.md` (Stage 1 compliance)
- Updated by: `commands/update-requirement.md`
