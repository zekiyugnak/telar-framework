---
name: "supabase-storage"
description: "File storage with Supabase in mobile apps."
source_type: "skill"
source_file: "skills/supabase-storage.md"
---

# supabase-storage

Migrated from `skills/supabase-storage.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Supabase Storage

File storage with Supabase in mobile apps.

## Bucket Configuration

```sql
-- Create a bucket via SQL
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true);

-- Storage policies
CREATE POLICY "Avatar images are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

CREATE POLICY "Users can upload their own avatar"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'avatars' AND
  auth.uid()::text = (storage.foldername(name))[1]
);
```

## Upload Files

```typescript
import { launchImageLibrary } from 'react-native-image-picker'

async function uploadAvatar(userId: string) {
  const result = await launchImageLibrary({ mediaType: 'photo' })
  if (!result.assets?.[0]) return

  const file = result.assets[0]
  const filePath = `${userId}/${Date.now()}.jpg`

  const formData = new FormData()
  formData.append('file', {
    uri: file.uri,
    type: file.type,
    name: file.fileName,
  } as any)

  const { data, error } = await supabase.storage
    .from('avatars')
    .upload(filePath, formData, {
      contentType: file.type,
      upsert: true,
    })

  return data?.path
}
```

## Get Public URL

```typescript
// For public buckets
const { data } = supabase.storage
  .from('avatars')
  .getPublicUrl('user123/avatar.jpg')

console.log(data.publicUrl)

// With transformations
const { data } = supabase.storage
  .from('avatars')
  .getPublicUrl('user123/avatar.jpg', {
    transform: {
      width: 200,
      height: 200,
      resize: 'cover',
    },
  })
```

## Signed URLs (Private Buckets)

```typescript
// Generate signed URL (expires in 1 hour)
const { data, error } = await supabase.storage
  .from('private-files')
  .createSignedUrl('document.pdf', 3600)

// Download file
const { data, error } = await supabase.storage
  .from('private-files')
  .download('document.pdf')
```

## Delete Files

```typescript
const { error } = await supabase.storage
  .from('avatars')
  .remove(['user123/old-avatar.jpg'])

// Delete multiple
const { error } = await supabase.storage
  .from('avatars')
  .remove(['file1.jpg', 'file2.jpg'])
```

## Best Practices

- Use RLS policies for storage security
- Organize files in user-specific folders
- Use image transformations for thumbnails
- Set appropriate cache headers
