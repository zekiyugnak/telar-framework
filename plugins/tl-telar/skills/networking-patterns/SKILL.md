---
name: "networking-patterns"
description: "Fast navigation between screens triggers duplicate API calls that race against each other, causing stale data overwrites, duplicate mutations, and UI flicker. Combined with poor retry logic and no offline support, this t"
source_type: "skill"
source_file: "skills/networking-patterns.md"
---

# networking-patterns

Migrated from `skills/networking-patterns.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Eliminate Race Conditions and Duplicate API Calls with Production Networking Patterns

Fast navigation between screens triggers duplicate API calls that race against each other, causing stale data overwrites, duplicate mutations, and UI flicker. Combined with poor retry logic and no offline support, this turns network issues into user-visible bugs.

## Problem

Duplicate and racing API calls caused by fast navigation and missing deduplication.

```typescript
// BAD: Every screen mount fires a fresh API call with no deduplication
function UserProfileScreen({ userId }: { userId: string }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Problem 1: No cancellation - if user navigates away and back,
    // two requests race and the slower one overwrites newer data
    fetch(`/api/users/${userId}`)
      .then((res) => res.json())
      .then((data) => {
        setUser(data);  // Stale response may overwrite fresh one
        setLoading(false);
      })
      .catch((err) => {
        // Problem 2: Generic error handling - user sees nothing useful
        console.log(err);
        setLoading(false);
      });
  }, [userId]);

  // Problem 3: No retry logic - transient 503 errors show as permanent failure
  // Problem 4: No caching - same user profile fetched 10 times per session

  return loading ? <Spinner /> : <Text>{user?.name}</Text>;
}
```

```typescript
// BAD: Optimistic update without rollback
async function toggleFavorite(itemId: string) {
  // Updates UI immediately but never reverts if API fails
  store.dispatch({ type: 'TOGGLE_FAVORITE', itemId });

  // If this fails, UI shows item as favorited but server disagrees
  await fetch(`/api/favorites/${itemId}`, { method: 'POST' });
  // No error handling, no rollback, no retry
}
```

```typescript
// BAD: Naive retry that hammers the server
async function fetchWithRetry(url: string, retries = 5) {
  for (let i = 0; i < retries; i++) {
    try {
      return await fetch(url);
    } catch {
      // Retries immediately with no delay - creates thundering herd
      // during outages as all clients retry simultaneously
      continue;
    }
  }
}
```

## Solution

### 1. Retry with Exponential Backoff and Jitter

```typescript
// GOOD: Production retry strategy that avoids thundering herd
interface RetryConfig {
  maxRetries: number;
  baseDelay: number;       // milliseconds
  maxDelay: number;        // cap to prevent absurd waits
  jitterFactor: number;    // 0-1, randomness to spread retries
  retryableStatuses: number[];
}

const DEFAULT_RETRY_CONFIG: RetryConfig = {
  maxRetries: 3,
  baseDelay: 1000,
  maxDelay: 30000,
  jitterFactor: 0.5,
  retryableStatuses: [408, 429, 500, 502, 503, 504],
};

function calculateDelay(attempt: number, config: RetryConfig): number {
  // Exponential backoff: 1s, 2s, 4s, 8s...
  const exponentialDelay = config.baseDelay * Math.pow(2, attempt);
  const capped = Math.min(exponentialDelay, config.maxDelay);

  // Add jitter: randomize between (1-jitter)*delay and (1+jitter)*delay
  // This prevents all clients from retrying at the exact same moment
  const jitter = capped * config.jitterFactor * (Math.random() * 2 - 1);
  return Math.max(0, capped + jitter);
}

