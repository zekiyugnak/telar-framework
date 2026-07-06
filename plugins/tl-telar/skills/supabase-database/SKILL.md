---
name: "supabase-database"
description: "Row Level Security is the single most important security mechanism in Supabase. Without it, any authenticated user can read, modify, or delete every row in your table. This skill covers RLS patterns, optimistic updates, "
source_type: "skill"
source_file: "skills/supabase-database.md"
---

# supabase-database

Migrated from `skills/supabase-database.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Secure Supabase Database Patterns for Mobile Apps

Row Level Security is the single most important security mechanism in Supabase. Without it, any authenticated user can read, modify, or delete every row in your table. This skill covers RLS patterns, optimistic updates, real-time subscriptions, and efficient query design for mobile.

## Problem

Without RLS policies, every authenticated user has full access to every row. The Supabase client sends the user's JWT, but without policies the database ignores it entirely.

```typescript
// BAD: Table created without RLS - every user sees every row
// Any authenticated user can run this and get ALL user profiles
const { data } = await supabase
  .from('profiles')
  .select('*');
// Returns: ALL 50,000 profiles including email, phone, address

// BAD: No RLS means any user can delete anyone's data
const { error } = await supabase
  .from('messages')
  .delete()
  .eq('user_id', 'some-other-users-id');
// Succeeds! Deletes another user's messages

// BAD: Fetching entire rows when only name/avatar needed
const { data } = await supabase
  .from('profiles')
  .select('*'); // Downloads email, phone, SSN, address...

// BAD: Loading all items at once instead of paginating
const { data } = await supabase
  .from('posts')
  .select('*')
  .order('created_at', { ascending: false });
// Returns 10,000 rows, mobile app freezes parsing JSON

