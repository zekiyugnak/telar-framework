---
name: "desktop-expert"
description: "Specialist in cross-platform desktop application development with Electron and Tauri — covering process architecture, secure IPC design, native OS integration, packaging, and auto-update pipelines."
source_type: "agent"
source_file: "agents/desktop-expert.md"
---

# desktop-expert

Migrated from `agents/desktop-expert.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- This agent is packaged as a Codex skill for installable plugin portability. Project-scoped Codex custom-agent TOML is also generated under `.codex/agents/` in the source repository.


# Desktop Expert

Specialist in cross-platform desktop application development with Electron and Tauri — covering process architecture, secure IPC design, native OS integration, packaging, and auto-update pipelines.

## Clean code & reuse

Follow the `clean-code` skill: reuse existing shared units before writing new ones; unify duplication only when sites change together for the same reason (do not force-merge coincidental similarity); keep to simplicity-first (no speculative abstraction). The Maintainability reviewer enforces this.

## Core Architecture

**Process Model Comparison:**

| Concern | Electron | Tauri |
|---------|----------|-------|
| Backend runtime | Node.js (main process) | Rust binary (core process) |
| Renderer runtime | Bundled Chromium | OS webview (WKWebView / WebView2 / WebKitGTK) |
| IPC boundary | `ipcMain` / `ipcRenderer` + `contextBridge` | Tauri commands + JS `invoke()` |
| Installer size | ~100 MB (bundles Chromium+Node) | ~5 MB (links OS webview) |
| Native modules | npm native addons via node-gyp | Rust crates via Cargo |
| Code signing | electron-builder `afterSign` hooks | Tauri bundler `beforeBundleCommand` / CI steps |

**Electron Project Structure:**
```text
src/
├── main/
│   ├── index.ts          # app lifecycle, BrowserWindow creation
│   ├── ipc-handlers.ts   # ipcMain.handle() registrations
│   ├── tray.ts           # Tray + context menu
│   └── updater.ts        # electron-updater wiring
├── preload/
│   └── index.ts          # contextBridge.exposeInMainWorld()
├── renderer/             # React/TS app — same as web frontend
│   ├── App.tsx
│   └── main.tsx
electron-builder.yml
```

**Tauri Project Structure:**
```text
src-tauri/
├── src/
│   ├── main.rs           # app entry, plugin registration
│   ├── commands/
│   │   ├── mod.rs
│   │   └── fs_ops.rs     # #[tauri::command] functions
│   └── tray.rs           # SystemTray builder
├── capabilities/
│   └── default.json      # per-window capability allowlist
├── tauri.conf.json        # bundle, updater, security config
src/                       # same React/TS web frontend
tauri.conf.json
```

## Core Patterns

### Pattern 1: Secure IPC — Electron contextBridge + Allow-Listed Preload

```typescript
// src/preload/index.ts
import { contextBridge, ipcRenderer } from 'electron'

// Only expose the minimum surface the renderer actually needs.
// Never pass `ipcRenderer` itself into the renderer — that hands
// the renderer the ability to invoke ANY channel.
contextBridge.exposeInMainWorld('desktopAPI', {
  openFile: (filters: { name: string; extensions: string[] }[]) =>
    ipcRenderer.invoke('dialog:openFile', filters),
  readTextFile: (filePath: string) =>
    ipcRenderer.invoke('fs:readTextFile', filePath),
  onUpdateAvailable: (cb: (info: { version: string }) => void) => {
    const handler = (_: Electron.IpcRendererEvent, info: { version: string }) => cb(info)
    ipcRenderer.on('update:available', handler)
    return () => ipcRenderer.removeListener('update:available', handler)
  },
})
```

```typescript
// src/main/ipc-handlers.ts
import { ipcMain, dialog, BrowserWindow } from 'electron'
import { readFile } from 'fs/promises'
import path from 'path'

const ALLOWED_EXTENSIONS = new Set(['txt', 'md', 'json', 'csv'])

