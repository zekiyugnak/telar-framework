---
name: "ai-api-integration"
description: "Integrating AI APIs (OpenAI, Claude, Gemini) in mobile apps."
source_type: "skill"
source_file: "skills/ai-api-integration.md"
---

# ai-api-integration

Migrated from `skills/ai-api-integration.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# AI API Integration

Integrating AI APIs (OpenAI, Claude, Gemini) in mobile apps.

## OpenAI Chat Completion

```typescript
import OpenAI from 'openai'

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
})

async function chat(messages: Message[]) {
  const completion = await openai.chat.completions.create({
    model: 'gpt-4o',
    messages,
    max_tokens: 1000,
  })

  return completion.choices[0].message.content
}
```

## Streaming Responses

```typescript
// React Native with streaming
async function streamChat(messages: Message[], onChunk: (text: string) => void) {
  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o',
      messages,
      stream: true,
    }),
  })

  const reader = response.body?.getReader()
  const decoder = new TextDecoder()

  while (true) {
    const { done, value } = await reader!.read()
    if (done) break

    const chunk = decoder.decode(value)
    const lines = chunk.split('\n').filter(line => line.startsWith('data:'))

    for (const line of lines) {
      const data = line.replace('data: ', '')
      if (data === '[DONE]') return

      const parsed = JSON.parse(data)
      const content = parsed.choices[0]?.delta?.content
      if (content) onChunk(content)
    }
  }
}
```

## Claude API

```typescript
import Anthropic from '@anthropic-ai/sdk'

const anthropic = new Anthropic({
  apiKey: process.env.CLAUDE_API_KEY,
})

async function claudeChat(messages: Message[]) {
  const response = await anthropic.messages.create({
    model: 'claude-sonnet-4-20250514',
    max_tokens: 1024,
    messages,
  })

  return response.content[0].text
}
```

## Edge Function Proxy (Supabase)

```typescript
// supabase/functions/chat/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import OpenAI from 'https://esm.sh/openai@4'

serve(async (req) => {
  const { messages } = await req.json()

  const openai = new OpenAI({
    apiKey: Deno.env.get('OPENAI_API_KEY'),
  })

  const completion = await openai.chat.completions.create({
    model: 'gpt-4o',
    messages,
  })

  return new Response(JSON.stringify({
    message: completion.choices[0].message.content,
  }))
})

// Client usage (API key stays secure)
const { data } = await supabase.functions.invoke('chat', {
  body: { messages },
})
```

## Chat UI Component

```typescript
function ChatScreen() {
  const [messages, setMessages] = useState<Message[]>([])
  const [input, setInput] = useState('')
  const [streaming, setStreaming] = useState('')

  async function sendMessage() {
    const userMessage = { role: 'user', content: input }
    setMessages(prev => [...prev, userMessage])
    setInput('')

    await streamChat([...messages, userMessage], (chunk) => {
      setStreaming(prev => prev + chunk)
    })

    setMessages(prev => [...prev, { role: 'assistant', content: streaming }])
    setStreaming('')
  }
}
```

## Best Practices

- Proxy API calls through backend
- Implement rate limiting
- Stream responses for better UX
- Handle token limits gracefully
