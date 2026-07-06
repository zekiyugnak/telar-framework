---
name: "update-requirement"
description: "Manage requirement changes mid-project with impact analysis and cascade updates across REQUIREMENTS.md, PLAN.md, and PROGRESS.md"
source_type: "command"
source_file: "commands/update-requirement.md"
---

# update-requirement

Migrated from `commands/update-requirement.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- In Codex, this skill is the replacement for the Claude slash command `/tl-telar:update-requirement`; invoke it as `$update-requirement` or through `@tl-telar`.
- Do not require Claude slash-command dispatch or Claude-only environment setup before following the workflow.
- When the original command says to load `skills/orchestration/<name>`, load the generated Codex skill at `../orchestration-<name>/SKILL.md` first. The original source copy also exists under `../../source/skills/orchestration/<name>/SKILL.md` for exact Telar-source references.


# Update Requirement

> Mid-project requirement changes are a Spec Layer change like any other: this command first resolves (or creates) the active change via `skills/requirements-gather.md` → "Step 0", edits that change's `tl-telar-spec/changes/<id>/REQUIREMENTS.md` (Steps 3–4 below), and — crucially — also records the same change as a `REQUIREMENTS.delta.md` (Step 3b) so `scripts/tl-telar-spec-archive.js` can later merge it into `tl-telar-spec/truth/<domain>/REQUIREMENTS.md`. A change with no delta file cannot be archived, so Step 3b is not optional.

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

## Step 3b: Record the delta (required for archiving)

Editing `REQUIREMENTS.md` alone is not enough — `scripts/tl-telar-spec-archive.js` reads only `REQUIREMENTS.delta.md`. Write (or append to) `tl-telar-spec/changes/<id>/REQUIREMENTS.delta.md` following `skills/requirements-gather.md` → "Delta Mode" (same header format and `baseline-hash` computation), mapping this change's type to a delta section:

| Change type | Delta section |
|-------------|---------------|
| New scope added (a brand-new F-x) | `## ADDED Requirements` |
| UPDATE / MOVE / TIER (existing F-x changes) | `## MODIFIED Requirements` (full replacement block for that F-x) |
| REMOVE | `## REMOVED Requirements` (F-x heading + one-line reason) |

DESIGN-only changes (Figma link/status) touch no F-x and need no delta entry; if a change produces no ADDED/MODIFIED/REMOVED F-x entry at all, there is nothing to archive into `truth/` and the archive step is skipped for it.

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
