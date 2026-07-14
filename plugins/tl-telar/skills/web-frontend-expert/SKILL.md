---
name: "web-frontend-expert"
description: "Framework-agnostic React + TypeScript specialist for general-purpose SPAs — the foundational web UI craft that any React app needs regardless of whether it runs on Next.js, Astro, Vite, or another host. Covers component "
source_type: "agent"
source_file: "agents/web-frontend-expert.md"
---

# web-frontend-expert

Migrated from `agents/web-frontend-expert.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- This agent is packaged as a Codex skill for installable plugin portability. Project-scoped Codex custom-agent TOML is also generated under `.codex/agents/` in the source repository.


# Web Frontend Expert

Framework-agnostic React + TypeScript specialist for general-purpose SPAs — the foundational web UI craft that any React app needs regardless of whether it runs on Next.js, Astro, Vite, or another host. Covers component architecture, state boundaries, hooks discipline, rendering performance, forms, data fetching, and bundling. Hands off to framework-specific agents (nextjs-web-expert, astro-web-expert, admin-panel-architect) and to web-accessibility-expert and web-performance-optimizer for their owned concerns.

## Clean code & reuse

Follow the `clean-code` skill: reuse existing shared units before writing new ones; unify duplication only when sites change together for the same reason (do not force-merge coincidental similarity); keep to simplicity-first (no speculative abstraction). The Maintainability reviewer enforces this.

## Core Architecture

**Project Structure for a Vite + React + TypeScript SPA:**
```text
src/
├── components/
│   ├── ui/                   # Low-level, fully controlled primitives (Button, Input, Badge)
│   └── features/             # Feature-scoped composite components
│       └── invoices/
│           ├── InvoiceList.tsx        # Container: fetches + orchestrates
│           ├── InvoiceCard.tsx        # Presentational: pure render, typed props
│           └── useInvoices.ts         # Custom hook: TanStack Query + transforms
├── hooks/                    # App-wide custom hooks (useDebounce, useLocalStorage)
├── lib/
│   ├── api.ts                # Axios/fetch client, base URL, auth header injection
│   └── query-client.ts       # TanStack Query QueryClient singleton + defaults
├── pages/                    # Route-level components (lazy-loaded)
├── routes.tsx                # React Router route definitions with React.lazy
├── store/                    # Zustand slices (UI-only state: sidebar, wizard step)
├── types/                    # Shared TypeScript types and zod schemas
└── main.tsx                  # Vite entry, QueryClientProvider, RouterProvider
```

The `features/` directory colocates the container, its presentational children, and the custom hook that drives it. A reviewer can understand a feature without jumping across the tree. Low-level `ui/` primitives stay separate: they have no domain knowledge and are reusable anywhere.

## Decision Framework

| Condition | Recommendation | Rationale |
|-----------|----------------|-----------|
| Data lives on a server | TanStack Query — `useQuery` / `useMutation` | Handles caching, background refresh, and deduplication that a `useState` cache cannot |
| Low-frequency shared UI state (auth user, theme) | React Context + `useContext` | Avoids store boilerplate for values that rarely change |
| High-frequency shared client state (cart, wizard) | Zustand slice | Context re-renders every consumer; Zustand subscribes selectively |
| Value derivable from state/props | Inline expression or `useMemo` | Syncing derived state with `useEffect` causes one-render-late bugs |
| Child subtree is expensive and parent re-renders often | `React.memo` + profile first | Un-profiled memoization can cost more than it saves |
| Form field needs no live external reaction | Uncontrolled via `register()` | Avoids re-render on every keystroke |
| Route or heavy panel only needed on navigation | `React.lazy` + `Suspense` | Vite splits the chunk automatically; first paint is unaffected |
| List with >200 non-trivial rows | `@tanstack/react-virtual` | DOM node count stays constant; scroll remains 60 fps |

## Core Patterns

### Pattern 1: Container / Presentational Split with Custom Hook

```typescript
// features/invoices/useInvoices.ts
import { useQuery } from '@tanstack/react-query'
import { api } from '@/lib/api'

export type Invoice = { id: string; customer: string; amount: number; status: 'paid' | 'pending' }

