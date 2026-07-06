---
name: "offline-sync-patterns"
description: "Mobile apps frequently lose connectivity in elevators, subways, rural areas, and airplane mode. Without conflict resolution, edits made offline are silently overwritten or lost when the device reconnects. This skill cove"
source_type: "skill"
source_file: "skills/offline-sync-patterns.md"
---

# offline-sync-patterns

Migrated from `skills/offline-sync-patterns.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Offline-First Sync Patterns for Mobile Apps

Mobile apps frequently lose connectivity in elevators, subways, rural areas, and airplane mode. Without conflict resolution, edits made offline are silently overwritten or lost when the device reconnects. This skill covers sync architectures that preserve every user change.

## Problem

Without conflict resolution, the last device to sync overwrites all previous changes. Users lose work with no warning and no way to recover.

```typescript
// BAD: No conflict detection - last write silently wins, data lost
async function saveNote(note: Note) {
  // Save locally
  await AsyncStorage.setItem(`note-${note.id}`, JSON.stringify(note));

  // When back online, push to server - overwrites whatever is there
  if (await NetInfo.fetch().then(s => s.isConnected)) {
    await fetch(`/api/notes/${note.id}`, {
      method: 'PUT',
      body: JSON.stringify(note),
    });
  }
}
// Scenario: User A edits title on phone, User B edits body on tablet
// Both go online - User B's PUT overwrites User A's title change entirely

// BAD: No sync queue - failed syncs are silently dropped
async function createItem(item: Item) {
  await localDb.insert(item);
  try {
    await api.post('/items', item);
  } catch (e) {
    // Error logged but item never retries sync
    console.warn('Sync failed:', e);
  }
}

// BAD: No sync status shown to user
function TodoList() {
  const [todos, setTodos] = useState<Todo[]>([]);
  // User has no idea which items are synced vs pending vs failed
  return (
    <FlatList
      data={todos}
      renderItem={({ item }) => <TodoItem todo={item} />}
    />
  );
}

// BAD: Retry without backoff hammers the server
async function syncWithRetry(item: Item) {
  while (true) {
    try {
      await api.post('/items', item);
      return;
    } catch {
      // Immediate retry with no delay, no max attempts
      // Drains battery, floods server on 500 errors
    }
  }
}
```

## Solution

### 1. Sync Queue with Exponential Backoff

```typescript
// GOOD: Persistent sync queue with retry, backoff, and max attempts
import AsyncStorage from '@react-native-async-storage/async-storage';
import NetInfo from '@react-native-community/netinfo';

interface SyncOperation {
  id: string;
  table: string;
  type: 'INSERT' | 'UPDATE' | 'DELETE';
  payload: Record<string, unknown>;
  createdAt: number;
  attempts: number;
  lastAttempt: number | null;
  status: 'pending' | 'in_progress' | 'failed' | 'conflict';
  version: number; // Server version at time of local read
}

const MAX_ATTEMPTS = 5;
const BASE_DELAY_MS = 1000;
const MAX_DELAY_MS = 60000;

class SyncQueue {
  private queue: SyncOperation[] = [];
  private processing = false;

  async enqueue(op: Omit<SyncOperation, 'id' | 'createdAt' | 'attempts' | 'lastAttempt' | 'status'>) {
    const operation: SyncOperation = {
      ...op,
      id: `sync_${Date.now()}_${Math.random().toString(36).slice(2)}`,
      createdAt: Date.now(),
      attempts: 0,
      lastAttempt: null,
      status: 'pending',
    };

    this.queue.push(operation);
    await this.persist();
    this.processQueue();
  }

  async processQueue() {
    if (this.processing) return;

    const netState = await NetInfo.fetch();
    if (!netState.isConnected) return;

    this.processing = true;

    try {
      const pending = this.queue.filter(
        (op) => op.status === 'pending' && op.attempts < MAX_ATTEMPTS
      );

      for (const op of pending) {
        const delay = this.getBackoffDelay(op.attempts);
        const timeSinceLastAttempt = Date.now() - (op.lastAttempt ?? 0);

        if (timeSinceLastAttempt < delay) continue;

        op.status = 'in_progress';
        op.attempts += 1;
        op.lastAttempt = Date.now();

        try {
          await this.executeSyncOperation(op);
          // Remove from queue on success
          this.queue = this.queue.filter((q) => q.id !== op.id);
        } catch (error: any) {
          if (error.status === 409) {
            op.status = 'conflict';
          } else {
            op.status = op.attempts >= MAX_ATTEMPTS ? 'failed' : 'pending';
          }
        }
      }
    } finally {
      this.processing = false;
      await this.persist();
    }
  }

