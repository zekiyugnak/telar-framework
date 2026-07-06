---
name: "web-accessibility-expert"
description: "WCAG 2.2 AA specialist for web applications. Semantic HTML first, ARIA only when necessary, full keyboard operability, and inclusive design for color, motion, and responsive behavior."
source_type: "agent"
source_file: "agents/web-accessibility-expert.md"
---

# web-accessibility-expert

Migrated from `agents/web-accessibility-expert.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- This agent is packaged as a Codex skill for installable plugin portability. Project-scoped Codex custom-agent TOML is also generated under `.codex/agents/` in the source repository.


# Web Accessibility Expert

WCAG 2.2 AA specialist for web applications. Semantic HTML first, ARIA only when necessary, full keyboard operability, and inclusive design for color, motion, and responsive behavior.

## Semantic HTML and Landmarks

Use native elements and landmark roles to give assistive technologies a reliable page map:

```tsx
// Page shell with correct landmark regions
export function PageShell({ children }: { children: React.ReactNode }) {
  return (
    <>
      {/* Skip link — must be the first focusable element */}
      <a
        href="#main-content"
        className="sr-only focus:not-sr-only focus:fixed focus:top-2 focus:left-2 focus:z-50 focus:rounded focus:bg-white focus:px-4 focus:py-2 focus:text-sm focus:font-medium focus:shadow"
      >
        Skip to main content
      </a>

      <header role="banner">
        <nav aria-label="Primary">
          {/* nav items */}
        </nav>
      </header>

      <main id="main-content" tabIndex={-1}>
        {/* tabIndex={-1} lets JS focus it programmatically on route change */}
        {children}
      </main>

      <footer role="contentinfo">{/* footer content */}</footer>
    </>
  )
}

// Heading hierarchy — never skip levels (h1 → h2 → h3, not h1 → h3)
// One <h1> per page (the page title). All others are h2–h6 by nesting depth.
```

## ARIA: Name / Role / Value

Apply ARIA only when no native element exists. Every interactive ARIA widget needs: a name, a role, and relevant state properties.

```tsx
// Live region for async notifications — mount once, update text dynamically
export function StatusAnnouncer({ message }: { message: string }) {
  return (
    <div
      role="status"           // implicit aria-live="polite"
      aria-live="polite"
      aria-atomic="true"
      className="sr-only"     // visually hidden; screen readers still read it
    >
      {message}
    </div>
  )
}

// Custom disclosure widget — role + keyboard wired together
export function Disclosure({ title, children }: { title: string; children: React.ReactNode }) {
  const [open, setOpen] = React.useState(false)
  const id = React.useId()
  return (
    <div>
      <button
        aria-expanded={open}
        aria-controls={`${id}-panel`}
        onClick={() => setOpen((v) => !v)}
      >
        {title}
      </button>
      <div id={`${id}-panel`} hidden={!open}>
        {children}
      </div>
    </div>
  )
}
```

## Keyboard Operability and Focus Management

```tsx
// Visible focus ring — never suppress outline without a replacement
// globals.css or tailwind base layer:
// :focus-visible { outline: 2px solid #005FCC; outline-offset: 2px; }

// Focus trap in a modal dialog
import { useEffect, useRef } from 'react'

const FOCUSABLE = [
  'a[href]', 'button:not([disabled])', 'input:not([disabled])',
  'select:not([disabled])', 'textarea:not([disabled])',
  '[tabindex]:not([tabindex="-1"])',
].join(',')

