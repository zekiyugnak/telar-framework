---
id: supabase-tus-resumable-upload
category: skill
impact: HIGH
impactDescription: "Turns large-file uploads from a single point of failure on flaky networks into a resumable operation, avoiding full-restart abandonment"
tags: [supabase, storage, tus, resumable-upload, tus-js-client, uppy, admin-panel, web]
capabilities:
  - Resumable large-file uploads to Supabase Storage via the TUS protocol
  - Configuring tus-js-client or Uppy's Tus plugin with the required chunk size
  - Authenticating TUS uploads with the operator's session access token
  - Resuming an interrupted upload after a network drop or tab reload
  - Tracking upload progress and attaching row metadata after the upload completes
useWhen:
  - Uploading files large enough that a single-request upload risks timing out or exhausting memory
  - An operator's upload fails partway through on an unreliable connection and needs to resume, not restart
  - Building a progress-tracked upload UI (dropzone, progress bar, retry) for the admin panel
  - Deciding whether to reach for TUS vs the plain supabase.storage.upload() call
---

# Resumable Large-File Uploads to Supabase Storage via TUS

Supabase Storage exposes a TUS-compatible endpoint alongside its plain REST upload API. TUS (the open resumable-upload protocol) splits a file into chunks, tracks how much of the file the server has already received, and lets an interrupted upload resume from that offset instead of restarting from byte zero. This is the right tool specifically for **large files uploaded from an operator's browser** — bulk export archives, video evidence, high-resolution media — where `skills/supabase-storage.md`'s plain `upload()` call (a single non-resumable HTTP request, covered for the mobile stack) becomes a liability. This skill focuses on what's different about doing it from a web SPA: chunk sizing, session-token auth headers, and resume-after-reload behavior.

## Problem

A plain `supabase.storage.from(bucket).upload()` call sends the entire file body as one HTTP request. For a multi-hundred-MB file on an office wifi connection with any packet loss, that single request either times out, gets dropped by an intermediate proxy, or — if the client buffered the whole file into memory first — pressures the browser tab's memory on lower-spec machines. When it fails at 95%, the only recovery is starting over from 0%.

```tsx
// BAD: single-request upload of a large file, no resumability
async function uploadEvidenceVideo(file: File, caseId: string) {
  const path = `cases/${caseId}/${file.name}`
  // If this drops at 400MB of a 420MB file, the next attempt re-sends
  // all 420MB again. On a slow or unstable connection this can simply
  // never complete.
  const { error } = await supabase.storage.from('case-evidence').upload(path, file)
  if (error) throw error
}
```

## Solution

### tus-js-client against Supabase Storage's TUS endpoint

```tsx
// src/features/uploads/useTusUpload.ts
import { useRef, useState } from 'react'
import * as tus from 'tus-js-client'
import { supabase } from '@/lib/supabase'

type UploadState = {
  progress: number // 0-100
  status: 'idle' | 'uploading' | 'paused' | 'success' | 'error'
  error?: string
}

export function useTusUpload(bucket: string) {
  const [state, setState] = useState<UploadState>({ progress: 0, status: 'idle' })
  const uploadRef = useRef<tus.Upload | null>(null)

  async function start(file: File, objectPath: string) {
    // The TUS endpoint needs the operator's own session access token, not
    // the bare anon key, so Storage's RLS-backed authorization (same model
    // as skills/supabase-rls-client-patterns.md) applies to the upload too.
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) throw new Error('No active session')

    // `storageUrl` is a protected member on SupabaseClient — not accessible
    // from application code. Build the Storage TUS endpoint from the same
    // project URL the client itself was constructed with.
    const storageUrl = `${import.meta.env.VITE_SUPABASE_URL}/storage/v1`

    const upload = new tus.Upload(file, {
      endpoint: `${storageUrl}/upload/resumable`,
      retryDelays: [0, 3000, 5000, 10000, 20000],
      headers: {
        authorization: `Bearer ${session.access_token}`,
        'x-upsert': 'false',
      },
      // Supabase Storage's TUS endpoint requires exactly 6MB chunks —
      // any other chunk size is rejected by the server.
      chunkSize: 6 * 1024 * 1024,
      metadata: {
        bucketName: bucket,
        objectName: objectPath,
        contentType: file.type,
        cacheControl: '3600',
      },
      // TUS resumability is keyed by this identifier — persisting it lets
      // a page reload find and continue the same upload (see Resuming below).
      storeFingerprintForResuming: true,
      onError: (error) => setState({ progress: 0, status: 'error', error: error.message }),
      onProgress: (bytesSent, bytesTotal) => {
        setState((prev) => ({ ...prev, status: 'uploading', progress: Math.round((bytesSent / bytesTotal) * 100) }))
      },
      onSuccess: () => setState((prev) => ({ ...prev, status: 'success', progress: 100 })),
    })

    uploadRef.current = upload

    // Check for a previous, interrupted upload of this exact file before
    // starting a fresh one — see "Resuming" below.
    const previousUploads = await upload.findPreviousUploads()
    if (previousUploads.length > 0) {
      upload.resumeFromPreviousUpload(previousUploads[0])
    }

    upload.start()
  }

  function pause() {
    uploadRef.current?.abort()
    setState((prev) => ({ ...prev, status: 'paused' }))
  }

  function resume() {
    uploadRef.current?.start()
  }

  return { state, start, pause, resume }
}
```

