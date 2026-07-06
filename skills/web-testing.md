---
id: web-testing
category: skill
impact: HIGH
impactDescription: "Eliminates brittle implementation-detail tests and flaky E2E suites; aligns the test pyramid so fast unit feedback survives rapid UI iteration without sacrificing confidence in critical user journeys"
tags: [testing, vitest, testing-library, playwright, web, e2e]
capabilities:
  - Writing component tests that query by role/label — behavior over implementation
  - Mocking network calls with MSW so tests survive API refactors without touching component code
  - Integration tests wiring real stores and routers without a browser
  - E2E tests with Playwright covering critical paths using built-in locator-based waiting
  - Catching accessibility regressions in E2E with @axe-core/playwright
useWhen:
  - Deciding which layer to test a new feature at (unit vs integration vs E2E)
  - Tests break every time a className or internal state key is renamed
  - Playwright tests flake because of arbitrary sleeps instead of locator-based waits
  - fetch/axios is mocked at the import level, making network-layer refactors break every test
  - A new flow needs an accessibility check beyond what manual review provides
---

# Build a React/TS Web Test Suite That's Fast at the Base and Honest at the Top

The most common testing mistake in a React/TypeScript web app is either testing implementation details — internal state, component method calls, class names — that shatter on every refactor, or having a thin unit layer and a massive Playwright suite that is slow and flaky. This skill covers the four layers that work well together: Vitest + Testing Library for fast component behavior, MSW for network boundaries, integration tests wiring real stores and routers, and Playwright for the critical journeys that genuinely need a browser — plus axe-core for accessibility regressions.

## Problem

```tsx
// BAD: tests an internal onClick handler and a CSS class — both invisible to the user
it('calls handleSubmit on click', () => {
  const { getByTestId } = render(<LoginForm />)
  fireEvent.click(getByTestId('submit-btn'))             // testId = brittle coupling
  expect(wrapper.instance().handleSubmit).toHaveBeenCalled() // implementation detail
})

// BAD: Playwright test with arbitrary sleep — passes on fast CI, fails on slow
await page.click('#submit')
await page.waitForTimeout(3000)                          // masking a timing problem
expect(await page.textContent('.result')).toBe('Done')  // class selector also brittle
```

## Solution

### Layer 1: component tests with Vitest + Testing Library

```tsx
// GOOD: queries by accessible role — same selector a screen reader uses.
// Renaming a CSS class or extracting a subcomponent will not break this test;
// removing the accessible label will, which is a regression worth catching.
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { LoginForm } from './LoginForm'

it('shows a field error when email is blank on submit', async () => {
  const user = userEvent.setup()
  render(<LoginForm onSuccess={vi.fn()} />)

  await user.click(screen.getByRole('button', { name: /sign in/i }))

  expect(screen.getByRole('alert')).toHaveTextContent('Email is required')
})

it('calls onSuccess with the email after a valid submission', async () => {
  const onSuccess = vi.fn()
  const user = userEvent.setup()
  render(<LoginForm onSuccess={onSuccess} />)

  await user.type(screen.getByLabelText(/email/i), 'user@example.com')
  await user.type(screen.getByLabelText(/password/i), 'secret')
  await user.click(screen.getByRole('button', { name: /sign in/i }))

  expect(onSuccess).toHaveBeenCalledWith('user@example.com')
})
```

Use `getByRole` / `getByLabelText` / `getByText` — never `getByTestId` or class selectors. This layer should be the largest by count and run in milliseconds with no network or browser involved.

### Layer 2: network mocking with MSW

```tsx
// GOOD: MSW intercepts at fetch/XHR level — the component runs real data-fetching code.
// Switching from axios to fetch, or changing a URL path, won't break these tests
// unless the observable behavior changes.
import { http, HttpResponse } from 'msw'
import { setupServer } from 'msw/node'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { LoginForm } from './LoginForm'

const server = setupServer(
  http.post('/api/auth/login', () =>
    HttpResponse.json({ token: 'tok_abc' }, { status: 200 })
  )
)
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))
afterEach(() => server.resetHandlers())  // prevent handler leak between tests
afterAll(() => server.close())

it('shows welcome text after a successful login', async () => {
  const user = userEvent.setup()
  render(<LoginForm onSuccess={vi.fn()} />)
  await user.type(screen.getByLabelText(/email/i), 'user@example.com')
  await user.type(screen.getByLabelText(/password/i), 'secret')
  await user.click(screen.getByRole('button', { name: /sign in/i }))

  expect(await screen.findByText(/welcome/i)).toBeInTheDocument()
})

it('shows an error when the API returns 401', async () => {
  server.use(http.post('/api/auth/login', () => HttpResponse.json({}, { status: 401 })))
  const user = userEvent.setup()
  render(<LoginForm onSuccess={vi.fn()} />)
  await user.type(screen.getByLabelText(/email/i), 'bad@example.com')
  await user.click(screen.getByRole('button', { name: /sign in/i }))

  expect(await screen.findByRole('alert')).toHaveTextContent(/invalid credentials/i)
})
```

`onUnhandledRequest: 'error'` fails loudly when a new API call is added to the component but not covered by a handler — preventing silent drift where the call returns `undefined` and the test coincidentally passes anyway.

### Layer 3: integration with real store and router

