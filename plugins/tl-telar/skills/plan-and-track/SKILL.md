---
name: "plan-and-track"
description: "Converts `RESEARCH.md` decisions into actionable implementation plans with requirement traceability and persistent progress tracking."
source_type: "skill"
source_file: "skills/plan-and-track.md"
---

# plan-and-track

Migrated from `skills/plan-and-track.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Plan and Track

Converts `RESEARCH.md` decisions into actionable implementation plans with requirement traceability and persistent progress tracking.

## Prerequisites

- `REQUIREMENTS.md` must exist (produced by `requirements-gather`)
- `RESEARCH.md` must exist (produced by `brainstorm-first`)

**Spec Layer location:** read `.tl-telar/context/active-change.txt` for the active change-id. `REQUIREMENTS.md`/`RESEARCH.md` are read from, and `PLAN.md`/`PROGRESS.md` are written to, `tl-telar-spec/changes/<id>/` — never the project root.

---

## Solution

### 1. PLAN.md Template

```markdown
# Plan: [Feature/App Name]

## Overview
**Based on:** REQUIREMENTS.md v[X], RESEARCH.md
**Estimated tasks:** [N]
**Estimated sessions:** [N]

## Task Breakdown

### Phase 1: Setup
- [ ] **T1**: [Task title] (~3 min)
  - Requirement: F-1
  - Files: `lib/features/auth/auth_repository.dart`
  - Acceptance: [What "done" looks like]
  - Depends on: none

- [ ] **T2**: [Task title] (~5 min)
  - Requirement: F-1
  - Files: `lib/features/auth/auth_screen.dart`
  - Acceptance: [What "done" looks like]
  - Depends on: T1

### Phase 2: Core Logic
- [ ] **T3**: [Task title] (~4 min)
  - Requirement: F-7
  - Files: `lib/features/calendar/calendar_provider.dart`
  - Acceptance: [What "done" looks like]
  - Depends on: T1

### Phase 3: UI
- [ ] **T4**: [Task title] (~5 min)
  - Requirement: UI-5, F-7
  - Files: `lib/screens/calendar/calendar_screen.dart`
  - Acceptance: [What "done" looks like]
  - Depends on: T2, T3

### Phase 4: Polish & Tests
- [ ] **T5**: [Task title] (~3 min)
  - Requirement: F-7
  - Files: `test/calendar_test.dart`
  - Acceptance: [What "done" looks like]
  - Depends on: T4

## Dependency Graph

```
T1 (setup) ──> T2 (screen)
    │
    └──> T3 (logic) ──> T4 (UI) ──> T5 (tests)
```markdown

## Amendment Log
| Date | Amendment | Triggered by |
|------|-----------|-------------|
| [date] | Added T14: share link | F-10 v1.1 update |
```

---

### 2. PROGRESS.md Template

```markdown
# Progress: [Feature/App Name]

## Status: In Progress
**Started:** [date]
**Last updated:** [date]
**Completion:** [X]%

## Tasks

| # | Task | Requirement | Status | Session | Notes |
|---|------|-------------|--------|---------|-------|
| T1 | [title] | F-1 | done | 1 | — |
| T2 | [title] | F-1 | done | 1 | — |
| T3 | [title] | F-7 | in-progress | 2 | — |
| T4 | [title] | UI-5, F-7 | pending | — | — |
| T5 | [title] | F-7 | pending | — | — |

## Status Definitions
| Status | Meaning |
|--------|---------|
| done | Complete, acceptance criteria met |
| in-progress | Currently being worked on |
| pending | Not started |
| rework | Was done; requirement changed — needs rework |
| blocked | Waiting on dependency or decision |

## Blockers
- [ ] [Blocker] — [what's needed]

## Decisions Log
| Date | Decision | Rationale |
|------|----------|-----------|
| [date] | [Decision] | [Why] |

## Session Notes
### Session 1 — [date]
- Completed: T1, T2
- Issues: none
- Next: T3
```

---

### 3. Task Quality Rules

Each task must be:
- **Atomic**: completable in one Claude Code turn (2–5 minutes)
- **Requirement-linked**: references at least one F-x or UI-x
- **Independently verifiable**: has clear acceptance criteria
- **Specific about files**: lists exact files to create or modify
- **Dependency-aware**: states what must be done first

---

### 4. Amendment Support

When a requirement changes (via `update-requirement` command):

1. Add new tasks at the end of the relevant phase
2. Mark affected done tasks as `rework` in PROGRESS.md
3. Add an entry to the Amendment Log in PLAN.md
4. Do not renumber existing tasks — use T[N+1] sequentially

---

### 5. Integration with Build Loop

PLAN.md tasks feed directly into the `iterative-build-loop` baton system:

1. Pick the next unblocked task from PLAN.md
2. Build using iterative build loop (write code → verify on simulator)
3. Update PROGRESS.md with status
4. Write `next-step.md` baton for the next session
5. Repeat until all tasks are complete

### 6. Completion Protocol

When all tasks are done:
1. Update PROGRESS.md status to "Complete"
2. Archive: run `node scripts/tl-telar-spec-archive.js <change-id>` — it moves the entire `tl-telar-spec/changes/<id>/` folder (PLAN.md, PROGRESS.md, REQUIREMENTS.md, RESEARCH.md, and any TRACEABILITY.md together) to `tl-telar-spec/changes/archive/<date>-<id>/` in one step, and merges any `REQUIREMENTS.delta.md` into `tl-telar-spec/truth/`. There is no separate `.claude/archive/` location.
3. Delete the `next-step.md` baton
4. Write a summary commit message referencing the plan

---

## Verification

1. Every task has a `Requirement:` field referencing at least one F-x or UI-x
2. PLAN.md has at least 3 tasks with acceptance criteria
3. Every task has file paths and dependencies listed
4. PROGRESS.md is updated after each task completion
5. No task exceeds ~5 minutes of work
6. Dependency graph has no cycles

## References

- Input: `skills/requirements-gather.md` (REQUIREMENTS.md), `skills/brainstorm-first.md` (RESEARCH.md)
- Output: `skills/iterative-build-loop.md`
- Traceability: `skills/requirements-traceability.md`
- Change management: `commands/update-requirement.md`
