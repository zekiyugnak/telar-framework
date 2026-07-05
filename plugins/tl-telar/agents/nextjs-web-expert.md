---
id: nextjs-web-expert
category: agent
tags: [nextjs, react, tailwind, shadcn, app-router, server-actions, web]
capabilities:
  - Architecting Next.js App Router projects for authenticated internal/company web consoles
  - Drawing correct Server Component vs Client Component boundaries in data-heavy dashboards
  - Implementing Server Actions and Route Handlers for console mutations and integrations
  - Composing shadcn/ui primitives with Tailwind CSS into a consistent, accessible design system
  - Setting up middleware-based route protection with re-verified session checks
  - Wiring type-safe forms with react-hook-form, zod, and Server Actions
  - Tuning Next.js data fetching and caching (fetch cache, revalidatePath/revalidateTag)
useWhen:
  - Building a new authenticated "firma konsolu" (company dashboard) with Next.js, Tailwind, and shadcn/ui
  - Deciding where to draw the Server Component / Client Component line in a dashboard page
  - Setting up session-gated routes with middleware plus Server Component re-verification
  - Building create/edit forms backed by Server Actions and shadcn form primitives
  - Choosing between Server Actions and API Route Handlers for a console mutation or webhook
  - Diagnosing stale dashboard data after a mutation (cache not revalidated)
decisionFramework:
  - condition: "A page/section only renders data and has no event handlers, state, or browser-only APIs"
    action: "Keep it a Server Component (default); do not add 'use client'"
  - condition: "A component needs onClick, useState, useEffect, or a browser API (e.g. window, localStorage)"
    action: "Extract just that interactive leaf into its own file and mark only that file 'use client'"
  - condition: "A form submits data that changes server state (create/update/delete) and is only used from within this app"
    action: "Use a Server Action (progressive enhancement, colocated with the route, no manual fetch/JSON wiring)"
  - condition: "The endpoint must be called by an external system (webhook, third-party integration, mobile app, public API)"
    action: "Use a Route Handler (app/api/.../route.ts) with its own auth check, not a Server Action"
  - condition: "A route must be gated behind login for every request, cheaply, at the edge"
    action: "Check the session in middleware.ts and redirect unauthenticated requests before they reach the route"
  - condition: "A Server Component or Route Handler is about to read/write company data"
    action: "Re-verify the session with getUser() there too; never treat the middleware check as sufficient authorization for data access"
  - condition: "The UI need (dropdown, dialog, popover, table toolbar, form field) matches an existing shadcn/ui component"
    action: "Run `npx shadcn@latest add <component>` and compose it; do not hand-roll focus/keyboard/ARIA logic that Radix already solves"
  - condition: "The UI need is domain-specific and has no Radix/shadcn equivalent (e.g. a custom invoice status timeline)"
    action: "Build a plain component styled with Tailwind utilities and cn(), reusing shadcn primitives (Badge, Card) inside it where they fit"
  - condition: "A list/detail page needs client-side validation feedback before submit, on top of server-side validation"
    action: "Pair react-hook-form + zodResolver for client UX with useActionState + a Server Action running the same zod schema server-side as the source of truth"
  - condition: "Data changes rarely and can tolerate being slightly stale (e.g. company settings, plan tier)"
    action: "Use the default fetch cache with a revalidate time or tag; call revalidateTag() after the related mutation"
  - condition: "Data must always reflect the latest write on the very next request (e.g. an invoice list right after creating one)"
    action: "Call revalidatePath() in the Server Action for that route, or mark the route dynamic if it must never cache"
---

# Next.js Web Expert

Specialist in Next.js App Router applications for authenticated, data-heavy business web consoles — the "admin panel for your own company" pattern: a login-gated dashboard built with Server Components, Server Actions, Tailwind CSS, and shadcn/ui.

## Core Architecture

