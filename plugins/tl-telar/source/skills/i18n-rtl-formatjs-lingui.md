---
id: i18n-rtl-formatjs-lingui
category: skill
impact: CRITICAL
impactDescription: "Prevents a costly full-UI re-audit later by building bilingual + RTL-ready layout discipline in from the first component"
tags: [i18n, formatjs, react-intl, lingui, rtl, tailwind, icu, admin-panel, web]
capabilities:
  - Choosing between FormatJS (react-intl) and Lingui for a Turkish/English admin panel
  - Message extraction workflow and ICU pluralization/formatting
  - RTL-readiness via CSS logical properties instead of physical left/right
  - Tailwind v4 rtl:/ltr: variant usage and dir="auto"/dir="rtl" handling
  - Testing a layout in both LTR and RTL without shipping a real RTL locale yet
  - Icon mirroring rules — which icons must flip for RTL and which must not
useWhen:
  - Setting up i18n for a new admin panel that must support Turkish and English
  - Writing any component that hardcodes English strings instead of message keys
  - Styling any element whose position is direction-dependent (padding, borders, alignment)
  - Deciding whether an icon (arrow, chevron, play button) should mirror under RTL
  - Reviewing a component for RTL-readiness before a future Arabic/Hebrew locale is added
---

# Bilingual (tr/en) i18n with RTL-Readiness: FormatJS vs Lingui

This admin panel ships in Turkish and English today, with an explicit requirement to be RTL-ready for a future locale (Arabic, Hebrew, etc.) without a structural rewrite. That means every string goes through an i18n library from day one, and every direction-sensitive style uses logical CSS properties from day one — retrofitting either later means auditing the entire component tree. This skill covers choosing between FormatJS and Lingui, the extraction/pluralization workflow, and the RTL layout discipline that makes a same-code-different-`dir` future locale a configuration change instead of a rewrite.

## Problem

Two mistakes compound over the life of a project: hardcoding strings "temporarily" because a component felt too small to bother wiring up i18n for, and styling with physical left/right properties because the only locales in front of you (Turkish, English) are both LTR, so a broken assumption about direction doesn't surface until much later.

```tsx
// BAD: hardcoded strings scattered through the component instead of message
// keys — by the time this needs a Turkish translation, someone has to hunt
// down every literal string across the whole file tree by hand
function DeleteConfirmDialog({ userName }: { userName: string }) {
  return (
    <Dialog>
      <DialogTitle>Delete user?</DialogTitle>
      <DialogDescription>
        This will permanently delete {userName}. This action cannot be undone.
      </DialogDescription>
      <Button variant="destructive">Delete</Button>
      <Button variant="ghost">Cancel</Button>
    </Dialog>
  )
}
```

```tsx
// BAD: physical left/right styling that is invisible today (both tr and en
// are LTR) but breaks the instant a future RTL locale is added, requiring
// a full pass over every component that has this pattern
<div className="flex items-center pl-6 border-l text-left">
  <BackArrowIcon className="mr-2" />
  <span>{title}</span>
</div>
```

## Solution

### Choosing FormatJS (react-intl) vs Lingui

| Factor | FormatJS (react-intl) | Lingui |
|---|---|---|
| Message format | ICU MessageFormat (industry standard, widely supported by translators/TMS tools) | ICU MessageFormat (same underlying format) |
| Extraction | CLI (`formatjs extract`) scans source for `<FormattedMessage>`/`intl.formatMessage()` calls | Compile-time macro (Babel/SWC/Vite plugin) extracts from `t\`...\`` / `<Trans>` |
| Boilerplate per string | Slightly more verbose (`intl.formatMessage({ id, defaultMessage })`) | More concise (`t\`Delete user?\`` or `<Trans>Delete user?</Trans>`) |
| Ecosystem/maturity | Larger, older, most translation-management integrations assume it | Smaller but modern, strong DX, first-class TypeScript |
| Team familiarity in most React codebases | More common — likely lower onboarding cost | Requires learning macro-based extraction |

**Default for this stack: FormatJS.** Its ICU pluralization handling and TMS (translation management system) ecosystem are the most battle-tested for a bilingual product that will eventually onboard professional translators, and the ecosystem is more likely to already be familiar to a React team. Choose Lingui instead only if the team specifically wants the terser macro syntax and is comfortable configuring its Babel/SWC/Vite integration — both libraries are ICU-compliant, so switching later is a mechanical (if tedious) migration, not a redesign.

