---
id: rn-state-management
category: skill
impact: CRITICAL
impactDescription: "Eliminates prop drilling re-render cascades causing 30fps scroll jank, reduces state boilerplate by 60%"
tags: [zustand, react-query, tanstack-query, state, persistence, optimistic-updates, selectors]
capabilities:
  - Replace prop drilling with Zustand selectors
  - React Query cache patterns with staleTime and queryKey design
  - Zustand persist middleware for React Native
  - Optimistic updates with mutation rollback
  - Server state vs client state separation
useWhen:
  - Choosing state management for React Native
  - Fixing unnecessary re-renders and scroll jank
  - Setting up React Query for API data
  - Implementing optimistic updates
  - Persisting state across app restarts
---

# Eliminate Prop Drilling Re-Renders Causing Scroll Jank in React Native

Prop drilling through 5+ component levels causes entire subtrees to re-render when any piece of state changes. In React Native, this directly causes dropped frames during scrolling because the JS thread is blocked re-rendering components that did not change. This skill covers replacing prop drilling with Zustand, managing server state with React Query, and implementing optimistic updates.

## Problem

Passing state through props forces every intermediate component to re-render even when only a leaf component needs the data. Combined with inline callbacks and object creation in render, this creates a cascade that drops the frame rate to 30fps or lower during scrolls.

```typescript
// BAD: Prop drilling causes entire tree re-render on any state change
// Every component between App and CartBadge re-renders when cart changes
function App() {
  const [user, setUser] = useState<User | null>(null);
  const [cart, setCart] = useState<CartItem[]>([]);
  const [theme, setTheme] = useState<'light' | 'dark'>('light');

  return (
    // WRONG: Header re-renders when cart changes even though it only uses user
    <Header user={user} cart={cart} theme={theme}>
      <Navigation user={user} cart={cart} theme={theme}>
        <TabBar cart={cart} theme={theme}>
          {/* CartBadge is the only component that needs cart.length */}
          {/* But every parent re-renders to pass cart down */}
          <CartBadge count={cart.length} />
        </TabBar>
      </Navigation>
    </Header>
  );
}

// BAD: Fetching data in useEffect without caching
// Every mount re-fetches, no loading/error states, no cache invalidation
function ProductList({ categoryId }: { categoryId: string }) {
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // WRONG: No error handling, no abort on unmount, no cache
    setLoading(true);
    fetch(`/api/products?category=${categoryId}`)
      .then(r => r.json())
      .then(data => {
        setProducts(data);
        setLoading(false);
      });
  }, [categoryId]);

  // WRONG: Creates new function on every render, breaks memoization
  const handleAddToCart = (product: Product) => {
    setCart(prev => [...prev, { ...product, quantity: 1 }]);
  };

  return (
    <FlatList
      data={products}
      // WRONG: Inline function and object creation in renderItem
      // FlatList cannot skip re-renders because the function identity changes
      renderItem={({ item }) => (
        <ProductCard product={item} onAdd={() => handleAddToCart(item)} />
      )}
    />
  );
}
```

## Solution

Separate client state (Zustand) from server state (React Query). Use selectors to subscribe to specific slices. Use React Query for all API data with proper cache keys and optimistic updates.

### Zustand Store with Persist Middleware

```typescript
// GOOD: Zustand store with granular selectors and AsyncStorage persistence
// src/stores/appStore.ts
import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import AsyncStorage from '@react-native-async-storage/async-storage';

interface CartItem {
  id: string;
  name: string;
  price: number;
  quantity: number;
}

interface AppState {
  // State slices
  theme: 'light' | 'dark';
  cart: CartItem[];
  onboardingComplete: boolean;

  // Actions - colocated with the state they modify
  toggleTheme: () => void;
  addToCart: (item: Omit<CartItem, 'quantity'>) => void;
  removeFromCart: (itemId: string) => void;
  updateQuantity: (itemId: string, quantity: number) => void;
  clearCart: () => void;
  completeOnboarding: () => void;
}

export const useAppStore = create<AppState>()(
  persist(
    (set, get) => ({
      theme: 'light',
      cart: [],
      onboardingComplete: false,

      toggleTheme: () =>
        set((state) => ({ theme: state.theme === 'light' ? 'dark' : 'light' })),

      addToCart: (item) =>
        set((state) => {
          const existing = state.cart.find((i) => i.id === item.id);
          if (existing) {
            return {
              cart: state.cart.map((i) =>
                i.id === item.id ? { ...i, quantity: i.quantity + 1 } : i
              ),
            };
          }
          return { cart: [...state.cart, { ...item, quantity: 1 }] };
        }),

      removeFromCart: (itemId) =>
        set((state) => ({
          cart: state.cart.filter((i) => i.id !== itemId),
        })),

      updateQuantity: (itemId, quantity) =>
        set((state) => ({
          cart: quantity <= 0
            ? state.cart.filter((i) => i.id !== itemId)
            : state.cart.map((i) => (i.id === itemId ? { ...i, quantity } : i)),
        })),

      clearCart: () => set({ cart: [] }),
      completeOnboarding: () => set({ onboardingComplete: true }),
    }),
    {
      name: 'app-storage',
      storage: createJSONStorage(() => AsyncStorage),
      // Only persist what survives app restarts - not loading states
      partialize: (state) => ({
        theme: state.theme,
        cart: state.cart,
        onboardingComplete: state.onboardingComplete,
      }),
      version: 1,
      migrate: (persisted, version) => {
        // Handle schema migrations between app versions
        if (version === 0) {
          return { ...persisted, onboardingComplete: false };
        }
        return persisted as AppState;
      },
    }
  )
);

// GOOD: Derived selectors prevent re-renders when unrelated state changes
// CartBadge only re-renders when cart length changes, not when theme changes
export const useCartCount = () => useAppStore((state) => state.cart.length);
export const useCartTotal = () =>
  useAppStore((state) =>
    state.cart.reduce((sum, item) => sum + item.price * item.quantity, 0)
  );
export const useTheme = () => useAppStore((state) => state.theme);
```

