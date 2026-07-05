---
name: "tanstack-query-patterns"
description: "TanStack Query is the cache layer between the admin panel's UI and Supabase's PostgREST API. This skill covers structuring query keys so invalidation is precise instead of a blunt `invalidateQueries()` on everything, sha"
source_type: "skill"
source_file: "skills/tanstack-query-patterns.md"
---

# tanstack-query-patterns

Migrated from `skills/tanstack-query-patterns.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Query Key Factories, Loader Integration, and Realtime Cache Sync

TanStack Query is the cache layer between the admin panel's UI and Supabase's PostgREST API. This skill covers structuring query keys so invalidation is precise instead of a blunt `invalidateQueries()` on everything, sharing one cache entry between a TanStack Router loader and the component it renders, doing optimistic updates safely, and keeping the cache in sync with Supabase Realtime so one operator's edit shows up for everyone else without a manual refresh.

## Problem

Without a deliberate key structure, query keys tend to be ad hoc strings duplicated across files, which makes invalidation either too broad (refetch everything, causing loading flicker across the whole app) or too narrow (miss a related cache entry, leaving stale data on screen).

```tsx
// BAD: inline, inconsistent query keys scattered across files
// features/users/UsersTable.tsx
useQuery({ queryKey: ['users'], queryFn: fetchUsers })

// features/users/UserDetailPanel.tsx
useQuery({ queryKey: ['user', userId], queryFn: () => fetchUser(userId) })

// features/users/EditUserForm.tsx — after saving, which keys need invalidating?
// Easy to forget 'users' (the list) still shows the old role for this user.
await updateUser(userId, changes)
queryClient.invalidateQueries({ queryKey: ['user', userId] })
```

```tsx
// BAD: loader and component each fetch independently — the loader's fetch
// is wasted because the component's useQuery call uses a different key
// and can't find the cache entry the loader already populated
export const Route = createFileRoute('/_authenticated/users')({
  loader: () => fetchUsers(), // fire-and-forget, result discarded
  component: () => {
    const { data } = useQuery({ queryKey: ['all-users'], queryFn: fetchUsers }) // refetches
    return <UsersTable data={data} />
  },
})
```

## Solution

### Query key factory

```ts
// src/features/users/queries.ts
import { queryOptions } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'

// A factory keeps every key for this feature in one place and typed, so
// invalidateQueries({ queryKey: userKeys.all }) reliably hits every
// related entry, and nothing can misspell 'users' vs 'Users' vs 'user-list'.
export const userKeys = {
  all: ['users'] as const,
  lists: () => [...userKeys.all, 'list'] as const,
  list: (filters: { status: string; page: number }) =>
    [...userKeys.lists(), filters] as const,
  details: () => [...userKeys.all, 'detail'] as const,
  detail: (userId: string) => [...userKeys.details(), userId] as const,
}

export const userListQueryOptions = (filters: { status: string; page: number }) =>
  queryOptions({
    queryKey: userKeys.list(filters),
    queryFn: async () => {
      const { data, error } = await supabase
        .from('users')
        .select('id, email, role, status')
        .eq('status', filters.status)
        .range(filters.page * 25, filters.page * 25 + 24)
      if (error) throw error
      return data
    },
  })

export const userDetailQueryOptions = (userId: string) =>
  queryOptions({
    queryKey: userKeys.detail(userId),
    queryFn: async () => {
      const { data, error } = await supabase
        .from('users')
        .select('*')
        .eq('id', userId)
        .single()
      if (error) throw error
      return data
    },
  })
```

### Sharing one cache entry between a router loader and the component

```tsx
// src/routes/_authenticated.users.$userId.tsx
import { createFileRoute } from '@tanstack/react-router'
import { userDetailQueryOptions } from '@/features/users/queries'

export const Route = createFileRoute('/_authenticated/users/$userId')({
  // ensureQueryData uses the SAME queryOptions object (same key) the
  // component below will read via useSuspenseQuery, so the loader's fetch
  // and the component's read are the same cache entry — one network call.
  loader: ({ context: { queryClient }, params }) =>
    queryClient.ensureQueryData(userDetailQueryOptions(params.userId)),
  component: UserDetailRoute,
})

function UserDetailRoute() {
  const { userId } = Route.useParams()
  // Reads the cache entry the loader already warmed. If the user navigates
  // back to this route later within staleTime, no refetch happens at all.
  const { data: user } = useSuspenseQuery(userDetailQueryOptions(userId))
  return <UserDetailPanel user={user} />
}
```

### Optimistic update with rollback

```tsx
// src/features/users/useUpdateUserRole.ts
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { userKeys } from './queries'