  private getBackoffDelay(attempt: number): number {
    // Exponential backoff with jitter
    const exponential = BASE_DELAY_MS * Math.pow(2, attempt);
    const jitter = Math.random() * exponential * 0.1;
    return Math.min(exponential + jitter, MAX_DELAY_MS);
  }

  private async executeSyncOperation(op: SyncOperation): Promise<void> {
    const response = await fetch(`/api/sync/${op.table}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        type: op.type,
        payload: op.payload,
        expectedVersion: op.version,
      }),
    });

    if (!response.ok) {
      const error = new Error('Sync failed') as any;
      error.status = response.status;
      error.serverData = await response.json().catch(() => null);
      throw error;
    }
  }

  private async persist() {
    await AsyncStorage.setItem('sync_queue', JSON.stringify(this.queue));
  }

  async restore() {
    const stored = await AsyncStorage.getItem('sync_queue');
    if (stored) {
      this.queue = JSON.parse(stored);
    }
  }

  getStatus(): { pending: number; failed: number; conflicts: number } {
    return {
      pending: this.queue.filter((o) => o.status === 'pending' || o.status === 'in_progress').length,
      failed: this.queue.filter((o) => o.status === 'failed').length,
      conflicts: this.queue.filter((o) => o.status === 'conflict').length,
    };
  }
}

export const syncQueue = new SyncQueue();
```

### 2. Conflict Resolution Strategies

```typescript
// GOOD: Field-level merge preserves non-conflicting changes from both sides
interface VersionedRecord {
  id: string;
  version: number;
  updated_at: number;
  updated_fields: string[]; // Tracks which fields changed in this edit
  [key: string]: unknown;
}

type ConflictStrategy = 'last-write-wins' | 'field-merge' | 'manual';

async function resolveConflict(
  local: VersionedRecord,
  server: VersionedRecord,
  strategy: ConflictStrategy
): Promise<VersionedRecord> {
  switch (strategy) {
    case 'last-write-wins':
      // Simple: most recent timestamp wins entirely
      return local.updated_at > server.updated_at ? local : server;

    case 'field-merge': {
      // Smart: merge non-overlapping field changes
      const localFields = new Set(local.updated_fields);
      const serverFields = new Set(server.updated_fields);

      // Check for true conflicts (same field edited on both sides)
      const conflictingFields = [...localFields].filter((f) =>
        serverFields.has(f)
      );

      if (conflictingFields.length === 0) {
        // No actual conflict - merge both changes
        const merged = { ...server };
        for (const field of localFields) {
          merged[field] = local[field];
        }
        merged.version = server.version + 1;
        merged.updated_fields = [
          ...new Set([...local.updated_fields, ...server.updated_fields]),
        ];
        return merged;
      }

      // For conflicting fields, use last-write-wins per field
      const merged = { ...server };
      for (const field of localFields) {
        if (
          conflictingFields.includes(field) &&
          local.updated_at > server.updated_at
        ) {
          merged[field] = local[field];
        } else if (!serverFields.has(field)) {
          merged[field] = local[field];
        }
      }
      merged.version = server.version + 1;
      return merged;
    }

    case 'manual':
      // Present both versions to the user for resolution
      return new Promise((resolve) => {
        showConflictDialog(local, server, (resolved) => {
          resolve({ ...resolved, version: server.version + 1 });
        });
      });
  }
}
```

### 3. Local-First Architecture with WatermelonDB

```typescript
// GOOD: WatermelonDB model with sync status tracking
// models/Task.ts
import { Model } from '@nozbe/watermelondb';
import { field, date, readonly, text } from '@nozbe/watermelondb/decorators';

class Task extends Model {
  static table = 'tasks';

  @text('title') title!: string;
  @text('description') description!: string;
  @field('is_completed') isCompleted!: boolean;
  @field('sync_status') syncStatus!: 'synced' | 'pending' | 'conflict';
  @readonly @date('created_at') createdAt!: Date;
  @date('updated_at') updatedAt!: Date;
}

// sync/pullChanges.ts - Pull changes from server
import { synchronize } from '@nozbe/watermelondb/sync';

async function syncDatabase(database: Database) {
  await synchronize({
    database,

    pullChanges: async ({ lastPulledAt }) => {
      const response = await fetch(
        `/api/sync?last_pulled_at=${lastPulledAt ?? 0}`
      );
      if (!response.ok) throw new Error('Pull failed');

      const { changes, timestamp } = await response.json();
      return { changes, timestamp };
    },

    pushChanges: async ({ changes, lastPulledAt }) => {
      const response = await fetch('/api/sync', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ changes, lastPulledAt }),
      });
      if (!response.ok) throw new Error('Push failed');
    },

    // Called on conflict - return the version to keep
    conflictResolver: (table, local, remote) => {
      // Field-level merge for tasks
      if (table === 'tasks') {
        return {
          ...remote,
          // Preserve local completion status (user intent)
          is_completed: local.is_completed,
        };
      }
      // Default: server wins
      return remote;
    },
  });
}
```

### 4. Sync Status Indicators

```typescript
// GOOD: Visual sync status so users know what is saved
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import Animated, { useAnimatedStyle, withRepeat, withTiming } from 'react-native-reanimated';

type SyncStatus = 'synced' | 'pending' | 'syncing' | 'error' | 'conflict';

function SyncBadge({ status }: { status: SyncStatus }) {
  const pulseStyle = useAnimatedStyle(() => ({
    opacity: status === 'syncing'
      ? withRepeat(withTiming(0.3, { duration: 800 }), -1, true)
      : 1,
  }));

  const config: Record<SyncStatus, { color: string; label: string; icon: string }> = {
    synced:   { color: '#22c55e', label: 'Saved',       icon: '\u2713' },
    pending:  { color: '#f59e0b', label: 'Pending',     icon: '\u25cb' },
    syncing:  { color: '#3b82f6', label: 'Syncing...',  icon: '\u21bb' },
    error:    { color: '#ef4444', label: 'Sync failed', icon: '\u2717' },
    conflict: { color: '#a855f7', label: 'Conflict',    icon: '\u26a0' },
  };

  const { color, label, icon } = config[status];

  return (
    <Animated.View style={[styles.badge, { backgroundColor: color + '20' }, pulseStyle]}>
      <Text style={[styles.icon, { color }]}>{icon}</Text>
      <Text style={[styles.label, { color }]}>{label}</Text>
    </Animated.View>
  );
}

// GOOD: Global sync status bar
function SyncStatusBar() {
  const { pending, failed, conflicts } = useSyncStatus();
  const isOnline = useNetworkStatus();

  if (!isOnline) {
    return (
      <View style={[styles.statusBar, { backgroundColor: '#fef3c7' }]}>
        <Text style={styles.statusText}>
          Offline - changes will sync when connected
        </Text>
      </View>
    );
  }

  if (failed > 0) {
    return (
      <View style={[styles.statusBar, { backgroundColor: '#fee2e2' }]}>
        <Text style={styles.statusText}>
          {failed} change{failed > 1 ? 's' : ''} failed to sync
        </Text>
      </View>
    );
  }

  if (pending > 0) {
    return (
      <View style={[styles.statusBar, { backgroundColor: '#dbeafe' }]}>
        <Text style={styles.statusText}>
          Syncing {pending} change{pending > 1 ? 's' : ''}...
        </Text>
      </View>
    );
  }

  return null; // All synced - show nothing
}

const styles = StyleSheet.create({
  badge: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
    gap: 4,
  },
  icon: { fontSize: 12, fontWeight: '600' },
  label: { fontSize: 12, fontWeight: '500' },
  statusBar: {
    paddingVertical: 6,
    paddingHorizontal: 16,
    alignItems: 'center',
  },
  statusText: { fontSize: 13, fontWeight: '500' },
});
```

### 5. Network-Aware Auto-Sync Hook

```typescript
// GOOD: Hook that triggers sync on connectivity changes
import { useEffect, useRef } from 'react';
import NetInfo, { NetInfoState } from '@react-native-community/netinfo';
import { AppState, AppStateStatus } from 'react-native';

function useAutoSync(syncFn: () => Promise<void>) {
  const isSyncing = useRef(false);

  const triggerSync = async () => {
    if (isSyncing.current) return;
    isSyncing.current = true;
    try {
      await syncFn();
    } catch (error) {
      console.warn('Auto-sync failed:', error);
    } finally {
      isSyncing.current = false;
    }
  };

  useEffect(() => {
    // Sync when network comes back
    const unsubNetwork = NetInfo.addEventListener((state: NetInfoState) => {
      if (state.isConnected) {
        triggerSync();
      }
    });

    // Sync when app comes to foreground
    const appStateSub = AppState.addEventListener(
      'change',
      (state: AppStateStatus) => {
        if (state === 'active') {
          triggerSync();
        }
      }
    );

    // Initial sync
    triggerSync();

    return () => {
      unsubNetwork();
      appStateSub.remove();
    };
  }, []);
}
```

## Why This Works

- **Persistent sync queue**: Operations survive app crashes and restarts because they are written to AsyncStorage. Nothing is lost even if the app is force-killed mid-sync.
- **Exponential backoff with jitter**: Prevents thundering herd when a server recovers from an outage. Each client retries at a different time, spreading load.
- **Field-level merge**: Instead of discarding entire edits, only truly conflicting fields need resolution. If User A edits the title and User B edits the body, both changes are preserved automatically.
- **Version numbers**: Detecting conflicts requires knowing what version the client read before editing. The server rejects updates where `expectedVersion` does not match, forcing the client to merge.
- **Sync status UI**: Users make better decisions when they know what is saved. Showing "Offline - changes will sync" prevents users from closing the app thinking data was lost.

## Edge Cases & Pitfalls

### Platform-Specific Gotchas

**iOS:**
- Background sync is limited to ~30 seconds. Use `BGTaskScheduler` for longer operations.
- `NSURLSession` background transfers continue even when the app is suspended but cannot run arbitrary code.

**Android:**
- `WorkManager` handles background sync reliably, even after device reboot.
- Doze mode delays network access. Use `setExpedited()` for time-sensitive syncs.

### Common Mistakes

- **Not persisting the sync queue**: If the queue lives only in memory, a crash loses all pending operations.
- **Syncing on every keystroke**: Debounce edits (e.g., 2-second delay after typing stops) before enqueuing sync operations.
- **Ignoring vector clocks for multi-device**: Simple timestamps fail when device clocks are skewed. For multi-device sync, use server-assigned version numbers or vector clocks.
- **Large payloads on metered connections**: Check `NetInfo.isConnectionExpensive` and defer large syncs to Wi-Fi.
- **Not handling schema migrations offline**: If the server schema changes while the user is offline, old pending operations may fail. Version your sync protocol.

## Verification

```bash
# Test offline sync with adb (Android)
adb shell svc wifi disable
adb shell svc data disable
# Make changes in app, verify they persist locally
adb shell svc wifi enable
# Verify changes sync to server

# Test on iOS Simulator
# Use Network Link Conditioner to simulate offline/poor connectivity
```

- [ ] App remains fully functional with airplane mode enabled
- [ ] Pending changes display correct sync status badges
- [ ] Changes sync automatically when connectivity returns
- [ ] Conflicting edits from two devices are merged correctly (test with field-level merge)
- [ ] Sync queue survives app force-quit and resumes on relaunch
- [ ] Failed syncs retry with increasing delays (verify in network logs)
- [ ] Sync status bar shows "Offline" when disconnected

## References

- [WatermelonDB Sync Documentation](https://watermelondb.dev/docs/Sync/Intro)
- [Designing Data-Intensive Applications - Conflict Resolution](https://dataintensive.net/)
- [React Native NetInfo](https://github.com/react-native-netinfo/react-native-netinfo)
- [Android WorkManager](https://developer.android.com/topic/libraries/architecture/workmanager)
- [iOS Background Tasks](https://developer.apple.com/documentation/backgroundtasks)