### React Query Setup with Cache Strategy

```typescript
// GOOD: React Query client with mobile-optimized defaults
// src/lib/queryClient.ts
import { QueryClient } from '@tanstack/react-query';
import { createAsyncStoragePersister } from '@tanstack/query-async-storage-persister';
import { PersistQueryClientProvider } from '@tanstack/react-query-persist-client';
import AsyncStorage from '@react-native-async-storage/async-storage';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // Data is fresh for 5 minutes - no refetch during this window
      staleTime: 5 * 60 * 1000,
      // Keep unused data in memory for 30 minutes
      gcTime: 30 * 60 * 1000,
      // Don't refetch when app comes to foreground (saves data on mobile)
      refetchOnWindowFocus: false,
      // Retry twice with exponential backoff
      retry: 2,
      retryDelay: (attempt) => Math.min(1000 * 2 ** attempt, 30000),
    },
    mutations: {
      retry: 1,
    },
  },
});

// Persist query cache to AsyncStorage for offline support
const asyncStoragePersister = createAsyncStoragePersister({
  storage: AsyncStorage,
  key: 'REACT_QUERY_OFFLINE_CACHE',
  throttleTime: 1000,
});

// Wrap your app with this instead of plain QueryClientProvider
export function QueryProvider({ children }: { children: React.ReactNode }) {
  return (
    <PersistQueryClientProvider
      client={queryClient}
      persistOptions={{
        persister: asyncStoragePersister,
        maxAge: 24 * 60 * 60 * 1000, // 24 hours
        dehydrateOptions: {
          // Only persist successful queries
          shouldDehydrateQuery: (query) => query.state.status === 'success',
        },
      }}
    >
      {children}
    </PersistQueryClientProvider>
  );
}
```

### Query Key Design and Data Fetching Hooks

```typescript
// GOOD: Structured query keys for precise cache invalidation
// src/hooks/useProducts.ts

// Query key factory - hierarchical keys enable granular invalidation
export const productKeys = {
  all: ['products'] as const,
  lists: () => [...productKeys.all, 'list'] as const,
  list: (filters: ProductFilters) => [...productKeys.lists(), filters] as const,
  details: () => [...productKeys.all, 'detail'] as const,
  detail: (id: string) => [...productKeys.details(), id] as const,
};

export function useProducts(filters: ProductFilters) {
  return useQuery({
    queryKey: productKeys.list(filters),
    queryFn: () => api.getProducts(filters),
    staleTime: 10 * 60 * 1000, // Products are stable, 10min stale time
    placeholderData: keepPreviousData, // Show old list while fetching new filters
  });
}

export function useProductDetail(productId: string) {
  return useQuery({
    queryKey: productKeys.detail(productId),
    queryFn: () => api.getProduct(productId),
    // Pre-populate from list cache if available
    initialData: () => {
      const lists = queryClient.getQueriesData<Product[]>({
        queryKey: productKeys.lists(),
      });
      for (const [, products] of lists) {
        const found = products?.find((p) => p.id === productId);
        if (found) return found;
      }
      return undefined;
    },
  });
}
```

### Optimistic Updates with Rollback

```typescript
// GOOD: Optimistic mutation with proper rollback on failure
// src/hooks/useAddToFavorites.ts
export function useToggleFavorite() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (productId: string) => api.toggleFavorite(productId),

    onMutate: async (productId) => {
      // Cancel in-flight refetches so they don't overwrite our optimistic update
      await queryClient.cancelQueries({ queryKey: productKeys.detail(productId) });

      // Snapshot the current value for rollback
      const previousProduct = queryClient.getQueryData<Product>(
        productKeys.detail(productId)
      );

      // Optimistically update the cache
      queryClient.setQueryData<Product>(
        productKeys.detail(productId),
        (old) => old ? { ...old, isFavorite: !old.isFavorite } : old
      );

      // Return snapshot for rollback
      return { previousProduct };
    },

    onError: (_err, productId, context) => {
      // Rollback to snapshot on failure
      if (context?.previousProduct) {
        queryClient.setQueryData(
          productKeys.detail(productId),
          context.previousProduct
        );
      }
    },

    onSettled: (_data, _err, productId) => {
      // Always refetch to ensure cache matches server
      queryClient.invalidateQueries({ queryKey: productKeys.detail(productId) });
    },
  });
}
```

