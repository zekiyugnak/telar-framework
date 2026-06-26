---
id: requirements-gather
category: skill
impact: CRITICAL
impactDescription: Establishes the single source of truth for what the app must do, preventing scope creep, misaligned implementation, and late-stage rework
tags: [requirements, discovery, figma, document-driven, gap-analysis, product, planning]
capabilities:
  - Gather requirements interactively from scratch (From Scratch Mode)
  - Accept and parse an existing requirements document (Document-Driven Mode)
  - Extract decisions without overriding user choices
  - Perform gap analysis and flag missing areas
  - Capture Figma / design asset references in a structured table
  - Produce REQUIREMENTS.md as the single source of truth
useWhen:
  - Starting a new app or major feature with no prior documentation
  - User provides an existing PRD, spec, or design document
  - Migrating an undocumented project to a structured workflow
  - REQUIREMENTS.md is missing or incomplete
---

# Requirements Gather

Establishes `REQUIREMENTS.md` — the single source of truth for what the app must do. Decoupled from `brainstorm-first` (which focuses on *how* to build it technically). This skill focuses exclusively on *what* to build.

Supports two modes:
- **From Scratch** — Interactively collects requirements when the user has no prior documentation
- **Document-Driven** — Accepts an existing document, parses it, and converts it to REQUIREMENTS.md format

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

## References

- Next step: `skills/brainstorm-first.md` (reads REQUIREMENTS.md to produce RESEARCH.md)
- Used by: `commands/create-app.md`, `commands/add-feature.md`
- Change management: `commands/update-requirement.md`
- Traceability: `skills/requirements-traceability.md`
