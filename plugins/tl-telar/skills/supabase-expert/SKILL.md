---
name: "supabase-expert"
description: "Specialist in Supabase backend development for mobile applications."
source_type: "agent"
source_file: "agents/supabase-expert.md"
---

# supabase-expert

Migrated from `agents/supabase-expert.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- This agent is packaged as a Codex skill for installable plugin portability. Project-scoped Codex custom-agent TOML is also generated under `.codex/agents/` in the source repository.


# Supabase Expert

Specialist in Supabase backend development for mobile applications.

## Project Setup

**React Native Integration:**
```typescript
import { createClient } from '@supabase/supabase-js'
import AsyncStorage from '@react-native-async-storage/async-storage'
import 'react-native-url-polyfill/auto'

const supabaseUrl = process.env.SUPABASE_URL!
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY!

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    storage: AsyncStorage,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
  },
})

// Type generation: npx supabase gen types typescript --project-id your-project-id > types/supabase.ts
import { Database } from '@/types/supabase'

export type Tables<T extends keyof Database['public']['Tables']> =
  Database['public']['Tables'][T]['Row']

export type InsertTables<T extends keyof Database['public']['Tables']> =
  Database['public']['Tables'][T]['Insert']
```

## Row Level Security

**Common RLS Patterns:**
```sql
-- Enable RLS
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- Users can only see their own data
CREATE POLICY "Users can view own tasks"
ON tasks FOR SELECT
USING (auth.uid() = user_id);

-- Users can insert their own data
CREATE POLICY "Users can insert own tasks"
ON tasks FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Users can update their own data
CREATE POLICY "Users can update own tasks"
ON tasks FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Users can delete their own data
CREATE POLICY "Users can delete own tasks"
ON tasks FOR DELETE
USING (auth.uid() = user_id);

-- Team-based access
CREATE POLICY "Team members can view team tasks"
ON tasks FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM team_members
    WHERE team_members.team_id = tasks.team_id
    AND team_members.user_id = auth.uid()
  )
);

-- Public read, authenticated write
CREATE POLICY "Anyone can view public posts"
ON posts FOR SELECT
USING (is_public = true);

CREATE POLICY "Authenticated users can create posts"
ON posts FOR INSERT
WITH CHECK (auth.role() = 'authenticated');
```

## RLS Design Patterns Decision Tree

```yaml
START: What is the data ownership model?
│
├── USER-OWNED (e.g., profiles, personal tasks)
│   ├── SELECT: USING (auth.uid() = user_id)
│   ├── INSERT: WITH CHECK (auth.uid() = user_id)
│   ├── UPDATE: USING + WITH CHECK on auth.uid() = user_id
│   └── DELETE: USING (auth.uid() = user_id)
│
├── TEAM-OWNED (e.g., org docs, shared projects)
│   ├── SELECT: USING (EXISTS (SELECT 1 FROM memberships WHERE ...))
│   ├── INSERT: WITH CHECK on membership + role check
│   ├── UPDATE: USING membership + role >= 'editor'
│   └── DELETE: USING membership + role = 'admin'
│
├── PUBLIC (e.g., blog posts, product listings)
│   ├── SELECT: USING (true) OR USING (is_published = true)
│   ├── INSERT: WITH CHECK (auth.role() = 'authenticated')
│   ├── UPDATE: USING (auth.uid() = author_id)
│   └── DELETE: USING (auth.uid() = author_id OR is_admin())
│
└── ADMIN-ONLY (e.g., system config, audit logs)
    ├── SELECT: USING (auth.jwt() ->> 'role' = 'admin')
    ├── INSERT: WITH CHECK (auth.jwt() ->> 'role' = 'admin')
    ├── UPDATE: USING (auth.jwt() ->> 'role' = 'admin')
    └── DELETE: USING (auth.jwt() ->> 'role' = 'admin')
```

**Helper function for admin checks:**
```sql
CREATE OR REPLACE FUNCTION is_admin()
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid()
    AND role = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER;
```

## Authentication

```typescript
// Sign up
const signUp = async (email: string, password: string) => {
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: { name: 'John Doe' },
    },
  })
  return { data, error }
}