### Uppy's Tus plugin (when a full dropzone/UI kit is preferred over hand-rolling one)

```tsx
// src/features/uploads/UppyUploadDropzone.tsx
import { useEffect, useRef } from 'react'
import Uppy from '@uppy/core'
import Tus from '@uppy/tus'
import { Dashboard } from '@uppy/react'
import { supabase } from '@/lib/supabase'
import '@uppy/core/dist/style.css'
import '@uppy/dashboard/dist/style.css'

export function UppyUploadDropzone({ bucket, folderPath }: { bucket: string; folderPath: string }) {
  const uppyRef = useRef<Uppy>()

  if (!uppyRef.current) {
    uppyRef.current = new Uppy({
      restrictions: { maxFileSize: 2 * 1024 * 1024 * 1024 }, // 2GB, tune per use case
    }).use(Tus, {
      // storageUrl is protected on SupabaseClient — build the endpoint from
      // the project URL instead, same as the tus-js-client example above.
      endpoint: `${import.meta.env.VITE_SUPABASE_URL}/storage/v1/upload/resumable`,
      chunkSize: 6 * 1024 * 1024, // required by Supabase Storage's TUS endpoint
      retryDelays: [0, 3000, 5000, 10000, 20000],
      // Uppy calls this before EACH upload/resume attempt, so a token that
      // expired mid-upload is refreshed rather than failing silently.
      onBeforeRequest: async (req) => {
        const { data: { session } } = await supabase.auth.getSession()
        req.setHeader('authorization', `Bearer ${session?.access_token}`)
      },
    })
  }

  useEffect(() => {
    const uppy = uppyRef.current!
    uppy.on('file-added', (file) => {
      uppy.setFileMeta(file.id, {
        bucketName: bucket,
        objectName: `${folderPath}/${file.name}`,
        contentType: file.type,
      })
    })
    return () => uppy.destroy()
  }, [bucket, folderPath])

  return <Dashboard uppy={uppyRef.current!} />
}
```

### Resuming after a network interruption or tab reload

```ts
// tus-js-client persists upload progress (by default in localStorage/
// IndexedDB, keyed by a fingerprint derived from file name + size + type)
// so a resumable upload can be found and continued even after a full page
// reload, not just a transient disconnect within the same session.
const upload = new tus.Upload(file, {
  endpoint: `${import.meta.env.VITE_SUPABASE_URL}/storage/v1/upload/resumable`,
  chunkSize: 6 * 1024 * 1024,
  storeFingerprintForResuming: true, // required for cross-reload resume
  headers: { authorization: `Bearer ${accessToken}` },
})

const previousUploads = await upload.findPreviousUploads()
if (previousUploads.length > 0) {
  // Present the operator a choice, or auto-resume the most recent match —
  // for an admin panel, auto-resuming the same file is usually correct UX.
  upload.resumeFromPreviousUpload(previousUploads[0])
}
upload.start()
```

### Upload-then-attach-metadata pattern

```tsx
// src/features/uploads/useCompleteEvidenceUpload.ts
// Do the TUS upload first, then write the application-level row that
// references the uploaded object — this keeps the Storage bucket as the
// source of truth for "did the bytes actually arrive," and the database
// row as the source of truth for "what does this file mean to the app."
export function useCompleteEvidenceUpload(caseId: string) {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async ({ objectPath, fileName, fileSizeBytes }: UploadResult) => {
      // RLS on case_evidence enforces who can attach evidence to this case;
      // the upload itself was already scoped by the storage bucket's own
      // RLS policies keyed off the same session token.
      const { error } = await supabase.from('case_evidence').insert({
        case_id: caseId,
        storage_path: objectPath,
        file_name: fileName,
        file_size_bytes: fileSizeBytes,
        uploaded_by: (await supabase.auth.getUser()).data.user?.id,
      })
      if (error) throw error
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['cases', caseId, 'evidence'] })
    },
  })
}
```