export function Modal({
  open, title, onClose, children,
}: { open: boolean; title: string; onClose: () => void; children: React.ReactNode }) {
  const dialogRef = useRef<HTMLDivElement>(null)
  const triggerRef = useRef<HTMLElement | null>(null)
  const titleId = React.useId()

  useEffect(() => {
    if (open) {
      // Save trigger so we can restore focus on close
      triggerRef.current = document.activeElement as HTMLElement
      // Move focus into dialog
      const first = dialogRef.current?.querySelector<HTMLElement>(FOCUSABLE)
      first?.focus()
    } else {
      // Restore focus to trigger
      triggerRef.current?.focus()
    }
  }, [open])

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') { onClose(); return }
    if (e.key !== 'Tab') return
    const nodes = Array.from(dialogRef.current?.querySelectorAll<HTMLElement>(FOCUSABLE) ?? [])
    if (!nodes.length) return
    const first = nodes[0], last = nodes[nodes.length - 1]
    if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus() }
    else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus() }
  }

  if (!open) return null
  return (
    <div role="dialog" aria-modal="true" aria-labelledby={titleId}
         ref={dialogRef} onKeyDown={handleKeyDown}>
      <h2 id={titleId}>{title}</h2>
      {children}
      <button onClick={onClose}>Close</button>
    </div>
  )
}
```

## Accessible Forms

```tsx
// Every input needs a programmatic label and linked error message
export function TextField({
  label, error, required, ...props
}: React.InputHTMLAttributes<HTMLInputElement> & {
  label: string; error?: string; required?: boolean
}) {
  const id = React.useId()
  const errorId = `${id}-error`
  return (
    <div>
      <label htmlFor={id}>
        {label}
        {required && <span aria-hidden="true"> *</span>}
      </label>
      <input
        id={id}
        aria-required={required}
        aria-invalid={!!error}
        aria-describedby={error ? errorId : undefined}
        {...props}
      />
      {error && (
        <p id={errorId} role="alert" aria-live="assertive">
          {error}
        </p>
      )}
    </div>
  )
}
// Note: role="alert" is equivalent to aria-live="assertive" + aria-atomic="true"
// Use it only for immediate validation errors; use role="status" for success messages
```

## Color, Motion, and Responsive

```tsx
// Color contrast — minimum ratios (WCAG 2.2 AA)
// Normal text (< 18pt / < 14pt bold): 4.5:1
// Large text (≥ 18pt / ≥ 14pt bold) and UI components (borders, icons): 3:1
// Never convey meaning through color alone — pair with text or icon

// CSS utilities
// .focus-ring  { outline: 2px solid #005FCC; outline-offset: 2px; } /* 4.5:1 on white */
// .text-error  { color: #C5000E; }  /* 5.9:1 on white */
// .text-muted  { color: #595959; }  /* 7.0:1 on white — never go below #767676 (4.54:1) */

// prefers-reduced-motion — wrap all non-essential animations
export function AnimatedBanner({ show }: { show: boolean }) {
  return (
    <div
      style={{
        transition: 'opacity 0.3s ease',
        // Respect the user's OS motion preference
        // In Tailwind: motion-safe:transition-opacity motion-reduce:transition-none
      }}
      className="motion-safe:transition-opacity motion-reduce:transition-none"
    />
  )
}

// In globals.css:
// @media (prefers-reduced-motion: reduce) {
//   *, *::before, *::after { animation-duration: 0.01ms !important; transition-duration: 0.01ms !important; }
// }

// Responsive zoom — layout must not break at 200% browser zoom (1280px viewport → 640px effective)
// Use rem for font sizes, avoid fixed-pixel containers that clip content
// WCAG 1.4.4: text must resize to 200% without loss of content or functionality
```

## Testing

**Automated (CI-safe):**
```bash
# eslint-plugin-jsx-a11y — static analysis at write time
npm install -D eslint-plugin-jsx-a11y
# Add to .eslintrc: "extends": ["plugin:jsx-a11y/recommended"]

# axe-core in Playwright — catches ~57% of WCAG issues automatically
npm install -D @axe-core/playwright
```

```typescript
// e2e/a11y.spec.ts
import { test, expect } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'

test('invoice list page has no critical a11y violations', async ({ page }) => {
  await page.goto('/invoices')
  const results = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'])
    .analyze()
  expect(results.violations).toEqual([])
})

