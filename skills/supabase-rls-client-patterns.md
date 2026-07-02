---
id: supabase-rls-client-patterns
category: skill
impact: CRITICAL
impactDescription: "Prevents full-database exposure through the public anon key — the single most severe failure mode of an RLS-only, service_role-free client"
tags: [supabase, rls, postgres, security, anon-key, admin-panel, web]
capabilities:
  - Designing RLS policies as the sole authorization boundary for an anon-key-only client
  - Structuring SELECT/INSERT/UPDATE/DELETE policies as separate, minimal grants
  - Testing RLS policies against roles other than the table owner
  - Using security_invoker views to avoid accidental RLS bypass
  - Recognizing where this admin-panel security model diverges from mobile's Supabase usage
useWhen:
  - Standing up a new Supabase table that the admin panel's browser client reads or writes
  - Reviewing whether a permission requirement is enforced in the database or only in the UI
  - A query returns rows an operator shouldn't be able to see, or rejects one they should
  - Adding a Postgres view for the admin panel to simplify a client-side query
  - Explaining to a reviewer why there is no service_role key anywhere in this codebase
---

# RLS as the Only Authorization Boundary in an Anon-Key-Only Client

This admin panel ships exclusively with the Supabase **anon key** — there is no server-side proxy, no edge function acting as a trusted intermediary for ordinary CRUD, and the `service_role` key must never exist in any file that Vite bundles into the browser. That single fact means Postgres Row Level Security is not "defense in depth" here — it is the *entire* authorization system. This skill covers how to design, structure, and test RLS policies under that constraint, and how it differs from how mobile apps in this framework typically use Supabase.

## Problem

The anon key is, by design, public. It is meant to be embedded in client code and is visible to anyone who opens browser devtools, inspects the network tab, or reads the deployed JS bundle. Two mistakes repeatedly show up when teams don't internalize this:

```ts
// BAD: service_role key referenced from client code because "it was easier"
// during a one-off migration script, then never removed. Any VITE_-prefixed
// env var is inlined into the bundle Vite ships to the browser — this key
// is now downloadable by anyone who visits the admin panel's URL.
const adminClient = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_SERVICE_ROLE_KEY // NEVER do this client-side
)
```

```sql
-- BAD: a permissive policy that technically satisfies "add RLS to this table"
-- (required before RLS enforcement even activates) but grants everyone access,
-- which is functionally equivalent to having no RLS at all
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "allow all"
ON public.invoices
USING (true)
WITH CHECK (true);
```

```sql
-- BAD: a policy defined only for SELECT, with the (incorrect) assumption
-- that it also covers writes. RLS command scopes are independent — INSERT,
-- UPDATE, and DELETE each need their own policy or they default to denied
-- (safe) OR, if a broader FOR ALL policy exists elsewhere, unexpectedly permitted.
CREATE POLICY "operators can view their team's invoices"
ON public.invoices FOR SELECT
USING (team_id = (SELECT team_id FROM public.profiles WHERE id = auth.uid()));
-- No INSERT/UPDATE/DELETE policy exists — is that intentional (read-only for
-- everyone) or an oversight? This must be an explicit decision, not a gap.
```

## Solution

### Enable RLS and grant exactly what each role needs, per command

```sql
-- 1. RLS is off by default on new tables — enabling it switches from
--    "no restrictions" to "deny by default, allow only what policies grant."
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;

-- 2. SELECT: operators see only their own team's invoices.
CREATE POLICY "select own team invoices"
ON public.invoices FOR SELECT
TO authenticated
USING (
  team_id = (SELECT team_id FROM public.profiles WHERE id = auth.uid())
);

-- 3. INSERT: operators can create invoices only for their own team, and the
--    WITH CHECK clause validates the ROW BEING WRITTEN, not the existing row.
CREATE POLICY "insert invoices for own team"
ON public.invoices FOR INSERT
TO authenticated
WITH CHECK (
  team_id = (SELECT team_id FROM public.profiles WHERE id = auth.uid())
);

-- 4. UPDATE: only admins can update, and only invoices that are still
--    'draft' — USING gates which existing rows are targetable, WITH CHECK
--    gates what the row is allowed to become.
CREATE POLICY "admins can update draft invoices"
ON public.invoices FOR UPDATE
TO authenticated
USING (
  status = 'draft'
  AND (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
)
WITH CHECK (
  status IN ('draft', 'sent') -- allow the update to transition status forward
);

-- 5. DELETE: nobody deletes invoices from the client at all — no DELETE
--    policy is created, so DELETE is denied for every role. This is a
--    deliberate, documented decision (use a 'voided' status instead).
```

