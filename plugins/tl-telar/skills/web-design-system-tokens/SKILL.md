---
name: "web-design-system-tokens"
description: "A single MASTER token source, authored once, that generates Tailwind v4 `@theme` tokens + shadcn `:root`/`.dark` CSS custom properties for every web surface **and** Flutter-consumable Dart from the same file. Mirrors the"
source_type: "skill"
source_file: "skills/web-design-system-tokens.md"
---

# web-design-system-tokens

Migrated from `skills/web-design-system-tokens.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Web Design System Tokens

A single MASTER token source, authored once, that generates Tailwind v4 `@theme` tokens + shadcn `:root`/`.dark` CSS custom properties for every web surface **and** Flutter-consumable Dart from the same file. Mirrors the mobile `design-system-persistence` skill (global MASTER + per-screen overrides) for the web + cross-platform world.

## Problem

Design decisions drift across surfaces. A brand blue is re-typed as `#2563eb` in the Astro marketing site, `bg-[#2563eb]` in the Vite/TanStack client, and a slightly different `#2563ea` in the admin panel — then diverges again in the Flutter apps. Dark mode is bolted on per surface by hand. Whitelabel verticals fork the whole palette "to be safe." Six months later a rebrand is a multi-day grep across four codebases, and no two surfaces render the same blue. Tailwind v4 makes this worse if tokens live in a lingering `tailwind.config.js` *and* in shadcn's CSS variables — two sources that silently disagree.

```tsx
// BAD: the same brand color, re-entered as magic values, per surface.
// A rebrand touches every file; the surfaces already disagree.
// src/web/Hero.astro           →  style="background:#2563eb"
// src/client-web/Cta.tsx        →  <button className="bg-[#2563eb]">
// src/admin/Toolbar.tsx         →  <div style={{ background: '#2563ea' }}>  // typo, now permanent
```

## Solution

### 1. MASTER — the single token source

Author one file, `src/shared/design-tokens/tokens.json`. It is brand- and platform-neutral, the only hand-edited token file, and the source both web CSS and Flutter Dart are generated from.

```jsonc
// src/shared/design-tokens/tokens.json — MASTER
{
  // Layer 1 — PRIMITIVES: the raw scale. Never referenced by components.
  "primitive": {
    "color": {
      "blue-500": "oklch(0.55 0.20 255)",
      "blue-600": "oklch(0.48 0.20 255)",
      "gray-0":   "oklch(1 0 0)",
      "gray-100": "oklch(0.97 0 0)",
      "gray-500": "oklch(0.55 0 0)",
      "gray-900": "oklch(0.22 0 0)",
      "gray-950": "oklch(0.15 0 0)",
      "red-500":  "oklch(0.58 0.24 27)"
    },
    "space":  { "1": "0.25rem", "2": "0.5rem", "3": "0.75rem", "4": "1rem", "6": "1.5rem", "8": "2rem" },
    "radius": { "sm": "0.375rem", "md": "0.5rem", "lg": "0.75rem", "full": "9999px" },
    "font":   { "sans": "'Inter', ui-sans-serif, system-ui, sans-serif" }
  },
  // Layer 2 — SEMANTICS: role → {light, dark} references into primitives.
  // This is the ONLY layer components (and Flutter) bind to.
  "semantic": {
    "background":            { "light": "gray-0",   "dark": "gray-950" },
    "foreground":            { "light": "gray-900", "dark": "gray-100" },
    "muted":                 { "light": "gray-100", "dark": "gray-900" },
    "muted-foreground":      { "light": "gray-500", "dark": "gray-500" },
    "primary":               { "light": "blue-600", "dark": "blue-500" },
    "primary-foreground":    { "light": "gray-0",   "dark": "gray-0" },
    "destructive":           { "light": "red-500",  "dark": "red-500" },
    "destructive-foreground":{ "light": "gray-0",   "dark": "gray-0" },
    "border":                { "light": "gray-100", "dark": "gray-900" }
  }
}
```

### 2. Semantic layering — the reference rule

```text
primitive  (blue-600, gray-950, space-4)   ← raw scale, brand-neutral, private to the source
    │  referenced only by ↓          (never by a component)
semantic   (primary, background, muted-foreground, border)   ← the public API components use
    │  referenced only by ↓
component  (button-x-pad, card-radius)   ← ONLY when genuinely component-specific AND reused
```

References only ever point downward. A component uses `bg-primary`; `--primary` points at a primitive; the primitive points at nothing. A component that reaches straight to a primitive (`bg-blue-600`) has opted out of dark mode and every vertical — that is the failure this layering exists to prevent.

### 3. Generated web CSS — Tailwind v4 `@theme` + `:root`/`.dark`

Codegen emits `generated/tokens.css` in shadcn's two-layer shape: raw palette values in `:root`/`.dark`, semantic aliases in `@theme inline` that Tailwind turns into utilities.