## Why This Works

- **TUS tracks a server-confirmed byte offset per upload, addressed by a resumable URL**: after a chunk is acknowledged, the client only needs to send bytes from that offset forward on resume — it never re-sends already-confirmed data, which is what makes recovering from a drop at 95% cost seconds instead of restarting the whole transfer.
- **The mandatory 6MB chunk size is a Supabase Storage server-side constraint, not a client tuning knob**: Supabase's TUS implementation is configured to accept exactly this chunk size; a client sending a different `chunkSize` will have uploads rejected, so this value is fixed rather than something to benchmark and adjust per file type.
- **Authenticating with the operator's session access token, not the bare anon key, routes the upload through the same RLS-backed authorization as everything else in this stack**: Storage bucket policies (see `skills/supabase-storage.md` for bucket policy syntax) evaluate `auth.uid()` from the JWT the same way table RLS does, so "who can upload into this bucket/path" is governed by the same policy model, not a separate one.
- **Separating the upload step from the metadata-insert step avoids a half-finished-looking record**: if the TUS upload fails, no `case_evidence` row was ever created referencing a file that doesn't (fully) exist; if the upload succeeds but the metadata insert fails, that's a recoverable, retryable state (the bytes are safely in Storage) rather than data loss.

## Edge Cases & Pitfalls

### Common Mistakes

- **Sending a chunk size other than 6MB**: any other value is silently rejected by Supabase's TUS endpoint at the protocol level — always hardcode `chunkSize: 6 * 1024 * 1024` rather than trying to tune it for perceived performance.
- **Authenticating with the anon key alone instead of the session access token**: the anon key identifies the *application*, not the *operator* — Storage RLS policies that check `auth.uid()` need the user's actual JWT in the `authorization` header, the same token `supabase.auth.getSession()` returns.
- **Letting the session token go stale mid-upload on a very large, slow file**: a multi-hour upload can outlive the access token's expiry. Refresh the token and update the TUS client's headers before resuming (Uppy's `onBeforeRequest` hook above handles this automatically per request; with raw `tus-js-client`, re-fetch the session and construct a fresh `Upload` with `resumeFromPreviousUpload` if a request starts failing with 401s).
- **Not calling `findPreviousUploads()` before starting a fresh upload**: without this check, reloading the page mid-upload starts an entirely new upload from scratch instead of resuming the one already in progress, even though the resumable state was available.
- **Forgetting `x-upsert` semantics**: by default TUS uploads to Supabase Storage do not overwrite an existing object at the same path; if the object already exists and no upsert header is set appropriately for your use case, the upload fails at the metadata step rather than silently overwriting operator data.
- **Assuming this skill duplicates `skills/supabase-storage.md`**: it doesn't — that skill covers bucket policy setup and the plain `upload()`/`getPublicUrl()`/`createSignedUrl()` API for typical mobile-sized files. Reach for TUS specifically when files are large enough that resumability and bounded-memory chunked transfer matter; for small files (avatars, thumbnails), the plain upload API is simpler and sufficient.

## Verification

```bash
# Confirm the TUS endpoint is reachable and reports the expected max chunk size
curl -I "$SUPABASE_URL/storage/v1/upload/resumable" \
  -H "authorization: Bearer $ACCESS_TOKEN"
```

- [ ] Start a large-file upload, then kill the network connection mid-transfer — confirm `onError`/retry logic engages rather than the whole upload failing outright.
- [ ] Reconnect the network — confirm the upload resumes from the last confirmed offset (visible as progress not resetting to 0%).
- [ ] Reload the browser tab mid-upload, then re-initiate the same file's upload — confirm `findPreviousUploads()` finds the incomplete upload and resumes rather than restarting.
- [ ] Attempt an upload with an expired session token — confirm it fails with an auth error rather than uploading anonymously or silently succeeding.
- [ ] After a successful upload, confirm the object exists in the target bucket AND the corresponding metadata row was inserted — verify both halves of the upload-then-attach pattern completed.

## References

- [Supabase Storage - Resumable Uploads (TUS)](https://supabase.com/docs/guides/storage/uploads/resumable-uploads)
- [tus.io - Protocol Overview](https://tus.io/protocols/resumable-upload)
- [tus-js-client - GitHub](https://github.com/tus/tus-js-client)
- [Uppy - Tus Plugin](https://uppy.io/docs/tus/)
- [Supabase Storage - Access Control](https://supabase.com/docs/guides/storage/security/access-control)
