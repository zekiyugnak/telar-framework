---
name: "web-e2e-locators"
description: "The most common mistake in Playwright specs against a Refine + TanStack + Supabase + shadcn/ui stack is reaching for CSS selectors or `waitForTimeout` because the UI is composed of Radix primitives (portals, generated id"
source_type: "skill"
source_file: "skills/web-e2e-locators.md"
---

# web-e2e-locators

Migrated from `skills/web-e2e-locators.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Write Playwright Locators That Survive shadcn/TanStack UI Churn

The most common mistake in Playwright specs against a Refine + TanStack + Supabase + shadcn/ui stack is reaching for CSS selectors or `waitForTimeout` because the UI is composed of Radix primitives (portals, generated ids) and async TanStack Query fetches. Both make specs flaky: CSS selectors break the moment a class name or DOM nesting changes, and fixed sleeps either fail on slow CI or waste seconds on fast runs. This skill covers a two-tier locator strategy — `data-testid` for domain-dense rows/actions, `getByRole`/`getByLabel` for generic controls — plus the exact recipes for shadcn/Radix comboboxes, dialogs, and toasts, and how to let Playwright's web-first auto-retrying assertions absorb TanStack Query's async settling instead of sleeping through it.

## Problem

```ts
// BAD: CSS selector reaches into Radix's generated DOM structure — breaks on any
// shadcn/ui version bump or component swap, and says nothing about user intent
await page.click('.select-trigger > span:nth-child(1)')
await page.click('[data-radix-popper-content-wrapper] div:nth-of-type(3)')

// BAD: fixed sleep to "wait out" a TanStack Query refetch — masks the real
// async boundary and either flakes under CI load or wastes wall-clock time
await page.getByRole('button', { name: /save/i }).click()
await page.waitForTimeout(2000)
expect(await page.getByTestId('shortlist-candidate-card').count()).toBeGreaterThan(0)

// BAD: asserting native HTML validity instead of the RHF/zod-driven error state
// the user actually sees — passes even when the visible error text is wrong or absent
const isValid = await page.locator('input[name="email"]').evaluate((el: HTMLInputElement) => el.validity.valid)
expect(isValid).toBe(false)
```

## Solution

### Locator priority: `data-testid` for domain-dense UI, role/label for generic controls

Use `data-testid` as the primary locator for rows, cards, and actions inside domain-dense UI — table rows, credential queues, reveal actions — where no single accessible role/name uniquely identifies the element, and where the id is often parameterized by a real record id (`credential-row-${id}`, `messaging-conversation-${conversationId}`). Use `getByRole`/`getByLabel` for login forms and other generic, single-purpose controls where the accessible name is already unique and stable.

```ts
// GOOD: parameterized data-testid for a real row in a TanStack Table-backed queue —
// matches what CredentialReviewQueueTable actually renders (data-testid={`credential-row-${c.id}`})
const row = page.getByTestId(`credential-row-${fixture.id}`)
await expect(row).toBeVisible()
await row.getByTestId(`credential-reject-${fixture.id}`).click()

// GOOD: generic domain-dense action testids, no id needed — single instance per view
await expect(page.getByTestId('reveal-cta')).toBeDisabled()
await expect(page.getByTestId('messaging-thread')).toBeVisible({ timeout: 15_000 })

// GOOD: getByRole/getByLabel for the login form — accessible name is already
// unique, and this is the same path a real user (or screen reader) takes
await page.getByLabel('Email').fill(user.email)
await page.getByLabel('Password').fill(PASSWORD)
await page.getByRole('button', { name: 'Sign in' }).click()
```

### shadcn/Radix Select (combobox → listbox → option)

Radix's `Select` renders the trigger with `role="combobox"` and portals the open listbox to the end of `<body>` with `role="listbox"`; Playwright pierces both the component boundary and the portal automatically, so no special selector is needed for either hop.

```ts
// GOOD: two-step combobox → listbox → option chain, works through the Radix portal
await page.getByRole('combobox').first().click()
await page.getByRole('listbox').getByRole('option', { name: 'Germany' }).click()
```

### shadcn/Radix Dialog and Toast

```ts
// Dialog: role="dialog" scopes all inner queries to the open modal, avoiding
// collisions with a same-named control still present in the page behind it
const dialog = page.getByRole('dialog', { name: /reject credential/i })
await dialog.getByLabel(/reason/i).fill('Document illegible')
await dialog.getByRole('button', { name: /confirm/i }).click()