### Setup and message extraction (FormatJS)

```tsx
// src/lib/i18n/IntlProvider.tsx
import { IntlProvider as ReactIntlProvider } from 'react-intl'
import { useLocale } from './useLocale'
import en from '@/locales/en.json'
import tr from '@/locales/tr.json'

const messages = { en, tr }

export function IntlProvider({ children }: { children: React.ReactNode }) {
  const { locale } = useLocale() // 'en' | 'tr', persisted per operator

  return (
    <ReactIntlProvider
      locale={locale}
      messages={messages[locale]}
      // A defaultLocale fallback ensures a missing key renders the English
      // string instead of a blank space or the raw message id.
      defaultLocale="en"
      onError={(err) => {
        // Missing-translation warnings should be visible in dev, not silent.
        if (import.meta.env.DEV) console.warn(err)
      }}
    >
      {children}
    </ReactIntlProvider>
  )
}
```

```tsx
// src/features/users/DeleteConfirmDialog.tsx
import { FormattedMessage, useIntl } from 'react-intl'

function DeleteConfirmDialog({ userName }: { userName: string }) {
  const intl = useIntl()

  return (
    <Dialog aria-label={intl.formatMessage({ id: 'users.deleteDialog.title' })}>
      <DialogTitle>
        <FormattedMessage id="users.deleteDialog.title" defaultMessage="Delete user?" />
      </DialogTitle>
      <DialogDescription>
        {/* ICU rich-text formatting: {userName} is interpolated, and the
            translator can reorder it relative to surrounding text per
            language without touching code. */}
        <FormattedMessage
          id="users.deleteDialog.body"
          defaultMessage="This will permanently delete {userName}. This action cannot be undone."
          values={{ userName: <strong>{userName}</strong> }}
        />
      </DialogDescription>
      <Button variant="destructive">
        <FormattedMessage id="common.delete" defaultMessage="Delete" />
      </Button>
    </Dialog>
  )
}
```

### ICU pluralization

```tsx
// ICU plural syntax handles language-specific plural rules (Turkish and
// English both have simple one/other plural categories, but writing it via
// ICU means the SAME code handles a future locale with more plural
// categories, like Arabic's six-way plural system, without a code change).
<FormattedMessage
  id="orders.selectedCount"
  defaultMessage="{count, plural, =0 {No orders selected} one {# order selected} other {# orders selected}}"
  values={{ count: selectedIds.length }}
/>
```

### Extraction workflow

```bash
# Extract every <FormattedMessage>/formatMessage() call in the source tree
# into a canonical en.json — this is the file sent to translators / a TMS.
npx formatjs extract 'src/**/*.tsx' \
  --out-file src/locales/en.json \
  --id-interpolation-pattern '[sha512:contenthash:base64:6]'

# tr.json is maintained by translators (or an initial machine pass reviewed
# by a native speaker) keyed by the SAME ids extraction produced for en.json.
```

### RTL-readiness: logical CSS properties over physical left/right

```tsx
// GOOD: every direction-sensitive property uses its logical equivalent.
// Under dir="ltr" these resolve exactly like the physical properties would
// (start = left, end = right); under a future dir="rtl" they resolve
// mirrored (start = right, end = left) with zero code changes.
<div className="flex items-center ps-6 border-s text-start">
  <BackArrowIcon className="me-2 rtl:-scale-x-100" />
  <span>{title}</span>
</div>
```

| Physical (avoid) | Logical (use) | Tailwind v4 utility |
|---|---|---|
| `margin-left` | `margin-inline-start` | `ms-*` |
| `margin-right` | `margin-inline-end` | `me-*` |
| `padding-left` | `padding-inline-start` | `ps-*` |
| `padding-right` | `padding-inline-end` | `pe-*` |
| `border-left` | `border-inline-start` | `border-s` |
| `text-align: left` | `text-align: start` | `text-start` |
| `left: 0` (absolute positioning) | `inset-inline-start: 0` | `start-0` |
| `float: right` | `float: inline-end` | (use flex/grid `justify-end` instead where possible) |

### `dir="auto"` vs explicit `dir="rtl"`, and Tailwind's `rtl:`/`ltr:` variants

