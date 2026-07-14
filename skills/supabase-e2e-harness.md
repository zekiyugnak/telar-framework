---
id: supabase-e2e-harness
category: skill
impact: CRITICAL
impactDescription: "Provides the Arrange/Act test-data model for Supabase E2E — service_role provisions data, real UI + RLS executes acts — so E2E suites exercise real authorization instead of bypassing it, with runId isolation replacing fragile teardown"
tags: [testing, e2e, supabase, playwright, rls, web]
capabilities:
  - Plain-fetch Supabase REST/RPC factory (no supabase-js in Playwright)
  - Arrange with service_role, act through real UI + RLS
  - Composable role factories (candidate, employer, staff, credential)
  - runId namespacing for isolation without per-test teardown
  - Ephemeral local Supabase in CI (supabase start + db reset + seed)
useWhen:
  - Setting up E2E test data for a Supabase-backed web app
  - Tests need authenticated per-role flows that must honor RLS
  - Avoiding supabase-js module-transform issues inside Playwright
---

# Build Supabase E2E Test Data with an Arrange/Act Split That Never Bypasses RLS

The most common mistake in Supabase E2E suites is letting `service_role` do double duty: it provisions the fixtures AND performs the action under test, which means the test never actually proves RLS works — it just proves the database accepts writes when policies are turned off. The second most common mistake is importing `@supabase/supabase-js` straight into Playwright's Node/ESM test runner, which hits module-transform breakage. This skill covers the harness pattern that avoids both: a plain-fetch factory that talks to `/auth/v1` and `/rest/v1` directly, a strict rule that `service_role` only arranges while every act goes through real UI + anon key + the user's own JWT, and `runId` namespacing that removes the need for teardown entirely.

## Problem

```typescript
// BAD: service_role performs the ACT, not just the arrange — RLS never runs,
// so a broken policy would never fail this test
const { data: reveal } = await supabaseAdmin
  .from('contact_reveals')
  .insert({ employer_id: employer.id, candidate_id: candidate.id }) // service_role bypasses RLS
  .select()
  .single()
expect(reveal).toBeTruthy() // passes even if the RLS policy is completely broken

// BAD: importing supabase-js into the Playwright test runner
import { createClient } from '@supabase/supabase-js' // module-transform issues under Playwright's Node/ESM runner
const supabase = createClient(url, anonKey)

// BAD: per-test teardown that races with parallel workers on a shared DB
afterEach(async () => {
  await supabaseAdmin.from('candidate_profiles').delete().eq('email', testEmail) // fragile, order-dependent
})
```

## Solution

### The Arrange/Act rule

**Arrange** (precondition setup) uses `service_role` via factory helpers — user provisioning, RBAC grants, entitlement/subscription/shortlist/step-up seeding. **Act** (the thing under test) always goes through real UI + anon key + the user's own JWT, so real RLS runs; RPC shortcuts are never used to fake an actor's action (reveal, credential-approval, etc. always run through real Edge/RLS, not a direct RPC call standing in for the UI).

### Plain-fetch Supabase factory (no supabase-js)

`factory/supabase.ts` talks to Supabase over raw `fetch` against `/auth/v1` and `/rest/v1` instead of importing `@supabase/supabase-js`, specifically to avoid supabase-js's module-transform issues inside Playwright's Node/ESM test runner. Note the anon-vs-service_role header split: `headers()` carries the anon `apikey` plus a live user's bearer token (so PostgREST evaluates RLS as that user); `adminHeaders()` carries the service_role key as both `apikey` and bearer (RLS bypass, arrange-only).

```typescript
function headers(token: string, extra: Record<string, string> = {}) {
  return { apikey: SUPABASE_ANON_KEY, Authorization: `Bearer ${token}`, "Content-Type": "application/json", ...extra };
}
function adminHeaders(extra: Record<string, string> = {}) {
  return { apikey: SUPABASE_SERVICE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`, "Content-Type": "application/json", ...extra };
}

export async function signUp(email: string, password: string, data: Json = {}): Promise<{ token: string; userId: string }> {
  const res = await req(`/auth/v1/signup`, {
    method: "POST",
    headers: { apikey: SUPABASE_ANON_KEY, "Content-Type": "application/json" },
    body: JSON.stringify({ email, password, data }),
  });
  if (!res.ok) throw new Error(`signUp ${res.status}: ${await res.text()}`);
  const body = await res.json();
  const token = body.access_token as string;
  if (!token) throw new Error(`signUp: response had no access_token: ${JSON.stringify(body)}`);
  return { token, userId: decodeSub(token) };
}

export async function signIn(email: string, password: string): Promise<{ token: string; userId: string }> { /* ... same shape via /auth/v1/token?grant_type=password ... */ }

export async function restSelect<T = Json>(table: string, query: string, token: string): Promise<T[]> {
  const res = await req(`/rest/v1/${table}?${query}`, { method: "GET", headers: headers(token) });
  if (!res.ok) throw new Error(`restSelect ${table} ${res.status}: ${await res.text()}`);
  return res.json();
}

