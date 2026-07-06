---
name: "image-video-generation"
description: "AI-powered image and video generation in mobile apps."
source_type: "skill"
source_file: "skills/image-video-generation.md"
---

# image-video-generation

Migrated from `skills/image-video-generation.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Image & Video Generation

AI-powered image and video generation in mobile apps.

## DALL-E Image Generation

```typescript
import OpenAI from 'openai'

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY })

async function generateImage(prompt: string) {
  const response = await openai.images.generate({
    model: 'dall-e-3',
    prompt,
    n: 1,
    size: '1024x1024',
    quality: 'standard',
    response_format: 'url', // or 'b64_json'
  })

  return response.data[0].url
}

// Edit existing image
async function editImage(imageBase64: string, prompt: string, maskBase64?: string) {
  const response = await openai.images.edit({
    image: Buffer.from(imageBase64, 'base64'),
    mask: maskBase64 ? Buffer.from(maskBase64, 'base64') : undefined,
    prompt,
    n: 1,
    size: '1024x1024',
  })

  return response.data[0].url
}
```

## Image Generation UI

```typescript
function ImageGenerator() {
  const [prompt, setPrompt] = useState('')
  const [image, setImage] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  async function generate() {
    setLoading(true)
    try {
      // Call via Edge Function to protect API key
      const { data } = await supabase.functions.invoke('generate-image', {
        body: { prompt },
      })
      setImage(data.url)
    } finally {
      setLoading(false)
    }
  }

  return (
    <View>
      <TextInput value={prompt} onChangeText={setPrompt} />
      <Button title="Generate" onPress={generate} disabled={loading} />
      {image && <Image source={{ uri: image }} style={styles.image} />}
    </View>
  )
}
```

## Replicate API (Stable Diffusion)

```typescript
// supabase/functions/generate-image/index.ts
import Replicate from 'https://esm.sh/replicate'

const replicate = new Replicate({
  auth: Deno.env.get('REPLICATE_API_TOKEN'),
})

const output = await replicate.run(
  'stability-ai/sdxl:39ed52f2a78e934b3ba6e2a89f5b1c712de7dfea535525255b1aa35c5565e08b',
  {
    input: {
      prompt: 'A serene mountain landscape',
      negative_prompt: 'blurry, low quality',
      width: 1024,
      height: 1024,
    },
  }
)
```

## Image Upload & Processing

```typescript
import { manipulateAsync, SaveFormat } from 'expo-image-manipulator'

async function processAndUpload(uri: string) {
  // Resize and compress
  const processed = await manipulateAsync(
    uri,
    [{ resize: { width: 1024 } }],
    { compress: 0.8, format: SaveFormat.JPEG }
  )

  // Upload to Supabase Storage
  const response = await fetch(processed.uri)
  const blob = await response.blob()

  const { data, error } = await supabase.storage
    .from('images')
    .upload(`generated/${Date.now()}.jpg`, blob)

  return supabase.storage.from('images').getPublicUrl(data.path)
}
```

## Best Practices

- Generate images server-side
- Implement content moderation
- Cache generated images
- Handle long generation times with loading states
