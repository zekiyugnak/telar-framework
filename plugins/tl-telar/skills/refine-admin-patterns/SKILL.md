---
name: "refine-admin-patterns"
description: "Refine is a headless React meta-framework: you declare a `resources` array and hand it four providers (`dataProvider`, `authProvider`, `routerProvider`, `accessControlProvider`), and it derives CRUD data flow, routing, a"
source_type: "skill"
source_file: "skills/refine-admin-patterns.md"
---

# refine-admin-patterns

Migrated from `skills/refine-admin-patterns.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Refine Resources, Supabase Providers, and RLS-Backed Access Control

Refine is a headless React meta-framework: you declare a `resources` array and hand it four providers (`dataProvider`, `authProvider`, `routerProvider`, `accessControlProvider`), and it derives CRUD data flow, routing, and auth-aware navigation for you — with zero opinion on the UI, which stays TanStack Table + shadcn/ui. This skill covers wiring those providers to Supabase under the same non-negotiable constraint as the rest of this admin stack: the browser holds only the **anon key**, so Postgres RLS — not any provider Refine runs client-side — is the real authorization boundary.

## Problem

Two failure modes recur. First, teams reach for Refine but then hand-roll every CRUD screen anyway — a bespoke `useState` + `fetch` + router wiring per resource — throwing away the exact leverage Refine exists to provide. Second, and more dangerous, teams read `accessControlProvider` (or an `authProvider.getPermissions` role check) as if it were a security control, when it runs in the browser against the public anon key and can be edited out of the bundle or replayed with `curl`.

```tsx
// BAD: Refine is installed, but every resource re-implements fetching, routing,
// pagination and mutation by hand — none of Refine's resource/provider leverage
// is used, so the dependency is pure overhead.
function CandidatesPage() {
  const [rows, setRows] = useState<Candidate[]>([])
  const [page, setPage] = useState(0)
  useEffect(() => {
    supabase.from('candidates').select('*').range(page * 25, page * 25 + 24)
      .then(({ data }) => setRows(data ?? []))
  }, [page])
  // ...hand-wired create/edit/delete buttons, hand-wired navigation, repeated per table
}
```

```tsx
// BAD: treating a client-side permission check as authorization. This hides the
// delete action in the UI, but the delete itself still succeeds for anyone who
// replays supabase.from('candidates').delete() with the anon key from devtools,
// because there is no trusted server between this client and Postgres.
const accessControlProvider = {
  can: async ({ action }) => ({ can: action !== 'delete' || currentUser.role === 'admin' }),
}
// ...with no corresponding `FOR DELETE` RLS policy on public.candidates
```

## Solution

### The `resources` array drives routing and CRUD derivation

```tsx
// src/App.tsx
import { Refine, type AccessControlProvider } from '@refinedev/core'
import { dataProvider, liveProvider } from '@refinedev/supabase'
import routerProvider, {
  NavigateToResource,
  UnsavedChangesNotifier,
  DocumentTitleHandler,
} from '@refinedev/react-router'
import { BrowserRouter, Routes, Route, Outlet } from 'react-router'
import { supabase } from '@/lib/supabase'
import { authProvider } from '@/providers/authProvider'
import { accessControlProvider } from '@/providers/accessControlProvider'
import { CandidateList, CandidateCreate, CandidateEdit, CandidateShow } from '@/features/candidates'
import { AuthLayout, LoginPage } from '@/features/auth'

