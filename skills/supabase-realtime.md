---
id: supabase-realtime
category: skill
tags: [supabase, realtime, subscriptions, presence, broadcast]
capabilities:
  - Realtime subscriptions
  - Presence tracking
  - Broadcast channels
  - Database change streaming
useWhen:
  - Building real-time features
  - Implementing presence
  - Creating collaborative features
---

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