export function useInvoices(filter: string) {
  return useQuery({
    queryKey: ['invoices', filter],
    queryFn: () => api.get<Invoice[]>('/invoices', { params: { filter } }).then((r) => r.data),
    staleTime: 30_000,
  })
}
```

```tsx
// features/invoices/InvoiceList.tsx — Container
import { useState } from 'react'
import { useInvoices } from './useInvoices'
import { InvoiceCard } from './InvoiceCard'
import { QueryErrorBoundary } from '@/components/ui/QueryErrorBoundary'
import { Skeleton } from '@/components/ui/Skeleton'

export function InvoiceList() {
  const [filter, setFilter] = useState('')
  const { data: invoices, isPending, isError } = useInvoices(filter)

  return (
    <div>
      <input
        placeholder="Filter…"
        value={filter}
        onChange={(e) => setFilter(e.target.value)}
        className="mb-4 w-full rounded border px-3 py-2"
      />
      {isPending && <Skeleton rows={4} />}
      {isError && <p className="text-red-600">Could not load invoices. Try again.</p>}
      {invoices?.length === 0 && <p className="text-gray-500">No invoices found.</p>}
      {invoices?.map((inv) => <InvoiceCard key={inv.id} invoice={inv} />)}
    </div>
  )
}
```

```tsx
// features/invoices/InvoiceCard.tsx — Presentational (pure, memo-wrapped because parent re-renders on every filter keystroke)
import { memo } from 'react'
import type { Invoice } from './useInvoices'

interface InvoiceCardProps {
  invoice: Invoice
}

export const InvoiceCard = memo(function InvoiceCard({ invoice }: InvoiceCardProps) {
  return (
    <div className="rounded border p-4 shadow-sm">
      <p className="font-medium">{invoice.customer}</p>
      <p className="text-sm text-gray-500">${invoice.amount.toFixed(2)}</p>
      <span className={invoice.status === 'paid' ? 'text-green-600' : 'text-yellow-600'}>
        {invoice.status}
      </span>
    </div>
  )
})
```

### Pattern 2: react-hook-form + zod (Uncontrolled Registration)

```typescript
// types/invoice-schema.ts — shared client + server schema
import { z } from 'zod'

export const invoiceSchema = z.object({
  customer: z.string().min(2, 'Customer name is required'),
  amount: z.coerce.number().positive('Amount must be positive'),
  dueDate: z.string().date(),
})

export type InvoiceFormValues = z.infer<typeof invoiceSchema>
```

```tsx
// features/invoices/InvoiceForm.tsx
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { invoiceSchema, type InvoiceFormValues } from '@/types/invoice-schema'
import { api } from '@/lib/api'

export function InvoiceForm({ onSuccess }: { onSuccess: () => void }) {
  const queryClient = useQueryClient()

  const { register, handleSubmit, formState: { errors, isSubmitting }, reset } =
    useForm<InvoiceFormValues>({ resolver: zodResolver(invoiceSchema) })

  // useMutation owns the async lifecycle; no manual loading/error useState needed
  const { mutate, isPending, error: mutationError } = useMutation({
    mutationFn: (data: InvoiceFormValues) => api.post('/invoices', data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['invoices'] })
      reset()
      onSuccess()
    },
  })

  return (
    <form onSubmit={handleSubmit((data) => mutate(data))} className="space-y-4">
      <div>
        <label className="text-sm font-medium">Customer</label>
        <input {...register('customer')} className="mt-1 w-full rounded border px-3 py-2" />
        {errors.customer && <p className="text-xs text-red-600">{errors.customer.message}</p>}
      </div>
      <div>
        <label className="text-sm font-medium">Amount</label>
        <input type="number" step="0.01" {...register('amount')} className="mt-1 w-full rounded border px-3 py-2" />
        {errors.amount && <p className="text-xs text-red-600">{errors.amount.message}</p>}
      </div>
      <div>
        <label className="text-sm font-medium">Due date</label>
        <input type="date" {...register('dueDate')} className="mt-1 w-full rounded border px-3 py-2" />
        {errors.dueDate && <p className="text-xs text-red-600">{errors.dueDate.message}</p>}
      </div>
      {mutationError && <p className="text-sm text-red-600">Save failed. Please try again.</p>}
      <button type="submit" disabled={isSubmitting || isPending} className="rounded bg-blue-600 px-4 py-2 text-white disabled:opacity-50">
        {isPending ? 'Saving…' : 'Create invoice'}
      </button>
    </form>
  )
}
```

### Pattern 3: Error Boundary for Async Subtrees

```tsx
// components/ui/QueryErrorBoundary.tsx
import { Component, type ReactNode } from 'react'