export function App() {
  return (
    <BrowserRouter>
      <Refine
        dataProvider={dataProvider(supabase)}
        liveProvider={liveProvider(supabase)}
        authProvider={authProvider}
        accessControlProvider={accessControlProvider}
        routerProvider={routerProvider}
        // Each resource entry is the single source of truth for that entity's
        // URLs. Refine derives useTable's default list query, the "create"/"edit"
        // buttons' navigation targets, breadcrumb labels, and document titles
        // from `name` + these route strings — you never wire them per screen.
        resources={[
          {
            name: 'candidates',
            list: '/candidates',
            create: '/candidates/create',
            edit: '/candidates/edit/:id',
            show: '/candidates/show/:id',
            meta: { canDelete: true, label: 'Candidates' },
          },
        ]}
        options={{ syncWithLocation: true, warnWhenUnsavedChanges: true }}
      >
        <Routes>
          <Route element={<AuthLayout />}>
            {/* These paths line up 1:1 with the resource route strings above. */}
            <Route index element={<NavigateToResource resource="candidates" />} />
            <Route path="/candidates">
              <Route index element={<CandidateList />} />
              <Route path="create" element={<CandidateCreate />} />
              <Route path="edit/:id" element={<CandidateEdit />} />
              <Route path="show/:id" element={<CandidateShow />} />
            </Route>
          </Route>
          <Route path="/login" element={<LoginPage />} />
        </Routes>
        <UnsavedChangesNotifier />
        <DocumentTitleHandler />
      </Refine>
    </BrowserRouter>
  )
}
```

### `dataProvider` wired to Supabase (anon key + RLS, server-side list ops)

The `@refinedev/supabase` `dataProvider` translates Refine's `getList` pagination/sort/filter descriptors into PostgREST `range()`/`order()`/filter calls against the same Supabase client the rest of the app uses. RLS scopes every result — the provider never adds an authorization filter of its own.

```ts
// src/lib/supabase.ts
import { createClient } from '@supabase/supabase-js'

// Single anon-key client for the whole app. No service_role key ever reaches
// this bundle — any VITE_-prefixed env var is inlined into the browser build.
export const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY,
  { auth: { persistSession: true, autoRefreshToken: true } },
)
```

```tsx
// src/features/candidates/CandidateList.tsx
import { useMemo } from 'react'
import { useTable } from '@refinedev/react-table'
import { type ColumnDef } from '@tanstack/react-table'
import type { HttpError } from '@refinedev/core'
import { DataTable } from '@/components/ui/data-table'

interface Candidate {
  id: string
  full_name: string
  stage: 'applied' | 'screening' | 'offer' | 'hired'
  created_at: string
}

export function CandidateList() {
  const columns = useMemo<ColumnDef<Candidate>[]>(
    () => [
      { id: 'full_name', accessorKey: 'full_name', header: 'Name' },
      { id: 'stage', accessorKey: 'stage', header: 'Stage', enableSorting: false },
      { id: 'created_at', accessorKey: 'created_at', header: 'Applied' },
    ],
    [],
  )

  // useTable resolves `resource: 'candidates'` from the route via routerProvider,
  // so it already knows the table. Pagination/sorting/filtering default to
  // server mode: page changes call the Supabase dataProvider's getList with the
  // right .range()/.order(), and RLS decides which rows come back.
  const {
    getHeaderGroups,
    getRowModel,
    refineCore: { tableQuery, setCurrent, current, pageCount },
  } = useTable<Candidate, HttpError>({ columns })

  return (
    <DataTable
      headerGroups={getHeaderGroups()}
      rows={getRowModel().rows}
      isLoading={tableQuery.isLoading}
      page={current}
      pageCount={pageCount}
      onPageChange={setCurrent}
    />
  )
}
```

### `authProvider` wired to Supabase Auth

`authProvider` is Refine's single session source: `check` gates every protected route, `onError` reacts to a Postgres/Auth 401/403, and `getIdentity` feeds the shell's user menu. There is one place session logic lives — components never call `supabase.auth` directly for these concerns.

```ts
// src/providers/authProvider.ts
import type { AuthProvider } from '@refinedev/core'
import { supabase } from '@/lib/supabase'

