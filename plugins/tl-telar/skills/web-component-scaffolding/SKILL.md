---
name: "web-component-scaffolding"
description: "Scaffold production-quality React/TSX components from a spec with complete file structure, type safety, token-driven variants, accessibility, and test coverage — the web parity of `component-scaffolding`."
source_type: "skill"
source_file: "skills/web-component-scaffolding.md"
---

# web-component-scaffolding

Migrated from `skills/web-component-scaffolding.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Web Component Scaffolding

Scaffold production-quality React/TSX components from a spec with complete file structure, type safety, token-driven variants, accessibility, and test coverage — the web parity of `component-scaffolding`.

## Problem

Developers building web components from scratch waste time on repetitive boilerplate: typing prop interfaces, wiring `forwardRef`, assembling variant class logic, adding ARIA attributes, and writing test + story files. Without a standard pattern, each component is structured differently — some hand-roll variants with string concatenation, some skip `forwardRef` (breaking `asChild`/focus composition), some inline styles that bypass the theme — producing an inconsistent, hard-to-maintain codebase.

## Solution

### 1. File Structure Convention

Every component generates a directory with a predictable set of files:

```text
src/components/StatusBadge/
  StatusBadge.tsx          # Component implementation (forwardRef + cva)
  useStatusBadge.ts        # Optional hook for non-trivial logic
  StatusBadge.test.tsx     # Vitest + @testing-library + jest-axe
  StatusBadge.stories.tsx  # Optional Storybook story
  index.ts                 # Barrel export (component + prop types + variants)
```

Rules:
- **Presentational primitives** (badge, button, card) usually need no hook — the `cva` declaration is the logic.
- **Behavioral components** (a controllable disclosure, a debounced search field) split state/effects into `use<Name>.ts` so the `.tsx` stays declarative.
- Variants live in one `cva` declaration exported for reuse and typed via `VariantProps`.
- Style only with Tailwind **semantic tokens** (`bg-primary`, `text-muted-foreground`) — never inline styles or raw hex/px.

### 2. Component Template (presentational primitive)

```tsx
// StatusBadge/StatusBadge.tsx
import { forwardRef } from 'react'
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '@/lib/utils'

// One declaration is the single source of truth for every variant/size.
// Consumers get compile-time autocomplete via VariantProps below.
export const statusBadgeVariants = cva(
  'inline-flex items-center gap-1 rounded-md border font-medium transition-colors',
  {
    variants: {
      tone: {
        neutral: 'border-border bg-muted text-foreground',
        success: 'border-transparent bg-emerald-600 text-white',
        warning: 'border-transparent bg-amber-500 text-amber-950',
        danger: 'border-transparent bg-destructive text-destructive-foreground',
      },
      size: {
        sm: 'px-1.5 py-0.5 text-xs',
        md: 'px-2 py-0.5 text-sm',
      },
    },
    defaultVariants: { tone: 'neutral', size: 'md' },
  },
)

export interface StatusBadgeProps
  extends React.HTMLAttributes<HTMLSpanElement>,
    VariantProps<typeof statusBadgeVariants> {
  /** Visible label; also used as the accessible name via aria-label when children are icon-only. */
  label: string
  /** Optional leading icon (decorative — marked aria-hidden). */
  icon?: React.ReactNode
}

// forwardRef so parents can measure, focus-manage, or use `asChild` composition.
export const StatusBadge = forwardRef<HTMLSpanElement, StatusBadgeProps>(function StatusBadge(
  { label, icon, tone, size, className, ...props },
  ref,
) {
  return (
    <span
      ref={ref}
      // role="status" makes assistive tech announce state changes; the
      // label is the accessible name even when the icon carries the meaning.
      role="status"
      aria-label={label}
      className={cn(statusBadgeVariants({ tone, size }), className)}
      {...props}
    >
      {icon ? <span aria-hidden>{icon}</span> : null}
      <span>{label}</span>
    </span>
  )
})
```

### 3. Behavioral Component + Companion Hook

When a component owns state or effects, keep the `.tsx` declarative and put logic in a hook.

```tsx
// SearchField/SearchField.tsx
import { forwardRef } from 'react'
import { cn } from '@/lib/utils'
import { Input } from '@/components/ui/input'
import { useSearchField } from './useSearchField'

export interface SearchFieldProps {
  /** Accessible label (required — the field has no visible <label>). */
  label: string
  /** Placeholder text (already localized by the caller). */
  placeholder?: string
  /** Debounced change handler — fires ~300ms after the user stops typing. */
  onDebouncedChange: (value: string) => void
  defaultValue?: string
  className?: string
}

export const SearchField = forwardRef<HTMLInputElement, SearchFieldProps>(function SearchField(
  { label, placeholder, onDebouncedChange, defaultValue = '', className },
  ref,
) {
  const { value, handleChange } = useSearchField({ defaultValue, onDebouncedChange })
  return (
    <Input
      ref={ref}
      type="search"
      role="searchbox"
      aria-label={label}
      placeholder={placeholder}
      value={value}
      onChange={(e) => handleChange(e.target.value)}
      className={cn('max-w-sm', className)}
    />
  )
})
```

```tsx
// SearchField/useSearchField.ts
import { useCallback, useEffect, useRef, useState } from 'react'

interface Params {
  defaultValue: string
  onDebouncedChange: (value: string) => void
}

