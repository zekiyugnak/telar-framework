---
name: "command-palette-cmdk"
description: "A command palette gives operators a keyboard-first way to jump to any screen or trigger a cross-cutting action without leaving the keyboard. This skill covers building one with the `cmdk` library: a global shortcut that "
source_type: "skill"
source_file: "skills/command-palette-cmdk.md"
---

# command-palette-cmdk

Migrated from `skills/command-palette-cmdk.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Command Palette (cmd-k) for an Admin Panel Shell

A command palette gives operators a keyboard-first way to jump to any screen or trigger a cross-cutting action without leaving the keyboard. This skill covers building one with the `cmdk` library: a global shortcut that doesn't hijack ordinary typing, grouped and fuzzy-searchable commands, correct arrow-key/scroll behavior, and wiring navigation commands into TanStack Router.

## Problem

The two most common ways a command palette implementation goes wrong: the global keyboard listener fires even while the user is typing into an unrelated text input (so pressing `k` while filling out a form pops the palette open), and the palette's command list becomes a second, drifting source of truth for navigation that falls out of sync with the actual sidebar.

```tsx
// BAD: no guard against active form fields — pressing "k" while typing in
// ANY input, textarea, or contenteditable element on the page opens the
// palette mid-sentence, destroying the operator's typing flow
useEffect(() => {
  function onKeyDown(e: KeyboardEvent) {
    if (e.key === 'k' && (e.metaKey || e.ctrlKey)) {
      e.preventDefault()
      setOpen((prev) => !prev)
    }
  }
  document.addEventListener('keydown', onKeyDown)
  return () => document.removeEventListener('keydown', onKeyDown)
}, [])
```

```tsx
// BAD: command palette entries hardcoded separately from the sidebar's
// nav config — add a new route to the sidebar, forget to also add it here,
// and the palette silently falls behind what's actually navigable
const commands = [
  { label: 'Users', path: '/users' },
  { label: 'Orders', path: '/orders' },
  // 'Settings' was added to the sidebar last sprint and never added here
]
```

## Solution

### Global shortcut with an input-field guard

```tsx
// src/components/CommandPalette.tsx
import { useEffect, useState } from 'react'
import { Command } from 'cmdk'
import { useNavigate } from '@tanstack/react-router'

export function CommandPalette() {
  const [open, setOpen] = useState(false)
  const navigate = useNavigate()

  useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      const isTypingTarget =
        e.target instanceof HTMLElement &&
        (e.target.tagName === 'INPUT' ||
          e.target.tagName === 'TEXTAREA' ||
          e.target.isContentEditable)

      // Cmd/Ctrl+K is exempt from the guard — that's the whole point of a
      // global shortcut, and it's an uncommon combination inside ordinary
      // text fields. A guard is still applied to bare single-key shortcuts
      // (e.g. "/") which DO collide with normal typing.
      if (e.key === 'k' && (e.metaKey || e.ctrlKey)) {
        e.preventDefault()
        setOpen((prev) => !prev)
        return
      }

      // Bare "/" as an alternate open shortcut must respect the guard —
      // otherwise typing a literal "/" into any text field anywhere on the
      // page (a URL, a search query, a file path) opens the palette instead.
      if (e.key === '/' && !isTypingTarget) {
        e.preventDefault()
        setOpen(true)
      }
    }
    document.addEventListener('keydown', onKeyDown)
    return () => document.removeEventListener('keydown', onKeyDown)
  }, [])

  return (
    <Command.Dialog
      open={open}
      onOpenChange={setOpen}
      label="Command Palette"
      shouldFilter={true}
    >
      <Command.Input placeholder="Search commands or navigate..." />
      <Command.List>
        <Command.Empty>No results found.</Command.Empty>
        <NavigationCommands onSelect={() => setOpen(false)} navigate={navigate} />
        <ActionCommands onSelect={() => setOpen(false)} />
      </Command.List>
    </Command.Dialog>
  )
}
```

### Grouping commands: navigation vs actions, sourced from one registry

```tsx
// src/lib/commandRegistry.ts
// A single source of truth for palette entries, built from the SAME route
// metadata the sidebar renders from — adding a route to the sidebar config
// automatically makes it available in the palette, no separate list to keep in sync.
import { routeTree } from '@/routeTree.gen'

export type CommandEntry =
  | { type: 'navigation'; label: string; path: string; keywords?: string[] }
  | { type: 'action'; label: string; run: () => void; keywords?: string[] }

export const navigationCommands: CommandEntry[] = [
  { type: 'navigation', label: 'Users', path: '/users', keywords: ['operators', 'accounts'] },
  { type: 'navigation', label: 'Orders', path: '/orders', keywords: ['sales'] },
  { type: 'navigation', label: 'Settings', path: '/settings' },
]
```

```tsx
// src/components/NavigationCommands.tsx
import { Command } from 'cmdk'
import { navigationCommands } from '@/lib/commandRegistry'