async function fetchWithRetry(
  url: string,
  options: RequestInit = {},
  config: RetryConfig = DEFAULT_RETRY_CONFIG,
): Promise<Response> {
  let lastError: Error | null = null;

  for (let attempt = 0; attempt <= config.maxRetries; attempt++) {
    try {
      const response = await fetch(url, options);

      // Do not retry client errors (400, 401, 403, 404) - they won't change
      if (response.ok) return response;

      if (config.retryableStatuses.includes(response.status)) {
        // Check for Retry-After header (common with 429 rate limiting)
        const retryAfter = response.headers.get('Retry-After');
        if (retryAfter && attempt < config.maxRetries) {
          const retryMs = parseInt(retryAfter, 10) * 1000 || config.baseDelay;
          await new Promise((resolve) => setTimeout(resolve, retryMs));
          continue;
        }

        lastError = new Error(`HTTP ${response.status}`);
        if (attempt < config.maxRetries) {
          await new Promise((resolve) =>
            setTimeout(resolve, calculateDelay(attempt, config)),
          );
          continue;
        }
      }

      // Non-retryable error - throw immediately
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    } catch (error) {
      lastError = error as Error;

      // Network errors (offline, DNS failure) are retryable
      if (attempt < config.maxRetries && error instanceof TypeError) {
        await new Promise((resolve) =>
          setTimeout(resolve, calculateDelay(attempt, config)),
        );
        continue;
      }

      if (attempt === config.maxRetries) break;
    }
  }

  throw lastError ?? new Error('Request failed after retries');
}
```

### 2. Request Deduplication for Concurrent Identical Requests

```typescript
// GOOD: Deduplication layer ensures identical in-flight requests share one promise
class RequestDeduplicator {
  private inFlight = new Map<string, Promise<any>>();

  async request<T>(key: string, executor: () => Promise<T>): Promise<T> {
    // If an identical request is already in flight, return its promise
    const existing = this.inFlight.get(key);
    if (existing) return existing as Promise<T>;

    // Execute the request and store the promise
    const promise = executor().finally(() => {
      this.inFlight.delete(key);
    });

    this.inFlight.set(key, promise);
    return promise;
  }
}

const deduplicator = new RequestDeduplicator();

// Usage: even if called 5 times in 100ms, only 1 request fires
async function getUser(userId: string) {
  return deduplicator.request(`user:${userId}`, () =>
    fetchWithRetry(`/api/users/${userId}`).then((r) => r.json()),
  );
}

// React hook with deduplication and cancellation
function useDeduplicatedFetch<T>(url: string) {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<Error | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;

    deduplicator
      .request(url, () => fetchWithRetry(url).then((r) => r.json()))
      .then((result) => {
        if (!cancelled) {
          setData(result);
          setLoading(false);
        }
      })
      .catch((err) => {
        if (!cancelled) {
          setError(err);
          setLoading(false);
        }
      });

    // Cancel prevents stale responses from updating state
    return () => { cancelled = true; };
  }, [url]);

  return { data, error, loading };
}
```

### 3. Optimistic Updates with Rollback

```typescript
// GOOD: Optimistic update that rolls back cleanly on failure
import { useMutation, useQueryClient } from '@tanstack/react-query';

function useFavoriteToggle() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (itemId: string) =>
      fetchWithRetry(`/api/favorites/${itemId}`, { method: 'POST' })
        .then((r) => r.json()),

    // Optimistically update before the request completes
    onMutate: async (itemId: string) => {
      // Cancel in-flight queries to prevent overwrites
      await queryClient.cancelQueries({ queryKey: ['favorites'] });

      // Snapshot current state for rollback
      const previousFavorites = queryClient.getQueryData<string[]>(['favorites']);

      // Optimistically update the cache
      queryClient.setQueryData<string[]>(['favorites'], (old = []) => {
        return old.includes(itemId)
          ? old.filter((id) => id !== itemId)
          : [...old, itemId];
      });

      // Return snapshot for rollback
      return { previousFavorites };
    },

    // Rollback on error using the snapshot
    onError: (_err, _itemId, context) => {
      if (context?.previousFavorites) {
        queryClient.setQueryData(['favorites'], context.previousFavorites);
      }
    },

    // Refetch after success or error to ensure consistency
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['favorites'] });
    },
  });
}

// Usage in component
function FavoriteButton({ itemId }: { itemId: string }) {
  const { mutate, isPending } = useFavoriteToggle();
  const favorites = useQuery({ queryKey: ['favorites'] });

  const isFavorited = favorites.data?.includes(itemId) ?? false;

  return (
    <Pressable
      onPress={() => mutate(itemId)}
      disabled={isPending}
      style={{ opacity: isPending ? 0.6 : 1 }}
    >
      <HeartIcon filled={isFavorited} />
    </Pressable>
  );
}
```

### 4. Offline Queue with Background Sync

```typescript
// GOOD: Queue mutations while offline and replay when connectivity returns
import NetInfo, { NetInfoState } from '@react-native-community/netinfo';
import AsyncStorage from '@react-native-async-storage/async-storage';

interface QueuedRequest {
  id: string;
  url: string;
  method: string;
  body: string;
  timestamp: number;
  retryCount: number;
}

