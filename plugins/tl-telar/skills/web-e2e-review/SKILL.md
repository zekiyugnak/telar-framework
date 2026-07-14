---
name: "web-e2e-review"
description: "A green E2E suite proves nothing on its own — a spec that swallows an error, forgets `await` on an assertion, sleeps on a fixed timer instead of waiting for state, or performs its act with an admin/service key can pass o"
source_type: "skill"
source_file: "skills/web-e2e-review.md"
---

# web-e2e-review

Migrated from `skills/web-e2e-review.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Review E2E Specs for Silent Always-Pass Anti-Patterns Before They Reach Green

A green E2E suite proves nothing on its own — a spec that swallows an error, forgets `await` on an assertion, sleeps on a fixed timer instead of waiting for state, or performs its act with an admin/service key can pass on every run, including the run where the feature is completely broken. This skill is a review gate, not a test generator: it walks a spec against a 24-pattern taxonomy organized into P0 (silently always passes), P1 (flaky or leaky), and P2 (dead weight), plus one harness-specific rule inherited from `[[supabase-e2e-harness]]` — `service_role` may only arrange, never act. Run this before merging any new or changed spec, and whenever a suite is suspiciously green under a change that should have broken something.

## Problem

```typescript
// P0: missing await on expect — the assertion never actually runs;
// the test function returns before the promise settles, so a rejection
// is an unhandled rejection, not a test failure
test('shows error on invalid login', async ({ page }) => {
  await page.getByRole('button', { name: /sign in/i }).click()
  expect(page.getByRole('alert')).toBeVisible() // missing await — always "passes"
})

// P0: swallowed error — any exception inside becomes a silent no-op
test('completes checkout', async ({ page }) => {
  try {
    await page.getByRole('button', { name: /pay/i }).click()
    await expect(page.getByText(/order confirmed/i)).toBeVisible()
  } catch {
    // swallows every failure — checkout could be fully broken and this stays green
  }
})

// P0: service_role performs the ACT — RLS/authorization is never exercised
// (see [[supabase-e2e-harness]] Arrange/Act rule)
await supabaseAdmin.from('orders').update({ status: 'paid' }).eq('id', orderId) // service_role bypasses RLS
await expect(page.getByText(/paid/i)).toBeVisible() // proves nothing about the real act