```css
/* src/shared/design-tokens/generated/tokens.css — GENERATED, do not hand-edit */

/* Layer: @theme inline maps semantic Tailwind utilities (bg-primary,
   text-muted-foreground) to the palette variables below. Because it is
   `inline`, the utilities resolve to var(--x) at runtime — so a :root→.dark
   swap re-themes every utility with no regeneration and no component change. */
@theme inline {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-muted: var(--muted);
  --color-muted-foreground: var(--muted-foreground);
  --color-primary: var(--primary);
  --color-primary-foreground: var(--primary-foreground);
  --color-destructive: var(--destructive);
  --color-border: var(--border);
  --radius-sm: 0.375rem;
  --radius-md: 0.5rem;
  --radius-lg: 0.75rem;
  --font-sans: 'Inter', ui-sans-serif, system-ui, sans-serif;
}

/* Palette layer — light. Raw values, resolved from the MASTER semantics. */
:root {
  --background: oklch(1 0 0);
  --foreground: oklch(0.22 0 0);
  --muted: oklch(0.97 0 0);
  --muted-foreground: oklch(0.55 0 0);
  --primary: oklch(0.48 0.20 255);
  --primary-foreground: oklch(1 0 0);
  --destructive: oklch(0.58 0.24 27);
  --border: oklch(0.97 0 0);
}

/* Palette layer — dark. Explicit values, NOT computed from light. */
.dark {
  --background: oklch(0.15 0 0);
  --foreground: oklch(0.97 0 0);
  --muted: oklch(0.22 0 0);
  --muted-foreground: oklch(0.55 0 0);
  --primary: oklch(0.55 0.20 255);
  --primary-foreground: oklch(1 0 0);
  --destructive: oklch(0.58 0.24 27);
  --border: oklch(0.22 0 0);
}
```

Each surface's entry stylesheet is then just:

```css
/* src/web/styles.css · src/client-web/index.css · src/admin/index.css — identical */
@import "tailwindcss";
@import "../../shared/design-tokens/generated/tokens.css";
```

Components across all three surfaces bind to semantic utilities only:

```tsx
// One shadcn-style button, identical in marketing/client/admin. It names
// roles, so it inherits scheme AND vertical without knowing either exists.
export function PrimaryCta({ children }: { children: React.ReactNode }) {
  return (
    <button className="rounded-md bg-primary px-4 py-2 text-primary-foreground hover:bg-primary/90">
      {children}
    </button>
  )
}
```

### 4. Per-surface and per-vertical overrides — deltas, not forks

An override file sets **only** the palette variables it changes and is loaded **after** the base. The CSS cascade merges them; there is no JS merge and no forked palette.

```css
/* src/shared/design-tokens/overrides/surface-admin.css
   Admin is a dense data UI — tighter radius only. Everything else inherited. */
[data-surface="admin"] {
  --radius-md: 0.375rem;
  --radius-lg: 0.5rem;
}

/* src/shared/design-tokens/verticals/expat.css & gastro.css
   Whitelabel brands. Each sets ONLY the accent it owns — no semantic aliases,
   no component code. Scoped by [data-vertical] so one <html> attribute
   re-brands the whole app at runtime with zero rebuild. */
[data-vertical="expat"]      { --primary: oklch(0.52 0.17 255); --primary-foreground: oklch(1 0 0); }
[data-vertical="expat"].dark { --primary: oklch(0.62 0.17 255); }
[data-vertical="gastro"]      { --primary: oklch(0.62 0.18 35); --primary-foreground: oklch(0.15 0 0); }
[data-vertical="gastro"].dark { --primary: oklch(0.70 0.18 35); }
```

```html
<!-- Each surface's root layout stamps the active surface + vertical + scheme.
     talent-portal routes /expat/* and /gastro/* set data-vertical here. -->
<html data-surface="admin" data-vertical="gastro" class="dark">
```

### 5. Override precedence

```text
Lowest → highest (each layer overrides only its own delta; cascade resolves it):
  1. base palette      :root / .dark              (from tokens.json)
  2. surface override  [data-surface="admin"]     (e.g. denser radius)
  3. vertical override [data-vertical="gastro"]   (brand accent)
  4. scheme            .dark                       (orthogonal — combines with 1–3)

Resolution is pure CSS specificity + source order — no runtime recompute.
`[data-vertical="gastro"].dark` (two selectors) beats `.dark` (one), so a
vertical's dark accent wins over the base dark palette, exactly as intended.
```

### 6. Single source → generate web + Flutter (codegen)

The same `tokens.json` is projected into both the web CSS above and a Flutter Dart file. Because both are projections of one object, they cannot drift. A build-time contrast gate runs before anything is written.