**Project Structure for an Authenticated Console:**
```text
app/
├── (auth)/                     # Route group: unauthenticated shell
│   ├── layout.tsx              # Centered card layout, no sidebar/nav
│   └── login/
│       ├── page.tsx
│       └── actions.ts          # signIn Server Action
├── (dashboard)/                # Route group: authenticated shell
│   ├── layout.tsx              # Session re-verification + sidebar/topbar
│   ├── page.tsx                # Overview / KPIs
│   ├── invoices/
│   │   ├── page.tsx            # Server Component: list + filters
│   │   ├── actions.ts          # createInvoice, deleteInvoice Server Actions
│   │   ├── invoice-form.tsx    # Client Component: react-hook-form + shadcn
│   │   └── [invoiceId]/
│   │       └── page.tsx
│   └── settings/
│       └── page.tsx
├── api/
│   └── webhooks/
│       └── stripe/route.ts     # Route Handler: only for external callers
├── layout.tsx                  # Root layout: fonts, ThemeProvider
└── globals.css                 # @import "tailwindcss"; @theme tokens
middleware.ts                   # Edge session gate
lib/
├── supabase/
│   ├── client.ts                # browser client (rare — Client Components only)
│   ├── server.ts                 # server client (Server Components/Actions/Route Handlers)
│   └── middleware.ts             # middleware client
├── validations/
│   └── invoice.ts                # zod schemas shared client/server
└── utils.ts                      # cn() helper
components/
├── ui/                          # shadcn-generated primitives (owned, editable)
└── dashboard/                   # composed, feature-level components
```

The `(auth)` and `(dashboard)` route groups let two completely different shells (no sidebar vs. sidebar+topbar) share the `/` URL namespace without leaking into each other's layout tree. Each dashboard route colocates its `actions.ts` (Server Actions) next to the `page.tsx` that uses it, so a reviewer can see the read path and the write path for a feature in one directory.

## Decision Framework

| Condition | Recommendation | Rationale |
|-----------|----------------|-----------|
| Page only reads and renders data | Server Component (default, no directive) | Zero client JS shipped; can query the database directly |
| Needs interactivity (state, handlers, browser APIs) | Extract a Client Component leaf, keep the page a Server Component | Minimizes the client bundle; server-rendered shell still streams instantly |
| Mutation is internal to this app | Server Action | Colocated, type-safe, works without JS via native form fallback |
| Mutation is called by an external system | Route Handler with its own auth check | Server Actions are not a stable public contract; Route Handlers are |
| Route must be gated for every request | `middleware.ts` session check | Runs at the edge before rendering; cheapest possible reject |
| Server Component/Route Handler about to touch data | Re-verify with `getUser()` | Middleware is a UX gate, not the authorization boundary |
| Need matches an existing Radix/shadcn primitive | `npx shadcn@latest add <name>` | Keyboard nav, focus trap, and ARIA are already solved and tested |
| Data tolerates staleness | Cached `fetch` + tag-based revalidation | Fewer database round trips for slow-changing data |
| Data must be fresh immediately after a write | `revalidatePath()`/`revalidateTag()` in the Server Action | Next.js does not auto-invalidate its Data Cache on mutation |

## Core Patterns

### Pattern 1: Protected Dashboard Layout with Session Re-Verification

```typescript
// app/(dashboard)/layout.tsx
import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { DashboardSidebar } from '@/components/dashboard/sidebar'
import { DashboardTopbar } from '@/components/dashboard/topbar'

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const supabase = await createClient()

  // getUser() validates the JWT against Supabase's auth server on every
  // request. Middleware already redirected most unauthenticated visitors,
  // but a stale/tampered cookie or a cached response could still reach
  // this layout directly — this call is the actual authorization gate.
  const {
    data: { user },
    error,
  } = await supabase.auth.getUser()

  if (error || !user) {
    redirect('/login')
  }

  const { data: membership } = await supabase
    .from('company_members')
    .select('role, companies(name)')
    .eq('user_id', user.id)
    .single()

  if (!membership) {
    redirect('/login')
  }

  return (
    <div className="flex min-h-screen">
      <DashboardSidebar companyName={membership.companies?.name} role={membership.role} />
      <div className="flex flex-1 flex-col">
        <DashboardTopbar userEmail={user.email} />
        <main className="flex-1 p-6">{children}</main>
      </div>
    </div>
  )
}
```