export async function restInsert<T = Json>(table: string, rows: Json | Json[], token: string, prefer = "return=representation"): Promise<T[]> { /* anon+JWT insert → RLS */ }

export async function rpc<T = unknown>(fn: string, args: Json, token: string): Promise<T> {
  const res = await req(`/rest/v1/rpc/${fn}`, { method: "POST", headers: headers(token), body: JSON.stringify(args) });
  if (!res.ok) throw new Error(`rpc ${fn} ${res.status}: ${await res.text()}`);
  return res.json();
}

export async function adminInsert<T = Json>(table: string, rows: Json | Json[], prefer = "return=representation"): Promise<T[]> {
  const res = await req(`/rest/v1/${table}`, { method: "POST", headers: adminHeaders({ Prefer: prefer }), body: JSON.stringify(rows) });
  if (!res.ok) throw new Error(`adminInsert ${table} ${res.status}: ${await res.text()}`);
  return prefer.includes("representation") ? res.json() : [];
}

export async function adminSelect<T = Json>(table: string, query: string): Promise<T[]> {
  const res = await req(`/rest/v1/${table}?${query}`, { method: "GET", headers: adminHeaders() });
  if (!res.ok) throw new Error(`adminSelect ${table} ${res.status}: ${await res.text()}`);
  return res.json();
}
```

`createAuthUser` (the Admin API path, service_role) lives in the sibling `factory/admin.ts`:

```typescript
export async function createAuthUser(email: string, password: string, metadata: Record<string, unknown>): Promise<string> {
  const res = await fetch(`${SUPABASE_URL}/auth/v1/admin/users`, {
    method: "POST",
    headers: { apikey: SUPABASE_SERVICE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ email, password, email_confirm: true, user_metadata: metadata }),
  });
  if (!res.ok) throw new Error(`createAuthUser ${res.status}: ${await res.text()}`);
  const body = await res.json();
  return body.id as string;
}
```

### runId namespacing instead of teardown

`newRunId()` generates an 8-hex-char id per test run; `scopedEmail()` uses it to build a namespaced, collision-free email. Because every row a scenario creates is tagged with this run-unique id, scenarios never collide and the harness needs no teardown/reset step between runs.

```typescript
import { randomBytes } from "node:crypto";

export function newRunId(): string {
  return randomBytes(4).toString("hex"); // 8 hex char, unique per run
}

export function scopedEmail(prefix: string, runId: string): string {
  return `${prefix}-${runId}@e2e.local`;
}
```

### Composable role factories

Each role factory composes the plain-fetch primitives (`signUp`/`signIn`/`rpc`/`adminInsert`/`adminSelect`, `createAuthUser`) into one arrange call that returns everything a scenario needs. Entitlements are never read from a static seed/lookup table — `createEmployerWithReveal` resolves the plan's real, live limits via the `core_resolve_plan_entitlements` RPC (called with the service_role bearer) so tests stay correct even if plan features change.

```typescript
// candidate.ts
export async function createFinalizedCandidate(runId: string, region: string): Promise<{
  email: string; password: string; userId: string; token: string; candidateProfileId: string;
}> {
  const email = scopedEmail(`cand-${region.toLowerCase()}`, runId);
  const { token, userId } = await signUp(email, PASSWORD, { region });
  const [profile] = await adminInsert<{ id: string }>("candidate_profiles", {
    user_id: userId, region, approval_status: "passive", display_name: `E2E Candidate ${runId}`,
    willing_to_relocate: true, willing_abroad: true, availability_status: "passive", profile_completion_score: 0,
  }, "return=representation");
  await rpc("core_finalize_candidate_application", { p_candidate_profile_id: profile.id, p_note: "e2e finalize" }, token);
  return { email, password: PASSWORD, userId, token, candidateProfileId: profile.id };
}
```

```typescript
// employer.ts — entitlements resolved live via RPC, not a seed table
const entRows = await rpc<Array<{ feature_code: string; limit_value: number | null }>>(
  "core_resolve_plan_entitlements", { p_plan_id: plan.id }, SUPABASE_SERVICE_KEY);
const quotaLimit = entRows.find((r) => r.feature_code === "contact_reveals")?.limit_value ?? null;

export async function createEmployerWithReveal(
  runId: string,
  region: string,
  candidateProfileId: string,
  opts?: { usedQuota?: number; exhaustQuota?: boolean; candidateRegion?: string },
): Promise<{
  email: string; password: string; userId: string; token: string;
  employerProfileId: string; subscriptionId: string; shortlistId: string; periodStart: string;
  quotaLimit: number | null; usedQuota: number;
}> { /* verified profile + owner + subscription + shortlist + step-up grants */ }
```

```typescript
// staff.ts
export async function createStaff(runId: string, region: string): Promise<{ email: string; password: string; userId: string; token: string }> {
  const email = scopedEmail(`staff-${region.toLowerCase()}`, runId);
  const userId = await createAuthUser(email, PASSWORD, { region });
  await ensureStaffPermission();
  await grantUserRole(userId, "operator", region);
  const { token } = await signIn(email, PASSWORD);
  return { email, password: PASSWORD, userId, token };
}
```

### UI-login act using real testids

The act half of the split logs in through the actual login form — never through a stashed session or a `signIn()` shortcut inside the test body — so the assertion exercises the same code path a real user hits:

```typescript
const staff = await createStaff(runId, "EU"); // arrange: service_role

