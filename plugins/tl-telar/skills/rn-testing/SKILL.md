---
name: "rn-testing"
description: "Testing patterns with Jest and React Native Testing Library."
source_type: "skill"
source_file: "skills/rn-testing.md"
---

# rn-testing

Migrated from `skills/rn-testing.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# React Native Testing

Testing patterns with Jest and React Native Testing Library.

## Jest Setup

```javascript
// jest.config.js
module.exports = {
  preset: 'react-native',
  setupFilesAfterEnv: ['@testing-library/jest-native/extend-expect'],
  transformIgnorePatterns: [
    'node_modules/(?!(react-native|@react-native|@react-navigation)/)',
  ],
}
```

## Component Testing

```typescript
import { render, screen, fireEvent } from '@testing-library/react-native'

test('button calls onPress', () => {
  const onPress = jest.fn()
  render(<Button title="Submit" onPress={onPress} />)

  fireEvent.press(screen.getByText('Submit'))

  expect(onPress).toHaveBeenCalledTimes(1)
})

test('form shows validation error', async () => {
  render(<LoginForm />)

  fireEvent.press(screen.getByText('Login'))

  await waitFor(() => {
    expect(screen.getByText('Email is required')).toBeOnTheScreen()
  })
})
```

## Mocking Native Modules

```javascript
// __mocks__/@react-native-async-storage/async-storage.js
export default {
  setItem: jest.fn(() => Promise.resolve()),
  getItem: jest.fn(() => Promise.resolve(null)),
  removeItem: jest.fn(() => Promise.resolve()),
}
```

## Hook Testing

```typescript
import { renderHook, waitFor } from '@testing-library/react-native'

test('useUser fetches user data', async () => {
  const { result } = renderHook(() => useUser('123'), { wrapper })

  await waitFor(() => {
    expect(result.current.data).toEqual({ id: '123', name: 'John' })
  })
})
```

## Best Practices

- Test behavior, not implementation
- Use testIDs for reliable selectors
- Mock at module boundaries
- Keep snapshot tests focused

## Flake Resistance (integration & E2E)

These standards apply to integration and E2E tests (Detox, Maestro, Appium), where flakiness is most costly:

- **No fixed sleeps** — never `setTimeout`/`waitForTimeout`/`sleep`. Wait for a specific element or state: `await waitFor(element(by.id('x'))).toBeVisible().withTimeout(5000)`.
- **No "network idle" waits** — wait for the concrete UI the network produces, not a global idle signal.
- **User-visible locators first** — prefer role/label/text; fall back to `testID` only when necessary. Avoid style/structure selectors.
- **Dynamic per-run data** — generate unique data each run so tests parallelize and never collide: `` `test-${Date.now()}` ``.
- **Isolation** — no test depends on state left by another; credentials come from env vars, never hardcoded.
- **Exit bar** — a new or changed E2E test must pass **3+ consecutive headless runs** before it counts as done. Passing once is not done. See `verification-before-completion`.