// Toast: Radix Toast renders role="status" (polite) or role="alert" (assertive) —
// assert on it directly instead of a CSS class or animation-timing sleep
await expect(page.getByRole('status')).toContainText(/credential rejected/i)
```

### TanStack Table: assert on rendered rows after sort/filter/paginate

Sorting, filtering, and paginating a TanStack Table are all async-adjacent (they can trigger a TanStack Query refetch with server-side filtering). Never assume the interaction is done after the click — assert on the resulting row set via the same `data-testid`/role locators used elsewhere, and let Playwright's auto-retry absorb the settle time.

```ts
// GOOD: click header to sort, then assert the DOM row order — no timeout,
// the toBeVisible/toHaveText assertion retries until TanStack Table re-renders
await page.getByRole('columnheader', { name: /submitted/i }).click()
const firstRow = page.getByTestId('credential-queue-table').getByRole('row').nth(1)
await expect(firstRow).toContainText(fixture.mostRecentLabel)

// GOOD: filter input narrows rows; assert count settles instead of sleeping
await page.getByTestId('candidate-search-query').fill('Berlin')
await page.getByTestId('candidate-search-submit').click()
await expect(page.getByTestId('candidate-search-result')).toHaveCount(1)
```

### TanStack Query settle: assert on resulting UI, never `waitForTimeout`

```ts
// GOOD: the mutation's onSuccess invalidates the query, the list re-renders,
// and toBeVisible retries until that render lands — no sleep, no race
await page.getByTestId('add-to-shortlist-cta').click()
await expect(page.getByTestId('shortlist-candidate-card')).toBeVisible()
```

### react-hook-form + zod validation state

React Hook Form's `fieldState.error` drives the visible error text and `aria-invalid` — assert on those, not on native HTML5 `validity`, since zod's resolver is what actually gates submission in this stack and native constraints are frequently absent or overridden.

```ts
// GOOD: submit with an invalid value, assert the RHF/zod-driven error text
// and aria-invalid — both reflect what a real user and a screen reader see
await page.getByLabel(/email/i).fill('not-an-email')
await page.getByRole('button', { name: /submit/i }).click()

