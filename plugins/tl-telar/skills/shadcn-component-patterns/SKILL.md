---
name: "shadcn-component-patterns"
description: "shadcn/ui is not an npm UI library — it is a CLI that copies component source directly into your repository, built on top of Radix UI primitives for behavior and Tailwind CSS for styling. Treating it like a package (impo"
source_type: "skill"
source_file: "skills/shadcn-component-patterns.md"
---

# shadcn-component-patterns

Migrated from `skills/shadcn-component-patterns.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Compose shadcn/ui Primitives Instead of Hand-Rolling Interactive Components

shadcn/ui is not an npm UI library — it is a CLI that copies component source directly into your repository, built on top of Radix UI primitives for behavior and Tailwind CSS for styling. Treating it like a package (importing from `node_modules`, or reimplementing its components from scratch with raw `div`s and `onClick`) throws away the accessibility and interaction-state work Radix already solved, and produces inconsistent variant styling. This skill covers the CLI ownership model, composing primitives correctly, `cn()` + `cva` for variants, CSS-variable theming, building a compound component, and dark mode.

## Problem

Developers new to shadcn/ui often do one of two things wrong: they try to `npm install shadcn-ui` and import components as a black-box package (there is no such importable package — components are generated into your own `components/ui` folder), or they avoid shadcn entirely and hand-roll interactive widgets with plain elements and manual event listeners, missing focus trapping, keyboard navigation, and correct ARIA roles/states.

```tsx
// BAD: Hand-rolled dropdown. No focus trap, no Escape-to-close, no
// arrow-key navigation, no role/aria-expanded — a screen reader user
// cannot tell this is a menu, and a keyboard-only user cannot open it.
function CustomDropdown({ items }: { items: string[] }) {
  const [open, setOpen] = useState(false)
  return (
    <div className="relative">
      <button onClick={() => setOpen(!open)}>Menu</button>
      {open && (
        <div
          className="absolute left-0 top-full bg-white shadow"
          onMouseLeave={() => setOpen(false)}
        >
          {items.map((item) => (
            <div key={item} onClick={() => setOpen(false)}>
              {item}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
```

```tsx
// BAD: Ad-hoc variant styling with string concatenation. "danger" and
// "size-lg" classes can silently conflict (e.g. two different px-*
// classes both landing in the DOM), and there is no single place that
// documents what variants exist.
function Button({ variant, size, className, ...props }: ButtonProps) {
  const variantClass = variant === 'danger' ? 'bg-red-600 text-white' : 'bg-slate-900 text-white'
  const sizeClass = size === 'lg' ? 'px-6 py-3 text-lg' : 'px-4 py-2 text-sm'
  return <button className={`${variantClass} ${sizeClass} ${className}`} {...props} />
}
```

## Solution

### Generate components with the CLI — you own the source

```bash
# Components are written directly into components/ui/*.tsx in your repo.
# There is nothing to update in package.json for the component itself —
# only its underlying Radix dependency (e.g. @radix-ui/react-dropdown-menu).
npx shadcn@latest add button dropdown-menu input table form
```

### Compose the generated primitive correctly

```tsx
// components/ui/dropdown-menu.tsx (CLI-generated — a thin, typed wrapper
// over Radix's DropdownMenu. Edit it if you need to diverge from the
// default styling, but understand you are now maintaining that diff.)
'use client'

import * as DropdownMenuPrimitive from '@radix-ui/react-dropdown-menu'
import { cn } from '@/lib/utils'

function DropdownMenuContent({
  className,
  sideOffset = 4,
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.Content>) {
  return (
    <DropdownMenuPrimitive.Portal>
      <DropdownMenuPrimitive.Content
        data-slot="dropdown-menu-content"
        sideOffset={sideOffset}
        className={cn(
          'z-50 min-w-[8rem] rounded-md border bg-popover p-1 text-popover-foreground shadow-md',
          'data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0',
          className
        )}
        {...props}
      />
    </DropdownMenuPrimitive.Portal>
  )
}

export { DropdownMenuContent }
```

Radix handles focus trapping inside the content, closes on `Escape` and outside click, moves focus with arrow keys, and sets `role="menu"`/`aria-expanded` on the trigger automatically. Your job is composition and styling, not reimplementing interaction state machines.

### `cn()` + `cva` for deterministic variant styling

```typescript
// lib/utils.ts
import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'

// clsx composes conditional class names; twMerge resolves conflicting
// Tailwind utilities (e.g. "px-2 ... px-4" collapses to "px-4") so the
// last class applied always wins deterministically, instead of both
// classes landing in the DOM and depending on CSS source order.
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
```

```typescript
// components/ui/badge.tsx
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '@/lib/utils'

const badgeVariants = cva(
  'inline-flex items-center rounded-md border px-2 py-0.5 text-xs font-medium transition-colors',
  {
    variants: {
      variant: {
        default: 'border-transparent bg-primary text-primary-foreground',
        outline: 'border-border text-foreground',
        destructive: 'border-transparent bg-destructive text-destructive-foreground',
        success: 'border-transparent bg-emerald-600 text-white',
      },
    },
    defaultVariants: { variant: 'default' },
  }
)

interface BadgeProps
  extends React.HTMLAttributes<HTMLSpanElement>,
    VariantProps<typeof badgeVariants> {}

export function Badge({ className, variant, ...props }: BadgeProps) {
  return (
    <span data-slot="badge" className={cn(badgeVariants({ variant }), className)} {...props} />
  )
}

// Usage: <Badge variant="success">Paid</Badge>
```

`cva` centralizes every variant/size combination in one declaration next to the component, so "what variants exist" is answerable by reading one file instead of grepping for string concatenation across the codebase.

### Theming via CSS variables

```css
/* app/globals.css */
@import "tailwindcss";

/* @theme inline maps semantic Tailwind utility names (bg-primary,
   text-primary-foreground) to the raw palette values defined below.
   Components never hardcode colors; they use the semantic classes,
   so swapping :root/.dark values re-themes the whole app. */
@theme inline {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-primary: var(--primary);
  --color-primary-foreground: var(--primary-foreground);
  --color-destructive: var(--destructive);
  --radius-md: var(--radius);
}

:root {
  --background: oklch(1 0 0);
  --foreground: oklch(0.145 0 0);
  --primary: oklch(0.205 0 0);
  --primary-foreground: oklch(0.985 0 0);
  --destructive: oklch(0.577 0.245 27.325);
  --radius: 0.5rem;
}

.dark {
  --background: oklch(0.145 0 0);
  --foreground: oklch(0.985 0 0);
  --primary: oklch(0.922 0 0);
  --primary-foreground: oklch(0.205 0 0);
  --destructive: oklch(0.704 0.191 22.216);
}
```

Every shadcn primitive is generated with a `data-slot="..."` attribute (e.g. `data-slot="dropdown-menu-content"`). Use these as stable hooks for targeted CSS overrides or tests instead of relying on generated class name order, which can shift between shadcn CLI versions.

### Building a compound component: a data table toolbar

```tsx
// components/dashboard/invoices-toolbar.tsx
'use client'

import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuCheckboxItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { SlidersHorizontal, Plus } from 'lucide-react'
import type { Table } from '@tanstack/react-table'
import type { Invoice } from '@/lib/types'

interface InvoicesToolbarProps {
  table: Table<Invoice>
  onCreate: () => void
}

// A compound component: each shadcn primitive keeps its own internal
// state (open/closed, focus, ARIA roles) while this component only
// owns the domain state — the table's filter value and column visibility.
export function InvoicesToolbar({ table, onCreate }: InvoicesToolbarProps) {
  return (
    <div className="flex items-center justify-between gap-2 py-4">
      <Input
        placeholder="Filter by customer..."
        value={(table.getColumn('customerName')?.getFilterValue() as string) ?? ''}
        onChange={(event) => table.getColumn('customerName')?.setFilterValue(event.target.value)}
        className="max-w-sm"
      />
      <div className="flex items-center gap-2">
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="outline" size="sm">
              <SlidersHorizontal className="mr-2 size-4" />
              Columns
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            {table
              .getAllColumns()
              .filter((column) => column.getCanHide())
              .map((column) => (
                <DropdownMenuCheckboxItem
                  key={column.id}
                  className="capitalize"
                  checked={column.getIsVisible()}
                  onCheckedChange={(value) => column.toggleVisibility(!!value)}
                >
                  {column.id}
                </DropdownMenuCheckboxItem>
              ))}
          </DropdownMenuContent>
        </DropdownMenu>
        <Button size="sm" onClick={onCreate}>
          <Plus className="mr-2 size-4" />
          New invoice
        </Button>
      </div>
    </div>
  )
}
```

### Dark mode toggle

```tsx
// components/theme-toggle.tsx
'use client'

import { useTheme } from 'next-themes'
import { Button } from '@/components/ui/button'
import { Moon, Sun } from 'lucide-react'

export function ThemeToggle() {
  const { resolvedTheme, setTheme } = useTheme()
  return (
    <Button
      variant="ghost"
      size="icon"
      aria-label="Toggle theme"
      onClick={() => setTheme(resolvedTheme === 'dark' ? 'light' : 'dark')}
    >
      {resolvedTheme === 'dark' ? <Sun className="size-4" /> : <Moon className="size-4" />}
    </Button>
  )
}
```

```tsx
// app/layout.tsx — wrap with next-themes' provider, suppress the
// unavoidable hydration warning caused by the theme class being set
// by an inline script before React hydrates
import { ThemeProvider } from 'next-themes'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body>
        <ThemeProvider attribute="class" defaultTheme="system" enableSystem>
          {children}
        </ThemeProvider>
      </body>
    </html>
  )
}
```

## Why This Works

- **Radix owns interaction state, you own visual state**: focus management, roving tabindex, `Escape`/outside-click dismissal, and ARIA role/state attributes are implemented and tested upstream in Radix. shadcn's generated wrapper only adds Tailwind classes on top — none of that behavior is reimplemented per project.
- **Copy-in-repo means no version lock-in**: because components live in your codebase, you can patch one component's behavior without waiting on an upstream release or fighting a library's override API. The tradeoff is you also inherit responsibility for keeping it in sync with security/accessibility fixes upstream.
- **`cva` variants are statically discoverable**: TypeScript's `VariantProps<typeof x>` gives autocomplete for every valid variant/size combination, catching typos (`variant="danger"` when only `"destructive"` exists) at compile time instead of silently rendering unstyled.
- **CSS variables make theming a data problem, not a component problem**: because `bg-primary` resolves to `var(--color-primary)` which resolves to a value set on `:root`/`.dark`, dark mode and future brand re-themes never require touching component source.

## Edge Cases & Pitfalls

### Accessibility Boundaries

**What Radix already covers:**
- Keyboard navigation, focus trap, and dismissal for Dialog, DropdownMenu, Select, Popover, and Tooltip
- Correct `role`, `aria-expanded`, `aria-controls`, and `aria-selected` wiring on interactive primitives

**What you must still add yourself:**
- `aria-label` on icon-only buttons (Radix has no way to infer what an icon means)
- `alt` text on images and meaningful `aria-describedby` links for form error messages
- Logical heading order (`h1` → `h2` → `h3`) — Radix components don't know your page's document outline
- Sufficient color contrast for custom variant colors you add to `cva` — Radix guarantees interaction semantics, not your chosen palette's contrast ratio

### Common Mistakes

- Overriding a shadcn component's className without using `cn()`/`twMerge`, causing two conflicting Tailwind classes (e.g. two different `bg-*` utilities) to both end up in the DOM with unpredictable precedence.
- Rendering `DropdownMenuContent`/`DialogContent` (both portal-rendered) inside a parent with `overflow: hidden` or a lower `z-index` stacking context, clipping or hiding the popover unexpectedly — portals escape the DOM tree but not always the *visual* expectations of nested layouts.
- Editing a CLI-generated file in `components/ui/` and then re-running `npx shadcn@latest add <same-component>`, silently overwriting local customizations. Diff before overwriting, or track these files closely in code review.
- Forgetting `suppressHydrationWarning` on `<html>` when using `next-themes`, producing a console warning (and a visible flash) because the theme class is applied by an inline script before React hydrates.

## Verification

```bash
# List installed shadcn components and their Radix dependencies
cat components.json
grep '@radix-ui' package.json

# Type-check to catch invalid cva variant usage
tsc --noEmit
```

- [ ] Tab through a Dialog/DropdownMenu using only the keyboard — focus should trap inside and `Escape` should close it
- [ ] Run an automated a11y check (e.g. axe DevTools) on a page using these components — failures should point to your custom markup, not the primitives
- [ ] Toggle dark mode and confirm no flash-of-wrong-theme on initial page load
- [ ] Resize the browser to trigger a Dialog/DropdownMenu near a viewport edge — content should reposition, not clip
- [ ] Override a component's `className` with a conflicting utility and confirm `cn()` resolves to the expected single class

## References

- [shadcn/ui Documentation](https://ui.shadcn.com/docs)
- [shadcn/ui CLI](https://ui.shadcn.com/docs/cli)
- [shadcn/ui Theming](https://ui.shadcn.com/docs/theming)
- [Radix UI Primitives](https://www.radix-ui.com/primitives/docs/overview/introduction)
- [class-variance-authority](https://cva.style/docs)
- [tailwind-merge](https://github.com/dcastil/tailwind-merge)