```ts
// src/shared/design-tokens/generate.ts  (pnpm --filter @app/design-tokens tokens:build)
import tokens from './tokens.json' assert { type: 'json' }
import { writeFileSync } from 'node:fs'
import { contrastRatio } from './contrast'

const { primitive: prim, semantic: sem } = tokens
const ref = (n: string) => (prim.color as Record<string, string>)[n] ?? n

// --- Contrast gate: fail the BUILD, not a later audit ---
const AA_NORMAL = 4.5
for (const scheme of ['light', 'dark'] as const) {
  const pairs: [string, string][] = [
    [sem.foreground[scheme], sem.background[scheme]],
    [sem['primary-foreground'][scheme], sem.primary[scheme]],
    [sem['destructive-foreground'][scheme], sem.destructive[scheme]],
  ]
  for (const [fg, bg] of pairs) {
    const r = contrastRatio(ref(fg), ref(bg))
    if (r < AA_NORMAL) throw new Error(`Contrast ${r.toFixed(2)}:1 < AA for ${fg}/${bg} (${scheme})`)
  }
}

// --- Web projection: :root/.dark palette + @theme inline aliases (see §3) ---
writeFileSync('generated/tokens.css', renderWebCss(prim, sem))

// --- Flutter projection: same semantic names as a Dart ColorScheme source ---
const camel = (k: string) => k.replace(/-([a-z])/g, (_, c) => c.toUpperCase())
const dart = (scheme: 'light' | 'dark') =>
  Object.entries(sem)
    .map(([k, v]) => `  static const ${camel(k)} = Color(0xFF${oklchToHex(ref(v[scheme]))});`)
    .join('\n')

writeFileSync('generated/app_tokens.dart', `// GENERATED — edit tokens.json, not this file
import 'package:flutter/material.dart';
abstract class AppTokensLight {
${dart('light')}
}
abstract class AppTokensDark {
${dart('dark')}
}
`)
```

The web surfaces `@import` `generated/tokens.css`; the Flutter apps import `generated/app_tokens.dart` and wire it into `ThemeData` (owned by `mobile-design-system-architect`). The MASTER stays the one place a cross-platform value is ever defined.

## Anti-Patterns

- **Two sources of truth**: leaving colors in a `tailwind.config.js` `theme.extend` block *and* in the generated CSS variables. In Tailwind v4 the two can silently disagree and load order decides the winner. Keep every token in the MASTER → generated CSS; the config, if kept at all, is for plugins only.
- **Forking the palette per surface**: shipping a full copy of every token for admin "to be safe." Two palettes drift the instant one is edited. Override only the delta in a `[data-surface]` file.
- **Computing dark from light at runtime**: `darken(light.primary, 0.3)` on toggle. A fixed lightness delta lands differently per hue and breaks contrast. Author explicit `.dark` values; let the contrast gate verify them.
- **Components referencing primitives**: `bg-blue-600` instead of `bg-primary`. Re-couples the component to a value and opts it out of scheme + vertical theming. Bind to semantic roles only.
- **Verticals redefining semantics or components**: a vertical file that re-declares `@theme inline` aliases or ships its own component variants. Verticals set palette variables only; the semantic layer and components stay shared.
- **Hardcoded arbitrary values**: `bg-[#2563eb]` / `style={{ color: '#...' }}`. Defeats the whole system and guarantees the surfaces disagree. Add it to the MASTER once.

## Verification

```bash
# 1. Regenerate from the single source; the contrast gate must pass (non-zero exit = a bad pair)
pnpm --filter @app/design-tokens tokens:build

# 2. No hardcoded colors bypassing tokens in surface code (should print nothing)
grep -rnE '#[0-9A-Fa-f]{3,8}|rgba?\(|bg-\[#|oklch\(' src/web src/client-web src/admin \
  --include='*.tsx' --include='*.astro' --include='*.css' | grep -v 'shared/design-tokens'

# 3. Every surface imports the generated CSS; no leftover v3 @tailwind directives
grep -rn 'shared/design-tokens/generated/tokens.css' src/web src/client-web src/admin
grep -rn '@tailwind ' src/web src/client-web src/admin      # must be empty (v4 uses @import)

# 4. Verticals set palette vars only — never semantic aliases or component code
grep -rn '@theme\|--color-' src/shared/design-tokens/verticals/   # must be empty
```

- [ ] `tokens.json` is the only hand-edited token file; `generated/*.css` and `generated/*.dart` are marked GENERATED
- [ ] Both light and dark values are declared explicitly for every semantic role (no runtime computation)
- [ ] `@theme inline` aliases point at `:root`/`.dark` palette variables; components use only semantic utilities
- [ ] Toggling `.dark` and switching `data-vertical` re-themes all three surfaces with zero component diffs
- [ ] Surface/vertical override files contain only the variables they change (deltas, not forks)
- [ ] Web CSS and Flutter Dart are both regenerated from the same source and agree on every shared value

## References

- [Tailwind CSS v4 `@theme` Theme Variables](https://tailwindcss.com/docs/theme)
- [Tailwind CSS v4 Upgrade Guide](https://tailwindcss.com/docs/upgrade-guide)
- [shadcn/ui Theming (CSS variables)](https://ui.shadcn.com/docs/theming)
- [oklch color model](https://developer.mozilla.org/en-US/docs/Web/CSS/color_value/oklch)
- Companion: `tailwind-v4-design-tokens` (v4 `@theme` mechanics), `shadcn-component-patterns` (consuming the theme in components), `design-system-persistence` (the mobile MASTER.md counterpart this mirrors)