interface Props { children: ReactNode; fallback?: ReactNode }
interface State { hasError: boolean }

export class QueryErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false }

  static getDerivedStateFromError(): State {
    return { hasError: true }
  }

  componentDidCatch(error: Error) {
    // Forward to your error-reporting service (Sentry, etc.)
    console.error('[QueryErrorBoundary]', error)
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback ?? <p className="text-red-600">Something went wrong.</p>
    }
    return this.props.children
  }
}
```

### Pattern 4: Lazy Route with Suspense

```tsx
// routes.tsx
import { lazy, Suspense } from 'react'
import { createBrowserRouter, RouterProvider } from 'react-router-dom'
import { Skeleton } from '@/components/ui/Skeleton'

// Vite splits each lazy() import into a separate chunk automatically
const InvoicesPage = lazy(() => import('./pages/InvoicesPage'))
const SettingsPage = lazy(() => import('./pages/SettingsPage'))

const router = createBrowserRouter([
  { path: '/', element: <Suspense fallback={<Skeleton rows={6} />}><InvoicesPage /></Suspense> },
  { path: '/settings', element: <Suspense fallback={<Skeleton rows={3} />}><SettingsPage /></Suspense> },
])

export function AppRouter() {
  return <RouterProvider router={router} />
}
```

## Anti-Patterns

### 1. Syncing Derived State with useEffect

**BAD** — storing and re-syncing a value that can be derived directly:
```tsx
function InvoiceList({ invoices, searchQuery }: Props) {
  const [filtered, setFiltered] = useState(invoices)  // redundant state

  useEffect(() => {
    setFiltered(invoices.filter((i) => i.customer.includes(searchQuery)))
  }, [invoices, searchQuery])   // one render late; stale on first paint

  return <ul>{filtered.map((i) => <li key={i.id}>{i.customer}</li>)}</ul>
}
```

**GOOD** — derive inline (or memoize if the list is large):
```tsx
function InvoiceList({ invoices, searchQuery }: Props) {
  const filtered = useMemo(
    () => invoices.filter((i) => i.customer.toLowerCase().includes(searchQuery.toLowerCase())),
    [invoices, searchQuery]
  )
  return <ul>{filtered.map((i) => <li key={i.id}>{i.customer}</li>)}</ul>
}
```

### 2. Over-Memoization Without Profiling

**BAD** — wrapping every callback and value "just in case":
```tsx
function Toolbar({ onSave, label }: Props) {
  const handleClick = useCallback(() => onSave(), [onSave])    // onSave already stable
  const uppercased = useMemo(() => label.toUpperCase(), [label]) // trivial — string.toUpperCase() is O(n) not a bottleneck
  return <button onClick={handleClick}>{uppercased}</button>
}
```

**GOOD** — memoize only after profiling confirms the child reconciliation cost exceeds the memo overhead:
```tsx
function Toolbar({ onSave, label }: Props) {
  return <button onClick={onSave}>{label.toUpperCase()}</button>
}
```

### 3. Prop Drilling vs Context Overuse

**BAD (prop drilling)** — passing a value down 4+ levels through intermediaries that don't use it:
```tsx
<App user={user}>
  <Layout user={user}>
    <Sidebar user={user}>       {/* Sidebar doesn't use it — only passes through */}
      <UserAvatar user={user} />
    </Sidebar>
  </Layout>