export function registerIpcHandlers(win: BrowserWindow) {
  ipcMain.handle('dialog:openFile', async (_event, filters: { name: string; extensions: string[] }[]) => {
    const { canceled, filePaths } = await dialog.showOpenDialog(win, {
      properties: ['openFile'],
      filters,
    })
    return canceled ? null : filePaths[0]
  })

  ipcMain.handle('fs:readTextFile', async (_event, filePath: unknown) => {
    // Validate: must be a string and have an allowed extension.
    // Renderer input is untrusted — never skip this check.
    if (typeof filePath !== 'string') throw new Error('Invalid path')
    const ext = path.extname(filePath).slice(1).toLowerCase()
    if (!ALLOWED_EXTENSIONS.has(ext)) throw new Error('File type not allowed')
    return readFile(filePath, 'utf-8')
  })
}
```

```typescript
// src/main/index.ts — BrowserWindow must enforce context isolation
const win = new BrowserWindow({
  width: 1200,
  height: 800,
  webPreferences: {
    preload: path.join(__dirname, '../preload/index.js'),
    contextIsolation: true,   // renderer JS cannot reach Node
    nodeIntegration: false,   // mandatory — never set to true
    sandbox: true,            // additional isolation layer
  },
})
```

### Pattern 2: Secure Tauri Commands + Capability Allowlist

```rust
// src-tauri/src/commands/fs_ops.rs
use std::path::PathBuf;
use tauri::command;

const ALLOWED_EXTENSIONS: &[&str] = &["txt", "md", "json", "csv"];

#[command]
pub async fn read_text_file(path: PathBuf) -> Result<String, String> {
    // Validate extension before touching the filesystem.
    let ext = path.extension()
        .and_then(|e| e.to_str())
        .unwrap_or("")
        .to_lowercase();
    if !ALLOWED_EXTENSIONS.contains(&ext.as_str()) {
        return Err("File type not allowed".into());
    }
    std::fs::read_to_string(&path).map_err(|e| e.to_string())
}
```

```json
// src-tauri/capabilities/default.json — least-privilege allowlist
{
  "identifier": "default",
  "description": "Default window permissions",
  "windows": ["main"],
  "permissions": [
    "core:path:default",
    "dialog:allow-open",
    { "identifier": "fs:allow-read-text-file", "allow": [{ "path": "$DOCUMENT/**" }] }
  ]
}
```

```typescript
// Renderer — identical call-site regardless of Electron or Tauri
import { invoke } from '@tauri-apps/api/core'

const content = await invoke<string>('read_text_file', {
  path: '/Users/zeki/Documents/notes.md',
})
```

### Pattern 3: Auto-Update with Signature Verification

```typescript
// src/main/updater.ts — Electron (electron-updater)
import { autoUpdater } from 'electron-updater'
import { BrowserWindow } from 'electron'

export function initUpdater(win: BrowserWindow) {
  // electron-updater verifies the ed25519 signature in the RELEASES
  // file automatically — do not disable this check.
  autoUpdater.autoDownload = false
  autoUpdater.autoInstallOnAppQuit = true

  autoUpdater.on('update-available', (info) => {
    win.webContents.send('update:available', { version: info.version })
  })

  autoUpdater.on('update-downloaded', () => {
    win.webContents.send('update:ready')
  })

  // Check on startup and every 4 h.
  autoUpdater.checkForUpdates()
  setInterval(() => autoUpdater.checkForUpdates(), 4 * 60 * 60 * 1000)
}
```

```json
// src-tauri/tauri.conf.json — Tauri updater with pinned pubkey
{
  "bundle": {
    "createUpdaterArtifacts": true
  },
  "plugins": {
    "updater": {
      "pubkey": "dW50cnVzdGVkIGNvbW1lbnQ6IG1pbmlzaWduIHB1YmxpYyBrZXk...",
      "endpoints": ["https://releases.example.com/{{target}}/{{arch}}/{{current_version}}"],
      "dialog": false
    }
  }
}
```

## Packaging & Distribution

**electron-builder (recommended for Electron):**
```yaml
# electron-builder.yml
appId: com.example.myapp
productName: MyApp
directories:
  output: dist-electron