export const authProvider: AuthProvider = {
  login: async ({ email, password }: { email: string; password: string }) => {
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) {
      return { success: false, error: { name: 'LoginError', message: error.message } }
    }
    return { success: true, redirectTo: '/' }
  },

  logout: async () => {
    const { error } = await supabase.auth.signOut()
    if (error) {
      return { success: false, error: { name: 'LogoutError', message: error.message } }
    }
    return { success: true, redirectTo: '/login' }
  },

  // Runs before every protected route renders. Returning authenticated:false
  // with redirectTo means an expired/absent session never mounts a resource
  // screen — the same "guard before render" property as a route beforeLoad.
  check: async () => {
    const { data } = await supabase.auth.getSession()
    if (data.session) return { authenticated: true }
    return { authenticated: false, redirectTo: '/login', logout: true }
  },

  // Called when a data-provider request rejects. A 401/403 from PostgREST
  // (e.g. a JWT expired mid-session) triggers a clean logout + redirect
  // instead of leaving a half-authenticated screen showing stale data.
  onError: async (error) => {
    if (error?.statusCode === 401 || error?.statusCode === 403) {
      return { logout: true, redirectTo: '/login', error }
    }
    return {}
  },

  getIdentity: async () => {
    const { data } = await supabase.auth.getUser()
    if (!data.user) return null
    return {
      id: data.user.id,
      name: data.user.user_metadata?.full_name ?? data.user.email,
      email: data.user.email,
      avatar: data.user.user_metadata?.avatar_url,
    }
  },

  // Reads the caller's role. This drives UI affordances only — it is NOT the
  // authorization boundary (see accessControlProvider and Anti-Patterns).
  getPermissions: async () => {
    const { data } = await supabase.auth.getUser()
    if (!data.user) return null
    const { data: profile } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', data.user.id)
      .single()
    return profile?.role ?? 'member'
  },
}
```

### `accessControlProvider` mapping to roles — UI-hiding, not the boundary

```ts
// src/providers/accessControlProvider.ts
import type { AccessControlProvider } from '@refinedev/core'
import { authProvider } from './authProvider'

// Refine calls `can` to decide whether to render a create/edit/delete button
// or a nav item. It answers "should we SHOW this affordance to this operator",
// never "is this operator ALLOWED to perform it" — that answer lives in RLS.
// A returned `can: false` hides a button; it does not stop a crafted request.
export const accessControlProvider: AccessControlProvider = {
  can: async ({ resource, action }) => {
    const role = (await authProvider.getPermissions?.()) as string | null

    if (action === 'delete' && role !== 'admin') {
      return {
        can: false,
        reason: 'Only admins can delete records (enforced by RLS regardless).',
      }
    }
    if (resource === 'audit_log' && role !== 'admin') {
      return { can: false, reason: 'Admins only.' }
    }
    return { can: true }
  },
  options: { buttons: { enableAccessControl: true, hideIfUnauthorized: true } },
}
```

```sql
-- The REAL boundary the client-side `can` mirrors. Without this policy, hiding
-- the delete button changes nothing about what an anon-key caller can execute.
CREATE POLICY "only admins delete candidates"
ON public.candidates FOR DELETE
TO authenticated
USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');
```

### Integrating `useTable` with TanStack Table headless UI + shadcn/Radix

`@refinedev/react-table`'s `useTable` *is* a TanStack Table instance with a `refineCore` bag attached, so you render it with the exact same `flexRender` + shadcn `<Table>` primitives you'd use for a hand-rolled grid — Refine only supplies the data and the server-side pagination/sort wiring.

```tsx
// src/components/ui/data-table.tsx
import { flexRender, type HeaderGroup, type Row } from '@tanstack/react-table'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Button } from '@/components/ui/button'

interface DataTableProps<T> {
  headerGroups: HeaderGroup<T>[]
  rows: Row<T>[]
  isLoading: boolean
  page: number
  pageCount: number
  onPageChange: (page: number) => void
}

export function DataTable<T>({
  headerGroups,
  rows,
  isLoading,
  page,
  pageCount,
  onPageChange,
}: DataTableProps<T>) {
  return (
    <div className="space-y-3">
      <Table>
        <TableHeader>
          {headerGroups.map((hg) => (
            <TableRow key={hg.id}>
              {hg.headers.map((header) => (
                <TableHead
                  key={header.id}
                  // Refine drives server-side sort through the same TanStack
                  // handler — clicking re-issues getList with the new .order().
                  onClick={header.column.getToggleSortingHandler()}
                  className="cursor-pointer select-none"
                >
                  {flexRender(header.column.columnDef.header, header.getContext())}
                  {{ asc: ' ↑', desc: ' ↓' }[header.column.getIsSorted() as string] ?? null}
                </TableHead>
              ))}
            </TableRow>
          ))}
        </TableHeader>
        <TableBody>
          {rows.map((row) => (
            <TableRow key={row.id} data-state={isLoading ? 'loading' : undefined}>
              {row.getVisibleCells().map((cell) => (
                <TableCell key={cell.id}>
                  {flexRender(cell.column.columnDef.cell, cell.getContext())}
                </TableCell>
              ))}
            </TableRow>
          ))}
        </TableBody>
      </Table>
      <div className="flex items-center justify-end gap-2">
        <Button variant="outline" size="sm" disabled={page <= 1} onClick={() => onPageChange(page - 1)}>
          Previous
        </Button>
        <span className="text-sm text-muted-foreground">
          {page} / {Math.max(pageCount, 1)}
        </span>
        <Button variant="outline" size="sm" disabled={page >= pageCount} onClick={() => onPageChange(page + 1)}>
          Next
        </Button>
      </div>
    </div>
  )
}
```

### `i18nProvider` bridging react-intl

The panel already runs react-intl for its own screen copy. Rather than run a second catalog for Refine's framework strings (buttons, notification toasts, page titles), point Refine's `i18nProvider` at the same `IntlShape`, so both resolve from one `en.json`/`tr.json`.

```tsx
// src/providers/RefineWithI18n.tsx
import { useMemo, type ReactNode } from 'react'
import { useIntl } from 'react-intl'
import { Refine, type I18nProvider } from '@refinedev/core'

