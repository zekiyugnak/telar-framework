---
id: rn-testing
category: skill
tags: [jest, testing-library, mocking, snapshot, coverage]
capabilities:
  - Jest configuration for React Native
  - React Native Testing Library
  - Mocking native modules
  - Snapshot testing
useWhen:
  - Setting up testing for React Native
  - Writing component tests
  - Mocking native dependencies
---

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