// P1: fixed sleep instead of waiting for real state
await page.click('#submit')
await page.waitForTimeout(3000) // passes on fast CI, false-passes-then-flakes on slow CI
expect(await page.textContent('.result')).toBe('Done')
```

## Solution

### P0 — silent always-pass (block merge on any of these)

| Pattern | Why it silently passes |
|---|---|
| Missing `await` on `expect(...)` in an async test | The assertion promise is never resolved before the test function returns; a rejection becomes an unhandled rejection instead of a failure. |
| `try/catch` (or `.catch(() => {})`) that swallows the failure | Any thrown error inside — including the assertion itself — is caught and discarded; the test body completes normally regardless of outcome. |
| Assertions that can't fail (`expect(true).toBe(true)`, `expect(1).toBeTruthy()`) or no assertion at all | The test exercises code paths but never checks the actual outcome, so it passes whether the feature works or is fully broken. |
| Missing auth/precondition setup so the act never really runs | If login/session setup silently no-ops (e.g., a fixture returns `undefined` and no one checks), the "act" runs as an anonymous/guest user against a redirect or empty state — asserting on that state passes without ever reaching the code under test. |
| **`service_role` used in the ACT** (harness-specific — Arrange/Act violation, see `[[supabase-e2e-harness]]`) | `service_role` bypasses RLS entirely. If the act (the behavior under assertion) is performed with the admin key instead of the actor's own JWT through real UI, a broken or missing authorization policy can never fail the test — it just proves the database accepts writes when policies are turned off. |
| Assertion runs on the wrong/stale object (e.g., asserting on a `page` reference captured before a `page.reload()` or a popup navigation) | The old reference still resolves DOM queries against a torn-down or previous document, so a check that "should" fail after a regression keeps matching stale content. |
| Conditional assertion behind an `if` that can silently be false (`if (await locator.isVisible()) { await expect(...) }`) | When the element is absent — which may itself be the regression — the assertion block never executes, and the test exits with zero assertions run. |

### P1 — flaky or leaky (fix before merge, does not always silently pass but erodes trust)

| Pattern | Why it's a problem |
|---|---|
| Hard-coded sleeps (`waitForTimeout`, fixed `setTimeout`, `sleep(ms)`) | Masks a real timing dependency instead of waiting for it; passes by luck on fast runs and flakes under load, teaching the team to re-run instead of investigate. |
| Unmocked real-backend writes in what should be an isolated unit/component test | Couples a fast, isolated layer to network/DB availability and ordering; a slow or down dependency fails tests that have nothing to do with it, and successes don't prove the unit's logic is correct. |
| Inconsistent or duplicated structure that hides intent (copy-pasted specs with one line changed, no shared arrange helper) | A reviewer (or the author, six months later) cannot tell which line encodes the actual behavior under test versus incidental setup, so regressions in the "boilerplate" lines go unnoticed. |

### P2 — dead weight (flag, don't block, but track for removal)

| Pattern | Why it's a problem |
|---|---|
| Zombie/dead specs (`test.skip`, `.only` left in, or a spec that hasn't run in CI for months) | Contributes to suite count and green-checkmark confidence without ever exercising code; a `.only` left in accidentally also silently skips every *other* spec in the file. |
| YAGNI over-scoped fixtures (arrange helpers that seed data no assertion in the spec ever reads) | Slows every run and widens the blast radius of arrange-step failures for zero coverage benefit; a sign the spec was copied from a broader scenario and never trimmed. |

### Reviewer checklist

- [ ] Every `expect(...)` call inside an `async` test/callback is `await`ed (or is a synchronous Playwright assertion form that doesn't need it — confirm which).
- [ ] No `try/catch` around the act or the assertion without re-throwing or explicitly failing (`expect.fail(...)`) in the catch branch.
- [ ] No assertion is a tautology (`expect(true)`) and no test body reaches its end with zero assertions executed.
- [ ] Auth/precondition setup (login, seeded role, feature flag) is itself asserted or guaranteed — not assumed — before the act runs.
- [ ] `grep` for `SUPABASE_SERVICE_KEY` / `service_role` outside `factory/*.ts` arrange helpers returns nothing — the act always goes through real UI + anon key + the actor's own JWT.
- [ ] No `page`/`locator` reference is reused across a `reload()`, popup, or new-tab boundary without re-acquiring it.
- [ ] Conditional assertions (`if (await x.isVisible())`) either have an `else` that fails, or are replaced with an unconditional `expect(x).toBeVisible()`.
- [ ] Zero `waitForTimeout` / fixed `setTimeout` calls; every wait targets a locator or a real condition.
- [ ] No `test.skip` or `.only` left in the diff.
- [ ] Every arrange-step fixture is read by at least one assertion in the spec.

### Failure classification (route a real failure to its root cause)

When a reviewed spec does fail for real, classify before proposing a fix — the fix differs by category:

- **Flaky timing** — passes most runs, fails under load/parallelism; look for a replaced `waitForTimeout` or a race between two async operations.
- **Selector drift** — the DOM changed (renamed test id, restructured markup) but the locator didn't; prefer role/label locators (see `web-testing.md`) to reduce this class.
- **Isolation failure** — a prior test's leftover state (shared email, unreset MSW handler, un-namespaced row) leaks into this one; check for `runId` scoping per `[[supabase-e2e-harness]]`.
- **Hydration race** — the assertion runs before client-side JS attaches interactivity (common right after SSR navigation); wait on an interactive-state locator, not just visibility.
- **Missing auth** — the session/token setup silently failed and the act ran as anonymous/wrong-role; assert the authenticated state explicitly before the act.
- **Env mismatch** — spec assumes a seed value, feature flag, or config that differs between local/CI/staging; pin the assumption in the arrange step instead of the environment.

## Why This Works

- **Every P0 pattern is deterministic and greppable** — missing `await`, empty `catch`, `service_role` outside a factory file, `test.skip`/`.only` — so a reviewer (or a pre-commit check) can flag them mechanically instead of relying on careful reading of test logic.
- **Silent-pass bugs are asymmetric**: a false positive (test passes when it shouldn't) is far more expensive than a false negative, because it removes the safety net exactly when a regression ships. Tiering P0 as blocking reflects that asymmetry directly in the review gate.
- **The Arrange/Act rule generalizes the RLS-specific harness rule into a review-time check**: any test whose "proof" comes from an admin-privileged call instead of the real code path under test has the same failure mode as a `service_role`-in-act bug, whether or not Supabase is involved.
- **Classifying failures by root cause before fixing** prevents the most common bad fix — wrapping a flaky-timing failure in a longer `waitForTimeout`, which converts a P1 flake into a P0 silent-pass.

## Edge Cases & Pitfalls

### Common Mistakes

- **Treating this as a test generator**: this skill reviews and flags; it does not rewrite specs. Hand the flagged list back to the spec's author (or the `web-testing` skill) for fixes.
- **Confusing `expect.poll`/`toPass` retries with fixed sleeps**: `await expect.poll(() => getStatus()).toBe('done')` and `await expect(async () => { ... }).toPass()` are legitimate condition-based retries — they re-evaluate a real predicate on an interval and fail if it never becomes true. A fixed `waitForTimeout(3000)` waits blindly regardless of whether the condition is already true or will ever become true. Do not flag the former; always flag the latter.
- **Flagging every `try/catch` as P0**: a catch block that asserts on the error (`expect(err.message).toMatch(/invalid/)`) or re-throws after logging is fine — only a catch that discards the failure and lets the test exit cleanly is the anti-pattern.
- **Missing the auth-setup case because the test "looks" complete**: a spec with a full act + assertion can still be a P0 if the arrange step silently produced an unauthenticated or wrong-role session; check what the act actually operated as, not just whether an assertion exists.
- **Approving a suite because it's green under this review**: this gate catches structural always-pass smells, not business-logic correctness — a spec can pass every checklist item and still assert the wrong thing. Pair with requirement-level review, not as a substitute for it.

## Verification

```bash
# P0: expect(...) calls without await in the same statement (manual triage of hits —
# some may be intentionally-synchronous Playwright soft-assertion forms)
grep -rn "expect(" tests/ e2e/ | grep -v "await expect("

# P0: service_role/admin key reaching outside arrange helpers
grep -rln "SUPABASE_SERVICE_KEY\|service_role" tests/ e2e/ --include="*.spec.ts" | grep -v "factory/"

# P0/P2: empty catch blocks and skipped/focused specs left in
grep -rn "catch\s*(.*)\s*{\s*}" tests/ e2e/
grep -rn "test\.skip\|test\.only\|describe\.only" tests/ e2e/

# P1: fixed sleeps instead of locator-based waits
grep -rn "waitForTimeout\|setTimeout(.*[0-9]\{3,\})" tests/ e2e/
```

- [ ] Zero unawaited `expect(` calls in async contexts (each `grep` hit triaged, not just silenced).
- [ ] Zero `service_role`/`SUPABASE_SERVICE_KEY` occurrences outside `factory/*.ts` arrange helpers.
- [ ] Zero empty `catch` blocks and zero `test.skip`/`.only` left in the diff.
- [ ] Zero `waitForTimeout` calls; any retry loop uses `expect.poll`/`toPass` against a real condition.
- [ ] Every arrange-step fixture in the spec is read by at least one assertion.

## References

- [voidmatcha/e2e-skills](https://github.com/voidmatcha/e2e-skills) — the 24-pattern P0/P1/P2 silent-always-pass taxonomy this skill adapts.
- `[[supabase-e2e-harness]]` — source of the Arrange/Act rule (`service_role` arranges only, every act goes through real UI + RLS) that this skill enforces as a P0 review item.
- `skills/web-testing.md` — the authoring-side companion; use it to write the fix once this gate flags a pattern.