```tsx
// src/routes/__root.tsx
// This is a pure Vite SPA (no SSR) — index.html already owns the actual
// <html>/<body> tags, and the root route only ever mounts into a <div id="root">
// inside them. A root route component CANNOT render <html>/<body> itself
// (that's a TanStack Start/SSR pattern, not a Vite SPA one); set dir/lang via
// an effect against document.documentElement instead.
import { useEffect } from 'react'
import { useLocale } from '@/lib/i18n/useLocale'

const RTL_LOCALES = new Set(['ar', 'he', 'fa', 'ur'])

function RootLayout() {
  const { locale } = useLocale()
  const dir = RTL_LOCALES.has(locale) ? 'rtl' : 'ltr'

  // Setting dir on the root element is what makes every `ps-*`/`me-*`/
  // `text-start` utility (and Tailwind's rtl:/ltr: variants) resolve
  // correctly. Neither Turkish nor English trigger dir="rtl" today —
  // this is purely the switch that makes a future RTL locale "just work."
  useEffect(() => {
    document.documentElement.dir = dir
    document.documentElement.lang = locale
  }, [dir, locale])

  return <Outlet />
}
```

```tsx
// Tailwind v4's rtl:/ltr: variants are for the rare case where a property
// genuinely has no logical equivalent, or where the mirrored behavior is
// more than a simple start/end flip (e.g. a custom transform or shadow
// direction). Prefer logical properties first; reach for rtl:/ltr: second.
<div className="shadow-[4px_0_8px_rgba(0,0,0,0.1)] rtl:shadow-[-4px_0_8px_rgba(0,0,0,0.1)]">
  {/* drop shadow direction has no "logical" CSS equivalent */}
</div>
```

```tsx
// dir="auto" lets the BROWSER infer direction from the actual text content
// of a specific element — use it for user-generated or dynamic freeform
// text (a support ticket body, a comment) where the surrounding UI stays
// LTR/RTL per the app locale, but this one field's content might be in a
// different script than the interface itself.
<p dir="auto">{ticket.body}</p>
```

### Testing a layout in both directions before a real RTL locale exists

```tsx
// A dev-only toggle that force-sets dir="rtl" on the root element lets the
// team visually verify every screen under RTL BEFORE actually adding an
// Arabic/Hebrew locale — catching physical-property regressions early
// instead of discovering them all at once when locale #3 ships.
function DevRtlToggle() {
  if (!import.meta.env.DEV) return null
  return (
    <button onClick={() => document.documentElement.setAttribute(
      'dir',
      document.documentElement.dir === 'rtl' ? 'ltr' : 'rtl'
    )}>
      Toggle RTL (dev only)
    </button>
  )
}
```

### Icon mirroring rules

Not every directional icon should flip under RTL — the rule is whether the icon represents **reading/navigation direction** (which is direction-relative) or a **fixed real-world concept** (which is not).

| Icon | Mirror under RTL? | Why |
|---|---|---|
| Back arrow / breadcrumb chevron | Yes | Points toward "previous" in reading order, which flips with direction |
| Forward/next arrow, pagination chevrons | Yes | Same reasoning — "next" is direction-relative |
| Sidebar collapse/expand chevron | Yes | Points toward the edge of the screen content collapses into |
| Play button (media) | No | Universally understood as "play," not tied to reading direction |
| Undo/redo icons | Often no (convention-dependent) | Widely recognized as fixed symbols in most design systems; verify against the icon set's own guidance |
| Checkmark, warning triangle, info icon | No | Semantic status icons with no directional meaning |
| Clock/time icon | No | Not directional |
| External-link icon (arrow out of a box) | No — usually fixed | Represents "leaving," a spatial metaphor for a diagonal escape, not reading direction |

```tsx
// Tailwind's rtl: variant with a horizontal flip transform is the standard
// way to mirror an icon conditionally, keeping the mirroring decision
// visible right where the icon is used rather than in a separate config.
<ChevronRightIcon className="rtl:-scale-x-100" /> {/* mirrors: correct, it's a "next" chevron */}
<PlayIcon /> {/* no rtl: class: correct, play is not directional */}
```

## Why This Works

