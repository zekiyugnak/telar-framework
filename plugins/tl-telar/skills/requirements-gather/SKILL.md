---
name: "requirements-gather"
description: "Establishes `REQUIREMENTS.md` — the single source of truth for what the app must do. Decoupled from `brainstorm-first` (which focuses on *how* to build it technically). This skill focuses exclusively on *what* to build."
source_type: "skill"
source_file: "skills/requirements-gather.md"
---

# requirements-gather

Migrated from `skills/requirements-gather.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Requirements Gather

Establishes `REQUIREMENTS.md` — the single source of truth for what the app must do. Decoupled from `brainstorm-first` (which focuses on *how* to build it technically). This skill focuses exclusively on *what* to build.

Supports two modes:
- **From Scratch** — Interactively collects requirements when the user has no prior documentation
- **Document-Driven** — Accepts an existing document, parses it, and converts it to REQUIREMENTS.md format

---

## Step 0: Resolve Spec Layer location (change-id + domain)

Before gathering requirements, resolve where REQUIREMENTS.md will be written:

1. **Read the active change pointer**: `.tl-telar/context/active-change.txt` (one line, the current change-id). If it exists and its change dir under `tl-telar-spec/changes/<id>/` exists, reuse it.
2. **If absent, or if it points at a change whose directory under `tl-telar-spec/changes/<id>/` no longer exists** (e.g. it was already archived), this is a new change:
   - Generate a change-id: `<YYYY-MM-DD>-<kebab-case-slug-from-feature-description>` (e.g. `2026-07-add-dark-mode`).
   - If `tl-telar-spec/` doesn't exist yet, run `node scripts/tl-telar-spec-bootstrap.js` first — this creates the skeleton and migrates any pre-existing root-level REQUIREMENTS.md/RESEARCH.md/PLAN.md into `tl-telar-spec/truth/`.
   - Create `tl-telar-spec/changes/<id>/`.
   - Write the change-id to `.tl-telar/context/active-change.txt` (git-ignored — matches the existing `.tl-telar/context/` convention; this pointer is ephemeral session state, not a durable artifact).
3. **Determine domain**: if candidate file paths are already known (e.g. from a prior RESEARCH.md or an epic file), run `node -e "console.log(require('./scripts/tl-telar-spec-domain.js').inferDomain(process.argv.slice(1)))" -- <path1> <path2> ...`. Otherwise ask the user directly: "Which part of the app does this belong to — auth, navigation, checkout, ...?" Always show the inferred/asked domain to the user for confirmation before writing any file. This skill authors exactly one domain per change today; the `deltas/<domain>.REQUIREMENTS.delta.md` multi-file convention that `scripts/tl-telar-spec-archive.js` and `scripts/validate-spec-layer.js` already support is not yet produced by any skill — a change touching multiple domains currently needs to be split into one change per domain.
4. **Check for an existing truth doc**: does `tl-telar-spec/truth/<domain>/REQUIREMENTS.md` exist?
   - **Yes** → this run operates in **Delta Mode** (below).
   - **No** → proceed with the ordinary **From Scratch** / **Document-Driven** mode below to write the full `REQUIREMENTS.md`, then follow "Seeding a Brand-New Domain" (below) to also produce a delta file — `scripts/tl-telar-spec-archive.js` only ever reads delta files, so a change with no delta file cannot be archived; this step is what lets the very first change in a domain actually reach `truth/`.

All REQUIREMENTS.md output from this skill is written to `tl-telar-spec/changes/<id>/REQUIREMENTS.md` — never to the project root.

---

## Seeding a Brand-New Domain

Triggered when Step 0 found NO existing `tl-telar-spec/truth/<domain>/REQUIREMENTS.md` (the greenfield case). After writing the full `REQUIREMENTS.md` via From Scratch or Document-Driven mode:

1. Extract every F-x id and its full block from the just-written `REQUIREMENTS.md`.
2. Write `tl-telar-spec/changes/<id>/REQUIREMENTS.delta.md`:

   ```markdown
   <!-- tl-telar-spec-delta: domain=<domain> baseline-hash=none -->
   # Delta: <change-id> / <domain> (initial seed)

   ## ADDED Requirements
   ### F-1: <Title>
   [full block, copied verbatim from REQUIREMENTS.md]

   ### F-2: <Title>
   [full block, copied verbatim from REQUIREMENTS.md]
   ```

3. This is what `node scripts/tl-telar-spec-archive.js <change-id>` merges into a brand-new `truth/<domain>/REQUIREMENTS.md`. `scripts/tl-telar-spec-merge.js`'s `mergeDelta` already handles merging ADDED entries into empty truth content correctly (see `tests/spec-layer/merge.test.js` and `tests/spec-layer/archive-smoke.sh`'s `test_happy_path_first_delta`) — no code changes are needed for this, only this authoring step.

---

## Delta Mode

Triggered when Step 0 found an existing `tl-telar-spec/truth/<domain>/REQUIREMENTS.md`. Instead of writing a full REQUIREMENTS.md from a blank slate:

1. Read the existing F-x list from `tl-telar-spec/truth/<domain>/REQUIREMENTS.md`.
2. Ask the user which F-x are: **new** (ADDED), **changing** (MODIFIED — reference the existing F-x id), or **being retired** (REMOVED — reference the existing F-x id, ask for a one-line reason).
3. Compute the `baseline-hash`: `node -e "console.log(require('crypto').createHash('sha256').update(require('fs').readFileSync('tl-telar-spec/truth/<domain>/REQUIREMENTS.md','utf8')).digest('hex'))"` — or the literal string `none` if that truth file does not exist yet.
4. Write `tl-telar-spec/changes/<id>/REQUIREMENTS.delta.md`:

   ```markdown
   <!-- tl-telar-spec-delta: domain=<domain> baseline-hash=<hash-or-none> -->
   # Delta: <change-id> / <domain>

   ## ADDED Requirements
   ### F-<n>: <Title>
   **Description:** ...
   **Business rules:** ...
   **User story:** ...
   **Phase:** ...
   **Tier:** ...

   ## MODIFIED Requirements
   ### F-<existing-id>: <Title>
   [full replacement block, same shape as the REQUIREMENTS.md Template below]

   ## REMOVED Requirements
   ### F-<existing-id>: <Title>
   **Reason:** [one line]
   ```

5. Also write the FULL, current-state `REQUIREMENTS.md` (existing F-x list plus the new/changed ones) to `tl-telar-spec/changes/<id>/REQUIREMENTS.md` — downstream skills (`brainstorm-first`, `plan-and-track`) read this file, never the delta.
6. The delta is merged into `truth/<domain>/REQUIREMENTS.md` later, via `node scripts/tl-telar-spec-archive.js <change-id>` — run by the orchestrator/command after the final review step (see `commands/orchestrate.md`), not by this skill.

---

## Mode Selection

Before starting, determine which mode to use:

| Condition | Mode |
|-----------|------|
| User has no documentation, just an idea | **From Scratch** |
| User provides a requirements doc, PRD, spec, wireframe set, or design doc | **Document-Driven** |
| REQUIREMENTS.md already exists and is complete | **Skip** — proceed to `brainstorm-first` |
| REQUIREMENTS.md exists but has gaps | **Gap-fill** — complete missing sections only |

---

## From Scratch Mode

### Step 1: Gather Inputs

Ask the user:

1. **Existing document?** — "Do you have a requirements document, PRD, or spec I should use as a starting point?"
   - Yes → Switch to **Document-Driven Mode**
   - No → Continue

2. **Existing designs?** — "Do you have Figma designs, wireframes, or mockups?"
   - Yes → Ask for Figma links or files; catalogue in Design Assets table
   - No → Note as "No design yet" in Design Assets table

3. **Core questions** (ask conversationally, not as a form):
   - What is the app called and what does it do in one sentence?
   - Who is the target user and what problem does it solve for them?
   - What are the must-have features for launch (Phase 1)?
   - Are there premium/paid tiers? What features are gated?
   - Who are the different user roles and what can each do?
   - Are there screens or flows you already know you need?
   - Any features explicitly out of scope?
   - Any open decisions or unknowns to flag?

### Step 2: Produce REQUIREMENTS.md

Use the template below. Fill all sections. For unknowns, use `TBD` and add to Open Items.

---

## Document-Driven Mode

### Step 1: Accept Document

Accept the user's document in any format:
- Markdown file (`.md`) — file upload or paste
- PDF or Word document
- Pasted text in conversation
- File path reference

### Step 2: Extract Decisions

Parse the document and map content to REQUIREMENTS.md sections:

| REQUIREMENTS.md Section | What to Look For |
|---|---|
| Application Identity | App name, slogan, purpose, target users |
| Monetization & Tiers | Tier names, pricing, feature gating rules |
| User Roles & Permissions | Role definitions, visibility, access control |
| Navigation Structure | Tab bar, drawer, screen list, flow descriptions |
| UI Requirements (UI-x) | Screen names, layout descriptions, wireframe references |
| Functional Requirements (F-x) | Feature descriptions, business rules, edge cases |
| Design Assets | Figma links, node IDs, design status |
| Data & Storage | Data models, retention policies, storage quotas |
| Development Phases | Phase breakdown, feature assignment per phase |
| Open Items | Unresolved questions, pending decisions |
| Out of Scope | Explicitly excluded features |

### Step 3: Gap Analysis

Present to the user:

```markdown
## Gap Analysis

