---
id: web-state-management
category: skill
impact: HIGH
impactDescription: "Prevents the most common React/TS architecture mistake — server data leaking into global stores — and keeps re-renders minimal by matching the right tool to each state category"
tags: [state-management, zustand, redux-toolkit, jotai, signals, tanstack-query, web]
capabilities:
  - Deciding which tool owns each piece of state (server vs client vs URL vs local)
  - Zustand slice pattern with typed selectors that avoid whole-store subscriptions
  - Persist middleware for client-only state that survives page refresh
  - When to reach for Redux Toolkit over Zustand (and when not to)
  - Jotai atoms and signals for fine-grained, leaf-level reactive state
  - URL search-param state for shareable, bookmarkable UI
useWhen:
  - Starting a new React/TS feature and deciding where state lives
  - A component re-renders too often despite no relevant data changing
  - Server data keeps going stale in a global store after a mutation
  - Choosing between Zustand, Redux Toolkit, and Jotai for a new project
  - URL state (filters, page, selected id) needs to survive a browser refresh
---

# Client State Boundaries and the Server-State Rule

The single biggest cause of stale-data bugs in React apps is putting server state in a global store. Server state — anything fetched from an API — already has a cache manager in TanStack Query (see `tanstack-query-patterns`). Global stores are for genuine client state: UI toggles, wizard step, selected theme, shopping cart draft — things that only exist in the browser and are not the authoritative copy of any backend record.

## The Decision List

| State category | Right tool | Wrong tool |
|---|---|---|
| Remote data (API response) | TanStack Query | Zustand / Redux |
| UI toggle, wizard step, dialog open | `useState` / Zustand | TanStack Query |
| Cross-route shared UI state | Zustand | React Context (high-frequency) |
| Low-frequency wide values (theme, locale, auth user) | React Context | Zustand (overkill) |
| Filter / sort / page (shareable URL) | URL search params | Zustand |
| Atomic leaf state updated at high frequency | Jotai / signals | Redux |
| Complex async flows, time-travel devtools, middleware chain | Redux Toolkit | Zustand |
| Local component state not shared | `useState` / `useReducer` | Any global store |

## Problem

```tsx
// BAD: server data stored in Zustand — now there are two sources of truth.
// After a mutation the Zustand slice is stale until someone manually syncs it.
interface ProductStore {
  products: Product[]          // THIS is server data — it belongs in TanStack Query
  selectedCategory: string     // THIS is client state — fine here
  fetchProducts: () => void    // manual fetch re-invents the query cache
}

// BAD: one giant store with everything — every component re-renders on any change
const useStore = create<ProductStore & CartStore & UserStore & UIStore>(...)

// BAD: Context used for high-frequency state (e.g. cursor position, scroll offset)
// Every consumer re-renders on every update, even if it only reads unrelated fields
const AppContext = createContext<{ cart: CartItem[]; setCursor: ... }>()
```

## Solution

### The server-state boundary — keep API data in TanStack Query only

```tsx
// src/features/products/queries.ts  (cross-reference tanstack-query-patterns)
export const productKeys = {
  all: ['products'] as const,
  list: (category: string) => [...productKeys.all, 'list', category] as const,
}

export const useProducts = (category: string) =>
  useQuery({
    queryKey: productKeys.list(category),
    queryFn: () => api.getProducts(category),
    staleTime: 5 * 60 * 1000,
  })

// The Zustand store ONLY holds selectedCategory — the client-side choice.
// The products themselves live in TanStack Query's cache.
export const useUIStore = create<{ selectedCategory: string; setCategory: (c: string) => void }>(
  (set) => ({
    selectedCategory: 'all',
    setCategory: (selectedCategory) => set({ selectedCategory }),
  })
)
```

### Zustand — slices, typed selectors, persist

```tsx
// src/stores/cartStore.ts
import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'

interface CartState {
  items: CartItem[]
  addItem: (item: Omit<CartItem, 'quantity'>) => void
  removeItem: (id: string) => void
  clear: () => void
}

export const useCartStore = create<CartState>()(
  persist(
    (set) => ({
      items: [],
      addItem: (item) =>
        set((s) => {
          const existing = s.items.find((i) => i.id === item.id)
          return existing
            ? { items: s.items.map((i) => (i.id === item.id ? { ...i, quantity: i.quantity + 1 } : i)) }
            : { items: [...s.items, { ...item, quantity: 1 }] }
        }),
      removeItem: (id) => set((s) => ({ items: s.items.filter((i) => i.id !== id) })),
      clear: () => set({ items: [] }),
    }),
    { name: 'cart', storage: createJSONStorage(() => localStorage) }
  )
)

// Granular selectors — each component subscribes only to what it renders.
// CartBadge re-renders only when item count changes, not when item names change.
export const useCartCount = () => useCartStore((s) => s.items.length)
export const useCartTotal = () =>
  useCartStore((s) => s.items.reduce((sum, i) => sum + i.price * i.quantity, 0))
// For multi-field reads use useShallow to avoid creating a new object every render:
// import { useShallow } from 'zustand/react/shallow'
// const { count, total } = useCartStore(useShallow((s) => ({ count: s.items.length, total: ... })))
```

