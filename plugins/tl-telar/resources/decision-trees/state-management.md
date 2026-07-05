# State Management Decision Tree

Choose the right state management solution for your mobile app.

## React Native

```
START
├── Only need server state (API data)?
│   └── YES → TanStack React Query (alone)
├── Simple local UI state (< 5 shared values)?
│   └── YES → React Context + useReducer
├── Need persisted client state + server state?
│   └── YES → Zustand (client) + React Query (server)
├── Large team with strict architecture requirements?
│   └── YES → Redux Toolkit + RTK Query
├── Need real-time sync across devices?
│   └── YES → Zustand + Supabase Realtime
└── DEFAULT → Zustand + React Query
```

### Comparison

| Library | Bundle Size | Learning Curve | DevTools | Persistence | Best For |
|---------|------------|----------------|----------|-------------|----------|
| Zustand | 1.1KB | Low | Yes (Redux DevTools) | Built-in middleware | Most apps |
| Redux Toolkit | 11KB | Medium | Excellent | redux-persist | Large teams |
| Jotai | 2.4KB | Low | Yes | atomWithStorage | Atom-based state |
| React Query | 13KB | Medium | Excellent | persistQueryClient | Server state |
| Context | 0KB | Low | React DevTools | Manual | Simple UI state |

### Recommendation by App Type

| App Type | Client State | Server State |
|----------|-------------|-------------|
| Simple CRUD | Zustand | React Query |
| E-commerce | Zustand (cart, prefs) | React Query (products, orders) |
| Social media | Zustand (UI state) | React Query (feed, profiles) |
| Real-time chat | Zustand (messages) | Supabase Realtime |
| Offline-first | Zustand + MMKV | React Query + persistence |

## Flutter

```
START
├── Simple app (< 10 screens)?
│   └── YES → Provider (or built-in ChangeNotifier)
├── Team prefers reactive/declarative?
│   └── YES → Riverpod
├── Team prefers event-driven architecture?
│   └── YES → flutter_bloc (BLoC pattern)
├── Need code generation for boilerplate?
│   ├── Riverpod → riverpod_generator
│   └── BLoC → bloc already has good defaults
├── Complex async state (API + caching)?
│   └── YES → Riverpod (AsyncNotifier)
└── DEFAULT → Riverpod
```

### Comparison

| Library | Testability | Code Gen | Learning Curve | Best For |
|---------|------------|----------|----------------|----------|
| Riverpod | Excellent | Optional | Medium | Most Flutter apps |
| flutter_bloc | Excellent | No | Medium-High | Event-driven apps |
| Provider | Good | No | Low | Simple apps |
| GetX | Fair | No | Low | Prototypes (not recommended for production) |

### Recommendation by App Type

| App Type | Recommendation |
|----------|---------------|
| Simple CRUD | Provider or Riverpod |
| Complex business logic | BLoC |
| Data-heavy with caching | Riverpod (AsyncNotifier) |
| Real-time features | Riverpod + stream providers |
| Enterprise with strict testing | BLoC (explicit event/state) |

## Anti-Patterns to Avoid

1. **Mixing multiple state solutions** - Pick one client state lib, one server state lib
2. **Putting server state in client store** - Use React Query/Riverpod for API data
3. **Global state for local UI state** - Keep modal open/close, form state local
4. **Not separating concerns** - Auth state, UI state, and server cache are different
5. **Premature optimization** - Start simple, add complexity only when needed
