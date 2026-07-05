# Requirements: {{product / area name}}
<!-- orchestrate-input: requirements -->
<!-- schema: requirements-input/v1 -->

> The program-level "**what & why**". One requirements doc can span many
> features; each feature you then build becomes its own `epic.md` (see
> `templates/epic.md`). Satisfies the plugin's `requirements-first` rule.
> The orchestrator and the Plan Review Gate's Scope-Alignment reviewer read
> this to keep what gets built aligned with what was asked.

## Vision

{{1-3 sentences: who this is for and the outcome it delivers.}}

## In scope / Out of scope

- **In scope:** {{the features this document covers}}
- **Out of scope (now):** {{explicitly deferred — prevents scope drift at the gate}}

## Functional Requirements

<!--
One row per capability. F-ids are referenced from epic tasks (`Requirements:` field)
so every built task traces back to a requirement. Acceptance criteria here become
the seed for each epic task's `dod`.
-->

| ID | Requirement | Acceptance criteria (verifiable) | Priority |
|----|-------------|----------------------------------|----------|
| F-1 | {{capability}} | {{Given/When/Then or a checkable statement}} | Must / Should / Could |
| F-2 | {{capability}} | {{...}} | Must |

## UI Surfaces

<!-- Screens/flows this area needs. UI-ids are referenced from epic tasks and
     drive the orchestrator's UI-clarification + (optional) visual checks. -->

| ID | Screen / flow | Platform surface | Notes / design ref |
|----|---------------|------------------|--------------------|
| UI-1 | {{screen}} | iOS / Android / app+web | {{link to mockup or design doc}} |

## Non-Functional Requirements

- **Performance:** {{budgets — e.g., list scroll 60fps, cold start < Xs}}
- **Security / privacy:** {{auth model, PII handling, compliance — e.g., KVKK/GDPR}}
- **Accessibility:** {{e.g., WCAG 2.1 AA, dynamic type, screen-reader labels}}
- **i18n / l10n:** {{languages, RTL, currency/region}}

## Decisions & Constraints

- **Architecture decisions:** {{links to ADRs / RESEARCH.md sections}}
- **Tech stack / non-negotiables:** {{framework, state mgmt, backend, libraries}}
- **Dependencies:** {{external services, other teams, prerequisite features}}

## Open Questions

- [ ] {{anything unresolved — resolve before authoring the epic, or the gate will surface it}}

## Change Log

| Date | Change | Triggered by |
|------|--------|--------------|
| {{ISO date}} | {{what changed}} | {{stakeholder / review}} |
