# Backend & Data-Layer Security Adversarial Rubric

## Purpose

Used by the always-on Adversarial Backend & Data Security Reviewer in `skills/orchestration/adversarial-code-review.md`. Extends the generic adversarial rubric with Postgres/Supabase/SQL/service-layer security failure modes.

## Reviewer mode

**Adversarial.** Same discipline as the generic rubric: fresh `Task()` instance, sees only WU spec + DoD + file scope + diff. Binary PASS/FAIL.

## Evaluation criteria

### BD. Backend & data-layer security failures

A WU FAILS backend & data-layer security review if any of:

- BD1. A table that holds user or tenant data (profiles, messages, documents, billing, audit logs) is introduced or modified without `ALTER TABLE … ENABLE ROW LEVEL SECURITY` AND `ALTER TABLE … FORCE ROW LEVEL SECURITY` present in the migration. RLS disabled by default is not acceptable even under an owner connection assumption.
- BD2. An RLS policy is created but does not cover all four operations (SELECT, INSERT, UPDATE, DELETE) for every role that has a grant on the table. A policy set that covers only SELECT leaves INSERT/UPDATE/DELETE unguarded; reviewer must enumerate the missing verbs.
- BD3. An RLS policy uses a `NOT EXISTS (SELECT 1 FROM other_table WHERE …)` or any correlated subquery against a second RLS-protected table without going through a `SECURITY DEFINER` helper function. The subquery runs in the caller's RLS context, making the restriction a silent dead no-op when the caller cannot read `other_table`. The fix is a `SECURITY DEFINER` wrapper with its own explicit auth check (see BD4).
- BD4. A `SECURITY DEFINER` function is introduced without both: (a) `SET search_path = pg_catalog, public` (or a fully-qualified schema) pinned in the function definition, and (b) an explicit `auth.uid()` / `auth.role()` / ownership check inside the function body before any privileged operation. Missing either → FAIL.
- BD5. A function or view uses `SECURITY DEFINER` where `SECURITY INVOKER` is the correct trust-boundary choice (i.e., the caller already has the needed grants, and DEFINER is used only for convenience). Conversely, `SECURITY INVOKER` used where the function must cross a privilege boundary and relies on the caller having superuser rights. Wrong DEFINER/INVOKER choice relative to the WU's stated trust model → FAIL.
- BD6. Dynamic SQL is constructed by string concatenation or interpolation (`'SELECT … ' || user_input`, `format('… %s …', val)`) rather than parameterized queries or `format` with the `%I`/`%L` identifiers. Any raw `%s` / `||` with an externally-supplied value is a SQL-injection vector → FAIL.
- BD7. A query, RPC, or policy relies on a scope identifier (tenant_id, org_id, user_id, project_id) supplied by the client request body, JWT custom claim used without signature verification, or a URL/header parameter — without re-deriving the scope server-side from `auth.uid()` or a verified session. Client-supplied scope trusted without server-side re-validation → FAIL.
- BD8. A migration is not safely reversible: it lacks a `down` migration (or equivalent rollback path) for a destructive change (DROP COLUMN, DROP TABLE, column type narrowing); or a CHECK constraint expansion does not include the full union of all previously allowed values (orphaning existing rows on the next DB validation pass); or `supabase db reset` is used in the migration itself rather than a forward-only idempotent migration file.
- BD9. A `GRANT` statement gives `anon`, `public`, or `authenticated` more than least-privilege access: SELECT on columns that include secrets or internal flags, or INSERT/UPDATE/DELETE on a table where the role's only legitimate path is through a SECURITY DEFINER RPC. Over-broad grants bypass RLS when combined with ownership quirks → FAIL.

## Verdict format

JSON per the schema. Use rule IDs BD1-BD9. The reviewer's `reviewer` field is `"backend-data-security"`.