await expect(page.getByText(/must be a valid email/i)).toBeVisible()
await expect(page.getByLabel(/email/i)).toHaveAttribute('aria-invalid', 'true')
```

## Why This Works

- **`data-testid` on parameterized rows survives refactors that role/label locators can't handle** — a table row for a specific credential or conversation has no unique accessible name on its own, so `credential-row-${id}` / `messaging-conversation-${conversationId}` is the only locator that stays stable when the row's visible text (status, timestamp) changes between runs.
- **Playwright pierces the Radix portal and shadow DOM by default**, so `getByRole('listbox')` finds the popover content even though Radix appends it to `document.body` outside the trigger's DOM subtree — no `page.locator('body >> role=listbox')` workaround is needed.
- **`role="status"`/`role="alert"` on Radix Toast means the same accessibility-tree query used for buttons and dialogs also covers transient notifications**, so toast assertions don't need a separate CSS-class-based recipe.
- **Web-first auto-retrying assertions (`expect(locator).toBeVisible()`, `.toHaveCount()`, `.toContainText()`) poll until the condition holds or the assertion times out**, which is exactly the shape of a TanStack Query cache invalidation → refetch → re-render cycle — the assertion naturally waits exactly as long as needed and no longer.
- **Asserting `aria-invalid` and the rendered error text (not native `validity`) verifies the state react-hook-form + zod actually control**, catching regressions where the zod schema changes but the visible error message doesn't, or vice versa.

## Edge Cases & Pitfalls

### Common Mistakes

- **Reaching for CSS selectors on Radix internals**: `[data-radix-popper-content-wrapper]`, `.select-trigger`, or nth-child chains all break on a shadcn/ui version bump. Use the `role`-based combobox/listbox/option chain instead — it targets Radix's stable ARIA contract, not its DOM implementation.
- **Calling `waitForTimeout` to "wait out" a refetch**: replace it with an assertion on the resulting UI (`toBeVisible`, `toHaveCount`, `toContainText`). If no locator changes after the action, that is itself a signal the interaction didn't do what the test expects — a timeout would only hide it.
- **Using `data-testid` for controls that already have a unique accessible name**: a login form's Email/Password fields and Sign-in button don't need testids — `getByLabel`/`getByRole` are shorter, and adding a testid there is a missed opportunity to catch an accessibility regression.
- **Asserting native HTML5 `validity` on RHF/zod-driven forms**: react-hook-form typically omits or overrides native `required`/`pattern` attributes in favor of the zod resolver: assert on `aria-invalid` and the rendered error text, which is what the resolver actually drives.
- **Querying inside a dialog/toast without scoping to its role first**: `page.getByRole('button', { name: /confirm/i })` can match a same-named button still mounted behind an open modal. Scope through `page.getByRole('dialog', ...)` first.
- **Forgetting `{ timeout: 15_000 }` on assertions that follow a real network round-trip** (login redirect, first message in a new thread): Playwright's default 5s assertion timeout is tuned for local re-renders, not an auth or Supabase Realtime round-trip — raise it explicitly on those specific assertions rather than raising the global timeout.

## Verification

```bash
# Full suite in headed mode — confirms combobox/dialog/toast interactions visually
npx playwright test --headed

# Grep the spec files for the anti-patterns this skill eliminates
grep -rn "waitForTimeout" src/e2e src/client-web/tests/e2e src/admin/tests/e2e   # expect 0 hits
grep -rn "data-radix-popper\|nth-child\|nth-of-type" src/e2e src/client-web/tests/e2e src/admin/tests/e2e  # expect 0 hits

# Open the trace for the most recent failed run
npx playwright show-report
```

- [ ] Zero `waitForTimeout` calls anywhere in the E2E suite.
- [ ] Zero CSS/nth-child selectors targeting Radix internals — every combobox/dialog/toast interaction goes through `getByRole`.
- [ ] Every parameterized row/action locator uses `data-testid` with the real record id, not an index-based `.nth()` on an untagged list.
- [ ] Every login/generic-control locator uses `getByLabel`/`getByRole`, not a testid.
- [ ] Form validation assertions check `aria-invalid` + visible error text, not native `validity`.

## References

- [Playwright — Locators](https://playwright.dev/docs/locators)
- [Playwright — Auto-retrying assertions](https://playwright.dev/docs/test-assertions)
- [Radix UI — Select](https://www.radix-ui.com/primitives/docs/components/select)
- [Radix UI — Toast](https://www.radix-ui.com/primitives/docs/components/toast)
- [TanStack Table — Docs](https://tanstack.com/table/latest)
- [React Hook Form — `fieldState`](https://react-hook-form.com/docs/useform/formstate)
- `skills/web-testing.md` — the base testing-pyramid skill this one specializes for locator/waiting strategy.
- `skills/supabase-e2e-harness.md` — sibling skill for Arrange/Act test-data setup against Supabase-backed E2E; pairs with this skill's act-side locators.
- Real source: `talent-portal/src/admin/tests/e2e/credential-review.spec.ts` (`credential-row-${id}` pattern), `talent-portal/src/e2e/scenarios/S06-messaging.spec.ts` (`messaging-thread`, `messaging-conversation-${id}`), `talent-portal/src/e2e/scenarios/S02-corridor-closed.spec.ts` (`reveal-cta`).