### Testing policies as the role the client actually uses

```sql
-- Run inside the Supabase SQL editor (or psql) to simulate what an
-- authenticated operator's browser session can actually do — testing as
-- the table owner (the default connection) bypasses RLS entirely and
-- proves nothing about what the anon-key client can do.
BEGIN;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT * FROM public.invoices; -- should return only rows for that user's team

SET LOCAL request.jwt.claims = '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
SELECT * FROM public.invoices; -- should return a DIFFERENT set of rows

ROLLBACK;
```

### `security_invoker` views to avoid accidental RLS bypass

```sql
-- BAD: a Postgres view is, by default, evaluated with the PRIVILEGES OF
-- ITS OWNER (usually a superuser/table owner role) rather than the calling
-- role — this silently bypasses RLS on the underlying table, exposing
-- every team's invoices through a view that "looks" read-only and safe.
CREATE VIEW public.invoice_summary AS
SELECT id, team_id, total, status FROM public.invoices;

-- GOOD: security_invoker (Postgres 15+ / Supabase supports it) makes the
-- view evaluate RLS as the CALLING role, not the view's owner, so a view
-- built on invoices is just as restricted as querying invoices directly.
CREATE VIEW public.invoice_summary
WITH (security_invoker = true) AS
SELECT id, team_id, total, status FROM public.invoices;
```

### Querying from the client — no client-side re-filtering needed

```ts
// src/features/invoices/api.ts
// The client does NOT add .eq('team_id', currentTeamId) — RLS already
// scopes this to the caller's team. Adding a redundant client-side filter
// doesn't add security (the policy already enforces it) and risks the
// filter drifting out of sync with what the policy actually allows.
export async function fetchInvoices() {
  const { data, error } = await supabase
    .from('invoice_summary')
    .select('*')
    .order('created_at', { ascending: false })
  if (error) throw error
  return data
}
```

## Why This Works

- **RLS evaluates per-row on every query, at the database engine level**: it cannot be bypassed by a crafted request, a modified client bundle, or a direct `curl` call to the PostgREST endpoint with the anon key, because the restriction lives inside Postgres itself, not in any code the client controls.
- **Separate policies per command (`FOR SELECT` / `FOR INSERT` / `FOR UPDATE` / `FOR DELETE`) make each grant explicit and independently auditable**: a reviewer can check "can operators delete invoices?" by searching for a `FOR DELETE` policy and finding none, instead of reasoning through a single combined policy's boolean logic to infer what it does *not* cover.
- **`USING` vs `WITH CHECK` encode two different questions**: `USING` controls which existing rows a command can even target/see; `WITH CHECK` controls what the resulting row is allowed to look like after a write. Confusing them is how "operators can update draft invoices" accidentally becomes "operators can update any invoice as long as it started as a draft, into any state."
- **`security_invoker = true` closes the classic view-based RLS bypass**: Postgres views default to invoker-of-owner semantics for backward compatibility, which is precisely wrong for a security boundary — this setting flips the default to the safe behavior for RLS-protected tables.

## Edge Cases & Pitfalls

### Common Mistakes