class OfflineQueue {
  private queue: QueuedRequest[] = [];
  private isProcessing = false;
  private readonly STORAGE_KEY = '@offline_queue';
  private readonly MAX_AGE_MS = 24 * 60 * 60 * 1000; // 24 hours

  async initialize() {
    // Restore queue from persistent storage
    const stored = await AsyncStorage.getItem(this.STORAGE_KEY);
    if (stored) {
      this.queue = JSON.parse(stored);
      // Remove expired entries
      this.queue = this.queue.filter(
        (req) => Date.now() - req.timestamp < this.MAX_AGE_MS,
      );
    }

    // Listen for connectivity changes
    NetInfo.addEventListener((state: NetInfoState) => {
      if (state.isConnected && this.queue.length > 0) {
        this.processQueue();
      }
    });
  }

  async enqueue(url: string, method: string, body: any): Promise<void> {
    const request: QueuedRequest = {
      id: `${Date.now()}-${Math.random().toString(36).slice(2)}`,
      url,
      method,
      body: JSON.stringify(body),
      timestamp: Date.now(),
      retryCount: 0,
    };

    this.queue.push(request);
    await AsyncStorage.setItem(this.STORAGE_KEY, JSON.stringify(this.queue));
  }

  private async processQueue(): Promise<void> {
    if (this.isProcessing || this.queue.length === 0) return;
    this.isProcessing = true;

    // Process in FIFO order to maintain mutation sequence
    while (this.queue.length > 0) {
      const request = this.queue[0];
      try {
        await fetch(request.url, {
          method: request.method,
          headers: { 'Content-Type': 'application/json' },
          body: request.body,
        });
        // Success - remove from queue
        this.queue.shift();
        await AsyncStorage.setItem(this.STORAGE_KEY, JSON.stringify(this.queue));
      } catch {
        // Failed - stop processing, will retry on next connectivity change
        request.retryCount++;
        if (request.retryCount >= 5) {
          this.queue.shift(); // Drop after 5 failures
        }
        break;
      }
    }

    this.isProcessing = false;
  }
}

const offlineQueue = new OfflineQueue();

// Usage: wrap mutation calls to support offline
async function createPost(title: string, content: string) {
  const netInfo = await NetInfo.fetch();

  if (!netInfo.isConnected) {
    await offlineQueue.enqueue('/api/posts', 'POST', { title, content });
    // Show user confirmation that post will be submitted when online
    return { queued: true };
  }

  return fetchWithRetry('/api/posts', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ title, content }),
  }).then((r) => r.json());
}
```

### 5. Certificate Pinning

```typescript
// GOOD: React Native - certificate pinning with react-native-ssl-pinning
import { fetch as pinnedFetch } from 'react-native-ssl-pinning';

async function secureApiCall(endpoint: string, options: any = {}) {
  return pinnedFetch(`https://api.myapp.com${endpoint}`, {
    method: options.method || 'GET',
    headers: options.headers || {},
    body: options.body,
    // Pin to the public key hash of your certificate
    sslPinning: {
      certs: ['api_myapp_com'], // .cer file in native project
    },
    timeoutInterval: 30000,
  });
}
```

```kotlin
// GOOD: Android - certificate pinning with OkHttp (used by React Native)
// android/app/src/main/res/xml/network_security_config.xml
/*
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">api.myapp.com</domain>
        <pin-set expiration="2025-12-31">
            <!-- Pin the public key hash (SHA-256) -->
            <pin digest="SHA-256">AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=</pin>
            <!-- Always include a backup pin for key rotation -->
            <pin digest="SHA-256">BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=</pin>
        </pin-set>
    </domain-config>
</network-security-config>
*/
```

```xml
<!-- Reference in AndroidManifest.xml -->
<application
    android:networkSecurityConfig="@xml/network_security_config"
    ... >
```

### 6. API Response Caching Strategy

```typescript
// GOOD: Tiered caching strategy using React Query
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { createAsyncStoragePersister } from '@tanstack/query-async-storage-persister';
import { persistQueryClient } from '@tanstack/react-query-persist-client';
import AsyncStorage from '@react-native-async-storage/async-storage';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // Data considered fresh for 5 minutes (no refetch in this window)
      staleTime: 5 * 60 * 1000,
      // Keep unused data in memory for 30 minutes
      gcTime: 30 * 60 * 1000,
      // Retry transient failures
      retry: 2,
      retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 30000),
    },
  },
});

// Persist cache to AsyncStorage for offline and instant restart
const asyncStoragePersister = createAsyncStoragePersister({
  storage: AsyncStorage,
  key: 'REACT_QUERY_CACHE',
  throttleTime: 1000,
});