export function useSearchField({ defaultValue, onDebouncedChange }: Params) {
  const [value, setValue] = useState(defaultValue)
  const timer = useRef<ReturnType<typeof setTimeout>>()

  const handleChange = useCallback(
    (next: string) => {
      setValue(next)
      clearTimeout(timer.current)
      timer.current = setTimeout(() => onDebouncedChange(next), 300)
    },
    [onDebouncedChange],
  )

  // Clear the pending timer on unmount so we never call back after teardown.
  useEffect(() => () => clearTimeout(timer.current), [])

  return { value, handleChange }
}
```

### 4. Test Template (Vitest + @testing-library + jest-axe)

```tsx
// StatusBadge/StatusBadge.test.tsx
import { render, screen } from '@testing-library/react'
import { axe } from 'jest-axe'
import { StatusBadge } from './StatusBadge'

describe('StatusBadge', () => {
  it('renders its label', () => {
    render(<StatusBadge label="Active" tone="success" />)
    expect(screen.getByText('Active')).toBeInTheDocument()
  })

  it('exposes the label as the accessible name', () => {
    render(<StatusBadge label="Pending review" tone="warning" />)
    expect(screen.getByRole('status', { name: 'Pending review' })).toBeInTheDocument()
  })

  it('merges a caller className without dropping variant classes', () => {
    render(<StatusBadge label="X" tone="danger" className="ms-2" />)
    const el = screen.getByRole('status')
    expect(el).toHaveClass('ms-2')
    expect(el.className).toMatch(/bg-destructive/)
  })

  it.each(['neutral', 'success', 'warning', 'danger'] as const)('renders %s tone', (tone) => {
    render(<StatusBadge label={tone} tone={tone} />)
    expect(screen.getByText(tone)).toBeInTheDocument()
  })

  it('has no axe violations', async () => {
    const { container } = render(<StatusBadge label="Active" tone="success" />)
    expect(await axe(container)).toHaveNoViolations()
  })
})
```

### 5. Story Template (optional — Storybook)

```tsx
// StatusBadge/StatusBadge.stories.tsx
import type { Meta, StoryObj } from '@storybook/react'
import { StatusBadge } from './StatusBadge'

const meta: Meta<typeof StatusBadge> = {
  title: 'Components/StatusBadge',
  component: StatusBadge,
  argTypes: {
    tone: { control: 'select', options: ['neutral', 'success', 'warning', 'danger'] },
    size: { control: 'select', options: ['sm', 'md'] },
  },
}
export default meta

type Story = StoryObj<typeof StatusBadge>

export const Success: Story = { args: { label: 'Active', tone: 'success' } }
export const Warning: Story = { args: { label: 'Pending', tone: 'warning' } }
export const Danger: Story = { args: { label: 'Rejected', tone: 'danger' } }
export const Small: Story = { args: { label: 'New', tone: 'neutral', size: 'sm' } }
```

### 6. Barrel Export

```ts
// StatusBadge/index.ts
export { StatusBadge, statusBadgeVariants } from './StatusBadge'
export type { StatusBadgeProps } from './StatusBadge'
```

## Why This Works

Colocating component, hook, test, and story enforces separation of concerns at the file-system level: behavioral logic lives in the hook so the `.tsx` is declarative, variants live in one `cva` block so "what variants exist" is answerable by reading one file, and `forwardRef` keeps the component composable (`asChild`, focus management, measurement). Because styling flows through semantic Tailwind tokens, dark mode and re-theming never touch component source. Generating the test alongside the component means accessibility (`jest-axe`) and interaction coverage ship from day one instead of as an afterthought.

## Edge Cases

- **Compound components** (Accordion + AccordionItem): scaffold a shared React context in the directory and export the parts together; each part still lives in its own file.
- **Polymorphic / `asChild` components**: accept a Radix `Slot` and forward props/ref, so a `<Button asChild><a/></Button>` renders the anchor with the button's styling and behavior.
- **Controlled vs uncontrolled**: the hook accepts optional `value`/`onChange` and falls back to internal state when they are absent (like the SearchField pattern).
- **Server vs client components** (Next.js): mark the file `'use client'` only when it uses state, effects, or event handlers; keep pure presentational components as server components.
- **i18n**: components never hardcode display strings — accept already-localized text as props, or render `react-intl` inside if the component owns its copy.

## Verification

1. **TypeScript strict mode**: compiles under `strict: true` with no `any` and no non-null-assertion hacks — `npx tsc --noEmit`.
2. **No inline styles / raw values**: `grep -rn 'style={{' src/components/<Name>/` returns zero; no hardcoded hex/oklch or raw px — only semantic tokens.
3. **forwardRef where composed**: any component a parent may focus, measure, or use with `asChild` forwards its ref.
4. **Deterministic variants**: overriding `className` with a conflicting utility resolves via `cn()`/`twMerge` (last wins), not two classes in the DOM.
5. **Accessibility**: every interactive element has an accessible name; the test includes a passing `jest-axe` assertion.
6. **Test coverage**: render, each variant, className merge, interaction/state, and an axe check.

## References

- shadcn/ui component patterns: `skills/shadcn-component-patterns.md`
- Tailwind v4 tokens: `skills/tailwind-v4-design-tokens.md`
- class-variance-authority: https://cva.style/docs
- tailwind-merge: https://github.com/dcastil/tailwind-merge
- Testing Library (React): https://testing-library.com/docs/react-testing-library/intro/
- jest-axe: https://github.com/nickcolley/jest-axe
- React `forwardRef`: https://react.dev/reference/react/forwardRef
- WCAG 2.2 Target Size (Minimum): https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html
</content>
