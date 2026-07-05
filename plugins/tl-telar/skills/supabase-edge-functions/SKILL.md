---
name: "supabase-edge-functions"
description: "Serverless functions with Supabase Edge Functions."
source_type: "skill"
source_file: "skills/supabase-edge-functions.md"
---

# supabase-edge-functions

Migrated from `skills/supabase-edge-functions.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Supabase Edge Functions

Serverless functions with Supabase Edge Functions.

## Create Edge Function

```bash
# Create new function
supabase functions new my-function

# Local development
supabase functions serve my-function --env-file .env.local
```

## Basic Function

```typescript
// supabase/functions/my-function/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const { data, error } = await supabase
      .from('users')
      .select('*')
      .limit(10)

    return new Response(JSON.stringify({ data }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
```

## Authenticated Requests

```typescript
serve(async (req) => {
  // Get JWT from Authorization header
  const authHeader = req.headers.get('Authorization')!
  const token = authHeader.replace('Bearer ', '')

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } }
  )

  // This respects RLS
  const { data: { user } } = await supabase.auth.getUser(token)
  const { data } = await supabase.from('posts').select('*')

  return new Response(JSON.stringify({ user, data }))
})
```

## Call from Client

```typescript
// Call edge function
const { data, error } = await supabase.functions.invoke('my-function', {
  body: { name: 'John' },
  headers: { 'Custom-Header': 'value' },
})

// With authentication (automatic)
const { data, error } = await supabase.functions.invoke('protected-function')
```

## Deploy

```bash
# Set secrets
supabase secrets set OPENAI_API_KEY=sk-xxx

# Deploy single function
supabase functions deploy my-function

# Deploy all functions
supabase functions deploy
```

## Best Practices

- Use service role key only when needed
- Pass auth header for user context
- Store secrets with `supabase secrets`
- Handle CORS for browser requests