// Sign in
const signIn = async (email: string, password: string) => {
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  })
  return { data, error }
}

// Social login
const signInWithGoogle = async () => {
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: 'myapp://auth/callback',
    },
  })
}

// Sign in with Apple
const signInWithApple = async () => {
  const { data, error } = await supabase.auth.signInWithIdToken({
    provider: 'apple',
    token: appleIdToken,
    nonce: nonce,
  })
}

// Auth state listener
useEffect(() => {
  const { data: { subscription } } = supabase.auth.onAuthStateChange(
    (event, session) => {
      if (event === 'SIGNED_IN') {
        // Handle sign in
      } else if (event === 'SIGNED_OUT') {
        // Handle sign out
      } else if (event === 'TOKEN_REFRESHED') {
        // Token refreshed
      }
    }
  )

  return () => subscription.unsubscribe()
}, [])
```

## Database Operations

```typescript
// Fetch with types
const getTasks = async (userId: string) => {
  const { data, error } = await supabase
    .from('tasks')
    .select('*, project:projects(*)')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })

  return data as (Tables<'tasks'> & { project: Tables<'projects'> })[]
}

// Insert
const createTask = async (task: InsertTables<'tasks'>) => {
  const { data, error } = await supabase
    .from('tasks')
    .insert(task)
    .select()
    .single()

  return { data, error }
}

// Update
const updateTask = async (id: string, updates: Partial<Tables<'tasks'>>) => {
  const { data, error } = await supabase
    .from('tasks')
    .update(updates)
    .eq('id', id)
    .select()
    .single()

  return { data, error }
}

// Delete
const deleteTask = async (id: string) => {
  const { error } = await supabase
    .from('tasks')
    .delete()
    .eq('id', id)

  return { error }
}
```

## Realtime Subscriptions

```typescript
// Subscribe to changes
const subscribeToTasks = (userId: string, callback: (task: Tables<'tasks'>) => void) => {
  const channel = supabase
    .channel('tasks-changes')
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'tasks',
        filter: `user_id=eq.${userId}`,
      },
      (payload) => {
        callback(payload.new as Tables<'tasks'>)
      }
    )
    .subscribe()

  return () => {
    supabase.removeChannel(channel)
  }
}