// Build the provider inside a child of <IntlProvider> so it closes over the
// live IntlShape. Refine calls translate(key, params, defaultMessage); react-intl
// wants formatMessage({ id, defaultMessage }, values) — this adapter is the bridge.
export function useRefineI18nProvider(): I18nProvider {
  const intl = useIntl()
  return useMemo<I18nProvider>(
    () => ({
      translate: (key, params?, defaultMessage?) =>
        intl.formatMessage(
          { id: key, defaultMessage: defaultMessage ?? key },
          params as Record<string, string | number> | undefined,
        ),
      changeLocale: (locale: string) => {
        // Persist and let the top-level <IntlProvider> re-render with the new
        // catalog; Refine re-reads translate() on the next render automatically.
        localStorage.setItem('locale', locale)
        window.location.reload()
        return Promise.resolve()
      },
      getLocale: () => intl.locale,
    }),
    [intl],
  )
}

export function RefineRoot({ children, ...providers }: { children: ReactNode } & Record<string, unknown>) {
  const i18nProvider = useRefineI18nProvider()
  return (
    <Refine i18nProvider={i18nProvider} {...providers}>
      {children}
    </Refine>
  )
}
```

## Why This Works

- **`resources` is a declaration, not glue code**: because every entity's URLs and capabilities live in one array, `useTable`/`useForm`/`useShow` and the navigation buttons all derive their target resource from the current route — adding a screen means adding a route entry, not re-wiring fetch + pagination + navigation by hand for each one.
- **The Supabase `dataProvider` keeps list operations server-side by construction**: Refine's `getList` descriptor maps directly onto PostgREST `range()`/`order()`/filter operators, so a 100k-row table paginates in the database, and RLS filters the result set before it ever leaves Postgres — the provider adds no client-side row filter to drift out of sync.
- **One `authProvider` means one session story**: `check` gates routes before render, `onError` converts a PostgREST 401/403 into a clean logout, and `getIdentity` feeds the shell — none of it duplicated across components calling `supabase.auth` ad hoc.
- **`accessControlProvider` and RLS answer two different questions**: `can` answers "render this button?" (UX); the RLS policy answers "may this row be deleted?" (security). Keeping the client check as a mirror of a policy that actually exists is fine; keeping it *instead* of the policy is the whole vulnerability.
- **Bridging `i18nProvider` onto react-intl avoids a second source of truth**: Refine's framework strings and the app's own strings resolve through the same `IntlShape` and the same ICU catalogs, so a Turkish translation is added once and covers both.

## Anti-Patterns

### 1. A `service_role` key (or any elevated key) inside a provider

**What it looks like:**
```ts
// BAD: reaching for service_role to "make the dataProvider just work" past an
// RLS policy that's rejecting a write. Any VITE_-prefixed var is inlined into
// the browser bundle — this hands every visitor full RLS bypass.
export const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_SERVICE_ROLE_KEY, // NEVER client-side
)
```
**Why it's wrong:** the panel is a pure static SPA with no trusted server; the anon key in the bundle is the entire credential a caller needs to hit PostgREST. A `service_role` key there is a full-database read/write leak to anyone who opens devtools.
**Instead:** keep the client on the anon key and fix the failing write in an RLS policy (`WITH CHECK`), or escalate the operation to a real backend endpoint (see `agents/admin-panel-architect.md` Escalation Paths). See `skills/supabase-rls-client-patterns.md`.

### 2. Treating `accessControlProvider` / `getPermissions` as the authorization boundary

**What it looks like:**
```ts
// BAD: the only thing standing between "member" and deleting candidates is this
// client-side branch. There is no `FOR DELETE` RLS policy behind it.
can: async ({ action }) => ({ can: action !== 'delete' || role === 'admin' })
```
**Why it's wrong:** `can` runs in the browser and only hides UI. A caller replays `supabase.from('candidates').delete().eq('id', …)` with the anon key and the delete succeeds, because RLS — not the provider — is what Postgres consults.
**Instead:** write the matching `FOR DELETE` policy (shown above) and keep `can` as a UX mirror of it, explicitly documented as convenience, not control.

### 3. Bypassing Refine's providers to call Supabase directly inside resource screens

**What it looks like:**
```tsx
// BAD: hand-rolling a mutation inside an edit screen, duplicating the auth,
// error-normalization, cache-invalidation and notification behavior the
// dataProvider + useForm already provide — and drifting out of sync with them.
async function save(values: Candidate) {
  await supabase.from('candidates').update(values).eq('id', id)
  // no optimistic UI, no Refine cache invalidation, no onError→logout wiring
}
```
**Why it's wrong:** it re-implements (inconsistently) exactly what `useForm`/`useUpdate` already do through the `dataProvider` — including invalidating the list cache, surfacing errors via `authProvider.onError`, and firing success notifications. The two paths diverge and the hand-rolled one silently skips the 401→logout behavior.
**Instead:** mutate through Refine's data hooks (`useForm`, `useUpdate`, `useDelete`); drop to a raw `supabase` call only for genuinely non-CRUD operations Refine doesn't model, and route those through a custom `dataProvider.custom` method so error handling stays uniform.

### 4. Running two i18n systems side by side

**What it looks like:**
```tsx
// BAD: Refine gets its own hardcoded English strings while the app uses react-intl,
// so a Turkish operator sees translated screens but English framework buttons/toasts.
<Refine /* no i18nProvider */>
```
**Why it's wrong:** framework strings (Save, Delete, "Successfully created") stay English regardless of the selected locale, and there are now two places to add a translation.
**Instead:** bridge `i18nProvider` onto the existing `IntlShape` (shown above) so both resolve from one catalog.

## Verification

```bash
# Type-check providers, resources, and the useTable generics
npx tsc --noEmit