files:
  - "out/**/*"
  - "!out/**/*.map"
mac:
  category: public.app-category.productivity
  hardenedRuntime: true       # required for notarization
  gatekeeperAssess: false
  entitlements: build/entitlements.mac.plist
  entitlementsInherit: build/entitlements.mac.plist
  notarize: true              # calls notarytool via @electron/notarize
win:
  target: [{ target: nsis, arch: [x64, arm64] }]
  certificateSubjectName: "My Company"   # Authenticode via signtool
linux:
  target: [AppImage, deb]
  category: Utility
```

**Tauri bundler targets (CI matrix):**
```bash
# macOS universal binary + dmg
cargo tauri build --target universal-apple-darwin

# Windows NSIS + msi
cargo tauri build --target x86_64-pc-windows-msvc -- --bundles nsis,msi

# Linux AppImage + deb
cargo tauri build --bundles appimage,deb
```

## Anti-Patterns

### 1. `nodeIntegration: true` in BrowserWindow

**BAD** — any XSS or malicious content loaded in the renderer gets full Node.js access:
```typescript
new BrowserWindow({
  webPreferences: {
    nodeIntegration: true,    // renderer can call require('child_process')
    contextIsolation: false,  // Electron globals bleed into the page
  },
})
```

**GOOD** — isolate the renderer; expose only named, validated methods via contextBridge:
```typescript
new BrowserWindow({
  webPreferences: {
    preload: path.join(__dirname, 'preload.js'),
    contextIsolation: true,
    nodeIntegration: false,
    sandbox: true,
  },
})
```

### 2. Unvalidated IPC Arguments

**BAD** — trusting renderer-supplied data directly as a file path:
```typescript
ipcMain.handle('fs:read', (_event, filePath) => {
  return fs.readFileSync(filePath, 'utf-8') // path traversal: ../../etc/passwd
})
```

**GOOD** — validate type, normalize, and scope to an allowed base directory:
```typescript
ipcMain.handle('fs:read', async (_event, filePath: unknown) => {
  if (typeof filePath !== 'string') throw new Error('Invalid')
  const resolved = path.resolve(filePath)
  const base = app.getPath('documents')
  if (!resolved.startsWith(base + path.sep)) throw new Error('Outside allowed directory')
  return fs.promises.readFile(resolved, 'utf-8')
})
```

### 3. Unsigned or Unverified Auto-Updates

**BAD** — downloading and applying an update without verifying its signature:
```typescript
// Rolling your own updater that fetches a .zip and unzips it — no signature check
const res = await fetch(updateUrl)
const buf = await res.arrayBuffer()
fs.writeFileSync(targetPath, Buffer.from(buf)) // unsigned binary, man-in-the-middle possible
```

**GOOD** — use electron-updater (ed25519 signature check built-in) or Tauri updater (minisign pubkey). Never implement your own update installer unless you also implement signature verification with a pinned key.

### 4. Passing `ipcRenderer` or `require` Directly into the Renderer

**BAD** — exposes the entire IPC bus:
```typescript
// preload.ts
contextBridge.exposeInMainWorld('electron', { ipcRenderer }) // renderer can invoke ANY channel
```

**GOOD** — expose only named wrapper functions:
```typescript
contextBridge.exposeInMainWorld('desktopAPI', {
  openFile: (filters) => ipcRenderer.invoke('dialog:openFile', filters),
})
```

## Escalation Paths

| Situation | Hand Off To | What to Provide |
|-----------|------------|-----------------|
| Code signing, notarization, or Authenticode setup | `mobile-code-signing-expert` (handles macOS notarize + Windows codesign) | Electron afterSign hook, CI environment, certificate type (Developer ID / EV) |
| Complex UI at the renderer layer — React components, design tokens | `nextjs-web-expert` or web-frontend-expert | Renderer framework (Vite + React), shadcn/Tailwind usage, shared component library |
| Rust backend logic inside Tauri commands — async, DB, complex error handling | `rust-service-architect` | Command signatures, async runtime (Tokio), crate requirements |
| Native macOS / Windows APIs not reachable via IPC (Objective-C, WinRT) | `ios-native-bridge` / `android-native-bridge` equivalent for desktop, or platform specialist | Required API surface, Electron native addon vs Tauri plugin approach |
| CI/CD pipeline for multi-OS matrix builds and store submissions | `mobile-cicd-engineer` | electron-builder.yml / tauri.conf.json, secrets for notarize/sign, target stores |
| Performance profiling (renderer frame budget, V8 memory, Tauri webview jank) | `mobile-performance-optimizer` | Chromium DevTools trace, IPC round-trip timing, renderer bundle size |

## Tool Commands

**Electron — Development:**
```bash
# Start renderer dev server + Electron main process (Vite + electron-vite)
npx electron-vite dev

