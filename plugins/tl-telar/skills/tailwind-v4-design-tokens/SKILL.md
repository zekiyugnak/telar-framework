---
name: "tailwind-v4-design-tokens"
description: "Tailwind CSS v4 moved theme configuration out of `tailwind.config.js` and into your CSS file itself, via the `@theme` directive. Tokens declared there become both Tailwind utility classes (`bg-primary`) and real, runtime"
source_type: "skill"
source_file: "skills/tailwind-v4-design-tokens.md"
---

# tailwind-v4-design-tokens

Migrated from `skills/tailwind-v4-design-tokens.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Define Design Tokens with Tailwind v4's CSS-First `@theme`

Tailwind CSS v4 moved theme configuration out of `tailwind.config.js` and into your CSS file itself, via the `@theme` directive. Tokens declared there become both Tailwind utility classes (`bg-primary`) and real, runtime-readable CSS custom properties (`var(--color-primary)`) in the same declaration. Projects that keep authoring theme values the v3 way — a JS object, plus a separate set of CSS variables for shadcn theming — end up with two sources of truth that drift apart, and projects that copy an old `globals.css` verbatim break outright, because the v3 `@tailwind base/components/utilities` directives are gone.

## Problem

```javascript
// BAD (v3 mental model): design tokens defined in JS, disconnected
// from the CSS custom properties shadcn's components already expect
// in globals.css. Two files now have to be kept in sync by hand.
// tailwind.config.js
module.exports = {
  content: ['./app/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: '#0f172a',
        'primary-foreground': '#f8fafc',
      },
      screens: {
        '3xl': '1920px',
      },
    },
  },
}
```

```css
/* BAD (v3 entry point): these three directives are removed in v4.
   A stylesheet copy-pasted from an older project produces no error
   in some setups but silently generates none of Tailwind's utilities,
   leaving every className a no-op. */
@tailwind base;
@tailwind components;
@tailwind utilities;
```

## Solution

### CSS-first token definitions with `@theme`

```css
/* app/globals.css — Tailwind v4 entry point */
@import "tailwindcss";

/* @theme defines design tokens as real CSS custom properties. Every
   token here becomes both a Tailwind utility (bg-primary, text-primary)
   AND a runtime CSS variable (var(--color-primary)) usable outside
   Tailwind entirely — e.g. in an inline style or a <canvas> chart. */
@theme {
  --color-primary: oklch(0.205 0 0);
  --color-primary-foreground: oklch(0.985 0 0);
  --color-success: oklch(0.72 0.19 149);
  --breakpoint-3xl: 1920px;
  --font-sans: 'Inter', ui-sans-serif, system-ui;
  --radius-md: 0.5rem;
}
```

There is no separate build step or config file to keep in sync — the token declaration and the CSS variable are the same line. `content` path scanning is automatic in v4 for most project layouts; use `@source` only when you need to explicitly include files outside the auto-detected scope (e.g. a shared UI package outside the app directory).

```css
/* Only needed if Tailwind's automatic content detection misses a
   directory, e.g. a sibling workspace package */
@source "../../packages/ui/src/**/*.{ts,tsx}";
```

### Native `oklch` colors

```css
:root {
  /* oklch(lightness chroma hue) is perceptually uniform — increasing
     lightness by a fixed step looks like a consistent step across
     every hue, unlike hex/hsl where the same delta looks different
     per color. This is what makes generating a whole light/dark
     palette from a handful of base tones predictable. */
  --background: oklch(1 0 0);
  --foreground: oklch(0.145 0 0);
  --destructive: oklch(0.577 0.245 27.325);
}
```

### Container queries, built in

```tsx
// A stats grid that reflows based on the width of its own container —
// not the viewport — which matters inside a resizable dashboard
// sidebar or a card that can be dropped into different-width slots.
// No @tailwindcss/container-queries plugin needed; @container and the
// @sm/@md/@xl variants ship with the core in v4.
export function StatsGrid() {
  return (
    <div className="@container">
      <div className="grid grid-cols-1 gap-4 @md:grid-cols-2 @xl:grid-cols-4">
        <StatCard label="MRR" value="$42,300" />
        <StatCard label="Active companies" value="128" />
        <StatCard label="Open invoices" value="17" />
        <StatCard label="Churn" value="1.2%" />
      </div>
    </div>
  )
}
```

### How this interacts with shadcn's theming

shadcn's generated `globals.css` uses a two-layer token system that composes naturally with `@theme`:

```css
/* Layer 1: raw palette values, swapped per color scheme */
:root {
  --background: oklch(1 0 0);
  --primary: oklch(0.205 0 0);
}
.dark {
  --background: oklch(0.145 0 0);
  --primary: oklch(0.922 0 0);
}