### ✅ Fully Covered (no questions needed)
- [List sections with complete information]

### ⚠️ Partially Covered (need clarification)
- [Section]: [What's missing or unclear]

### ❌ Not Covered (need user input)
- [Section]: [What's entirely absent]
```

For each gap:
- Propose 2–3 options based on the document's context
- Recommend one option with rationale tied to existing decisions
- Wait for user decision before writing REQUIREMENTS.md

### Step 4: Document-Driven Rules

1. **Never override user decisions.** If the document says Premium tier includes X, do not remove or reorder it.
2. **Use the document's own wording.** Do not rephrase decisions in a way that changes their meaning.
3. **Flag contradictions, don't resolve them.** List conflicting statements and ask the user to clarify.
4. **Brainstorm only for gaps.** Do not produce option comparisons for areas the document already covers.
5. **Preserve phasing.** If the document defines Phase 1/2/3, respect that order exactly.
6. **Annotate source.** In REQUIREMENTS.md, note whether each decision came from the document or gap-filling.

---

## REQUIREMENTS.md Template

```markdown
# Requirements: [App Name]

## Source
**Mode:** From Scratch | Document-Driven
**Source document:** [filename or "N/A"]
**Version:** v1.0
**Last updated:** [date]

---

## Application Identity
- **Name:** [App name]
- **Slogan / tagline:** [One-liner]
- **Purpose:** [What the app does]
- **Target users:** [Who uses it]
- **Value proposition:** [What problem it solves]

---

## Monetization & Tiers

| Tier | Price | Target User |
|------|-------|-------------|
| Free | $0 | [Description] |
| Premium | $X/mo | [Description] |
| [Tier N] | | |

### Feature Gating
| Feature | Free | Premium | [Tier N] |
|---------|------|---------|----------|
| [F-x] | ✅ | ✅ | ✅ |
| [F-y] | ❌ | ✅ | ✅ |

---

## User Roles & Permissions

| Role | Description | Key Permissions |
|------|-------------|----------------|
| [Role 1] | | |
| [Role 2] | | |

---

## Navigation Structure

### Bottom Tab Bar
1. [Tab 1] — [Screen]
2. [Tab 2] — [Screen]
...

### Drawer / Side Menu
- [Item] → [Destination]

### Key Flows
- [Flow description]

---

## UI Requirements

### UI-1: [Screen Name]
**Purpose:** [What this screen does]
**Entry points:** [Where user comes from]
**Key elements:** [Main UI elements]
**Notes:** [Special behavior]

### UI-2: [Screen Name]
...

---

## Functional Requirements

### F-1: [Feature Name]
**Description:** [What it does]
**Business rules:** [Constraints, validations, edge cases]
**User story:** As a [role], I want to [action] so that [value]
**Phase:** [1 / 2 / 3]
**Tier:** [All / Premium / ...]

### F-2: [Feature Name]
...

---

## Design Assets

### Figma References
| Screen | Figma Link / Node ID | Status | Notes |
|--------|---------------------|--------|-------|
| UI-1: [Screen] | [link or node-id] | Final | |
| UI-2: [Screen] | [link or node-id] | Draft | |
| UI-3: [Screen] | — | No design | Build from spec |

**Status legend:** Final | Draft | WIP | No design

### Design Coverage Summary
- **Final designs:** X screens
- **Draft / WIP designs:** X screens
- **Spec only (no design):** X screens

---

## Data & Storage

- **Data retention:** [Policy]
- **User data:** [What is stored]
- **Media / files:** [Storage approach, size limits]
- **Offline availability:** [What works offline]

---

## Development Phases

### Phase 1 — MVP
**Goal:** [What defines MVP]
**Features:** F-1, F-2, F-3, ...
**Screens:** UI-1, UI-2, UI-3, ...

### Phase 2
**Goal:** [Phase 2 goal]
**Features:** F-4, F-5, ...

### Phase 3
**Goal:** [Phase 3 goal]
**Features:** F-6, F-7, ...

---

## Open Items

| # | Question | Owner | Status |
|---|----------|-------|--------|
| OI-1 | [Question] | [Who decides] | Open |

---

## Out of Scope

- [Feature explicitly excluded and why]

---

## Changelog

| Version | Date | Requirement | Change Type | Description |
|---------|------|-------------|-------------|-------------|
| v1.0 | [date] | — | INITIAL | Initial requirements |
```

---

## Verification

1. REQUIREMENTS.md exists before `brainstorm-first` is invoked
2. All F-x requirements have a phase and tier assignment
3. All UI-x screens are listed in Navigation Structure
4. Design Assets table is present (even if all rows are "No design")
5. Open Items section lists any unresolved questions
6. In Document-Driven Mode: no user decisions from the source document have been overridden
7. In Document-Driven Mode: Gap Analysis section is present with source annotations
8. `tl-telar-spec/changes/<id>/REQUIREMENTS.md` exists (never a root-level `REQUIREMENTS.md`)
9. If Delta Mode was used: `tl-telar-spec/changes/<id>/REQUIREMENTS.delta.md` exists with a valid `<!-- tl-telar-spec-delta: domain=... baseline-hash=... -->` header

## References

- Next step: `skills/brainstorm-first.md` (reads REQUIREMENTS.md to produce RESEARCH.md)
- Used by: `commands/create-app.md`, `commands/add-feature.md`
- Change management: `commands/update-requirement.md`
- Traceability: `skills/requirements-traceability.md`
- Spec Layer archive: `scripts/tl-telar-spec-archive.js` (merges deltas into `tl-telar-spec/truth/`, run after final review — see `commands/orchestrate.md`)
- Spec Layer bootstrap: `scripts/tl-telar-spec-bootstrap.js` (creates the `tl-telar-spec/` skeleton, migrates pre-existing root artifacts)