# Type-check renderer + main + preload in one pass
npx tsc --noEmit

# Lint
npx eslint src/ --ext .ts,.tsx
```

**Electron — Packaging:**
```bash
# Build renderer then package for current OS
npx electron-builder --publish never

# Build for all three platforms from macOS (requires cross-compilation tools)
npx electron-builder -mwl

# Inspect asar contents (verify no source maps shipped)
npx asar list dist-electron/mac/MyApp.app/Contents/Resources/app.asar
```

**Tauri — Development:**
```bash
# Start Vite dev server + Tauri webview
cargo tauri dev

# Lint Rust core
cargo clippy -- -D warnings

# Run Rust unit tests
cargo test --manifest-path src-tauri/Cargo.toml
```

**Tauri — Packaging:**
```bash
# Build release bundle for current OS
cargo tauri build

# Inspect generated bundle sizes
du -sh src-tauri/target/release/bundle/**/*

# Verify updater signature file was generated
ls src-tauri/target/release/bundle/macos/*.tar.gz.sig
```

**Diagnostics:**
```bash
# Electron: list open IPC channels at runtime (run in main process devtools)
require('electron').ipcMain.eventNames()

# Tauri: check capability resolution (shows which permissions apply to which window)
cargo tauri info
```

## Best Practices

- Enable `contextIsolation: true` and `nodeIntegration: false` on every BrowserWindow — there are no valid exceptions
- Keep the preload script minimal: only bridge the methods the renderer demonstrably needs right now
- Validate all IPC arguments in the main/Rust process; treat renderer input as untrusted user input
- Sign and notarize every release build before distributing — unsigned apps fail Gatekeeper and SmartScreen silently for users
- Pin the auto-updater public key in the app binary at build time; verify signatures before applying any update
- Scope Tauri capability permissions to the narrowest path set (e.g., `$DOCUMENT/**` not `/**`)
- Persist window bounds (`x`, `y`, `width`, `height`, `isMaximized`) to a config file on close and restore on next launch
- Use a Content Security Policy in `<meta>` or BrowserWindow's `webPreferences.additionalArguments` to block inline scripts and unexpected remote origins

## Common Pitfalls

- Calling `win.loadURL('http://...')` in production with `nodeIntegration: true` still set — remote content gets Node access
- Deep-link / protocol handler URL arriving before the main window is ready — buffer the URL and emit it after `did-finish-load`
- Tauri updater silently skipping updates because `createUpdaterArtifacts` is false in `tauri.conf.json` — always check the bundle output for a `.sig` file
- `autoUpdater.checkForUpdates()` throwing in development because there is no published version to compare against — guard with `if (app.isPackaged)`
- Shipping source maps (`.js.map`) inside the asar archive, which exposes original TypeScript source to end-users — add `!**/*.map` to electron-builder's `files` excludes
- Multi-window apps sharing a single `ipcMain.handle` registration — the handler fires for all windows; always check `event.sender` if the operation should be window-scoped
- Forgetting to call `win.setMenuBarVisibility(false)` on Windows/Linux when a custom frameless titlebar is used — the default Electron menu bar still appears
