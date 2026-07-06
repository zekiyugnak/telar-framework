---
name: "nextjs-auth-app-router"
description: "A Next.js App Router console needs two different session checks that are easy to conflate into one: a fast, edge-level check in `middleware.ts` that redirects unauthenticated visitors before a page even starts rendering,"
source_type: "skill"
source_file: "skills/nextjs-auth-app-router.md"
---

# nextjs-auth-app-router

Migrated from `skills/nextjs-auth-app-router.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Verify Sessions in Middleware for UX, Re-Verify in Server Components for Authorization

A Next.js App Router console needs two different session checks that are easy to conflate into one: a fast, edge-level check in `middleware.ts` that redirects unauthenticated visitors before a page even starts rendering, and a re-verification inside every Server Component or Route Handler that actually reads or writes data, which is the real authorization boundary. Treating the middleware check as sufficient, or reading a locally-cached session instead of validating it with the auth server, both open the same hole: a stale, forged, or replayed cookie reaching a data path unchecked. This skill is the web/cookie-session counterpart to `skills/supabase-auth.md`, which covers PKCE flows for React Native and Flutter — on the web, sessions live in HTTP-only cookies managed by `@supabase/ssr`, not in device secure storage.

## Problem

```typescript
// BAD: middleware redirects unauthenticated visitors, so this Route
// Handler assumes any request that reaches it is already authorized.
// A cached response, a direct API call bypassing the matcher, or a
// request against a route excluded from the middleware matcher all
// slip through with zero authorization.
// app/api/invoices/[id]/route.ts
export async function DELETE(_req: Request, { params }: { params: { id: string } }) {
  await supabase.from('invoices').delete().eq('id', params.id)
  return Response.json({ ok: true })
}
```

```tsx
// BAD: getSession() reads the JWT straight out of the cookie without
// contacting Supabase. A tampered or stale cookie passes this check
// even though the underlying session was revoked or expired.
export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const { data: { session } } = await supabase.auth.getSession()
  if (!session) redirect('/login')
  return <>{children}</>
}
```

```tsx
// BAD: a client-side AuthProvider fetching the session in useEffect as
// the only gate for an SSR'd page. The protected content either flashes
// briefly before the effect runs, or the page has to render a loading
// spinner shell that defeats the point of server rendering it at all.
'use client'
function AuthGate({ children }: { children: React.ReactNode }) {
  const [session, setSession] = useState<Session | null>(null)
  const [loading, setLoading] = useState(true)
  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session)
      setLoading(false)
    })
  }, [])
  if (loading) return <Spinner />
  if (!session) return <LoginPrompt />
  return <>{children}</>
}
```

## Solution

### Three Supabase SSR clients, one per execution context

```typescript
// lib/supabase/client.ts — Client Components only (rare in this
// architecture; most reads/writes happen in Server Components/Actions)
import { createBrowserClient } from '@supabase/ssr'

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  )
}
```

```typescript
// lib/supabase/server.ts — Server Components, Server Actions, Route
// Handlers. A new client is created per call because it closes over
// the current request's cookies; a module-level singleton would leak
// one user's session into another user's request in a shared runtime.
import { cookies } from 'next/headers'
import { createServerClient } from '@supabase/ssr'

export async function createClient() {
  const cookieStore = await cookies()

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll()
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            )
          } catch {
            // setAll throws when called from a Server Component render
            // (cookies are read-only there, not in Server Actions/Route
            // Handlers). Safe to ignore as long as middleware also
            // refreshes the session on every navigation.
          }
        },
      },
    }
  )
}
```

```typescript
// lib/supabase/middleware.ts
import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

export function createMiddlewareClient(request: NextRequest) {
  let response = NextResponse.next({ request })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll()
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value))
          response = NextResponse.next({ request })
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options)
          )
        },
      },
    }
  )

  return { supabase, response }
}
```

### Middleware: the fast UX gate, not the authorization boundary

```typescript
// middleware.ts
import { NextResponse, type NextRequest } from 'next/server'
import { createMiddlewareClient } from '@/lib/supabase/middleware'