// Presence for online status
const trackPresence = (roomId: string, userId: string) => {
  const channel = supabase.channel(`room:${roomId}`)

  channel
    .on('presence', { event: 'sync' }, () => {
      const state = channel.presenceState()
      console.log('Online users:', Object.keys(state))
    })
    .subscribe(async (status) => {
      if (status === 'SUBSCRIBED') {
        await channel.track({ user_id: userId, online_at: new Date().toISOString() })
      }
    })

  return () => supabase.removeChannel(channel)
}
```

## Edge Functions

```typescript
// supabase/functions/send-notification/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  const { userId, message } = await req.json()

  // Get user's push token
  const { data: user } = await supabase
    .from('users')
    .select('push_token')
    .eq('id', userId)
    .single()

  // Send notification via FCM/APNs
  // ...

  return new Response(JSON.stringify({ success: true }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
```

## Edge Function Patterns: When to Use

| Scenario | Use Edge Function? | Reasoning |
|----------|-------------------|-----------|
| Call third-party API with secret key | YES | Never expose API keys to client |
| Send push notifications | YES | Requires server-side credentials |
| Process payments (Stripe, etc.) | YES | Sensitive operations need server |
| Complex data aggregation | MAYBE | Use postgres function first, Edge if needs external data |
| Simple CRUD operations | NO | PostgREST handles this via client SDK |
| Data filtering/sorting | NO | Use client SDK .select().filter() |
| File validation before upload | YES | Enforce server-side validation |
| Webhook receiver | YES | External services call your endpoint |
| Scheduled/cron jobs | YES | Use pg_cron or Edge Function with cron trigger |

## Migration Strategies

**Safe Migrations (zero-downtime):**
```sql
-- Adding a nullable column (SAFE)
ALTER TABLE users ADD COLUMN avatar_url TEXT;

-- Adding an index concurrently (SAFE)
CREATE INDEX CONCURRENTLY idx_tasks_user_id ON tasks(user_id);

-- Adding a column with a default (SAFE in PG 11+)
ALTER TABLE users ADD COLUMN is_active BOOLEAN DEFAULT true;
```

**Unsafe Migrations (require planning):**
```sql
-- UNSAFE: Adding NOT NULL without default locks table
-- BAD:  ALTER TABLE users ADD COLUMN name TEXT NOT NULL;
-- GOOD: Split into steps:
ALTER TABLE users ADD COLUMN name TEXT;
UPDATE users SET name = 'Unknown' WHERE name IS NULL;
ALTER TABLE users ALTER COLUMN name SET NOT NULL;

-- UNSAFE: Renaming a column breaks running code
-- BAD:  ALTER TABLE users RENAME COLUMN name TO full_name;
-- GOOD: Add new column, migrate data, update code, then drop old:
ALTER TABLE users ADD COLUMN full_name TEXT;
UPDATE users SET full_name = name;
-- Deploy code using full_name --
ALTER TABLE users DROP COLUMN name;

-- UNSAFE: Changing column type can lock table
-- BAD:  ALTER TABLE orders ALTER COLUMN total TYPE NUMERIC(12,2);
-- GOOD: Add new column, backfill, swap in code, drop old
```

## Storage

```typescript
// Upload file
const uploadAvatar = async (userId: string, file: File) => {
  const path = `avatars/${userId}/${file.name}`

  const { data, error } = await supabase.storage
    .from('avatars')
    .upload(path, file, {
      cacheControl: '3600',
      upsert: true,
    })

  if (error) throw error

  // Get public URL
  const { data: { publicUrl } } = supabase.storage
    .from('avatars')
    .getPublicUrl(path)

  return publicUrl
}

// Download file
const downloadFile = async (path: string) => {
  const { data, error } = await supabase.storage
    .from('documents')
    .download(path)

  return data
}
```

## Decision Framework

```text
IF table has no RLS enabled
  → STOP: Enable RLS immediately, this is a critical security gap

IF query takes > 200ms on mobile
  → Check EXPLAIN ANALYZE, add missing indexes

IF client makes > 3 sequential queries for one screen
  → Refactor into single query with joins or create an RPC function

IF migration alters column type or adds NOT NULL
  → Use multi-step safe migration pattern

IF feature requires third-party API keys
  → Implement in Edge Function, never in client code

IF realtime subscription covers entire table
  → Add filter to subscription to reduce bandwidth

IF storage bucket has no policies
  → Add bucket-level RLS policies before going to production

IF auth flow needs custom claims
  → Use auth.hook or database trigger to set JWT claims
```

## Anti-Patterns

### 1. No RLS on Tables
```sql
-- BAD: Table without RLS (anyone with anon key has full access)
CREATE TABLE user_data (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES auth.users,
  secret_notes TEXT
);
-- Forgetting: ALTER TABLE user_data ENABLE ROW LEVEL SECURITY;

-- GOOD: Always enable RLS immediately after table creation
CREATE TABLE user_data (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES auth.users,
  secret_notes TEXT
);
ALTER TABLE user_data ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own data" ON user_data
  FOR SELECT USING (auth.uid() = user_id);
```

### 2. Fat Client Queries (N+1 Problem)
```typescript
// BAD: N+1 queries - fetches tasks then loops for each project
const tasks = await supabase.from('tasks').select('*').eq('user_id', uid)
for (const task of tasks.data) {
  const project = await supabase.from('projects').select('*').eq('id', task.project_id).single()
  task.project = project.data
}

// GOOD: Single query with join
const { data } = await supabase
  .from('tasks')
  .select('*, project:projects(*)')
  .eq('user_id', uid)
```

### 3. Missing Indexes on Foreign Keys and Filter Columns
```sql
-- BAD: Querying by user_id without an index (full table scan)
SELECT * FROM tasks WHERE user_id = '...';

-- GOOD: Add indexes on columns used in WHERE, JOIN, and RLS policies
CREATE INDEX idx_tasks_user_id ON tasks(user_id);
CREATE INDEX idx_team_members_team_user ON team_members(team_id, user_id);
```

### 4. Using Service Role Key in Client
```typescript
// BAD: Service role key in mobile app (bypasses all RLS)
const supabase = createClient(url, 'eyJhbGciOiJIUzI1NiIs...SERVICE_ROLE_KEY')

// GOOD: Only use anon key in client; use service role in Edge Functions only
const supabase = createClient(url, process.env.SUPABASE_ANON_KEY!)
```

### 5. Unfiltered Realtime Subscriptions
```typescript
// BAD: Subscribing to all changes on a table (wasteful on mobile)
supabase.channel('all').on('postgres_changes', { event: '*', schema: 'public', table: 'messages' }, handler)

// GOOD: Filter to only relevant rows
supabase.channel('my-messages').on('postgres_changes', {
  event: '*', schema: 'public', table: 'messages',
  filter: `room_id=eq.${roomId}`
}, handler)
```

## Escalation Paths

| Situation | Escalate To | Reason |
|-----------|-------------|--------|
| Complex PostgreSQL query optimization | DBA / PostgreSQL specialist | Requires deep knowledge of query planner and pg_stat |
| Authentication flow with native biometrics | mobile-security-expert | Biometric integration is platform-specific security |
| Realtime sync conflicts and offline-first | mobile-state-management agent | Conflict resolution is app-state concern |
| File upload with image processing | mobile-performance-expert | Image resizing/compression before upload |
| CI/CD pipeline for database migrations | mobile-cicd-engineer | Migration automation in deployment pipeline |
| Rollout of breaking schema changes | mobile-release-manager | Coordinating backend + client release timing |

## Tool Commands

```bash
# --- Project & Auth ---
supabase init                                  # Initialize local project
supabase login                                 # Authenticate CLI
supabase link --project-ref <ref>              # Link to remote project
supabase start                                 # Start local dev stack (db, auth, storage, etc.)
supabase stop                                  # Stop local dev stack
supabase status                                # Show local service status and URLs

# --- Database & Migrations ---
supabase db diff --use-migra -f <name>         # Generate migration from local schema diff
supabase migration new <name>                  # Create empty migration file
supabase migration list                        # List applied migrations
supabase db push                               # Push local migrations to remote
supabase db reset                              # Reset local DB and replay all migrations
supabase db lint                               # Lint database for common issues

# --- Type Generation ---
supabase gen types typescript --local > types/supabase.ts          # From local DB
supabase gen types typescript --project-id <ref> > types/supabase.ts  # From remote

# --- Edge Functions ---
supabase functions new <name>                  # Scaffold new Edge Function
supabase functions serve <name>                # Serve locally for development
supabase functions deploy <name>               # Deploy to production
supabase functions list                        # List deployed functions

# --- Debugging ---
supabase inspect db calls                      # Show most frequent queries
supabase inspect db long-running-queries       # Find slow queries
supabase inspect db table-sizes                # Show table sizes
supabase inspect db index-usage                # Check index utilization
supabase inspect db bloat                      # Detect table/index bloat
supabase inspect db locks                      # Show active locks

# --- Storage ---
supabase storage ls                            # List storage buckets
supabase storage cp <local> <remote>           # Upload file

# --- Logs ---
supabase logs --project-ref <ref> --service api       # API gateway logs
supabase logs --project-ref <ref> --service postgres   # Database logs
supabase logs --project-ref <ref> --service edge-function  # Edge Function logs
```

## Best Practices

- **Enable RLS on all tables** - never trust client-side only
- **Use service role key only in Edge Functions** - never in client
- **Generate TypeScript types** from database schema
- **Use realtime sparingly** - only where needed
- **Implement proper error handling** for all operations
- **Add indexes on all foreign keys and columns used in RLS policies**
- **Use CONCURRENTLY for index creation** on production tables
- **Test RLS policies** with `supabase db lint` and manual verification

## Common Pitfalls

- Disabling RLS for "convenience" (security risk)
- Using service role key in mobile app (exposes full access)
- Not handling realtime connection drops
- Missing foreign key constraints
- Running unsafe migrations without a rollback plan
- Subscribing to entire tables in realtime without filters
