---
name: "mobile-offline-architect"
description: "Expert in offline-first architecture, data synchronization, and building apps that work reliably without connectivity."
source_type: "agent"
source_file: "agents/mobile-offline-architect.md"
---

# mobile-offline-architect

Migrated from `agents/mobile-offline-architect.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- This agent is packaged as a Codex skill for installable plugin portability. Project-scoped Codex custom-agent TOML is also generated under `.codex/agents/` in the source repository.


# Mobile Offline Architect

Expert in offline-first architecture, data synchronization, and building apps that work reliably without connectivity.

## Offline-First Architecture

**Data Flow:**
```text
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   UI Layer  │ ←── │ Local Store │ ←── │  Sync Layer │
└─────────────┘     └─────────────┘     └─────────────┘
                           ↑                    ↕
                           │              ┌───────────┐
                           └───────────── │  Remote   │
                              (background)│   API     │
                                          └───────────┘
```

## Local Database Setup

**React Native with WatermelonDB:**
```typescript
import { Database } from '@nozbe/watermelondb'
import SQLiteAdapter from '@nozbe/watermelondb/adapters/sqlite'
import { mySchema } from './schema'
import { Task, Project } from './models'

const adapter = new SQLiteAdapter({
  schema: mySchema,
  migrations: [],
  jsi: true, // Enable JSI for performance
  onSetUpError: error => {
    // Handle database setup error
  },
})

export const database = new Database({
  adapter,
  modelClasses: [Task, Project],
})

// Model definition
import { Model } from '@nozbe/watermelondb'
import { field, date, readonly, children } from '@nozbe/watermelondb/decorators'

class Task extends Model {
  static table = 'tasks'
  static associations = {
    projects: { type: 'belongs_to', key: 'project_id' },
  }

  @field('title') title!: string
  @field('completed') completed!: boolean
  @field('sync_status') syncStatus!: 'synced' | 'pending' | 'failed'
  @readonly @date('created_at') createdAt!: Date
  @date('updated_at') updatedAt!: Date

  async markCompleted() {
    await this.update(task => {
      task.completed = true
      task.syncStatus = 'pending'
    })
  }
}
```

## Sync Engine

```typescript
class SyncEngine {
  private syncQueue: SyncOperation[] = []
  private isOnline = true
  private isSyncing = false

  constructor(
    private database: Database,
    private api: ApiClient
  ) {
    this.setupConnectivityListener()
  }

  private setupConnectivityListener() {
    NetInfo.addEventListener(state => {
      this.isOnline = state.isConnected ?? false
      if (this.isOnline) {
        this.processSyncQueue()
      }
    })
  }

  async pushChanges() {
    if (!this.isOnline || this.isSyncing) return

    this.isSyncing = true
    try {
      // Get all pending changes
      const pendingTasks = await this.database
        .get('tasks')
        .query(Q.where('sync_status', 'pending'))
        .fetch()

      for (const task of pendingTasks) {
        try {
          await this.api.syncTask(task.toJSON())
          await task.update(t => {
            t.syncStatus = 'synced'
          })
        } catch (error) {
          if (error.status === 409) {
            // Conflict - handle resolution
            await this.resolveConflict(task, error.serverVersion)
          } else {
            await task.update(t => {
              t.syncStatus = 'failed'
            })
          }
        }
      }
    } finally {
      this.isSyncing = false
    }
  }

  async pullChanges(lastSyncTimestamp: number) {
    const changes = await this.api.getChanges(lastSyncTimestamp)

    await this.database.write(async () => {
      for (const change of changes) {
        await this.applyChange(change)
      }
    })
  }

  private async resolveConflict(local: Task, server: TaskData) {
    // Last-write-wins strategy
    if (local.updatedAt > new Date(server.updatedAt)) {
      // Local wins - retry sync
      await this.api.syncTask(local.toJSON(), { force: true })
    } else {
      // Server wins - update local
      await local.update(t => {
        Object.assign(t, server)
        t.syncStatus = 'synced'
      })
    }
  }
}
```

## Optimistic Updates

```typescript
import { useMutation, useQueryClient } from '@tanstack/react-query'

function useUpdateTask() {
  const queryClient = useQueryClient()
  const database = useDatabase()

  return useMutation({
    mutationFn: async (task: Task) => {
      // Update local database immediately
      await database.write(async () => {
        await task.update(t => {
          t.syncStatus = 'pending'
        })
      })

      // Try to sync with server
      return api.updateTask(task.toJSON())
    },

    onMutate: async (newTask) => {
      // Cancel outgoing queries
      await queryClient.cancelQueries({ queryKey: ['tasks'] })

      // Snapshot previous value
      const previousTasks = queryClient.getQueryData(['tasks'])

      // Optimistically update
      queryClient.setQueryData(['tasks'], (old: Task[]) =>
        old.map(t => t.id === newTask.id ? newTask : t)
      )

      return { previousTasks }
    },

    onError: async (err, newTask, context) => {
      // Rollback on error
      queryClient.setQueryData(['tasks'], context?.previousTasks)

      // Mark as failed in local db
      await database.write(async () => {
        const task = await database.get('tasks').find(newTask.id)
        await task.update(t => {
          t.syncStatus = 'failed'
        })
      })
    },

    onSuccess: async (data, task) => {
      // Mark as synced
      await database.write(async () => {
        const localTask = await database.get('tasks').find(task.id)
        await localTask.update(t => {
          t.syncStatus = 'synced'
        })
      })
    },
  })
}
```

## Background Sync

```typescript
import BackgroundFetch from 'react-native-background-fetch'

async function configureBackgroundSync() {
  await BackgroundFetch.configure(
    {
      minimumFetchInterval: 15, // minutes
      stopOnTerminate: false,
      startOnBoot: true,
      enableHeadless: true,
    },
    async (taskId) => {
      console.log('[BackgroundFetch] task:', taskId)

      try {
        await syncEngine.pushChanges()
        await syncEngine.pullChanges(getLastSyncTimestamp())
      } catch (error) {
        console.error('[BackgroundFetch] error:', error)
      }

      BackgroundFetch.finish(taskId)
    },
    (taskId) => {
      console.log('[BackgroundFetch] TIMEOUT:', taskId)
      BackgroundFetch.finish(taskId)
    }
  )
}
```

## Connectivity Handling

```typescript
import NetInfo from '@react-native-community/netinfo'

function useConnectivity() {
  const [isOnline, setIsOnline] = useState(true)
  const [connectionType, setConnectionType] = useState<string>('unknown')

  useEffect(() => {
    const unsubscribe = NetInfo.addEventListener(state => {
      setIsOnline(state.isConnected ?? false)
      setConnectionType(state.type)
    })

    return () => unsubscribe()
  }, [])

  return { isOnline, connectionType }
}

// Offline indicator component
function OfflineIndicator() {
  const { isOnline } = useConnectivity()

  if (isOnline) return null

  return (
    <View style={styles.offlineBanner}>
      <Text>You're offline. Changes will sync when connected.</Text>
    </View>
  )
}
```

## Best Practices

- **Always read from local database** - network is supplementary
- **Queue all write operations** for reliable sync
- **Show sync status** to users for transparency
- **Implement conflict resolution** based on business rules
- **Handle network transitions gracefully**

## Common Pitfalls

- Not persisting sync queue across app restarts
- Ignoring conflict resolution strategies
- Not showing offline state to users
- Blocking UI while waiting for network operations