# Confirm no elevated key is reachable from the bundle
grep -RIn "SERVICE_ROLE\|service_role" src .env* 2>/dev/null   # must return nothing

# Build and confirm the anon key (not service_role) is what got inlined
npx vite build && grep -c "VITE_SUPABASE_ANON_KEY" dist/assets/*.js 2>/dev/null || true
```

- [ ] Log in as a non-admin, confirm the delete button is hidden (accessControlProvider), THEN replay the delete via a raw `fetch`/`supabase` call and confirm **Postgres** rejects it — proving RLS, not the UI, is the boundary.
- [ ] Paginate/sort a large table and confirm each interaction issues one PostgREST request with the new `range`/`order` (Network tab), not a client-side re-sort of the current page.
- [ ] Expire the session (delete the auth cookie/token) and trigger any list fetch — confirm `authProvider.onError` logs out and redirects to `/login` with no stale rows left on screen.
- [ ] Switch the locale and confirm both app screens AND Refine's own buttons/notifications change language (i18nProvider bridge working).
- [ ] Add a new resource by adding one `resources[]` entry + its routes, and confirm list/create/edit/show navigate correctly with no per-screen fetch wiring added.

## References

- [Refine - Data Provider](https://refine.dev/docs/data/data-provider/)
- [Refine - Supabase Data Provider](https://refine.dev/docs/data/packages/supabase/)
- [Refine - Auth Provider](https://refine.dev/docs/authentication/auth-provider/)
- [Refine - Access Control Provider](https://refine.dev/docs/authorization/access-control-provider/)
- [Refine - `useTable` (`@refinedev/react-table`)](https://refine.dev/docs/packages/tanstack-table/use-table/)
- [Refine - i18n Provider](https://refine.dev/docs/i18n/i18n-provider/)
- [Supabase - Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
</content>
</invoke>
