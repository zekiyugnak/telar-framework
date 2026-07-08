---
name: "okf-knowledge-authoring"
description: "An OKF knowledge bundle (`docs/knowledge/`) is only useful if agents can trust it. Three failure modes rot it: (1) a concept **restates a decision or schema** and then drifts from the real source, becoming a second, wron"
source_type: "skill"
source_file: "skills/okf-knowledge-authoring.md"
---

# okf-knowledge-authoring

Migrated from `skills/okf-knowledge-authoring.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# okf-knowledge-authoring

## Problem

An OKF knowledge bundle (`docs/knowledge/`) is only useful if agents can trust it. Three failure modes rot it: (1) a concept **restates a decision or schema** and then drifts from the real source, becoming a second, wrong source of truth; (2) a concept **has no citation**, so no reader can verify it; (3) a concept **leaks data rows, PII, or secrets** into a file that is world-readable within the repo. Authoring without a contract produces exactly these.

## Solution

Author every concept against one contract. The bundle is a **derived, machine-facing view** of `docs/adr/` (decisions) and `docs/data_model/` (schema) — never a second source.

### 1. Format (OKF v0.1)

- One `.md` file = one concept (a table, term, metric, playbook…). Reserved filenames: `index.md` (navigation / progressive disclosure, no required frontmatter) and `log.md` (change history, `## YYYY-MM-DD` headings, newest first).
- YAML frontmatter's only **required** key is `type` (non-empty). Recommended: `title`, `description`, `resource` (canonical URI), `tags`, `timestamp` (ISO 8601). Extra keys are fine — consumers must tolerate unknown keys.
- Relationships are ordinary markdown links between concepts (`[x](/core/tables/x.md)` or `[x](./x.md)`); the link graph is richer than the directory tree. Consumers must tolerate broken links.

A minimal table concept (`docs/knowledge/core/tables/candidates.md`):

```markdown
---
type: Postgres Table
title: candidates
description: One row per candidate profile.
resource: https://console.example/db/candidates
tags: [core, identity]
timestamp: 2026-07-08T00:00:00Z
---

# Schema
| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key. |
| `employer_id` | uuid | FK to [employers](/core/tables/employers.md). |

# Joins
Joined with [employers](/core/tables/employers.md) on `employer_id`.

# Citations
- Schema: [data_model/core/04](/docs/data_model/core/04-schema.md)
- Decision: ADR-0043 (documentation IA)
```

### 2. Authority & citations (one-way)

- On any conflict, the **ADR / schema wins** and you correct the concept — never the reverse.
- Never originate a decision in a concept. New rules land in an ADR or the schema spec first; the concept encodes an already-ratified fact.
- Every concept links its origin under a `# Citations` heading (ADR / EDR / spec path). **A concept without a citation is incomplete.**
- Bias content toward the **non-derivable**: relationships, business meaning, cross-cutting rules — not schema an agent can already read from the DDL.

### 3. PII & security boundary (binding)

- Schema, semantics, and metadata **only** — never data rows, never personal data.
- No secrets, tokens, connection strings, or `service_role` material. `resource` URIs point at consoles/paths, not credentials.
- Rule of thumb: nothing may appear here that could not sit in a code comment.

### 4. Naming & scope

- `core` concepts use neutral names (e.g. `Candidate`, `Employer`); vertical scopes may use concrete names. A `core` change that a vertical overrides gets a concept in that vertical scope — do not branch inside a `core` concept.

### 5. Maintenance (source-first, same change)

1. **Source first** — land the change in the migration / `data_model` / ADR (its authoritative home).
2. **Then derive** — update the matching `docs/knowledge/<scope>/…` concept and append a `log.md` entry.
3. **Removal** — when a concept's source is deleted upstream, delete the concept (and any links to it) and log the removal.
4. **PII gate** — re-confirm §3 on every edit.

Source and bundle move together within one change, not in a separate later pass (analogous to the schema `expand → migrate → contract` gate).

### 6. Cross-linking (the value multiplier)

Wire concepts so an agent starting anywhere reaches what it needs: `RPC → table`, `Access Policy → table`, `Invariant → RPC/table`, `Scenario → Screen → RPC → table`, `Decision → concept`. Use ordinary markdown links; path = entry name.

### 7. Validation checklist (before merge)

- [ ] Valid frontmatter with a non-empty `type`.
- [ ] Cites its ADR / EDR / spec origin (`# Citations`).
- [ ] The change landed in the authoritative source **before** the concept.
- [ ] No PII, no data rows, no secrets.
- [ ] `log.md` updated with a dated entry; `index.md` updated if navigation changed.
- [ ] `core` uses neutral naming; vertical specifics live in the vertical scope.
- [ ] The project's OKF validator passes (conformance; links reviewed).
- [ ] High-stakes concept (Access Policy / Invariant / Compliance Control)? Routed to adversarial review.