- **ICU MessageFormat is the shared format both FormatJS and Lingui compile down to**: pluralization, gender, and interpolation rules are expressed once per message key and resolved correctly per locale by the library's runtime, instead of each component hand-rolling `count === 1 ? 'order' : 'orders'` logic that doesn't generalize to languages with more plural categories.
- **Logical CSS properties resolve relative to the current writing mode, not a fixed screen edge**: the same `ps-6`/`text-start`/`border-s` utility class produces correct output whether the ambient `dir` is `ltr` or `rtl`, because the browser — not the developer — decides which physical edge "start" maps to.
- **Setting `dir` once on the document root cascades to every logical-property-based style beneath it**: this is why the discipline of "always use logical properties" pays off — flipping one attribute on `<html>` is enough to correctly mirror an entire application that was built with that discipline, versus requiring a line-by-line audit of an application that wasn't.
- **A dev-only RTL toggle turns "RTL-readiness" from an unverifiable claim into something the team actually observes**: without visually testing under `dir="rtl"` before a real RTL locale is required, physical-property regressions accumulate invisibly because neither Turkish nor English ever exercises that code path.

## Edge Cases & Pitfalls

### Common Mistakes

- **Hardcoding an English string "just for now" in a new component**: it never gets circled back to before shipping; wire every user-facing string through the i18n library from the component's first commit.
- **Using `text-left`/`text-right` Tailwind utilities out of habit** even after adopting logical properties elsewhere — these are easy to reach for from muscle memory and silently break RTL-readiness one component at a time.
- **Forgetting that numbers, dates, and currency need locale-aware formatting too, not just strings**: `Intl.NumberFormat`/`FormattedNumber`/`FormattedDate` (part of both FormatJS and the underlying `Intl` API) handle thousands separators, decimal marks, and date ordering that differ between Turkish and English conventions — don't hand-format these with template literals.
- **Mirroring an icon that shouldn't be mirrored** (or vice versa) out of a blanket "flip everything in RTL" instinct — apply the reading-direction-vs-fixed-concept test from the table above per icon, not as a global rule.
- **Testing RTL-readiness only by eyeballing a Figma mockup** instead of actually toggling `dir="rtl"` in the running app — many logical-property gaps (an inline SVG with hardcoded `x` coordinates, a manually positioned tooltip) only surface when the real browser layout engine mirrors the page.
- **Setting `dir="rtl"` on individual components instead of the document root**: nested, inconsistent `dir` attributes create direction "islands" that are far harder to reason about than one root-level setting that the whole logical-property system is designed around.
- **Using `dir="auto"` on interface chrome (buttons, labels, nav) instead of only on freeform user content**: `dir="auto"` is for text whose script the app doesn't control ahead of time; applying it to fixed UI strings defeats the deliberate, locale-driven `dir` set at the root.

## Verification

```bash
# FormatJS: confirm every extracted message id in en.json has a
# corresponding key in tr.json (a missing key falls back to English,
# which should be a deliberate interim state, not an unnoticed gap)
node -e "
const en = require('./src/locales/en.json');
const tr = require('./src/locales/tr.json');
const missing = Object.keys(en).filter((k) => !(k in tr));
if (missing.length) { console.log('Missing tr.json keys:', missing); process.exit(1); }
"
```

- [ ] Grep component source for quoted English literal text inside JSX that isn't wrapped in a `FormattedMessage`/`t()` call.
- [ ] Switch the app's locale to Turkish and visually confirm every screen — no leftover English strings, no truncated layout from longer Turkish text.
- [ ] Toggle the dev-only RTL flag and click through the primary flows — confirm spacing, borders, and text alignment all mirror correctly with no leftover left/right artifacts.
- [ ] Confirm directional icons (chevrons, back arrows) mirror under RTL and non-directional icons (play, checkmark) do not.
- [ ] Verify a pluralized string (e.g. "N orders selected") renders correctly for 0, 1, and multiple counts in both locales.
- [ ] Confirm dates/numbers/currency render via `Intl`/`FormattedNumber`/`FormattedDate`, not manual string formatting.

## References

- [FormatJS - react-intl](https://formatjs.io/docs/react-intl/)
- [FormatJS - Message Extraction](https://formatjs.io/docs/getting-started/message-extraction/)
- [ICU MessageFormat Syntax](https://formatjs.io/docs/core-concepts/icu-syntax/)
- [Lingui](https://lingui.dev/)
- [MDN - CSS Logical Properties](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_logical_properties_and_values)
- [Tailwind CSS - RTL Support](https://tailwindcss.com/docs/hover-focus-and-other-states#rtl-support)
- [W3C - Structural markup and RTL text (dir attribute)](https://www.w3.org/International/questions/qa-html-dir)