await adminPage.goto("/expat/login");
await adminPage.getByTestId("login-email").fill(staff.email);
await adminPage.getByTestId("login-password").fill(PASSWORD);
await adminPage.getByTestId("login-submit").click();
await expect(adminPage).toHaveURL(/\/expat$/, { timeout: 15_000 }); // act: real UI + RLS
```

## Why This Works

- **Every act runs against real RLS**, because the JWT used for `restInsert`/`restSelect`/`rpc` calls and for UI logins is the actor's own token from `signUp`/`signIn`/`createAuthUser`+`signIn` — never the service_role key. A broken or missing policy fails the test instead of silently passing.
- **`runId` namespacing removes teardown as a source of flake.** Every row a scenario creates carries `-<runId>@e2e.local` or an equivalent tag, so parallel or sequential runs never collide and there is nothing to reset between runs — isolation is structural, not procedural.
- **No `@supabase/supabase-js` import inside the Playwright process.** The plain-`fetch` factory against `/auth/v1` and `/rest/v1` sidesteps the module-transform issues supabase-js triggers under Playwright's Node/ESM test runner, so the harness has one less moving part to debug when the suite won't even boot.
- **Entitlements are resolved live via `core_resolve_plan_entitlements`, not a cached seed table**, so a plan-limits change in the database is reflected automatically instead of silently drifting from a stale fixture.

## Edge Cases & Pitfalls

### Common Mistakes

- **Letting `SUPABASE_SERVICE_KEY` reach the browser bundle**: it must stay a CI-secret / Node-only env var used exclusively inside the factory's `adminHeaders()`/`createAuthUser` calls. If it's ever read by client-side code or baked into a `VITE_`/`NEXT_PUBLIC_`-prefixed variable, it ships service_role (full RLS bypass) to end users.
- **Running with more than one worker against a shared local/CI Supabase instance**: `runId` isolates row-level data, but it does not prevent decision races on shared aggregate state (e.g., two workers processing the same admin queue). Set `workers: 1` (and `fullyParallel: false`) when scenarios share a live DB, not because the test data collides but because cross-scenario timing can.
- **Seeding entitlements/quota limits into a static lookup table**: read them live via the `core_resolve_plan_entitlements` RPC (service_role bearer) instead — a hardcoded fixture value silently diverges the day someone edits a plan in the database.
- **Reaching for `storageState`-per-role as the default speed-up**: it is a legitimate *future* optimization for slow suites, but it is deliberately NOT the default here. The Arrange/Act model's entire point is that the act logs in through the real UI/login-form/JWT-issuance path — replacing that with a pre-baked storage state means the login flow itself is never exercised, and any regression in it (broken redirect, session-restore race, cookie flag change) goes undetected. Only introduce it, scoped narrowly, once suite runtime is a proven bottleneck and login itself is covered elsewhere.
- **Using an RPC as a stand-in for a UI action under test**: seeding a subscription with `adminInsert` is arrange; calling a "reveal" or "approve" RPC directly with the service_role key instead of clicking through the real credential-review screen turns the act into another arrange step, and the RLS policy protecting that action is never verified.

## Verification

Run the suite against a fresh, ephemeral local Supabase stack — this is also how CI runs it (mirroring the ephemeral-Supabase-in-CI section of the harness):

```bash
# 1. Boot a fresh local Supabase stack
supabase start

# 2. Apply migrations + canonical seed
supabase db reset

# 3. Seed the E2E fixture (role users, RBAC, base rows)
./scripts/seed-e2e.sh

# 4. Run the Playwright suite (per-surface or full regression tier)
pnpm --filter @tp/e2e test:e2e:regression

# 5. Tear the stack down
supabase stop
```

- [ ] No test performs its act (the behavior under assertion) with the `service_role` key — grep the spec files for `SUPABASE_SERVICE_KEY` outside `factory/*.ts` arrange helpers.
- [ ] Every scenario's data is tagged with `runId` (via `scopedEmail` or an equivalent field) — no test relies on a fixed/shared email or row.
- [ ] `SUPABASE_SERVICE_KEY` does not appear in any client-bundled env var (`VITE_*`, `NEXT_PUBLIC_*`) — CI-secret / server-only only.
- [ ] No spec imports `@supabase/supabase-js` directly; all Supabase calls go through the plain-fetch factory.
- [ ] Entitlement/quota assertions read live values from `core_resolve_plan_entitlements` (or the app's equivalent RPC), not a hardcoded constant.

## References

- `docs/superpowers/references/2026-07-14-talent-portal-e2e-patterns.md` — the harvested reference this skill is distilled from (sections 1, 2, 3, 4, 8).
- Real source: `talent-portal/src/e2e/factory/supabase.ts` (plain-fetch factory), `talent-portal/src/e2e/README.md` (Arrange/Act + isolation principle).