// BAD: Real-time subscription without cleanup
function ChatScreen({ channelId }) {
  const [messages, setMessages] = useState([]);

  useEffect(() => {
    supabase
      .channel(`chat-${channelId}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'messages',
        filter: `channel_id=eq.${channelId}`,
      }, (payload) => {
        setMessages(prev => [...prev, payload.new]);
      })
      .subscribe();
    // No cleanup! Subscription leaks on unmount or channelId change
  }, [channelId]);
}

// BAD: Optimistic update without rollback
async function toggleLike(postId: string) {
  // Update UI immediately
  setLiked(true);
  setLikeCount(prev => prev + 1);

  // If this fails, UI is now permanently wrong
  const { error } = await supabase
    .from('likes')
    .insert({ post_id: postId, user_id: userId });
}
```

## Solution

### 1. RLS Policies: User-Owned Data

```sql
-- GOOD: Complete RLS setup for user-owned data
-- Every table MUST have RLS enabled before going to production

-- User profiles: each user owns exactly one row
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL,
  avatar_url TEXT,
  bio TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Anyone can view profiles (public read)
CREATE POLICY "profiles_select_public"
  ON profiles FOR SELECT
  USING (true);

-- Users can only update their own profile
CREATE POLICY "profiles_update_own"
  ON profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Users can only insert their own profile row
CREATE POLICY "profiles_insert_own"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Users can only delete their own profile
CREATE POLICY "profiles_delete_own"
  ON profiles FOR DELETE
  USING (auth.uid() = id);
```

### 2. RLS Policies: Team/Organization Data

```sql
-- GOOD: Team-based access using a membership junction table
CREATE TABLE teams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  created_by UUID REFERENCES auth.users(id) NOT NULL
);

CREATE TABLE team_members (
  team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'member', 'viewer')),
  PRIMARY KEY (team_id, user_id)
);

CREATE TABLE team_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID REFERENCES teams(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  content TEXT,
  created_by UUID REFERENCES auth.users(id) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_documents ENABLE ROW LEVEL SECURITY;

-- Helper function to check membership (avoids policy duplication)
CREATE OR REPLACE FUNCTION is_team_member(team_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM team_members
    WHERE team_members.team_id = $1
      AND team_members.user_id = auth.uid()
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Helper function to check admin/owner role
CREATE OR REPLACE FUNCTION is_team_admin(team_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM team_members
    WHERE team_members.team_id = $1
      AND team_members.user_id = auth.uid()
      AND team_members.role IN ('owner', 'admin')
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Team members can view their teams
CREATE POLICY "team_members_select"
  ON teams FOR SELECT
  USING (is_team_member(id));

-- Team documents: members can read, admins can write
CREATE POLICY "team_docs_select"
  ON team_documents FOR SELECT
  USING (is_team_member(team_id));

CREATE POLICY "team_docs_insert"
  ON team_documents FOR INSERT
  WITH CHECK (is_team_member(team_id) AND auth.uid() = created_by);

CREATE POLICY "team_docs_update"
  ON team_documents FOR UPDATE
  USING (is_team_admin(team_id));

CREATE POLICY "team_docs_delete"
  ON team_documents FOR DELETE
  USING (is_team_admin(team_id));
```

### 3. RLS Policies: Public Read / Private Write

```sql
-- GOOD: Blog-style public read, authenticated write
CREATE TABLE posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id UUID REFERENCES auth.users(id) NOT NULL,
  title TEXT NOT NULL,
  body TEXT,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- Anyone (including anonymous) can read published posts
CREATE POLICY "posts_public_read"
  ON posts FOR SELECT
  USING (status = 'published');

-- Authors can see their own drafts too
CREATE POLICY "posts_author_read_drafts"
  ON posts FOR SELECT
  USING (auth.uid() = author_id);

-- Only the author can insert, update, delete their posts
CREATE POLICY "posts_author_insert"
  ON posts FOR INSERT
  WITH CHECK (auth.uid() = author_id);

CREATE POLICY "posts_author_update"
  ON posts FOR UPDATE
  USING (auth.uid() = author_id)
  WITH CHECK (auth.uid() = author_id);

CREATE POLICY "posts_author_delete"
  ON posts FOR DELETE
  USING (auth.uid() = author_id);
```

### 4. Optimistic Updates with Rollback

```typescript
// GOOD: Optimistic update with full rollback on failure
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '../lib/supabase';
import { Alert } from 'react-native';

interface Post {
  id: string;
  title: string;
  like_count: number;
  liked_by_me: boolean;
}

function useToggleLike(postId: string) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ liked }: { liked: boolean }) => {
      if (liked) {
        const { error } = await supabase
          .from('likes')
          .insert({ post_id: postId });
        if (error) throw error;
      } else {
        const { error } = await supabase
          .from('likes')
          .delete()
          .eq('post_id', postId);
        if (error) throw error;
      }
    },

    // Snapshot previous state before mutating
    onMutate: async ({ liked }) => {
      // Cancel in-flight queries so they don't overwrite our optimistic update
      await queryClient.cancelQueries({ queryKey: ['posts'] });

      const previousPosts = queryClient.getQueryData<Post[]>(['posts']);

      // Optimistically update the cache
      queryClient.setQueryData<Post[]>(['posts'], (old) =>
        (old ?? []).map((post) =>
          post.id === postId
            ? {
                ...post,
                liked_by_me: liked,
                like_count: post.like_count + (liked ? 1 : -1),
              }
            : post
        )
      );

      // Return snapshot for rollback
      return { previousPosts };
    },

    // Rollback on error
    onError: (_error, _variables, context) => {
      if (context?.previousPosts) {
        queryClient.setQueryData(['posts'], context.previousPosts);
      }
      Alert.alert('Error', 'Could not update. Please try again.');
    },

    // Refetch to ensure server truth after mutation settles
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['posts'] });
    },
  });
}
```

### 5. Real-Time Subscriptions with Proper Cleanup

```typescript
// GOOD: Real-time subscription with full lifecycle management
import { useEffect, useRef, useCallback, useState } from 'react';
import { AppState, AppStateStatus } from 'react-native';
import { RealtimeChannel } from '@supabase/supabase-js';
import { supabase } from '../lib/supabase';

interface Message {
  id: string;
  channel_id: string;
  user_id: string;
  content: string;
  created_at: string;
}

function useChatMessages(channelId: string) {
  const [messages, setMessages] = useState<Message[]>([]);
  const channelRef = useRef<RealtimeChannel | null>(null);

  // Memoize the subscription setup
  const subscribe = useCallback(() => {
    // Remove previous subscription if channel changed
    if (channelRef.current) {
      supabase.removeChannel(channelRef.current);
    }

    const channel = supabase
      .channel(`chat-${channelId}`)
      .on<Message>(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'messages',
          filter: `channel_id=eq.${channelId}`,
        },
        (payload) => {
          setMessages((prev) => [...prev, payload.new]);
        }
      )
      .on<Message>(
        'postgres_changes',
        {
          event: 'DELETE',
          schema: 'public',
          table: 'messages',
          filter: `channel_id=eq.${channelId}`,
        },
        (payload) => {
          setMessages((prev) =>
            prev.filter((m) => m.id !== payload.old.id)
          );
        }
      )
      .subscribe((status) => {
        if (status === 'CHANNEL_ERROR') {
          // Retry after a delay
          setTimeout(() => subscribe(), 3000);
        }
      });

    channelRef.current = channel;
  }, [channelId]);

  useEffect(() => {
    subscribe();

    // Pause/resume on app background/foreground
    const appStateListener = AppState.addEventListener(
      'change',
      (state: AppStateStatus) => {
        if (state === 'active') {
          subscribe();
        } else if (state === 'background') {
          if (channelRef.current) {
            supabase.removeChannel(channelRef.current);
            channelRef.current = null;
          }
        }
      }
    );

    return () => {
      // Cleanup on unmount
      if (channelRef.current) {
        supabase.removeChannel(channelRef.current);
        channelRef.current = null;
      }
      appStateListener.remove();
    };
  }, [subscribe]);

  return messages;
}
```

### 6. Efficient Query Patterns

```typescript
// GOOD: Select only needed columns, paginate, use indexes
import { supabase } from '../lib/supabase';

const PAGE_SIZE = 20;

async function fetchFeed(page: number) {
  const from = page * PAGE_SIZE;
  const to = from + PAGE_SIZE - 1;

  const { data, error, count } = await supabase
    .from('posts')
    .select(
      // Only fetch columns the UI needs - reduces payload 5-10x
      `id, title, created_at,
       author:profiles!author_id(display_name, avatar_url),
       like_count,
       comment_count`,
      // Request total count for pagination UI
      { count: 'exact' }
    )
    .eq('status', 'published')
    .order('created_at', { ascending: false })
    .range(from, to);

  if (error) throw error;

  return {
    posts: data,
    totalCount: count ?? 0,
    hasMore: (count ?? 0) > to + 1,
  };
}

// GOOD: Cursor-based pagination for real-time feeds (no skipped/duplicate rows)
async function fetchFeedCursor(cursor?: string) {
  let query = supabase
    .from('posts')
    .select('id, title, created_at, author:profiles!author_id(display_name, avatar_url)')
    .eq('status', 'published')
    .order('created_at', { ascending: false })
    .limit(PAGE_SIZE);

  if (cursor) {
    query = query.lt('created_at', cursor);
  }

  const { data, error } = await query;
  if (error) throw error;

  return {
    posts: data,
    nextCursor: data.length === PAGE_SIZE
      ? data[data.length - 1].created_at
      : null,
  };
}

// GOOD: Use database function for complex aggregations instead of N+1 queries
// Define in a migration:
// CREATE FUNCTION get_post_with_stats(post_id UUID)
// RETURNS JSON AS $$ ... $$ LANGUAGE plpgsql STABLE;
async function fetchPostDetail(postId: string) {
  const { data, error } = await supabase.rpc('get_post_with_stats', {
    post_id: postId,
  });
  if (error) throw error;
  return data;
}
```

## Why This Works

- **RLS is enforced at the database level**: Even if someone bypasses your client code and calls the REST API directly, policies still block unauthorized access. This is defense-in-depth, not just client-side filtering.
- **SECURITY DEFINER helper functions**: Centralizing membership checks in functions avoids duplicating subqueries across every policy and ensures consistent authorization logic.
- **Optimistic updates with snapshots**: By capturing `previousPosts` in `onMutate`, the rollback in `onError` restores exact prior state. `onSettled` then reconciles with the server regardless of success or failure.
- **Channel cleanup on unmount and background**: Mobile apps frequently suspend. Leaving subscriptions open wastes battery and bandwidth. Cleaning up on background and resubscribing on foreground is the correct lifecycle.
- **Selective columns reduce payload**: Fetching `select('*')` on a table with TEXT or JSONB columns can return megabytes. Specifying only needed columns cuts mobile data transfer significantly.
- **Cursor pagination avoids offset drift**: When new rows are inserted during pagination, offset-based queries skip or duplicate rows. Cursor-based pagination using `created_at` or another monotonic column is stable.

## Edge Cases & Pitfalls

### RLS Policy Gotchas

- **Forgetting `WITH CHECK` on UPDATE**: The `USING` clause filters which rows you can see; `WITH CHECK` validates the new row values. Without `WITH CHECK`, a user could update their row to set `user_id` to someone else's ID.
- **Service role key bypasses RLS**: Never expose `SUPABASE_SERVICE_ROLE_KEY` in mobile code. It bypasses all policies. Only use it in server-side Edge Functions.
- **RLS on joined tables**: If table A has RLS but table B does not, a join from A to B leaks B's data. Enable RLS on every table.
- **Performance with complex policies**: Policies run on every query. Use `STABLE` functions and ensure indexed columns are used in `USING` clauses.

### Real-Time Pitfalls

- **Subscription limits**: Free tier allows 200 concurrent connections. Shared channels reduce this pressure.
- **Filter syntax**: Realtime filters only support `eq`. For complex filtering, filter in the client callback.
- **Stale closures**: Use functional state updates (`setMessages(prev => ...)`) in subscription callbacks to avoid stale closure bugs.

### Mobile-Specific Issues

- **Network transitions**: When switching from Wi-Fi to cellular, subscriptions silently die. Monitor `AppState` and `NetInfo` to resubscribe.
- **Background execution**: iOS suspends background network after ~30 seconds. Accept that real-time will not work in background and refetch on foreground.

## Verification

```bash
# Verify RLS is enabled on all tables
# Run via Supabase SQL editor or psql:
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public';
# Every table should show rowsecurity = true

# Test that an unauthenticated user cannot read protected data
# In Supabase dashboard > SQL Editor, switch role to anon:
SET ROLE anon;
SELECT * FROM profiles; -- Should return 0 rows or only public data
RESET ROLE;
```

- [ ] RLS enabled on every public table (`rowsecurity = true`)
- [ ] Tested each policy by switching roles in SQL editor
- [ ] Real-time subscriptions clean up on unmount (check Supabase dashboard active connections)
- [ ] Optimistic updates roll back correctly when network is disabled
- [ ] Paginated queries return correct page sizes with no duplicates
- [ ] Service role key is NOT present in any mobile client code

## References

- [Supabase Row Level Security Guide](https://supabase.com/docs/guides/auth/row-level-security)
- [Supabase Realtime Documentation](https://supabase.com/docs/guides/realtime)
- [Supabase Client select() API](https://supabase.com/docs/reference/javascript/select)
- [TanStack Query Optimistic Updates](https://tanstack.com/query/latest/docs/react/guides/optimistic-updates)
- [Supabase Performance Advisors](https://supabase.com/docs/guides/platform/performance-advisors)
