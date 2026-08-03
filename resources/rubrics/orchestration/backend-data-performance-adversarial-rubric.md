# Backend & Data-Layer Performance Adversarial Rubric

## Purpose

Used by the conditional Adversarial Backend & Data Performance Reviewer in `skills/orchestration/adversarial-code-review.md`. Fires when a WU `fileScope` intersects backend/data-layer code — Postgres migrations, SQL, RPC/PL-pgSQL functions, triggers, views, RLS policies, or Supabase/service-layer query code. Extends the generic adversarial rubric with Postgres/Supabase/SQL performance failure modes. The framework's existing performance rubrics (`web-performance`, mobile perf) cover client/render-path cost only; this rubric closes the gap for query-plan, index, and round-trip cost at the data layer.

## Reviewer mode

**Adversarial.** Same discipline as the generic rubric: fresh `Task()` instance, sees only WU spec + DoD + file scope + diff. Binary PASS/FAIL. The reviewer hunts for the failure conditions below rather than confirming the happy path; absence of evidence for a claimed hot-path performance property is itself a finding (see DP8).

## Evaluation criteria

### DP. Backend & data-layer performance failures

A WU FAILS backend & data-layer performance review if any of:

- DP1. N+1 / per-row query amplification: an RPC, PL-pgSQL function, trigger, or service-layer loop issues one query per row (a `SELECT`/`UPDATE` inside a `FOR … LOOP`, a per-element round-trip, or a row-level trigger firing a query per affected row) where a single set-based statement (`INSERT … SELECT`, `UPDATE … FROM`, `JOIN`, `unnest`, CTE) would do the same work in one pass. Any per-row query where a set-based rewrite is available → FAIL.
- DP2. Missing index on a filtered column: a new hot query relies on a column in a `WHERE`, `JOIN … ON`, `ORDER BY`, or foreign-key filter that has no supporting index created in the same WU (or verified pre-existing). Foreign-key columns are unindexed by default in Postgres; a new FK join or `ON DELETE` cascade path without a covering index → FAIL.
- DP3. Sequential scan on a large/growing table: a new or modified hot query is documented or `EXPLAIN`-shown to trigger a `Seq Scan` on a table that is large or unbounded-growth (events, logs, messages, line items) where a B-tree, partial, or composite index would convert it to an index scan. Reliance on full-table scans for selective predicates → FAIL. (A `Seq Scan` on a provably small/bounded lookup table is acceptable and NOT a finding.)
- DP4. Unbounded result set: a list query or RPC that returns rows from a growing table without a `LIMIT` and a keyset/cursor pagination contract (`WHERE (sort_key, id) > (:last_sort, :last_id) ORDER BY sort_key, id LIMIT :n`). Offset pagination (`OFFSET n LIMIT m`) on a large table is itself a FAIL for deep pages — cost grows linearly with offset. No bound + no keyset cursor → FAIL.
- DP5. `SELECT *` / over-fetch on a hot path: a hot query selects all columns (`SELECT *` or an ORM/PostgREST call with no column projection) when the caller uses a small subset, pulling wide/large columns (JSONB blobs, `text` bodies, `bytea`, embeddings) that inflate I/O, buffer cache pressure, and network payload. Over-fetch of unused (especially large) columns on a hot path → FAIL.
- DP6. Function volatility mislabel: a SQL/PL-pgSQL function used inside queries is left at the default `VOLATILE` (or explicitly mislabeled) where `STABLE` or `IMMUTABLE` is semantically correct. VOLATILE defeats function inlining, per-statement caching, and use in index expressions, forcing re-evaluation per row. A deterministic/read-only function marked VOLATILE (or a truly side-effecting one marked IMMUTABLE) → FAIL.
- DP7. Expensive per-row RLS predicate: an RLS `USING`/`WITH CHECK` clause contains a correlated subquery or non-`STABLE` function call that Postgres must evaluate once per candidate row (e.g. `(SELECT role FROM members WHERE user_id = auth.uid() AND org_id = t.org_id)` inline in the policy). The fix is an indexed expression, wrapping `auth.uid()` in a scalar subquery so it is evaluated once (`(select auth.uid())`), or a `STABLE SECURITY DEFINER` helper with its own auth check. A per-row correlated RLS predicate on a hot table → FAIL.
- DP8. No `EXPLAIN (ANALYZE, BUFFERS)` evidence: the WU introduces a new hot query/RPC and its spec or DoD claims it is performant (or the query is on a documented hot path) but no `EXPLAIN (ANALYZE, BUFFERS)` output is provided showing the plan, row estimates vs actuals, and buffer reads. Unsubstantiated performance claim for a new hot query → FAIL. Absence of the evidence is the finding.
- DP9. `count(*)` over a large table on a hot path: an exact `SELECT count(*)` (or `count(*)` for a "total results" badge / pagination total) against a large or growing table on a hot path, where an estimate (`reltuples` from `pg_class`, a maintained counter, or an approximate `count` accepting bounded staleness) is the appropriate tool. Exact full-table `count(*)` on a hot path without justification → FAIL.
- DP10. JSONB/array column searched without a GIN/expression index: a query filters, containment-tests (`@>`, `?`, `?|`, `?&`), or full-text-searches a `jsonb`, `array`, or `tsvector` column with no `GIN` (or targeted expression/`GIN (col jsonb_path_ops)`) index backing the predicate, forcing a scan-and-recheck over every row. Containment/array/FTS search without a matching GIN or expression index → FAIL.
- DP11. Chatty round-trips that should be one round-trip: service-layer code issues multiple sequential DB round-trips (a read-then-write, a fan-out of point lookups, or a loop of independent statements) that could be collapsed into a single statement or one RPC via `IN (…)`/`= ANY(:ids)`, a `JOIN`, a batched `INSERT … VALUES`, or a single set-based RPC. Each avoidable round-trip adds a full network + planning latency; chatty independent round-trips where one statement/RPC suffices → FAIL.

## Verdict format

JSON per the schema. Use rule IDs DP1-DP11. The reviewer's `reviewer` field is `"backend-data-performance"`.