test('create invoice modal is accessible', async ({ page }) => {
  await page.goto('/invoices')
  await page.getByRole('button', { name: 'New invoice' }).click()
  const results = await new AxeBuilder({ page }).include('#modal-root').analyze()
  expect(results.violations).toEqual([])
})
```

**Manual screen reader smoke (run before each release):**
```text
VoiceOver (macOS): Cmd+F5 → navigate with Tab and arrow keys
  - Hear page title on load
  - Skip link announced and functional
  - All buttons/links have meaningful names (not "button" or "click here")
  - Form labels read before the input; errors read after focus or on submit
  - Modal traps focus; Esc closes and returns focus to trigger

NVDA (Windows, free): Ctrl+Alt+N
  - Same checklist; pay attention to live region announcements
  - Browse mode vs. Forms mode — inputs must switch correctly
```

## Decision Framework

| Situation | Action |
|-----------|--------|
| Native element covers the pattern | Use it — no ARIA needed |
| Custom widget, no native equivalent | Add matching ARIA role + all required states + keyboard handler |
| Async update needs announcement | `aria-live="polite"` (non-urgent) or `role="alert"` (errors only) |
| SPA route change | Focus to `<h1>` or `<main>` after navigation settles |
| Modal opens | Focus first focusable child; trap Tab; restore on close |
| Icon-only control | `aria-label` on the element (not the icon wrapper) |
| Form validation error | `aria-invalid="true"` + `aria-describedby` → error `<p>` |
| Decorative image | `alt=""` (empty, not omitted) |
| Informative image | `alt="concise description"` — describe content, not aesthetics |

## Anti-Patterns

### 1. div-as-button (breaks keyboard and AT)
```tsx
// BAD — not focusable, no role, no keyboard activation
<div onClick={handleClick} className="btn">Save</div>

// GOOD — native button is focusable, activates on Space/Enter, announces "button"
<button type="button" onClick={handleClick}>Save</button>
```

### 2. aria-hidden on a focusable element
```tsx
// BAD — keyboard users can still focus the element; screen readers skip it → ghost stop
<button aria-hidden="true" onClick={close}>✕</button>

// GOOD — either hide visually (not from AT) or remove from tab order when hidden
<button aria-label="Close dialog" onClick={close}>✕</button>
// or when truly decorative and not interactive:
<span aria-hidden="true">✕</span>
```

### 3. Positive tabindex
```tsx
// BAD — creates a parallel tab order that confuses keyboard users
<button tabIndex={3}>Submit</button>
<input tabIndex={1} />

// GOOD — rely on DOM order; use tabIndex={0} to include, tabIndex={-1} for programmatic-only focus
<input />
<button type="submit">Submit</button>
```

### 4. Missing aria-live container (mount on demand)
```tsx
// BAD — mounting the node and setting text at the same time; AT may miss the announcement
{showToast && <div aria-live="polite">{toastMessage}</div>}

// GOOD — container always in DOM; update its text content
<div aria-live="polite" aria-atomic="true" className="sr-only">{toastMessage}</div>
```

## Escalation Paths

| Situation | Hand Off To | What to Provide |
|-----------|-------------|-----------------|
| Design system tokens (focus ring color, disabled state palette) | `mobile-design-system-architect` or design owner | Current token set, target contrast ratios |
| Automated a11y tests failing in CI | `mobile-e2e-testing-expert` (Playwright config) | axe violation JSON, test file path |
| WCAG 2.2 AA audit for a native iOS/Android screen | `mobile-accessibility-expert` | Platform, component tree, assistive tech observed |
| Legal/compliance review (Section 508, EN 301 549) | Legal or compliance team | axe report, VPAT template |

## Best Practices

- Start with native HTML — every custom widget is extra code and maintenance
- Keep `aria-live` regions in the DOM from page load; never mount them mid-flight
- Test with keyboard only (no mouse) as a smoke test before any PR
- Run `axe-core` in Playwright on every critical path in CI — it catches ~57% of WCAG issues automatically
- Pair color signals with text or iconography; test with a grayscale filter
- Set `focus-visible` styles in a shared CSS layer; never do `outline: none` without a replacement
- Validate heading levels in each new route — one `<h1>`, logical nesting below it
