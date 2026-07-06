# Web Accessibility Adversarial Rubric

## Purpose

Used by the conditional Adversarial Web A11y Reviewer (fired only when WU `fileScope` intersects web UI directories — see `skills/orchestration/mobile-adversarial-review.md` for the spawn pattern).

## Reviewer mode

**Adversarial.** Same discipline. Fresh `Task()` instance. Sees only the WU spec, DoD items, file scope, and git diff. Binary PASS/FAIL; no "minor changes" middle state. A FAIL must cite a rule ID.

## Evaluation criteria

### WA. Web accessibility failures (WCAG 2.2 AA)

A WU FAILS web accessibility review if any of:

- WA1. Non-semantic markup used where a semantic element exists: `<div>` or `<span>` wired as a button (click handler, no `role="button"`), as a link (no `<a>`), or as a heading (no `<h1>`–`<h6>`); page-level landmark regions (`<main>`, `<nav>`, `<header>`, `<footer>`, `<aside>`) absent or replaced with generic containers.
- WA2. Interactive element not keyboard-operable: missing `tabindex` on a custom control, `pointer-events: none` without a keyboard alternative, or a click handler with no `keydown`/`keyup` equivalent for Enter/Space.
- WA3. No visible focus indicator: `:focus` or `:focus-visible` outline is `outline: none` / `outline: 0` without a replacement visible style, leaving keyboard users with no caret location.
- WA4. Broken focus order or missing focus trap: logical reading order violated by `tabindex > 0` on multiple elements; modal/dialog that opens without moving focus inside it; modal that allows Tab to escape to background content; modal that does not return focus to the trigger element on close.
- WA5. Incorrect or redundant ARIA: `role` contradicts the host element's native semantics (e.g., `role="button"` on `<a href>`); interactive element missing an accessible name (`aria-label`, `aria-labelledby`, or visible label); `aria-hidden="true"` applied to a focusable element or its ancestor; `aria-expanded`/`aria-checked`/`aria-selected` state not updated to match visual state.
- WA6. Text contrast below WCAG AA: hardcoded color pairs where normal text (< 18 pt / 14 pt bold) falls below 4.5:1, or large text / UI components fall below 3:1. Reviewer flags visually suspect pairs (e.g., `#767676` on `#fff`, light placeholder on white). Meaning conveyed by color alone with no secondary indicator (pattern, icon, text) also fails here.
- WA7. Form control without a programmatically associated label: `<input>`, `<select>`, or `<textarea>` with no `<label for>`, no `aria-label`, and no `aria-labelledby`; or an error message not linked to its field via `aria-describedby`.
- WA8. Async/dynamic content updates not announced: new content injected into the DOM (toast, alert, validation error, live count) without an `aria-live` region, `role="status"`, or `role="alert"` so screen-reader users receive the update.
- WA9. Motion/animation that does not respect `prefers-reduced-motion`: CSS transitions, keyframe animations, or JS-driven motion added without a `@media (prefers-reduced-motion: reduce)` override or equivalent runtime check disabling/reducing the effect.
- WA10. Non-text content missing a text alternative: `<img>` without `alt` (decorative images must have `alt=""`); icon-only `<button>` without `aria-label` or visually-hidden text; `<svg>` used as meaningful content without `<title>` + `aria-labelledby` or `role="img" aria-label`.

## Verdict format

JSON per the schema. Rule IDs WA1-WA10. Reviewer field: `"web-a11y"`.
