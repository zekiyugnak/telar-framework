---
name: "blueprint-chat-feature"
description: "Real-time chat with message list, input bar, typing indicators, read receipts, and Supabase Realtime backend."
source_type: "blueprint"
source_file: "skills/blueprints/chat-feature.md"
---

# blueprint-chat-feature

Migrated from `skills/blueprints/chat-feature.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Blueprint: Chat Feature

Real-time chat with message list, input bar, typing indicators, read receipts, and Supabase Realtime backend.

## File Manifest

```markdown
# React Native (TypeScript)
src/
  screens/chat/
    ChatScreen.tsx
    ChatListScreen.tsx
  hooks/
    useMessages.ts
    useTypingIndicator.ts
    useChatRealtime.ts
  components/chat/
    MessageBubble.tsx
    ChatInput.tsx
    TypingIndicator.tsx
    MessageStatus.tsx
  __tests__/
    useMessages.test.ts
    ChatScreen.test.tsx

# Flutter (Dart)
lib/
  features/chat/
    screens/
      chat_screen.dart
      chat_list_screen.dart
    providers/
      messages_provider.dart
      typing_indicator_provider.dart
      chat_realtime_provider.dart
    widgets/
      message_bubble.dart
      chat_input.dart
      typing_indicator.dart
      message_status.dart
test/
  features/chat/
    messages_provider_test.dart
    chat_screen_test.dart
```

## React Native Implementation

### Real-time Messages Hook
```typescript
// src/hooks/useMessages.ts
import { useEffect, useState, useCallback, useRef } from 'react';
import { supabase } from '../services/supabase';

interface Message {
  id: string;
  chat_id: string;
  sender_id: string;
  content: string;
  status: 'sending' | 'sent' | 'delivered' | 'read';
  created_at: string;
}