```tsx
// GOOD: wire the real TanStack Router (or React Router) and a real Zustand/Redux store
// so the test exercises the same code path a user takes across a navigation boundary,
// without spinning up a browser or an actual server.
import { RouterProvider, createMemoryHistory, createRouter } from '@tanstack/react-router'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { routeTree } from '@/routeTree.gen'

it('navigates to the profile page after login', async () => {
  const history = createMemoryHistory({ initialEntries: ['/login'] })
  const router = createRouter({ routeTree, history })
  const user = userEvent.setup()
  render(<RouterProvider router={router} />)

  await user.type(screen.getByLabelText(/email/i), 'user@example.com')
  await user.type(screen.getByLabelText(/password/i), 'secret')
  await user.click(screen.getByRole('button', { name: /sign in/i }))

  expect(
    await screen.findByRole('heading', { name: /your profile/i })
  ).toBeInTheDocument()
})
```

### Layer 4: E2E with Playwright and @axe-core/playwright

```ts
// GOOD: Playwright locators wait for visible + stable automatically — no timeouts.
// Use auth fixtures so every test begins with a pre-authenticated session,
// not a repeated login flow that dominates suite time.
import { test, expect } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'

test('checkout flow: product → cart → order confirmation', async ({ page }) => {
  await page.goto('/products/widget-pro')
  await page.getByRole('button', { name: /add to cart/i }).click()
  await page.getByRole('link', { name: /view cart/i }).click()
  await page.getByRole('button', { name: /checkout/i }).click()

  await expect(page.getByRole('heading', { name: /order confirmed/i })).toBeVisible()
})

test('product page has no critical accessibility violations', async ({ page }) => {
  await page.goto('/products/widget-pro')
  const results = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa'])
    .analyze()
  expect(results.violations).toEqual([])
})
```

Set `trace: 'on-first-retry'` in `playwright.config.ts` — the trace viewer gives a step-by-step DOM/network replay that cuts flaky-test diagnosis time dramatically versus log tailing.

### Which layer for what

| What you are testing | Layer | Tool |
|---|---|---|
| Validation logic, utility functions | Unit | Vitest (plain) |
| Component renders correct roles / text | Component | Vitest + Testing Library |
| Component + network calls (success / error paths) | Component + network | Vitest + MSW |
| Multi-route flow with real store | Integration | Vitest + router + store |
| Critical end-to-end user journey | E2E | Playwright |
| Accessibility compliance per page / state | E2E | @axe-core/playwright |

**Pyramid shape**: most tests live in the component and MSW layers; a handful of integration tests cover cross-route flows; E2E tests cover only the 3–5 journeys that would be critical if broken in production.

## Why This Works

- **`getByRole` / `getByLabelText` queries are stable across refactors** because they target the accessible tree, not internal DOM structure — renaming a class or extracting a subcomponent doesn't break them, but removing the label does (a real regression worth catching).
- **MSW intercepts at the `fetch`/`XMLHttpRequest` boundary, not at the module import level**, so the component runs its real data-fetching code; only the HTTP response is controlled. This means a `vi.mock('axios')` call is never needed, and the test remains valid across fetch-library changes.
- **Playwright locators wait for the element to be visible and stable before interacting**, so `await page.getByRole('button', { name: /submit/i }).click()` cannot click before the button renders — eliminating the entire class of `waitForTimeout` flakes without any developer discipline required.
- **`@axe-core/playwright` runs axe in the real browser DOM** after navigation, catching contrast, missing labels, and ARIA errors that no amount of component-level testing can surface.

## Edge Cases & Pitfalls

### Common Mistakes

- **Querying by `data-testid` everywhere**: reserve it for elements with no accessible role or label. Every `getByTestId` is a missed chance to verify the accessible tree — and a hook that will break on DOM refactors.
- **Snapshot tests without behavioral assertions**: snapshots catch visual drift but don't verify the component works; add at least one interaction assertion alongside each snapshot so a failure points to something meaningful.
- **Over-mocking with `vi.mock`**: mocking every collaborator proves nothing about the integration; prefer MSW for network boundaries and the real module for everything internal to the feature.
- **Calling `waitForTimeout` in Playwright**: replace every instance with a locator assertion (`await expect(locator).toBeVisible()`) — if the right locator doesn't exist, the timeout is masking a real problem, not solving it.
- **Forgetting `afterEach(() => server.resetHandlers())`**: a test that overrides an MSW handler without resetting pollutes every subsequent test in the file.
- **Running axe only on the static landing page**: accessibility regressions most often appear on modal dialogs, error states, and post-submit confirmations — run axe after the interaction that surfaces each state.

## Verification

```bash
# Unit + component + integration tests; should finish under 10 s for a mid-sized app
npx vitest run

# Run Playwright in headed mode to confirm locator-based waits work visually
npx playwright test --headed

# Open trace for the most recent failed E2E run
npx playwright show-report
```

- [ ] Every new component test queries by `getByRole` or `getByLabelText`, not `getByTestId`.
- [ ] All network calls in component tests are handled by MSW, not `vi.mock('axios')` or `vi.mock('fetch')`.
- [ ] Playwright suite has zero `waitForTimeout` calls.
- [ ] At least one axe scan runs per critical page or interactive state in E2E.

## References

- [Testing Library — Query priority](https://testing-library.com/docs/queries/about#priority)
- [MSW — Getting started](https://mswjs.io/docs/getting-started)
- [Playwright — Locators](https://playwright.dev/docs/locators)
- [Playwright — Trace viewer](https://playwright.dev/docs/trace-viewer)
- [@axe-core/playwright](https://github.com/dequelabs/axe-core-npm/tree/develop/packages/playwright)
