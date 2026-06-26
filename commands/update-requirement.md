---
id: update-requirement
name: Update Requirement
description: Manage requirement changes mid-project with impact analysis and cascade updates across REQUIREMENTS.md, PLAN.md, and PROGRESS.md
category: command
usage: /tl-telar:update-requirement [F-x|UI-x] [change description]
examples:
  - /tl-telar:update-requirement F-10 add share link feature
  - /tl-telar:update-requirement move F-17 to Phase 1
  - /tl-telar:update-requirement remove F-16
  - /tl-telar:update-requirement change Timetable tier from Premium to Free
---

# Update Requirement

Manages requirement changes during development with structured impact analysis and cascade updates.

## When to Use

- A feature scope changes mid-project
- A feature moves between phases
- A feature is removed or deferred
- A tier assignment changes
- A Figma design reference is updated

## Step 1: Parse the Change

From the user's input, determine:

| Field | Extract |
|-------|--------|
| Target | Which F-x, UI-x, or topic |
| Change type | UPDATE / MOVE / REMOVE / TIER / DESIGN |
| New value | What the new state should be |

If the change is ambiguous, ask one clarifying question before proceeding.

## Step 2: Impact Analysis

Before making any changes, produce an impact report and **present it to the user for confirmation**:

```markdown
## Impact Analysis: [F-x] — [Change Type]

### What will change in REQUIREMENTS.md
- [Exact diff of the requirement]

### Requirement dependencies
- [Other F-x or UI-x that reference this requirement]
- Verdict: affected / not affected

### Code impact
- Files already implementing this: [list]
- Verdict: rework needed / no rework

### Plan impact
- Done tasks affected: [list with status change from done → rework]
- In-progress tasks affected: [list]
- New tasks needed: [list]

### Proceed? (yes / modify / cancel)
```

Wait for explicit user confirmation before Step 3.

## Step 3: Update REQUIREMENTS.md

Based on change type:

### UPDATE
- Edit the F-x / UI-x section with the new description or business rules
- Increment sub-version in the requirement header if versioned

### MOVE
- Change the `**Phase:**` field in the requirement
- Update Development Phases section tables

### REMOVE
- Remove the F-x / UI-x section
- Add to Out of Scope section with reason
- Note removal in Changelog

### TIER
- Update Feature Gating table for the affected feature
- Update the requirement's `**Tier:**` field

### DESIGN
- Update the Design Assets table: Figma link, node ID, or status

**Always:**
- Add a Changelog entry:
  ```markdown
  | v[N+1] | [date] | [F-x] | [CHANGE_TYPE] | [Description] |
  ```
- Increment the version in the Source header

## Step 4: Cascade Updates

### PLAN.md
- Add new tasks for any new scope (with F-x reference)
- Mark affected done tasks as `rework`
- Update dependency graph if needed

### PROGRESS.md
- New tasks → status: `pending`
- Rework tasks → status: `rework` (not `done`)
- Add note in Session Notes: "[F-x] changed — [N] tasks marked for rework"

### RESEARCH.md (if architectural impact)
- Update relevant section if the change affects platform, backend, or architecture decisions

### TRACEABILITY.md (if exists)
- Update RTM rows for affected requirements
- Recalculate coverage percentages

## Output Summary

After completing all updates, produce:

```markdown
## Update Complete: [F-x] v[N+1]

**Change:** [Summary]
**REQUIREMENTS.md:** Updated (v[N] → v[N+1])
**PLAN.md:** [N] tasks added, [N] tasks marked rework
**PROGRESS.md:** Updated
**Next action:** [What the developer should do next]
```

## Verification

1. Changelog entry added with correct version, date, and change type
2. All cascade files updated (PLAN.md, PROGRESS.md)
3. No done tasks left as `done` if they require rework
4. User confirmed impact analysis before changes were applied
