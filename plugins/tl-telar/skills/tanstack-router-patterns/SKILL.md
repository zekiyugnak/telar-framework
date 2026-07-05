---
name: "tanstack-router-patterns"
description: "TanStack Router generates a fully typed route tree from your file structure, so navigating to `/users/$userId` fails to compile if `userId` is missing, and reading a search param fails to compile if you misspell its name"
source_type: "skill"
source_file: "skills/tanstack-router-patterns.md"
---

# tanstack-router-patterns

Migrated from `skills/tanstack-router-patterns.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Type-Safe Routing and Guards with TanStack Router

TanStack Router generates a fully typed route tree from your file structure, so navigating to `/users/$userId` fails to compile if `userId` is missing, and reading a search param fails to compile if you misspell its name. This skill covers file-based route layout, search-param validation, loaders paired with pending/error UI, code-splitting, and the `beforeLoad` guard pattern for protected routes.

## Problem

Hand-rolled routing (React Router's `<Route>` JSX trees, or ad-hoc `switch` statements on `window.location`) has no compile-time link between a route's declared params and the code that reads them. Search params in particular are usually read as raw strings with manual parsing scattered across components, and "protected route" is implemented as a render-time redirect that still mounts the protected screen for one frame first.

```tsx
// BAD: search params read as untyped strings, parsed ad hoc in the component
function UsersPage() {
  const [searchParams] = useSearchParams()
  const page = Number(searchParams.get('page')) || 1  // silently NaN-safe, but
  const status = searchParams.get('status')            // no validation that this
                                                          // is one of the allowed values
  // ...
}

// BAD: "protection" is a render-time effect, so the protected screen's own
// data-fetching hooks still fire before the redirect happens
function AdminOnlyRoute({ children }: { children: React.ReactNode }) {
  const { session, isLoading } = useAuth()
  useEffect(() => {
    if (!isLoading && !session) navigate('/login')
  }, [isLoading, session])
  return <>{children}</>  // renders once, unguarded, before the effect runs
}
```

## Solution

### File-based route layout

```text
src/routes/
├── __root.tsx                       # shell layout, always renders
├── login.tsx                        # public route
├── _authenticated.tsx               # pathless layout route — the beforeLoad guard lives here
├── _authenticated.index.tsx         # -> /  (dashboard)
├── _authenticated.users.tsx         # -> /users
├── _authenticated.users.$userId.tsx # -> /users/:userId
└── _authenticated.settings.tsx      # -> /settings
```

A leading underscore (`_authenticated`) marks a **pathless layout route** — it contributes no URL segment but wraps every child route, which is exactly where a single `beforeLoad` auth check belongs instead of being copy-pasted per screen.

### Type-safe search params

```tsx
// src/routes/_authenticated.users.tsx
import { createFileRoute } from '@tanstack/react-router'
import { z } from 'zod'

// zodValidator (or a plain function) turns the raw URLSearchParams into a
// typed, validated object. Anything that fails parsing throws before the
// route ever renders, and TypeScript infers the shape everywhere `Route.useSearch()`
// is called downstream.
const usersSearchSchema = z.object({
  page: z.number().catch(1),
  status: z.enum(['active', 'invited', 'disabled']).catch('active'),
  q: z.string().optional(),
})

export const Route = createFileRoute('/_authenticated/users')({
  validateSearch: usersSearchSchema,
  component: UsersRoute,
})

function UsersRoute() {
  // `search` is `{ page: number; status: 'active' | 'invited' | 'disabled'; q?: string }`
  // — fully typed, no manual parsing, no possibility of an invalid `status`.
  const search = Route.useSearch()
  const navigate = Route.useNavigate()

  return (
    <StatusFilter
      value={search.status}
      onChange={(status) => navigate({ search: (prev) => ({ ...prev, status, page: 1 }) })}
    />
  )
}
```

### Loaders paired with pending and error components

```tsx
// src/routes/_authenticated.users.$userId.tsx
import { createFileRoute, notFound } from '@tanstack/react-router'
import { userDetailQueryOptions } from '@/features/users/queries'

export const Route = createFileRoute('/_authenticated/users/$userId')({
  loader: async ({ context: { queryClient }, params }) => {
    const user = await queryClient
      .ensureQueryData(userDetailQueryOptions(params.userId))
      .catch(() => null)

    // Throwing notFound() short-circuits straight to notFoundComponent —
    // no need for the component body to handle a null-user branch itself.
    if (!user) throw notFound()
    return user
  },
  // Shown immediately while the loader is in flight, before any data exists.
  pendingComponent: () => <UserDetailSkeleton />,
  // Shown if the loader throws anything other than notFound().
  errorComponent: ({ error }) => <RouteErrorPanel error={error} />,
  notFoundComponent: () => <NotFoundPanel entity="user" />,
  component: UserDetailRoute,
})