### URL as state for shareable filters

```tsx
// src/features/products/ProductsPage.tsx
// Filters belong in the URL so the user can bookmark ?category=electronics&page=2
import { useSearchParams } from 'react-router-dom'  // or TanStack Router's useSearch

function ProductsPage() {
  const [params, setParams] = useSearchParams()
  const category = params.get('category') ?? 'all'
  const page = Number(params.get('page') ?? '1')

  // Changing the URL triggers TanStack Query's queryKey to change and re-fetches.
  // No extra store entry needed — the URL IS the state.
  const { data } = useProducts(category)

  return (
    <>
      <CategoryPicker value={category} onChange={(c) => setParams({ category: c, page: '1' })} />
      <ProductGrid products={data} page={page} />
    </>
  )
}
```

### Jotai — atomic, fine-grained state

```tsx
// Jotai suits UI state that is local-ish but crosses a few components,
// or derived computations you want to memoize at the atom level.
import { atom, useAtom, useAtomValue } from 'jotai'

const sidebarOpenAtom = atom(false)
const themeModeAtom = atom<'light' | 'dark'>('light')
// Derived atom — only recomputes when themeModeAtom changes
const isDarkAtom = atom((get) => get(themeModeAtom) === 'dark')

// Components subscribe to a single atom; unrelated atom changes cause no re-render.
function Sidebar() {
  const [open, setOpen] = useAtom(sidebarOpenAtom)
  return <aside aria-hidden={!open}>...</aside>
}
```

### Redux Toolkit — when scale justifies it

Reach for Redux Toolkit when: (a) you need time-travel debugging via Redux DevTools, (b) you have complex async middleware (RTK Query, redux-saga), or (c) a large team needs strict action-traceability. For most admin panels and consumer apps, Zustand + TanStack Query is the right default.

```tsx
// RTK slice — if you've already chosen Redux Toolkit
import { createSlice, PayloadAction } from '@reduxjs/toolkit'

const uiSlice = createSlice({
  name: 'ui',
  initialState: { sidebarOpen: false, activeModal: null as string | null },
  reducers: {
    toggleSidebar: (s) => { s.sidebarOpen = !s.sidebarOpen },
    openModal: (s, a: PayloadAction<string>) => { s.activeModal = a.payload },
    closeModal: (s) => { s.activeModal = null },
  },
})
```

## Why This Works

- **Server state has one owner**: TanStack Query's cache is the single source of truth for API data. Mutations trigger `invalidateQueries`, and every component reading that key automatically gets fresh data — no manual sync step.
- **Granular Zustand selectors break re-render chains**: subscribing to `(s) => s.items.length` instead of `(s) => s` means Zustand only notifies this component when `length` changes by reference equality, not on every unrelated mutation.
- **URL state is free persistence**: filters stored in search params survive refresh, back-navigation, and copy-paste sharing without any store hydration code.
- **Jotai atoms are tree-independent**: each atom is a standalone reactive cell; derived atoms recompute lazily only when their dependencies change.

## Edge Cases & Pitfalls

### Common Mistakes

- **Syncing server data into Zustand after a fetch**: creates a stale second copy. Delete the Zustand field; read directly from `useQuery`.
- **Inline selector creating a new object**: `useStore((s) => ({ a: s.a, b: s.b }))` returns a new object on every render. Wrap with `useShallow` or split into two selectors.
- **Persisting everything**: do not persist loading states, error objects, or data that TanStack Query already caches. Persist only source-of-truth client values (theme, cart draft, onboarding flags).
- **Context for high-frequency state**: React Context triggers a full subtree re-render on every value change. Use Zustand or Jotai for anything updated more than a few times per second.
- **One giant Zustand store**: slicing into feature-scoped stores (`useCartStore`, `useUIStore`) limits subscription scope and makes each slice independently testable.

## Verification

```bash
# React DevTools Profiler: change theme, confirm unrelated components do not appear
# in the "Why did this render?" list
npm run dev
```

- [ ] Mutate a server resource; confirm the Zustand store has no field for that data and the UI updates via TanStack Query cache invalidation only.
- [ ] Change a filter; confirm the URL search param updates and the browser Back button restores the previous filter correctly.
- [ ] Trigger a Zustand action; open React DevTools Profiler and confirm only the component subscribed to the changed slice re-renders.
- [ ] Reload the page; confirm Zustand-persisted client state (cart, theme) is restored, and server data is re-fetched fresh by TanStack Query.

## References

- [Zustand Documentation](https://docs.pmnd.rs/zustand)
- [Zustand — useShallow](https://docs.pmnd.rs/zustand/guides/prevent-rerenders-with-use-shallow)
- [Zustand Persist Middleware](https://docs.pmnd.rs/zustand/integrations/persisting-store-data)
- [Jotai Documentation](https://jotai.org/docs/introduction)
- [TanStack Query — Server state vs client state](https://tanstack.com/query/latest/docs/framework/react/guides/does-this-replace-client-state-managers)
- [Redux Toolkit — When to use](https://redux.js.org/faq/general#when-should-i-use-redux)