- **`USING (true)` as a placeholder "I'll fix this later"**: this is functionally no RLS at all, and "later" reliably never happens before the panel ships. Never merge a permissive policy, even temporarily, on any table reachable from the client bundle.
- **Enabling RLS but adding zero policies**: RLS enabled with no matching policy denies all access for that command by default — the safe failure mode, but it's easy to mistake "the query returns nothing" for a bug rather than a missing policy, and equally easy to "fix" it by reaching for `USING (true)` instead of the correct narrow policy.
- **Forgetting that `auth.uid()` is `NULL` for the anon (unauthenticated) role**: any policy comparing `team_id = (SELECT team_id FROM profiles WHERE id = auth.uid())` correctly returns no rows for unauthenticated requests, but only if there is no separate, broader policy also matching the `anon` role — double check policies are scoped `TO authenticated`, not left open to `public`.
- **Subqueries inside `USING`/`WITH CHECK` that reference tables without their own RLS**: if `profiles` itself has no RLS, that's usually fine since it's only being read as a subquery to establish the caller's own team, not to leak other users' rows through it — but confirm the subquery's own SELECT policy doesn't accidentally restrict the caller from reading their own profile row, which would break every policy that depends on it.
- **Assuming client-side role checks add any real restriction beyond hiding UI**: this is the recurring anti-pattern across this whole framework's web-stack guidance — the client-side check is a UX nicety, and the RLS policy is the only thing standing between "operator with an anon key" and "every row in the table."
- **Testing policies only as the table owner / service role during development**: connecting through the Supabase dashboard's SQL editor by default runs as a privileged role that bypasses RLS entirely; always test with `SET LOCAL ROLE authenticated` plus a simulated JWT claim (see Solution above), or by hitting the actual PostgREST endpoint with a real anon-key session token.

### How This Differs From Mobile's Supabase Usage

Mobile apps in this framework (see `skills/supabase-auth.md` and `skills/supabase-database.md`) also use the anon key plus RLS as their primary model, so the core discipline is the same. The meaningful difference here is architectural, not conceptual: a mobile app can route sensitive writes or admin-only actions through Supabase Edge Functions invoked with the user's JWT, keeping a `service_role`-equivalent operation server-side while the app itself stays anon-key-only. This admin panel is defined as a **pure static SPA with no server of its own** — there is no edge function layer assumed by default in its baseline architecture, so any operation that would otherwise need elevated privilege must either be expressible as an RLS policy or explicitly escalated to a backend service (see `agents/admin-panel-architect.md` Escalation Paths) rather than quietly reached for a service-role key.

## Verification

```sql
-- List every policy on a table and its command scope — use this as a
-- checklist: does SELECT/INSERT/UPDATE/DELETE each have an explicit,
-- deliberate policy (or an explicit decision to have none)?
-- `qual`/`with_check` are readable columns on the pg_policies VIEW, not on
-- the pg_policy catalog table (there they're polqual/polwithcheck, and
-- polrelid needs a join to resolve) — query the view.
SELECT policyname, cmd, roles, qual, with_check
FROM pg_policies
WHERE tablename = 'invoices';
```

- [ ] Grep the entire repo (including `.env*` files and CI config) for `service_role` — it should appear nowhere in code the browser bundle can reach.
- [ ] Confirm `rowsecurity` is `true` for every table exposed via the client (`SELECT relname, relrowsecurity FROM pg_class WHERE relnamespace = 'public'::regnamespace;`).
- [ ] For each table, confirm there is a deliberate policy (or deliberate absence of one) for SELECT, INSERT, UPDATE, and DELETE individually.
- [ ] Run the `SET LOCAL ROLE authenticated` test as two different simulated users and confirm they see different, correctly-scoped result sets.
- [ ] Confirm every view built on an RLS-protected table has `security_invoker = true`.
- [ ] Attempt the same request that a hidden/disabled UI button would trigger via a raw `fetch()` call with the anon key — confirm Postgres, not the UI, is what rejects it.

## References

- [Supabase - Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Supabase - RLS Performance and Testing](https://supabase.com/docs/guides/database/postgres/row-level-security#testing-policies)
- [PostgreSQL - CREATE POLICY](https://www.postgresql.org/docs/current/sql-createpolicy.html)
- [PostgreSQL - CREATE VIEW (security_invoker)](https://www.postgresql.org/docs/current/sql-createview.html)
- [Supabase - API Keys (anon vs service_role)](https://supabase.com/docs/guides/api/api-keys)