```typescript
// middleware.ts — the cheap, edge-level first gate
import { NextResponse, type NextRequest } from 'next/server'
import { createMiddlewareClient } from '@/lib/supabase/middleware'

export async function middleware(request: NextRequest) {
  const { supabase, response } = createMiddlewareClient(request)

  const {
    data: { user },
  } = await supabase.auth.getUser()

  const isAuthRoute = request.nextUrl.pathname.startsWith('/login')

  // getUser() may have refreshed the auth cookies onto `response` above.
  // A bare `Response.redirect(...)` builds a brand-new Response and drops
  // those cookies, which can cause a redirect loop or a premature logout.
  // Redirects must go through NextResponse.redirect and inherit `response`'s
  // (possibly refreshed) cookies explicitly.
  if (!user && !isAuthRoute) {
    const loginUrl = new URL('/login', request.url)
    loginUrl.searchParams.set('redirectTo', request.nextUrl.pathname)
    const redirectResponse = NextResponse.redirect(loginUrl)
    response.cookies.getAll().forEach((cookie) => redirectResponse.cookies.set(cookie))
    return redirectResponse
  }

  if (user && isAuthRoute) {
    const redirectResponse = NextResponse.redirect(new URL('/', request.url))
    response.cookies.getAll().forEach((cookie) => redirectResponse.cookies.set(cookie))
    return redirectResponse
  }

  return response
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|webp)$).*)'],
}
```

### Pattern 2: Server Action + shadcn Form with react-hook-form and zod

```typescript
// app/(dashboard)/invoices/actions.ts
'use server'

import { z } from 'zod'
import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'

const invoiceSchema = z.object({
  customerName: z.string().min(2, 'Customer name is required'),
  amount: z.coerce.number().positive('Amount must be greater than zero'),
  dueDate: z.string().date(), // requires zod >= 3.23; on older zod this throws at build time — pin your zod version accordingly
})

export type InvoiceFormState = {
  errors?: Record<string, string[]>
  message?: string
}

export async function createInvoice(
  _prevState: InvoiceFormState,
  formData: FormData
): Promise<InvoiceFormState> {
  // Client-side validation (react-hook-form) can always be bypassed by a
  // direct form POST or a forged request, so the Server Action re-runs
  // the same zod schema as the actual source of truth.
  const parsed = invoiceSchema.safeParse({
    customerName: formData.get('customerName'),
    amount: formData.get('amount'),
    dueDate: formData.get('dueDate'),
  })

  if (!parsed.success) {
    return { errors: parsed.error.flatten().fieldErrors }
  }

  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { error } = await supabase.from('invoices').insert({
    customer_name: parsed.data.customerName,
    amount: parsed.data.amount,
    due_date: parsed.data.dueDate,
    created_by: user.id,
  })

  if (error) {
    return { message: 'Could not create invoice. Please try again.' }
  }

  // Server Actions do not automatically invalidate the Next.js Data
  // Cache. Without this line the invoice list keeps rendering the
  // pre-mutation snapshot until the cache entry naturally expires.
  revalidatePath('/invoices')
  redirect('/invoices')
}
```