export function useUpdateUserRole(userId: string) {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (role: string) => {
      const { error } = await supabase.from('users').update({ role }).eq('id', userId)
      // RLS still enforces who is actually allowed to perform this update;
      // this optimistic update is a UX affordance, not the authorization check.
      if (error) throw error
    },
    onMutate: async (newRole) => {
      await queryClient.cancelQueries({ queryKey: userKeys.detail(userId) })
      const previous = queryClient.getQueryData(userKeys.detail(userId))

      queryClient.setQueryData(userKeys.detail(userId), (old: any) =>
        old ? { ...old, role: newRole } : old
      )

      // Return the snapshot so onError can roll back to exactly this state.
      return { previous }
    },
    onError: (_err, _newRole, context) => {
      if (context?.previous) {
        queryClient.setQueryData(userKeys.detail(userId), context.previous)
      }
    },
    onSettled: () => {
      // Reconcile with the server regardless of outcome — covers cases
      // where a trigger or RLS-side default changed something beyond `role`.
      queryClient.invalidateQueries({ queryKey: userKeys.detail(userId) })
      queryClient.invalidateQueries({ queryKey: userKeys.lists() })
    },
  })
}
```

### Supabase Realtime keeping the cache in sync across operators

```tsx
// src/features/users/useUsersRealtimeSync.ts
import { useEffect } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { userKeys } from './queries'

// Mount once near the top of the users feature (e.g. in the route's layout)
// so any operator's INSERT/UPDATE/DELETE on `users` invalidates the cache
// for every other operator's open tab, without a client-side polling loop.
export function useUsersRealtimeSync() {
  const queryClient = useQueryClient()

  useEffect(() => {
    const channel = supabase
      .channel('users-changes')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'users' },
        (payload) => {
          // Broad invalidation is fine here — user list/detail queries are
          // cheap. For expensive queries, patch setQueryData directly using
          // payload.new instead of invalidating.
          queryClient.invalidateQueries({ queryKey: userKeys.all })
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [queryClient])
}
```

## Why This Works

- **Hierarchical keys make invalidation composable**: `invalidateQueries({ queryKey: userKeys.all })` matches every key that starts with `['users']` by default (TanStack Query does prefix matching), so a single call safely covers lists and every detail entry without enumerating them.
- **`queryOptions()` is the single source of truth for a query's identity**: passing the exact same `queryOptions()` result to both `queryClient.ensureQueryData` in a loader and `useSuspenseQuery` in a component guarantees they resolve to the identical cache entry — there is no possibility of the key drifting between the two call sites because it's defined once.
- **Optimistic updates need a matched `onMutate`/`onError` pair, not just an optimistic write**: `onMutate` must return the previous value, and `onError` must restore it, or a failed mutation leaves the UI silently wrong until the next full refetch.
- **Realtime subscriptions turn Supabase into a live cache invalidation signal**: `postgres_changes` fires over the same Realtime websocket regardless of which client made the change, so `queryClient.invalidateQueries` runs for every connected operator, not just the one who triggered the mutation — this is what makes a shared admin panel feel live without manual polling.

## Edge Cases & Pitfalls

### Common Mistakes

- **Passing a raw array key to `useQuery` in the component but a differently-shaped array in the loader**: even a reordered filter object inside the key (`{ status, page }` vs `{ page, status }`) can produce a different serialized key depending on TanStack Query's version/config. Always derive both from the same `queryOptions()` factory function.
- **Calling `invalidateQueries()` with no key at all** during development "to be safe": this invalidates the entire cache, causing every mounted query across the whole app to refetch simultaneously — visible as a full-page loading flicker on an admin panel with many concurrent widgets.
- **Forgetting `queryClient.cancelQueries()` in `onMutate`**: an in-flight refetch that resolves after the optimistic write can silently overwrite the optimistic state with stale data before the mutation itself even completes.
- **Subscribing to `postgres_changes` on `*` events for a high-write table without payload-level patching**: broad invalidation is fine for low-frequency tables, but on a table with frequent writes (e.g. an audit log), prefer patching `setQueryData` directly from `payload.new`/`payload.old` to avoid refetch storms.
- **Not unsubscribing the Realtime channel on unmount**: leaving `useEffect`'s cleanup out leaks a websocket subscription per mount, and after enough route visits the client accumulates duplicate `users-changes` channels all firing the same invalidation.

## Verification

```bash
# Open React Query Devtools during development to inspect key structure
# and confirm loader + component reads collapse into one cache entry
npm run dev
```

- [ ] Navigate to a detail route via a link (loader warms cache) — confirm the Network tab shows exactly one request, not two.
- [ ] Trigger the optimistic role-update mutation, then force the network request to fail (e.g. throttle to offline) — confirm the UI rolls back to the previous role.
- [ ] Open the same table in two browser tabs, edit a row in one — confirm the other tab's table updates without a manual refresh.
- [ ] Call `invalidateQueries({ queryKey: userKeys.detail(id) })` and confirm only that one row's related queries refetch, not the entire `users` list.

## References

- [TanStack Query - Query Keys](https://tanstack.com/query/latest/docs/framework/react/guides/query-keys)
- [TanStack Query - Query Options](https://tanstack.com/query/latest/docs/framework/react/guides/query-options)
- [TanStack Router - Integrating with TanStack Query](https://tanstack.com/router/latest/docs/framework/react/guide/data-loading#using-loaders-with-router-context)
- [TanStack Query - Optimistic Updates](https://tanstack.com/query/latest/docs/framework/react/guides/optimistic-updates)
- [Supabase - Realtime Postgres Changes](https://supabase.com/docs/guides/realtime/postgres-changes)
