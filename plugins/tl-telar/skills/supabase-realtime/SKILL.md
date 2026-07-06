---
name: "supabase-realtime"
description: "Real-time features with Supabase."
source_type: "skill"
source_file: "skills/supabase-realtime.md"
---

# supabase-realtime

Migrated from `skills/supabase-realtime.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Supabase Realtime

Real-time features with Supabase.

## Database Changes Subscription

```typescript
// Subscribe to table changes
useEffect(() => {
  const channel = supabase
    .channel('posts-changes')
    .on(
      'postgres_changes',
      {
        event: '*', // INSERT, UPDATE, DELETE
        schema: 'public',
        table: 'posts',
        filter: 'user_id=eq.123',
      },
      (payload) => {
        console.log('Change received:', payload)
        if (payload.eventType === 'INSERT') {
          setPosts(prev => [payload.new, ...prev])
        } else if (payload.eventType === 'DELETE') {
          setPosts(prev => prev.filter(p => p.id !== payload.old.id))
        }
      }
    )
    .subscribe()

  return () => {
    supabase.removeChannel(channel)
  }
}, [])
```

## Presence (Online Users)

```typescript
const channel = supabase.channel('room:lobby')

// Track user presence
channel
  .on('presence', { event: 'sync' }, () => {
    const state = channel.presenceState()
    setOnlineUsers(Object.values(state).flat())
  })
  .on('presence', { event: 'join' }, ({ key, newPresences }) => {
    console.log('User joined:', newPresences)
  })
  .on('presence', { event: 'leave' }, ({ key, leftPresences }) => {
    console.log('User left:', leftPresences)
  })
  .subscribe(async (status) => {
    if (status === 'SUBSCRIBED') {
      await channel.track({
        user_id: userId,
        username: 'John',
        online_at: new Date().toISOString(),
      })
    }
  })
```

## Broadcast (Ephemeral Messages)

```typescript
// Send cursor position (no persistence)
const channel = supabase.channel('room:drawing')

channel
  .on('broadcast', { event: 'cursor' }, ({ payload }) => {
    updateCursorPosition(payload.userId, payload.x, payload.y)
  })
  .subscribe()

// Send broadcast
function sendCursorPosition(x: number, y: number) {
  channel.send({
    type: 'broadcast',
    event: 'cursor',
    payload: { userId, x, y },
  })
}
```

## Flutter Realtime

```dart
final channel = supabase.channel('posts');

channel
    .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'posts',
      callback: (payload) {
        print('Change: ${payload.newRecord}');
      },
    )
    .subscribe();

// Cleanup
@override
void dispose() {
  supabase.removeChannel(channel);
  super.dispose();
}
```

## Best Practices

- Unsubscribe when component unmounts
- Use filters to reduce data transfer
- Implement reconnection handling
- Use broadcast for ephemeral data