function NavigationCommands({ navigate, onSelect }: { navigate: (opts: { to: string }) => void; onSelect: () => void }) {
  return (
    <Command.Group heading="Navigate">
      {navigationCommands.map((cmd) => (
        <Command.Item
          key={cmd.path}
          // cmdk fuzzy-matches against `value` plus any keywords, so
          // "operators" also surfaces the "Users" navigation entry.
          value={cmd.label}
          keywords={cmd.keywords}
          onSelect={() => {
            navigate({ to: cmd.path })
            onSelect()
          }}
        >
          {cmd.label}
        </Command.Item>
      ))}
    </Command.Group>
  )
}
```

```tsx
// src/components/ActionCommands.tsx
// Cross-cutting ACTIONS (not navigation, not a specific row's inline button)
// belong here: "Invite a new operator," "Export current view," "Toggle theme."
// A row-level action like "Delete this order" belongs on that row's own menu,
// not the global palette — see Edge Cases below.
function ActionCommands({ onSelect }: { onSelect: () => void }) {
  return (
    <Command.Group heading="Actions">
      <Command.Item onSelect={() => { openInviteOperatorDialog(); onSelect() }}>
        Invite Operator
      </Command.Item>
      <Command.Item onSelect={() => { toggleTheme(); onSelect() }}>
        Toggle Theme
      </Command.Item>
    </Command.Group>
  )
}
```

### Arrow-key navigation with correct scrollIntoView

```tsx
// cmdk handles arrow-key up/down and Enter-to-select internally, but the
// active item must scroll into view when the list is taller than the
// visible dropdown — this is the piece easy to omit when custom-styling.
<Command.List className="max-h-80 overflow-y-auto">
  {/* cmdk applies `data-selected` to the active Command.Item; style it
      and ensure it participates in scroll via `scroll-margin` so
      keyboard-only navigation never leaves the highlighted row hidden
      above or below the visible scroll area. */}
  <style>{`
    [cmdk-item][data-selected='true'] {
      scroll-margin-block: 8px;
    }
  `}</style>
  {/* ...Command.Group / Command.Item content... */}
</Command.List>
```

cmdk scrolls the selected item into view automatically as the arrow keys move focus through `Command.Item` elements; the `scroll-margin-block` above just ensures the item isn't flush against the container edge when it lands there.

## Why This Works

- **Guarding on `e.target`'s tag name/`isContentEditable` distinguishes "the operator is actively typing somewhere" from "the operator is browsing the page"**: a modifier-based shortcut (Cmd/Ctrl+K) is safe to leave unguarded because it's rare inside normal text entry, but a bare single-key shortcut like `/` is common in real user input (URLs, search terms, file paths) and must respect focus context.
- **Sourcing navigation commands from the same config the sidebar renders from eliminates an entire category of drift bugs**: there is exactly one place that declares "this route exists and is user-visible," and both the sidebar and the palette read from it.
- **`cmdk`'s built-in fuzzy filter plus explicit `keywords` on each item widens what an operator can type to find something**: an operator searching "accounts" finds "Users" without the palette needing an exact label match, because `keywords` participates in the same fuzzy scoring as `value`.
- **Scoping the palette to global/cross-cutting actions keeps it predictable**: if it also tried to host every row-level action from every table, the list would grow unbounded and stop being fast to scan, which defeats the entire point of a quick-access tool.

## Edge Cases & Pitfalls

### Common Mistakes

- **Not exempting Cmd/Ctrl+K from the typing-target guard**: some implementations guard *every* shortcut uniformly, which means an operator can't open the palette while their cursor happens to be resting in a search box — the opposite of the intended fast-access behavior.
- **Forgetting to `preventDefault()` on the activation keydown**: without it, `/` also gets typed into whatever's focused (or triggers the browser's native "quick find" in some browsers) at the same time the palette opens.
- **Putting destructive row-level actions in the global palette**: a "Delete User" action reachable from anywhere in the app, decoupled from which user is actually selected/visible, is an easy way to delete the wrong row if the palette's fuzzy match surfaces a similarly-named command. Keep destructive per-row actions on that row's own contextual menu.
- **Re-registering the global keydown listener on every render** by omitting the empty dependency array (or including something that changes every render) on the `useEffect` — this attaches and detaches the listener constantly, occasionally causing missed keypresses.
- **Not resetting the search input when the palette closes**: reopening the palette with the previous query still filled in is often surprising; clear `Command.Input`'s value in the `onOpenChange` handler when transitioning to closed.
- **Ignoring RTL for the palette's own layout**: the palette is UI chrome like anything else in the panel — its icon alignment, input padding, and group heading alignment should use the same logical-property conventions as the rest of the app (see `skills/i18n-rtl-formatjs-lingui.md`), not hardcoded left/right values.

## Verification

- [ ] Focus a text input in a form, type the letter "k" alone — confirm the palette does NOT open.
- [ ] Press Cmd/Ctrl+K while focused inside a text input — confirm the palette DOES open (modifier shortcuts are exempt from the guard).
- [ ] Press `/` while no input is focused — confirm the palette opens; press `/` while a text input IS focused — confirm it types a literal `/` instead.
- [ ] Add a new route to the sidebar config — confirm it appears in the palette's navigation group without any palette-specific code change.
- [ ] Use only the keyboard (arrow keys, Enter, Escape) to open the palette, navigate to an item below the visible fold, and select it — confirm the item scrolled into view and Enter navigated correctly.
- [ ] Select a navigation command — confirm the palette closes and the TanStack Router navigation actually occurs.

## References

- [cmdk - GitHub](https://github.com/pacocoursey/cmdk)
- [shadcn/ui - Command](https://ui.shadcn.com/docs/components/command)
- [TanStack Router - Navigation](https://tanstack.com/router/latest/docs/framework/react/guide/navigation)