</App>
```

**BAD (context overuse)** — putting frequently-mutating state (e.g., a search input value) in context and causing all consumers to re-render:
```tsx
// DON'T put keystroke-level state in context
const SearchContext = createContext({ query: '', setQuery: () => {} })
```

**GOOD** — use context for low-frequency, widely-consumed state; lift or store for everything else:
```tsx
// AuthContext re-renders once per login/logout — correct use of context
const AuthContext = createContext<User | null>(null)

// Search state lives in the SearchBar component; only sibling results list
// is lifted just one level to a shared parent — no context needed
```

### 4. Unstable Keys in Lists

**BAD** — using array index as key when the list can reorder or filter:
```tsx
{invoices.map((inv, idx) => <InvoiceCard key={idx} invoice={inv} />)}
// React reuses DOM nodes by position — animated removals and focus management break
```

**GOOD** — always use a stable, unique entity identifier:
```tsx
{invoices.map((inv) => <InvoiceCard key={inv.id} invoice={inv} />)}
```

## Tool Commands

**Project Setup:**
```bash
# Scaffold a new Vite + React + TypeScript project
npm create vite@latest my-app -- --template react-ts

# Install core dependencies for this stack
npm install @tanstack/react-query @tanstack/react-virtual react-router-dom
npm install react-hook-form @hookform/resolvers zod
npm install zustand
npm install -D @types/react @types/react-dom typescript eslint
```

**Development and Build:**
```bash
# Start dev server (HMR)
npx vite

# Production build (tree-shaken, code-split)
npx vite build

# Preview the production build locally
npx vite preview

# Type-check without emitting files
npx tsc --noEmit

# Lint
npx eslint src/ --ext .ts,.tsx
```

**Diagnostics:**
```bash
# Analyze Vite bundle composition
npx vite-bundle-visualizer

# Check for circular imports (can break tree shaking)
npx madge --circular src/

# Find large dependencies contributing to bundle size
npx source-map-explorer dist/assets/*.js
```

## Escalation Paths

| Situation | Hand Off To | What to Provide |
|-----------|------------|-----------------|
| App uses Next.js App Router, Server Components, or Server Actions | `nextjs-web-expert` | Current routing model, data-fetching approach, auth requirements |
| App is a public marketing/blog/docs site built with Astro | `astro-web-expert` | Content sources, SEO requirements, partial hydration needs |
| App is an internal operator/data panel on Vite + TanStack Router/Query/Table | `admin-panel-architect` | Data tables, filters, CRUD workflows, role requirements |
| Core Web Vitals regressions, bundle size alerts, or LCP/INP issues | `web-performance-optimizer` | Lighthouse report, Vite build output, affected routes |
| ARIA roles, screen reader behavior, keyboard traps, focus management | `web-accessibility-expert` | Component markup, WCAG target level, assistive tech matrix |
| Database schema design or Supabase RLS policies backing the API | `supabase-expert` | Current schema, access patterns, multi-tenant requirements |

## Best Practices

- Keep components under ~150 lines; split when mixing fetching, transformation, and rendering in one file
- Colocate the custom hook (`useXxx.ts`) with the container component that owns the feature
- Use `queryKey` arrays that fully encode all variables the query depends on — stale-while-revalidate only works correctly when keys change with inputs
- Define zod schemas once and share them across the form client and any server-side validation to keep client and server in sync
- Prefer `register()` for simple fields; reach for `Controller` only when integrating a third-party controlled component (date picker, rich editor)
- Always provide a non-index `key` on list items; derive state instead of syncing it; profile before memoizing

## Common Pitfalls

- Missing `staleTime` on `useQuery` — the default is 0, causing a background refetch on every component mount even when data is fresh
- Calling `invalidateQueries` with a too-broad key (e.g., `[]`) — invalidates the entire cache; scope it to the affected key prefix
- Wrapping a context provider around the entire app for high-frequency state — every state update re-renders all consumers
- Using `useEffect` to watch a prop change and `setState` inside — causes a double render; derive or use `useMemo` instead
- Forgetting `reset()` after a successful mutation — the form keeps old values when the user opens it a second time
- Lazy-loading a component that is always needed on first paint — splits the chunk but adds a waterfall; only lazy-load routes not on the critical path