/* Layer 2: semantic aliases that Tailwind utilities are generated
   from. Components use bg-background/bg-primary; only the raw
   palette layer changes between :root and .dark, so no component
   or utility class needs to know a theme switch happened. */
@theme inline {
  --color-background: var(--background);
  --color-primary: var(--primary);
}
```

This indirection — `--color-primary` (theme layer) pointing at `--primary` (palette layer) — is why toggling the `.dark` class on `<html>` re-themes the entire app without regenerating any Tailwind utility classes.

## Why This Works

- **One declaration, two consumers**: because `@theme` tokens are plain CSS custom properties, the same value is readable by Tailwind's utility generator and by arbitrary runtime code (charts, canvas, third-party widgets that accept a color prop) — no manual JS/CSS sync step.
- **`oklch` is perceptually uniform**: lightness/chroma/hue steps translate to consistent visual steps across hues, which is why v4's default palette and shadcn's generated tokens both use it instead of hex or hsl.
- **Native content detection removes a stale-config failure mode**: v3 projects commonly broke because a new file glob wasn't added to `content`; v4's automatic scanning removes that entire class of "my new component's classes aren't generating" bug for standard project layouts.
- **Container queries answer a different question than media queries**: `@md:` responds to the nearest `@container` ancestor's width, which is what you want for a component that can be embedded in variable-width layout slots (a dashboard widget, a sidebar card) — a plain `md:` breakpoint only knows the viewport width.

## Edge Cases & Pitfalls

### Migration Gotchas (v3 → v4)

- **`@tailwind base/components/utilities` are gone.** Replace all three with a single `@import "tailwindcss";`. A stylesheet that still has the old directives will not generate Tailwind's utilities in v4.
- **Default border and ring colors changed.** v3 defaulted unstyled borders/rings to a gray/blue shade; v4 defaults to `currentColor`. A `border` or `ring` utility with no explicit color that "just worked" in v3 can render invisible or unexpectedly colored after migrating — audit every bare `border`/`ring` usage.
- **Some utilities were renamed or restructured** (for example, outline-suppression behavior changed shape between versions). Don't assume a utility that compiled cleanly kept its exact old visual meaning — spot-check focus rings and outlines specifically, since they're easy to miss visually in a quick pass.
- **`tailwind.config.js` is now optional, not required.** If a project keeps one for plugin registration, know that `theme.extend` values there do not automatically sync with `@theme` CSS tokens — pick one system as the source of truth for a given token category rather than splitting colors across both.
- **Verify against the official upgrade guide before shipping a migration.** Point-release behavior for edge cases (variant stacking order, specific deprecated utility names) is exactly the kind of detail that changes between minor versions — treat this list as "what to check," not an exhaustive diff.

### Common Mistakes

- Defining the same color both in a lingering `tailwind.config.js` `theme.extend.colors` block and in `@theme` — the two can silently disagree, and which one "wins" depends on load order most developers don't reason about correctly.
- Hardcoding a hex value directly in a component (`className="bg-[#0f172a]"`) instead of adding it to `@theme` once — defeats the entire point of a token system and makes a future rebrand a grep-and-replace across every file instead of a one-line CSS edit.
- Using `@md:` (a container-query variant) when a plain `md:` (viewport variant) was intended, or vice versa — they look nearly identical in code but respond to different measurements, producing layouts that work in isolation but break once nested inside another container.

## Verification

```bash
# Confirm the v4 entry point is present and old directives are gone
grep -n '@import "tailwindcss"' app/globals.css
grep -n '@tailwind ' app/globals.css   # should return nothing

# Build and check that expected utility classes are actually generated
next build
```

- [ ] `globals.css` uses `@import "tailwindcss";` with no leftover `@tailwind base/components/utilities` lines
- [ ] Every color/spacing/font token used across the app is declared once in `@theme` (or shadcn's `:root`/`.dark` + `@theme inline` pair), not duplicated in a JS config
- [ ] Bare `border`/`ring` utilities render the expected color after migration, not `currentColor`'s unexpected result
- [ ] Dark mode toggle re-themes the whole app without any component code change
- [ ] A `@container`-based responsive component reflows correctly when nested inside a narrower parent, independent of viewport width

## References

- [Tailwind CSS v4 Documentation](https://tailwindcss.com/docs)
- [Tailwind CSS v4 Upgrade Guide](https://tailwindcss.com/docs/upgrade-guide)
- [Tailwind CSS Theme Variables (`@theme`)](https://tailwindcss.com/docs/theme)
- [Tailwind CSS Container Queries](https://tailwindcss.com/docs/responsive-design#container-queries)
- [shadcn/ui Theming](https://ui.shadcn.com/docs/theming)
