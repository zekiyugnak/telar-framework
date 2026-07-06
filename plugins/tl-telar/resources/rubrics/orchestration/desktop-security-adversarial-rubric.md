# Desktop App Security Adversarial Rubric

## Purpose

Used by the always-on Adversarial Desktop Security Reviewer in `skills/orchestration/adversarial-code-review.md`. Extends the generic adversarial rubric with Electron- and Tauri-specific security failure modes.

## Reviewer mode

**Adversarial.** Same discipline as the generic rubric: fresh `Task()` instance, sees only WU spec + DoD + file scope + diff. Binary PASS/FAIL.

## Evaluation criteria

### DS. Desktop security failures

A WU FAILS desktop security review if any of:

- DS1. An Electron `BrowserWindow` (or `webview`) is created with `nodeIntegration: true` or `contextIsolation: false` when it loads a remote URL, a URL that may contain user-supplied content, or any origin that is not a bundled local file explicitly under the app's own `app://` / `file://` origin. Either flag on a privileged window → FAIL.
- DS2. A `preload` script exposes raw Node.js globals (`require`, `process`, `Buffer`, `__dirname`) or the full `ipcRenderer` object to the renderer instead of a minimal, explicitly allow-listed API surface via `contextBridge.exposeInMainWorld`. A preload that re-exports every IPC channel or passes through arbitrary arguments without narrowing → FAIL.
- DS3. An `ipcMain.handle` / `ipcMain.on` handler (Electron) or a Tauri `#[tauri::command]` accepts renderer-supplied path segments, shell arguments, or arbitrary strings and uses them in `fs.*`, `child_process.*`, `shell.openPath`, or equivalent without validation and normalization (e.g., `path.resolve` + prefix check, allowlist match, or reject on `..`). Path traversal or arbitrary command execution reachable from the renderer → FAIL.
- DS4. `webPreferences.webSecurity` is set to `false`; a privileged window navigates to or loads content from a remote origin not on an explicit allowlist; or `will-navigate` / `new-window` / `setWindowOpenHandler` permits opening arbitrary URLs (including `javascript:` URIs or non-`https:` schemes) without an allowlist check. Any of these conditions → FAIL.
- DS5. The auto-update mechanism fetches or applies an update without verifying a cryptographic signature from a pinned key (e.g., `electron-updater` `publisherName` / code-signing chain absent, feed URL is plain HTTP, or update payload is applied after a hash check only without asymmetric signature verification). Unsigned or integrity-unverified auto-update path → FAIL.
- DS6. A Tauri `allowlist` (Tauri v1) or capability (Tauri v2) grants filesystem, shell, or HTTP scope that is broader than the minimum the WU requires — for example `fs` scope `"**"` when only one directory is needed, `shell` open enabled globally, or HTTP allowed to `*` instead of a named endpoint list. Over-broad capability grant not justified by the WU spec → FAIL.
- DS7. A secret (API key, OAuth client secret, service-role token, private key material) is embedded in the renderer bundle, stored in plain text in a location readable by the renderer process (`localStorage`, `sessionStorage`, a JS global, an unprotected config file in `app.getPath('userData')`), or present in a bundled asset reachable without OS-level access controls. Secrets must remain in the main process or OS credential store → FAIL.
- DS8. Input arriving through a custom protocol handler (`app.setAsDefaultProtocolClient`) or a deep-link URI is used in a privileged operation (IPC dispatch, file open, navigation, shell exec) without parsing, validating, and sanitizing each component against an explicit allowlist before use. Unvalidated deep-link data reaching a privileged sink → FAIL.

## Verdict format

JSON per the schema. Use rule IDs DS1-DS8. The reviewer's `reviewer` field is `"desktop-security"`.