export async function middleware(request: NextRequest) {
  const { supabase, response } = createMiddlewareClient(request)

  // This call both reads AND refreshes the session cookie if the access
  // token is close to expiry. It is the only place session refresh
  // needs to be triggered — Server Components never mutate cookies.
  const {
    data: { user },
  } = await supabase.auth.getUser()

  if (!user && !request.nextUrl.pathname.startsWith('/login')) {
    const url = request.nextUrl.clone()
    url.pathname = '/login'
    url.searchParams.set('redirectTo', request.nextUrl.pathname)
    // A bare `Response.redirect(url)` builds a brand-new Response, which
    // drops any refreshed auth cookies that `getUser()` just set on
    // `response` above. Redirect through NextResponse and carry those
    // cookies over explicitly, or a refreshed-but-redirected request can
    // loop or silently lose its new session.
    const redirectResponse = NextResponse.redirect(url)
    response.cookies.getAll().forEach((cookie) => redirectResponse.cookies.set(cookie))
    return redirectResponse
  }

  return response
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
}
```

### Server Component: the real authorization boundary

```tsx
// app/(dashboard)/layout.tsx
import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'

export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createClient()

  // getUser() validates the JWT against Supabase's auth server — it is
  // the source of truth. Middleware already redirected most
  // unauthenticated visitors, but a stale/tampered cookie or a cached
  // response could still reach this layout directly; never skip this.
  const {
    data: { user },
    error,
  } = await supabase.auth.getUser()
  if (error || !user) redirect('/login')

  // Pass the verified user down through props. No client-side
  // AuthContext/useEffect fetch is needed for the initial render — the
  // Server Component tree already has the data, synchronously available
  // to every child that needs it.
  return <DashboardShell user={user}>{children}</DashboardShell>
}
```

```tsx
// components/dashboard/shell.tsx
import type { User } from '@supabase/supabase-js'

export function DashboardShell({
  user,
  children,
}: {
  user: User
  children: React.ReactNode
}) {
  return (
    <div className="flex min-h-screen">
      <aside className="w-64 border-r p-4">
        <p className="text-sm text-muted-foreground">{user.email}</p>
      </aside>
      <main className="flex-1 p-6">{children}</main>
    </div>
  )
}
```

### Route Handler: re-verify and scope the query

```typescript
// app/api/invoices/[id]/route.ts
import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