### Component Using Selectors (No Prop Drilling)

```typescript
// GOOD: Components subscribe to exactly the data they need
// No props passed through intermediate components
function CartBadge() {
  // Only re-renders when cart count changes - not theme, not user, nothing else
  const count = useCartCount();
  if (count === 0) return null;
  return <Badge value={count} />;
}

function ProductCard({ productId }: { productId: string }) {
  const { data: product, isLoading } = useProductDetail(productId);
  const addToCart = useAppStore((s) => s.addToCart);
  const { mutate: toggleFav } = useToggleFavorite();

  // Stable callback reference - does not change between renders
  const handleAdd = useCallback(() => {
    if (product) addToCart({ id: product.id, name: product.name, price: product.price });
  }, [product, addToCart]);

  if (isLoading) return <ProductCardSkeleton />;
  if (!product) return null;

  return (
    <Pressable onPress={handleAdd}>
      <Text>{product.name}</Text>
      <Text>${product.price}</Text>
      <IconButton
        icon={product.isFavorite ? 'heart' : 'heart-outline'}
        onPress={() => toggleFav(product.id)}
      />
    </Pressable>
  );
}
```

## Why This Works

- **Zustand selectors use shallow equality**: `useAppStore((s) => s.cart.length)` subscribes to the return value. If `theme` changes but `cart.length` stays the same, the component does not re-render. This breaks the prop-drilling cascade where any change re-renders everything.
- **React Query separates server state from UI state**: API data lives in the query cache, not in component state. Multiple components can read the same data without prop passing. Cache invalidation handles freshness automatically.
- **Optimistic updates maintain perceived speed**: The UI updates immediately on user action. If the server rejects the mutation, the snapshot rollback restores the previous state. The user sees instant feedback instead of a loading spinner.
- **Query key hierarchy enables precise invalidation**: `queryClient.invalidateQueries({ queryKey: ['products'] })` invalidates all product queries. `queryClient.invalidateQueries({ queryKey: productKeys.detail('abc') })` invalidates only one product. No over-fetching.

## Edge Cases & Pitfalls

### Platform-Specific Gotchas

**iOS:**
- AsyncStorage on iOS uses `NSUserDefaults` underneath, which synchronizes to disk. Persisting large Zustand stores (>1MB) causes noticeable lag on app startup. Use `partialize` to limit what gets persisted.
- `refetchOnWindowFocus` in React Query fires when the app returns from background on iOS. Disable it for mobile to avoid unnecessary network requests on every app switch.

**Android:**
- AsyncStorage on Android has a default 6MB size limit. Large query caches can hit this. Set `maxAge` on the persister to auto-prune old entries.
- Android's aggressive background process killing means your React Query cache may be empty on resume. The `staleTime` setting ensures data is re-fetched smoothly when this happens.

### Common Mistakes

- **Creating new objects in selectors**: `useAppStore((s) => ({ count: s.cart.length, total: s.total }))` creates a new object every render, defeating selector optimization. Use `useShallow` from `zustand/react/shallow` for multi-value selectors.
- **Using the same query key for different data**: `['products']` for both the list and a single product means invalidating one invalidates both. Use the factory pattern (`productKeys.list()` vs `productKeys.detail(id)`).
- **Persisting everything**: Do not persist loading states, error objects, or derived data. Only persist source-of-truth values that should survive app restarts.
- **Missing `gcTime` configuration**: The default `gcTime` (formerly `cacheTime`) is 5 minutes. For mobile with limited memory, consider reducing it for large datasets or increasing it for data that is expensive to refetch.

## Verification

```bash
# Check for unnecessary re-renders with React DevTools Profiler
# In development, add this to your root component:
# import { useRenderCount } from '@uidotdev/usehooks';

# Verify AsyncStorage persistence
npx react-native start --reset-cache  # Clear Metro cache, NOT AsyncStorage
```

- [ ] Open React DevTools Profiler. Change theme. Verify `CartBadge` does not appear in the re-render list.
- [ ] Navigate to a product list, go offline (airplane mode), navigate back. Verify cached data displays.
- [ ] Toggle a favorite optimistically. Kill the network mid-request. Verify the UI rolls back.
- [ ] Kill the app, reopen. Verify Zustand persisted state (theme, cart) is restored.
- [ ] Change category filter rapidly 5 times. Verify no stale data flashes (placeholderData works).

## References

- [Zustand Documentation](https://docs.pmnd.rs/zustand)
- [Zustand Persist Middleware](https://docs.pmnd.rs/zustand/integrations/persisting-store-data)
- [TanStack Query React Native](https://tanstack.com/query/latest/docs/framework/react/react-native)
- [TanStack Query Key Factory](https://tanstack.com/query/latest/docs/framework/react/guides/query-keys)
- [TanStack Query Optimistic Updates](https://tanstack.com/query/latest/docs/framework/react/guides/optimistic-updates)
