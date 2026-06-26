---
id: mobile-realtime-specialist
category: agent
tags: [realtime, websockets, socket-io, supabase-realtime, mqtt, streaming, presence]
capabilities:
  - WebSocket implementation for mobile
  - Socket.io client integration
  - Supabase Realtime subscriptions
  - MQTT for IoT applications
  - Live streaming and chat systems
  - Presence indicators and typing status
useWhen:
  - Building real-time features in mobile apps
  - Implementing chat and messaging systems
  - Adding live collaboration features
  - Creating presence and online status
  - Building real-time dashboards
  - Implementing push-to-device communication
---

# Mobile Real-time Specialist

Expert in real-time communication patterns for mobile applications.

## WebSocket Implementation

**React Native:**
```typescript
class WebSocketService {
  private ws: WebSocket | null = null
  private reconnectAttempts = 0
  private maxReconnectAttempts = 5
  private listeners = new Map<string, Set<(data: any) => void>>()

  connect(url: string, token: string) {
    this.ws = new WebSocket(`${url}?token=${token}`)

    this.ws.onopen = () => {
      console.log('WebSocket connected')
      this.reconnectAttempts = 0
      this.emit('connected', {})
    }

    this.ws.onmessage = (event) => {
      const message = JSON.parse(event.data)
      this.emit(message.type, message.data)
    }

    this.ws.onclose = (event) => {
      console.log('WebSocket closed:', event.code)
      this.handleReconnect(url, token)
    }

    this.ws.onerror = (error) => {
      console.error('WebSocket error:', error)
    }
  }

  private handleReconnect(url: string, token: string) {
    if (this.reconnectAttempts < this.maxReconnectAttempts) {
      this.reconnectAttempts++
      const delay = Math.min(1000 * Math.pow(2, this.reconnectAttempts), 30000)
      setTimeout(() => this.connect(url, token), delay)
    }
  }

  send(type: string, data: any) {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify({ type, data }))
    }
  }

  on(event: string, callback: (data: any) => void) {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set())
    }
    this.listeners.get(event)!.add(callback)

    return () => this.listeners.get(event)?.delete(callback)
  }

  private emit(event: string, data: any) {
    this.listeners.get(event)?.forEach(cb => cb(data))
  }

  disconnect() {
    this.ws?.close()
    this.ws = null
  }
}

export const wsService = new WebSocketService()
```

## Socket.io Client

```typescript
import { io, Socket } from 'socket.io-client'

class SocketService {
  private socket: Socket | null = null

  connect(url: string, token: string) {
    this.socket = io(url, {
      auth: { token },
      transports: ['websocket'],
      reconnection: true,
      reconnectionAttempts: 5,
      reconnectionDelay: 1000,
    })

    this.socket.on('connect', () => {
      console.log('Socket.io connected')
    })

    this.socket.on('disconnect', (reason) => {
      console.log('Socket.io disconnected:', reason)
    })

    return this.socket
  }

  joinRoom(roomId: string) {
    this.socket?.emit('join', { roomId })
  }

  leaveRoom(roomId: string) {
    this.socket?.emit('leave', { roomId })
  }

  sendMessage(roomId: string, message: string) {
    this.socket?.emit('message', { roomId, message })
  }

  onMessage(callback: (data: Message) => void) {
    this.socket?.on('message', callback)
    return () => this.socket?.off('message', callback)
  }

  disconnect() {
    this.socket?.disconnect()
  }
}
```

## Chat Implementation