export async function DELETE(
  _req: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const { id } = await params
  const { error } = await supabase
    .from('invoices')
    .delete()
    .eq('id', id)
    .eq('created_by', user.id) // scope to the authenticated user's own rows

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 400 })
  }
  return NextResponse.json({ success: true })
}
```

## Why This Works

- **`getUser()` contacts Supabase; `getSession()` does not.** `getSession()` decodes the JWT already sitting in cookies — fast, but it trusts whatever is on disk. `getUser()` round-trips to the auth server, so a revoked or forged session is caught immediately. Use `getSession()` only for non-security-sensitive UI decisions (e.g. "should I show a login button"), never as a gate before a data read or write.
- **Middleware and Server Components solve different problems.** Middleware runs once per navigation at the edge and is the cheapest place to reject an obviously unauthenticated request — but it cannot see route-specific authorization rules (e.g. "does this user belong to this company"). Server Components and Route Handlers run exactly where the data access happens, so that's where the real check has to live.
- **Server Components eliminate an entire class of client-side auth-state bugs.** Because the verified `user` object is available synchronously during server rendering, there is no loading state, no flash of unauthenticated content, and no hydration mismatch between what the server rendered and what a client-side auth check would compute a moment later.
- **A new server client per request prevents cross-user leakage.** The `@supabase/ssr` server client closes over the current request's cookies. Caching or reusing one instance across requests in a shared module scope (common in serverless/edge runtimes that reuse warm instances) would let one user's session bleed into another user's request.

## Edge Cases & Pitfalls

### Runtime-Specific Gotchas

**Edge Runtime (middleware):**
- Middleware runs on the Edge Runtime, not Node — no Node-only APIs are available. `@supabase/ssr`'s cookie adapter works fine here, but anything needing `service_role` privileges or heavier server SDKs belongs in a Route Handler on the Node runtime instead.
- Edge middleware has a strict CPU/time budget per request; keep the `getUser()` call as the only real work done per request in the gate — don't add extra database queries there.

**Node Runtime (Server Components / Route Handlers):**
- Server Components can only *read* cookies, not set them (a Next.js restriction) — the `try/catch` around `setAll` above swallows the resulting error; the actual cookie refresh happens in middleware, which runs on every navigation anyway.
- A statically rendered or `fetch`-cached Server Component can serve a stale `user` snapshot across requests if you're not careful. Auth-gated layouts should generally be dynamically rendered (the `cookies()` call already forces this) rather than opted into the Data Cache.

### Common Mistakes

- Using `getSession()` instead of `getUser()` anywhere a request result feeds into a data read or write — this is the single most common way to accidentally accept a stale or forged session.
- Declaring a Supabase client at module scope (`export const supabase = createServerClient(...)`) instead of creating one per request inside `createClient()` — this can leak session state across concurrent requests in serverless/edge environments where module scope persists between invocations.
- Relying on a client-side `AuthProvider` with `onAuthStateChange` as the *only* gate for an SSR'd page. It is the right tool for reacting to sign-out or token-refresh events *after* the authenticated Server Component tree has already rendered — not for the initial authorization decision.
- Excluding too little from the middleware `matcher`, causing every static asset request (images, fonts) to also pay for a Supabase round trip.
- Skipping Row Level Security on the database because "the route is already gated." Route/layout checks gate navigation; without RLS keyed off `auth.uid()`, a user who reaches an API can still query another company's rows if `company_id`/`created_by` isn't enforced at the Postgres level, not just in application code.

## Verification

```bash
# Confirm an unauthenticated request to a protected route is redirected
curl -i http://localhost:3000/invoices | grep -i location

# Confirm a Route Handler rejects a request with no session cookie
curl -i -X DELETE http://localhost:3000/api/invoices/123

# Inspect the Supabase auth cookies set after login
curl -i -c cookies.txt -X POST http://localhost:3000/login -d "email=...&password=..."
cat cookies.txt
```

- [ ] Visiting a protected route while signed out redirects to `/login` with a `redirectTo` param
- [ ] Visiting `/login` while already signed in redirects away from the auth shell
- [ ] Revoking a session from the Supabase dashboard causes the next Server Component render to redirect to `/login`, not silently serve stale data
- [ ] A Route Handler called with no cookies returns `401`, not a successful mutation
- [ ] Deleting/updating a row via a Route Handler only succeeds for rows the authenticated user actually owns (RLS + explicit `.eq()` scoping both enforced)
- [ ] No client-side loading spinner is visible on first paint of an authenticated dashboard route

## References

- [Next.js Middleware](https://nextjs.org/docs/app/building-your-application/routing/middleware)
- [Next.js Authentication](https://nextjs.org/docs/app/guides/authentication)
- [Next.js Route Handlers](https://nextjs.org/docs/app/building-your-application/routing/route-handlers)
- [Supabase Auth with Next.js (`@supabase/ssr`)](https://supabase.com/docs/guides/auth/server-side/nextjs)
- [Supabase — Server-Side Auth Overview](https://supabase.com/docs/guides/auth/server-side-rendering)
- Mobile PKCE flows: `skills/supabase-auth.md` (this plugin) — the React Native/Flutter equivalent for device-stored sessions
