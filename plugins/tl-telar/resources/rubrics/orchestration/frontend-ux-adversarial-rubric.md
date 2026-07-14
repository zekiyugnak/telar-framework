# Frontend UX Completeness & i18n Adversarial Rubric

## Purpose

Used by the Adversarial Frontend UX Reviewer when a WU's `fileScope` intersects UI
component, screen, or locale/translation directories. Distinct from the accessibility
rubric — covers async-state, empty/error states, form guards, responsive layout, and
i18n catalog integrity. Not WCAG.

## Reviewer mode

**Adversarial.** Fresh `Task()` instance. Sees only the WU spec, DoD items, declared
`fileScope`, and git diff — no prior context, no other reviewers' findings. Binary
PASS/FAIL; no "consider improving" middle state. A FAIL must cite a rule ID.

## Evaluation criteria

### UX. Interaction completeness

A WU FAILS interaction-completeness review if any of:

- UX1. A component that fetches async data renders no loading state (spinner,
  skeleton, or placeholder) while the request is in flight.
- UX2. A list or collection view that can be empty (zero items) has no empty
  state — no message, illustration, or call-to-action rendered when the data
  set is empty.
- UX3. A fetch or mutation has no error state: failure is silently swallowed,
  console-logged only, or leaves the UI indefinitely in the loading state.
- UX4. A form submit button is not disabled or guarded while pending (double-submit);
  OR validation errors are never surfaced to the user.
- UX5. New layout code uses fixed pixel widths or absolute positioning that
  causes visible overflow or clipping at viewport ≤375 px or ≥1440 px; OR a
  breakpoint is added without a matching style change for the affected element.

### I18N. Localization

A WU FAILS localization review if any of:

- I18N1. A user-visible string (label, placeholder, error, button text, toast) is
  hardcoded instead of routed through the locale catalog (`t()`, `useTranslation`,
  `<Trans>`, or the project-specific equivalent).
- I18N2. A new locale key is present in one language file but absent from at
  least one other supported language file — catalog completeness (e.g., key in
  `tr.json`, missing from `en.json`).
- I18N3. Layout code uses physical directional CSS (`margin-left`, `padding-right`,
  `text-align: left`) where RTL locale support is declared; logical properties
  required (`margin-inline-start`, `padding-inline-end`, `text-align: start`).
- I18N4. A date, relative time, number, or currency is rendered via `toString()`,
  a template literal, or `toFixed()` instead of a locale-aware formatter
  (`Intl.DateTimeFormat`, `Intl.NumberFormat`, or the i18n library's helpers).
- I18N5. Pluralization or string interpolation uses JS concatenation or ternary
  (`count === 1 ? 'item' : 'items'`) instead of the i18n library's plural or
  interpolation mechanism (ICU message format or project-equivalent).

### Reuse & duplication

- UXR1. A UI element re-implements an existing shared component instead of reusing it → FAIL. A new element used the same way in more than one surface but left inlined → defer to the Maintainability rubric (`D-DUP`/`D-REUSE`) as an advisory. Do NOT force-merge visually-similar components that have different behavior/responsibility.

## Verdict format

JSON per the schema. Rule IDs UX1–UX5, I18N1–I18N5. Reviewer field: `"frontend-ux"`.