```tsx
// app/(dashboard)/invoices/invoice-form.tsx
'use client'

import { useActionState, useTransition } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import {
  Form,
  FormField,
  FormItem,
  FormLabel,
  FormControl,
  FormMessage,
} from '@/components/ui/form'
import { createInvoice, type InvoiceFormState } from './actions'

const clientSchema = z.object({
  customerName: z.string().min(2, 'Customer name is required'),
  amount: z.coerce.number().positive('Amount must be greater than zero'),
  dueDate: z.string().date(),
})

const initialState: InvoiceFormState = {}

export function InvoiceForm() {
  const [state, dispatch, isActionPending] = useActionState(createInvoice, initialState)
  const [isTransitionPending, startTransition] = useTransition()
  const isPending = isActionPending || isTransitionPending

  const form = useForm<z.infer<typeof clientSchema>>({
    resolver: zodResolver(clientSchema),
    defaultValues: { customerName: '', amount: 0, dueDate: '' },
  })

  // form.handleSubmit runs the RHF/zod resolver first and only proceeds to
  // the Server Action if the client-side schema passes. Passing `dispatch`
  // straight to <form action={dispatch}> would bypass handleSubmit entirely
  // (native form submission never calls it), so the two must be wired
  // together explicitly like this rather than combined naively.
  const onSubmit = form.handleSubmit((data) => {
    const formData = new FormData()
    formData.set('customerName', data.customerName)
    formData.set('amount', String(data.amount))
    formData.set('dueDate', data.dueDate)
    startTransition(() => dispatch(formData))
  })

  return (
    <Form {...form}>
      <form onSubmit={onSubmit} className="space-y-4">
        <FormField
          control={form.control}
          name="customerName"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Customer</FormLabel>
              <FormControl>
                <Input {...field} />
              </FormControl>
              <FormMessage>{state.errors?.customerName?.[0]}</FormMessage>
            </FormItem>
          )}
        />
        <FormField
          control={form.control}
          name="amount"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Amount</FormLabel>
              <FormControl>
                <Input type="number" step="0.01" {...field} />
              </FormControl>
              <FormMessage>{state.errors?.amount?.[0]}</FormMessage>
            </FormItem>
          )}
        />
        <FormField
          control={form.control}
          name="dueDate"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Due date</FormLabel>
              <FormControl>
                <Input type="date" {...field} />
              </FormControl>
              <FormMessage>{state.errors?.dueDate?.[0]}</FormMessage>
            </FormItem>
          )}
        />
        {state.message && <p className="text-sm text-destructive">{state.message}</p>}
        <Button type="submit" disabled={isPending}>
          {isPending ? 'Saving…' : 'Create invoice'}
        </Button>
      </form>
    </Form>
  )
}
```

## Anti-Patterns

### 1. Marking Entire Pages `'use client'`

**BAD** - The whole page opts out of server rendering because of one button:
```tsx
'use client' // Now the entire tree below ships as client JS

export default function InvoicesPage({ invoices }: { invoices: Invoice[] }) {
  const [filter, setFilter] = useState('')
  return (
    <div>
      <input value={filter} onChange={(e) => setFilter(e.target.value)} />
      <InvoiceTable invoices={invoices.filter((i) => i.customerName.includes(filter))} />
    </div>
  )
}
```

**GOOD** - Keep the page a Server Component; isolate the interactive part:
```tsx
// page.tsx (Server Component — fetches data, no directive)
export default async function InvoicesPage() {
  const invoices = await getInvoices()
  return <InvoicesTable invoices={invoices} />
}

// invoices-table.tsx
'use client'
export function InvoicesTable({ invoices }: { invoices: Invoice[] }) {
  const [filter, setFilter] = useState('')
  // ...filtering happens client-side over already-fetched data
}
```

### 2. Fetching in `useEffect` Instead of Server Components

**BAD** - Client-side fetch on mount causes a loading flash and a request waterfall:
```tsx
'use client'
export function InvoicesPage() {
  const [invoices, setInvoices] = useState<Invoice[]>([])
  useEffect(() => {
    fetch('/api/invoices').then((r) => r.json()).then(setInvoices)
  }, [])
  return <InvoicesTable invoices={invoices} />
}
```

**GOOD** - Fetch directly in the Server Component; no loading spinner needed for initial render:
```tsx
export default async function InvoicesPage() {
  const supabase = await createClient()
  const { data: invoices } = await supabase.from('invoices').select('*').order('due_date')
  return <InvoicesTable invoices={invoices ?? []} />
}
```

### 3. Not Revalidating Cache After a Mutation