export function useMessages(chatId: string) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [loading, setLoading] = useState(true);
  const channelRef = useRef<ReturnType<typeof supabase.channel> | null>(null);

  // Load initial messages
  useEffect(() => {
    const load = async () => {
      const { data } = await supabase
        .from('messages')
        .select('*')
        .eq('chat_id', chatId)
        .order('created_at', { ascending: false })
        .limit(50);
      setMessages((data ?? []).reverse());
      setLoading(false);
    };
    load();
  }, [chatId]);

  // Subscribe to real-time inserts
  useEffect(() => {
    const channel = supabase
      .channel(`chat:${chatId}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'messages',
        filter: `chat_id=eq.${chatId}`,
      }, (payload) => {
        setMessages(prev => [...prev, payload.new as Message]);
      })
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'messages',
        filter: `chat_id=eq.${chatId}`,
      }, (payload) => {
        setMessages(prev =>
          prev.map(m => m.id === payload.new.id ? payload.new as Message : m)
        );
      })
      .subscribe();

    channelRef.current = channel;
    return () => { supabase.removeChannel(channel); };
  }, [chatId]);

  const sendMessage = useCallback(async (content: string) => {
    const optimisticId = `temp-${Date.now()}`;
    const optimistic: Message = {
      id: optimisticId,
      chat_id: chatId,
      sender_id: 'current-user',
      content,
      status: 'sending',
      created_at: new Date().toISOString(),
    };

    setMessages(prev => [...prev, optimistic]);

    const { data, error } = await supabase
      .from('messages')
      .insert({ chat_id: chatId, content })
      .select()
      .single();

    if (error) {
      setMessages(prev => prev.filter(m => m.id !== optimisticId));
    } else {
      setMessages(prev =>
        prev.map(m => m.id === optimisticId ? data : m)
      );
    }
  }, [chatId]);

  return { messages, loading, sendMessage };
}
```

### Chat Screen
```tsx
// src/screens/chat/ChatScreen.tsx
import { FlatList, KeyboardAvoidingView, Platform } from 'react-native';
import { useMessages } from '../../hooks/useMessages';
import { useTypingIndicator } from '../../hooks/useTypingIndicator';
import { MessageBubble } from '../../components/chat/MessageBubble';
import { ChatInput } from '../../components/chat/ChatInput';
import { TypingIndicator } from '../../components/chat/TypingIndicator';

export function ChatScreen({ route }: Props) {
  const { chatId } = route.params;
  const { messages, loading, sendMessage } = useMessages(chatId);
  const { isTyping, setTyping } = useTypingIndicator(chatId);
  const flatListRef = useRef<FlatList>(null);

  const renderMessage = useCallback(({ item }: { item: Message }) => (
    <MessageBubble
      message={item}
      isOwn={item.sender_id === currentUserId}
    />
  ), [currentUserId]);

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      keyboardVerticalOffset={90}
    >
      <FlatList
        ref={flatListRef}
        data={messages}
        renderItem={renderMessage}
        keyExtractor={(item) => item.id}
        onContentSizeChange={() => flatListRef.current?.scrollToEnd()}
        inverted={false}
        accessibilityRole="list"
        accessibilityLabel="Chat messages"
      />

      {isTyping && <TypingIndicator />}

      <ChatInput
        onSend={sendMessage}
        onTyping={setTyping}
      />
    </KeyboardAvoidingView>
  );
}
```

### Typing Indicator Hook
```typescript
// src/hooks/useTypingIndicator.ts
export function useTypingIndicator(chatId: string) {
  const [typingUsers, setTypingUsers] = useState<string[]>([]);
  const timeoutRef = useRef<NodeJS.Timeout>();

  useEffect(() => {
    const channel = supabase.channel(`typing:${chatId}`)
      .on('presence', { event: 'sync' }, () => {
        const state = channel.presenceState();
        const typing = Object.values(state)
          .flat()
          .filter((p: any) => p.is_typing && p.user_id !== currentUserId)
          .map((p: any) => p.user_id);
        setTypingUsers(typing);
      })
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [chatId]);

  const setTyping = useCallback((isTyping: boolean) => {
    clearTimeout(timeoutRef.current);
    supabase.channel(`typing:${chatId}`).track({ is_typing: isTyping, user_id: currentUserId });
    if (isTyping) {
      timeoutRef.current = setTimeout(() => {
        supabase.channel(`typing:${chatId}`).track({ is_typing: false, user_id: currentUserId });
      }, 3000);
    }
  }, [chatId]);

  return { isTyping: typingUsers.length > 0, typingUsers, setTyping };
}
```

## Flutter Implementation

### Messages Provider
```dart
// lib/features/chat/providers/messages_provider.dart
final messagesProvider = StateNotifierProvider.family<MessagesNotifier, MessagesState, String>(
  (ref, chatId) => MessagesNotifier(Supabase.instance.client, chatId),
);

class MessagesNotifier extends StateNotifier<MessagesState> {
  final SupabaseClient _client;
  final String _chatId;
  RealtimeChannel? _channel;

  MessagesNotifier(this._client, this._chatId) : super(const MessagesState()) {
    _loadMessages();
    _subscribeToRealtime();
  }

  Future<void> _loadMessages() async {
    state = state.copyWith(loading: true);
    final data = await _client
        .from('messages')
        .select()
        .eq('chat_id', _chatId)
        .order('created_at', ascending: false)
        .limit(50);
    state = state.copyWith(
      messages: (data as List).map((e) => Message.fromJson(e)).toList().reversed.toList(),
      loading: false,
    );
  }

  void _subscribeToRealtime() {
    _channel = _client.channel('chat:$_chatId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'chat_id', value: _chatId),
        callback: (payload) {
          final msg = Message.fromJson(payload.newRecord);
          state = state.copyWith(messages: [...state.messages, msg]);
        },
      )
      .subscribe();
  }

  Future<void> sendMessage(String content) async {
    final optimistic = Message(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      chatId: _chatId,
      senderId: _client.auth.currentUser!.id,
      content: content,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, optimistic]);

    try {
      await _client.from('messages').insert({'chat_id': _chatId, 'content': content});
    } catch (e) {
      state = state.copyWith(
        messages: state.messages.where((m) => m.id != optimistic.id).toList(),
      );
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
```

## Supabase Backend

```sql
CREATE TABLE public.chats (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.chat_members (
  chat_id UUID REFERENCES public.chats(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (chat_id, user_id)
);

CREATE TABLE public.messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  chat_id UUID REFERENCES public.chats(id) ON DELETE CASCADE NOT NULL,
  sender_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  content TEXT NOT NULL,
  status TEXT DEFAULT 'sent' CHECK (status IN ('sent', 'delivered', 'read')),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX messages_chat_created ON public.messages (chat_id, created_at DESC);

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Chat members can read messages"
  ON public.messages FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM public.chat_members
    WHERE chat_members.chat_id = messages.chat_id
    AND chat_members.user_id = auth.uid()
  ));

CREATE POLICY "Chat members can send messages"
  ON public.messages FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id
    AND EXISTS (
      SELECT 1 FROM public.chat_members
      WHERE chat_members.chat_id = messages.chat_id
      AND chat_members.user_id = auth.uid()
    )
  );

-- Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
```

## Tests

```typescript
describe('useMessages', () => {
  it('loads initial messages', async () => {
    const { result } = renderHook(() => useMessages('chat-1'), { wrapper });
    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(result.current.messages).toHaveLength(10);
  });

  it('sends message optimistically', async () => {
    const { result } = renderHook(() => useMessages('chat-1'), { wrapper });
    await act(async () => { await result.current.sendMessage('Hello!'); });
    expect(result.current.messages.at(-1)?.content).toBe('Hello!');
  });
});
```

## Accessibility Checklist

- [x] Message list announces new messages via live region
- [x] Message bubbles include sender name and timestamp for screen readers
- [x] Chat input has accessible label and send button
- [x] Typing indicator announced to screen readers
- [x] Keyboard avoiding works for all screen sizes
- [x] Message status (sent/delivered/read) communicated accessibly