persistQueryClient({
  queryClient,
  persister: asyncStoragePersister,
  maxAge: 24 * 60 * 60 * 1000, // Cache valid for 24 hours
});

// Per-query cache tuning
function useUserProfile(userId: string) {
  return useQuery({
    queryKey: ['user', userId],
    queryFn: () => getUser(userId),
    staleTime: 10 * 60 * 1000,  // Profile rarely changes - 10 min fresh
  });
}

function useFeed() {
  return useQuery({
    queryKey: ['feed'],
    queryFn: () => fetchWithRetry('/api/feed').then((r) => r.json()),
    staleTime: 30 * 1000,       // Feed changes often - 30 sec fresh
    refetchOnWindowFocus: true,  // Refetch when app comes to foreground
  });
}
```

## Why This Works

- **Exponential backoff with jitter** prevents the thundering herd problem: when a server returns 503, all clients retrying simultaneously would keep it overloaded. Jitter spreads retries across a time window so the server can recover.
- **Request deduplication** shares a single in-flight promise across multiple callers. Five components mounting simultaneously requesting the same user profile produce one HTTP request, not five.
- **Optimistic updates with snapshot rollback** provide instant UI feedback (< 16ms) while guaranteeing consistency: if the server rejects the mutation, the UI reverts to the snapshotted state and then refetches the authoritative data.
- **Offline queue with FIFO processing** ensures mutation ordering is preserved. A user who creates a post then edits it will not have the edit arrive before the create, which would fail on the server.
- **Certificate pinning** prevents MITM attacks even if the device's CA store is compromised or the user is on a hostile network. The backup pin ensures the app continues working during certificate rotation.

## Edge Cases & Pitfalls

### Platform-Specific Gotchas

**iOS:**
- iOS kills background tasks after ~30 seconds. Use `BGTaskScheduler` for offline queue processing instead of relying on the app staying active.
- `NSAppTransportSecurity` must be configured if pinning certificates with non-standard CAs.

**Android:**
- `WorkManager` is the correct way to schedule offline queue retries. `AlarmManager` is unreliable on modern Android with Doze mode.
- Certificate pins must include a backup pin per Android documentation; a single pin causes crashes on rotation.

### Common Mistakes

- **Retrying POST/PUT/DELETE requests without idempotency keys** - the server may process the mutation twice. Include an `Idempotency-Key` header for non-GET requests.
- **Not cancelling requests on unmount** - navigating away while a request is in flight can cause `setState` on an unmounted component (React warning) or stale data overwrites.
- **Caching authenticated data globally** - user A's cached data must not appear for user B after logout. Clear the query cache on sign-out: `queryClient.clear()`.
- **Pinning to the leaf certificate instead of the public key** - leaf certificates rotate yearly. Pin to the public key hash or an intermediate CA for longer validity.
- **Infinite retry on 401** - authentication errors should trigger re-auth flow, not retry. Retrying 401s with the same expired token creates an infinite loop.

## Verification

```bash
# Test retry behavior with a mock server
npx json-server --watch db.json --port 3000

# Simulate network conditions on iOS
# Xcode > Developer Tools > Network Link Conditioner

# Simulate offline on Android
adb shell svc wifi disable
adb shell svc data disable

# Test certificate pinning (should fail with wrong cert)
# Use Charles Proxy or mitmproxy - requests should be rejected
```

- [ ] Duplicate API calls eliminated (verify with network inspector)
- [ ] Retry logic uses exponential backoff (observe in console/debugger)
- [ ] Optimistic updates roll back cleanly when API call fails
- [ ] Offline queue persists across app restart and processes on reconnect
- [ ] Certificate pinning rejects proxy/MITM certificates
- [ ] Cache is cleared on user logout
- [ ] No `setState on unmounted component` warnings during fast navigation

## References

- [React Query Documentation](https://tanstack.com/query/latest)
- [Exponential Backoff (AWS)](https://docs.aws.amazon.com/general/latest/gr/api-retries.html)
- [Android Network Security Config](https://developer.android.com/training/articles/security-config)
- [react-native-ssl-pinning](https://github.com/nickclaw/react-native-ssl-pinning)
- [NetInfo API](https://github.com/react-native-netinfo/react-native-netinfo)
- [OWASP Certificate Pinning](https://owasp.org/www-community/controls/Certificate_and_Public_Key_Pinning)