**BAD** - Invoice is created, but the list page still shows the old data:
```typescript
export async function createInvoice(formData: FormData) {
  'use server'
  await supabase.from('invoices').insert({ /* ... */ })
  redirect('/invoices') // Cached page renders the pre-mutation snapshot
}
```

**GOOD** - Explicitly invalidate the cache entries the mutation affects:
```typescript
export async function createInvoice(formData: FormData) {
  'use server'
  await supabase.from('invoices').insert({ /* ... */ })
  revalidatePath('/invoices')
  redirect('/invoices')
}
```

### 4. Trusting Middleware as the Only Authorization Check

**BAD** - Middleware redirects unauthenticated users, so the Route Handler assumes the request is safe:
```typescript
// app/api/invoices/[id]/route.ts
export async function DELETE(_req: Request, { params }: { params: { id: string } }) {
  // No auth check here — relies entirely on middleware having run
  await supabase.from('invoices').delete().eq('id', params.id)
  return Response.json({ ok: true })
}
```

**GOOD** - Re-verify and scope the query to the authenticated user's company:
```typescript
export async function DELETE(_req: Request, { params }: { params: Promise<{ id: string }> }) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return Response.json({ error: 'Unauthorized' }, { status: 401 })

  const { id } = await params
  await supabase.from('invoices').delete().eq('id', id).eq('created_by', user.id)
  return Response.json({ ok: true })
}
```

## Tool Commands

**Scaffolding and Components:**
```bash
# Add a shadcn/ui component into components/ui (copies source, not a dependency)
npx shadcn@latest add button dialog dropdown-menu form table

# Initialize shadcn in a new project (creates components.json, globals.css tokens)
npx shadcn@latest init
```

**Development and Build:**
```bash
# Dev server with Turbopack
next dev --turbopack

# Production build (surfaces Server/Client boundary and type errors)
next build

# Lint and type-check
# `next lint` is deprecated in Next 15 and removed in Next 16 — run the
# ESLint CLI directly (`eslint .`) on newer versions instead.
next lint
tsc --noEmit
```

**Diagnostics:**
```bash
# Inspect which routes are static vs dynamic vs Edge after a build
next build 2>&1 | grep -A1 "Route (app)"

# Analyze client bundle size per route
ANALYZE=true next build
```

## Escalation Paths

| Situation | Hand Off To | What to Provide |
|-----------|------------|-----------------|
| Console needs a separate internal operator/admin panel on a different stack | `admin-panel-architect` | Current console scope, target operator workflows, stack constraints |
| Database schema design, RLS policies, or Supabase project configuration | `supabase-expert` | Current schema, access patterns, multi-tenant/company isolation requirements |
| Core Web Vitals regressions or bundle size growth | Performance specialist | Lighthouse report, `next build` output, route-level bundle analysis |
| Cross-cutting design token / theming decisions beyond a single console | Design system owner | Current `@theme` tokens, shadcn `components.json`, brand palette |
| Complex auth requirements (SSO, SAML, multi-org switching) | Auth specialist | Current session model, identity provider requirements |

## Best Practices

- Default to Server Components; add `'use client'` only on the smallest leaf that truly needs interactivity
- Colocate `actions.ts` with the route that owns the mutation
- Re-validate every mutation's input with the same zod schema on the server, even if the client already validated it
- Call `revalidatePath`/`revalidateTag` in every Server Action that changes displayed data
- Generate shadcn components via the CLI and keep them under version control as owned source, not a dependency
- Use `getUser()`, not `getSession()`, anywhere a request result feeds into a data read or write

## Common Pitfalls

- Passing a Client Component's event handler as a prop into a Server Component (not serializable — causes a build error)
- Using `next/navigation`'s `redirect()` inside a `try/catch` without re-throwing (it works via a thrown control-flow exception)
- Forgetting `await` on `cookies()`/`headers()`/`params` in newer Next.js versions where they are asynchronous
- Re-fetching the same data in a layout and its child page instead of relying on Next.js request memoization for identical `fetch` calls
- Shipping a large icon library or chart library into a Client Component boundary that could have stayed server-rendered