function UserDetailRoute() {
  const user = Route.useLoaderData() // already resolved, non-null, fully typed
  return <UserDetailPanel user={user} />
}
```

### Code-splitting per route without manual `React.lazy`

```tsx
// src/routes/_authenticated.settings.tsx
// createLazyFileRoute keeps route config (loader, validateSearch, guards) in
// the "eager" .tsx file but defers the component's own bundle chunk until
// the route is actually visited — Vite splits it automatically.
import { createLazyFileRoute } from '@tanstack/react-router'

export const Route = createLazyFileRoute('/_authenticated/settings')({
  component: SettingsRoute,
})

function SettingsRoute() {
  return <SettingsPanel />
}
```

### Protected-route guard via `beforeLoad`

```tsx
// src/routes/_authenticated.tsx
import { createFileRoute, redirect } from '@tanstack/react-router'
import { supabase } from '@/lib/supabase'

export const Route = createFileRoute('/_authenticated')({
  // beforeLoad runs before ANY child route's loader or component executes.
  // Throwing redirect() here means the protected screen's component body
  // never mounts for an unauthenticated visitor — not even for one frame.
  beforeLoad: async ({ location }) => {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) {
      throw redirect({
        to: '/login',
        search: { redirectTo: location.href },
      })
    }
    // Returning data here makes it available to every descendant route's
    // loader via `context`, avoiding a second session fetch per route.
    return { session }
  },
  component: () => <Outlet />,
})
```

## Why This Works

- **Route tree generation is a build step, not a runtime guess**: the router CLI (or the Vite plugin) scans `routes/` and emits a `routeTree.gen.ts` file with exact literal types for every path and param. Navigating to a route that doesn't exist, or omitting a required param, is a TypeScript error at the call site.
- **`beforeLoad` runs strictly before rendering**: unlike a `useEffect`-based redirect, throwing inside `beforeLoad` (or a loader) aborts the navigation before the component tree for that route — or any nested route — is constructed, so there's no unauthenticated flash and no wasted data fetch.
- **`validateSearch` makes bad URLs a controlled failure, not a silent bug**: a manually crafted or bookmarked URL with `?status=deleted` fails validation predictably (via `.catch()` fallback or a thrown error), instead of `status` silently being the literal string `"deleted"` deep inside a component that assumed a closed enum.
- **`createLazyFileRoute` separates route metadata from the component bundle**: the router needs `validateSearch`/`loader`/`beforeLoad` synchronously to plan navigation, but the actual screen JSX can load lazily, keeping the main bundle small for an admin panel with dozens of rarely visited settings screens.

## Edge Cases & Pitfalls

### Common Mistakes

- **Putting `beforeLoad` on every leaf route instead of one shared pathless layout route**: duplicating the session check per screen means it's easy to add a new route and forget the guard. Centralize it once on `_authenticated.tsx`.
- **Returning `redirect()` instead of throwing it**: `redirect()` and `notFound()` are only special-cased by the router when *thrown*. Returning them from `beforeLoad` or a loader does nothing and the route renders normally with a `redirect` object floating around as if it were data.
- **Using `useSearch()` from a parent route's context to read a child route's params**: search params are scoped to the route they're declared on. Reading them from the wrong route in the tree returns `undefined` typed as if it were present, unless `strict: false` is explicitly opted into.
- **Forgetting `.catch()` (or an equivalent default) in `validateSearch`**: without it, a malformed query string throws and the user sees a hard error boundary instead of falling back to sane defaults — usually the wrong tradeoff for filter/pagination state that's fine to reset.
- **Re-fetching the session in every route's loader instead of reading it from `beforeLoad`'s returned context**: the guard already fetched it once; propagate it through `context` rather than calling `supabase.auth.getSession()` again per route.

## Verification

```bash
# Regenerate the route tree after adding/renaming a route file
npx tsr generate

# Type-check — a missing/misspelled route path or param shows up here
npx tsc --noEmit
```

- [ ] Navigate directly to a deep URL for a protected route while logged out — confirm you land on `/login` with no flash of the protected screen.
- [ ] Bookmark a URL with an invalid search param value (e.g. `?status=bogus`) and reload — confirm it falls back to the default instead of crashing.
- [ ] Check the network tab on first load of a rarely visited settings route — confirm its component chunk is a separate lazy-loaded file, not part of the main bundle.
- [ ] Trigger a loader error (e.g. disconnect network) on a detail route — confirm `errorComponent` renders instead of an unhandled promise rejection.

## References

- [TanStack Router - File-Based Routing](https://tanstack.com/router/latest/docs/framework/react/routing/file-based-routing)
- [TanStack Router - Search Params](https://tanstack.com/router/latest/docs/framework/react/guide/search-params)
- [TanStack Router - Authenticated Routes](https://tanstack.com/router/latest/docs/framework/react/guide/authenticated-routes)
- [TanStack Router - Code Splitting](https://tanstack.com/router/latest/docs/framework/react/guide/code-splitting)
- [TanStack Router - Data Loading](https://tanstack.com/router/latest/docs/framework/react/guide/data-loading)