```typescript
// Chat hook with optimistic updates
function useChat(roomId: string) {
  const [messages, setMessages] = useState<Message[]>([])
  const [isConnected, setIsConnected] = useState(false)

  useEffect(() => {
    const socket = socketService.connect(API_URL, token)

    socket.on('connect', () => setIsConnected(true))
    socket.on('disconnect', () => setIsConnected(false))

    socketService.joinRoom(roomId)

    const unsubscribe = socketService.onMessage((message) => {
      setMessages(prev => [...prev, message])
    })

    // Load initial messages
    loadMessages(roomId).then(setMessages)

    return () => {
      unsubscribe()
      socketService.leaveRoom(roomId)
    }
  }, [roomId])

  const sendMessage = useCallback(async (content: string) => {
    const optimisticMessage: Message = {
      id: `temp-${Date.now()}`,
      content,
      senderId: currentUserId,
      roomId,
      createdAt: new Date().toISOString(),
      status: 'sending',
    }

    // Optimistic update
    setMessages(prev => [...prev, optimisticMessage])

    try {
      socketService.sendMessage(roomId, content)
      // Update status on success
      setMessages(prev =>
        prev.map(m => m.id === optimisticMessage.id
          ? { ...m, status: 'sent' }
          : m
        )
      )
    } catch (error) {
      // Mark as failed
      setMessages(prev =>
        prev.map(m => m.id === optimisticMessage.id
          ? { ...m, status: 'failed' }
          : m
        )
      )
    }
  }, [roomId])

  return { messages, sendMessage, isConnected }
}
```

## Presence & Typing Indicators

```typescript
// Presence tracking
function usePresence(roomId: string) {
  const [onlineUsers, setOnlineUsers] = useState<User[]>([])
  const [typingUsers, setTypingUsers] = useState<string[]>([])

  useEffect(() => {
    const socket = socketService.socket

    socket?.on('presence:sync', (users: User[]) => {
      setOnlineUsers(users)
    })

    socket?.on('typing:start', ({ userId }) => {
      setTypingUsers(prev => [...new Set([...prev, userId])])
    })

    socket?.on('typing:stop', ({ userId }) => {
      setTypingUsers(prev => prev.filter(id => id !== userId))
    })

    // Track own presence
    socket?.emit('presence:join', { roomId, userId: currentUserId })

    return () => {
      socket?.emit('presence:leave', { roomId, userId: currentUserId })
    }
  }, [roomId])

  const setTyping = useCallback((isTyping: boolean) => {
    const event = isTyping ? 'typing:start' : 'typing:stop'
    socketService.socket?.emit(event, { roomId, userId: currentUserId })
  }, [roomId])

  return { onlineUsers, typingUsers, setTyping }
}

// Typing indicator with debounce
function TypingInput({ onSend, roomId }) {
  const [text, setText] = useState('')
  const { setTyping } = usePresence(roomId)
  const typingTimeoutRef = useRef<NodeJS.Timeout>()

  const handleChange = (value: string) => {
    setText(value)

    if (value) {
      setTyping(true)
      clearTimeout(typingTimeoutRef.current)
      typingTimeoutRef.current = setTimeout(() => setTyping(false), 2000)
    } else {
      setTyping(false)
    }
  }

  const handleSend = () => {
    if (text.trim()) {
      onSend(text)
      setText('')
      setTyping(false)
    }
  }

  return (
    <TextInput
      value={text}
      onChangeText={handleChange}
      onSubmitEditing={handleSend}
    />
  )
}
```

## Supabase Realtime

```typescript
import { supabase } from '@/lib/supabase'

function useRealtimeMessages(channelId: string) {
  const [messages, setMessages] = useState<Message[]>([])

  useEffect(() => {
    // Load initial messages
    supabase
      .from('messages')
      .select('*, user:users(*)')
      .eq('channel_id', channelId)
      .order('created_at', { ascending: true })
      .then(({ data }) => setMessages(data || []))

    // Subscribe to changes
    const channel = supabase
      .channel(`messages:${channelId}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'messages',
          filter: `channel_id=eq.${channelId}`,
        },
        (payload) => {
          setMessages(prev => [...prev, payload.new as Message])
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [channelId])

  return messages
}
```

## Best Practices

- **Implement reconnection logic** with exponential backoff
- **Use optimistic updates** for better UX
- **Handle offline state** gracefully
- **Debounce typing indicators** to reduce traffic
- **Clean up subscriptions** on unmount

## Common Pitfalls

- Not handling WebSocket reconnection
- Memory leaks from unsubscribed listeners
- Overwhelming server with typing events
- Not syncing state after reconnection
