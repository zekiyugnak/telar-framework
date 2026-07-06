---
name: "rust-sqlx-patterns"
description: "sqlx's core value is catching SQL/schema mismatches at `cargo build` time instead of at runtime, but three things routinely go wrong around it: the connection pool gets misconfigured (either too small under load or accid"
source_type: "skill"
source_file: "skills/rust-sqlx-patterns.md"
---

# rust-sqlx-patterns

Migrated from `skills/rust-sqlx-patterns.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Use sqlx's Compile-Time Query Checking Without Getting Burned by the Pool or Multi-Tenancy

sqlx's core value is catching SQL/schema mismatches at `cargo build` time instead of at runtime, but three things routinely go wrong around it: the connection pool gets misconfigured (either too small under load or accidentally recreated per request), routine list-then-lookup code turns into N+1 query storms, and — for backends serving many tenants — the fact that the Rust service usually connects with a single elevated-privilege role gets treated as "we don't need to think about tenant scoping," which is not true for backend code any more than it is for a browser client.

## Problem

```rust
// BAD: runtime-only query construction, no compile-time verification, brittle to column changes
async fn get_order(pool: &PgPool, id: Uuid) -> Result<Order, sqlx::Error> {
    sqlx::query_as::<_, Order>("SELECT * FROM orders WHERE id = $1") // typos and renamed columns fail at runtime only
        .bind(id)
        .fetch_one(pool)
        .await
}

// BAD: N+1 — one query per order to fetch its line items
async fn list_orders_with_items(pool: &PgPool, user_id: Uuid) -> Result<Vec<OrderWithItems>, sqlx::Error> {
    let orders = sqlx::query_as!(Order, "SELECT * FROM orders WHERE user_id = $1", user_id)
        .fetch_all(pool)
        .await?;

    let mut result = Vec::new();
    for order in orders {
        // Runs once per order — 50 orders means 51 round trips to Postgres
        let items = sqlx::query_as!(LineItem, "SELECT * FROM line_items WHERE order_id = $1", order.id)
            .fetch_all(pool)
            .await?;
        result.push(OrderWithItems { order, items });
    }
    Ok(result)
}

// BAD: service connects with a superuser-equivalent role and trusts every caller-supplied
// user_id without an explicit WHERE clause tying it back to the authenticated tenant
async fn get_invoice(pool: &PgPool, invoice_id: Uuid) -> Result<Invoice, sqlx::Error> {
    sqlx::query_as!(Invoice, "SELECT * FROM invoices WHERE id = $1", invoice_id) // no tenant_id check!
        .fetch_one(pool)
        .await
}
```

## Solution

### Compile-time checked queries with `query_as!`

```rust
// GOOD: verified against the live DB (or committed .sqlx cache) at compile time.
// `query_as!` maps columns to fields itself and does NOT require `FromRow` — only
// derive it if this struct is also used with the runtime `sqlx::query_as::<_, T>(...)`
// form shown below.
#[derive(sqlx::FromRow)]
pub struct Order {
    pub id: Uuid,
    pub user_id: Uuid,
    pub total_cents: i64,
    pub status: String,
}

pub async fn get_order(pool: &PgPool, id: Uuid) -> sqlx::Result<Option<Order>> {
    sqlx::query_as!(
        Order,
        r#"SELECT id, user_id, total_cents, status FROM orders WHERE id = $1"#,
        id
    )
    .fetch_optional(pool) // fetch_optional, not fetch_one, for "may not exist" lookups
    .await
}
```

Prefer `query_as!` (compile-time) over the runtime `sqlx::query_as::<_, T>("...")` form by default. Reach for the runtime form only when the query is genuinely dynamic — built up conditionally from user-selected filters — where a fixed macro string can't express it; in that case, build the dynamic parts carefully (see the crate [sqlx::QueryBuilder](https://docs.rs/sqlx/latest/sqlx/struct.QueryBuilder.html)) and never via raw string interpolation of user input.

### Connection pool: build once, size deliberately

```rust
// GOOD: one pool at startup, sized from expected concurrent DB-bound work, not RPS
use sqlx::postgres::PgPoolOptions;
use std::time::Duration;

pub async fn build_pool(database_url: &str) -> sqlx::Result<PgPool> {
    PgPoolOptions::new()
        .max_connections(20)            // start here; tune from pool-wait metrics under load testing
        .min_connections(2)              // keep a few warm to avoid cold-connect latency after idle periods
        .acquire_timeout(Duration::from_secs(3)) // fail fast instead of queuing requests indefinitely
        .idle_timeout(Duration::from_secs(300))
        .connect(database_url)
        .await
}
```

`max_connections` should stay well under Postgres's own `max_connections` divided by the number of service instances you run — a pool sized without regard to instance count is a common cause of "works in staging, exhausts connections in production with 5 replicas."

### Migrations

```bash
# Create a new migration file (creates migrations/<timestamp>_add_orders_status_index.sql)
sqlx migrate add add_orders_status_index

# Apply pending migrations against DATABASE_URL
sqlx migrate run

# Revert the most recent migration (requires a paired .down.sql if using reversible migrations)
sqlx migrate revert
```

```sql
-- migrations/20260115120000_add_orders_status_index.sql
-- GOOD: migrations are plain SQL, reviewed like any other code change, applied explicitly
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_status ON orders (status)
WHERE status != 'completed'; -- partial index, since most queries filter to active orders
```

`sqlx migrate run` wraps each migration file in a transaction by default, and Postgres refuses to run `CREATE INDEX CONCURRENTLY` inside a transaction block — this specific migration will error if applied through the normal `sqlx::migrate!()` flow. Check whether your pinned sqlx version supports opting a single migration out of transactional wrapping; if not, apply concurrent-index migrations manually (`psql -f migrations/...sql`) outside the migrator, tracked separately, rather than assuming `sqlx migrate run` handles it.

Run `sqlx::migrate!().run(&pool).await?` at service startup for automated environments, but gate it behind a flag or a separate deploy step in production so migrations are applied deliberately, not implicitly on every restart of every replica racing each other.

### Transactions

```rust
// GOOD: explicit transaction, rolled back automatically if any step returns Err before commit
pub async fn create_order_with_items(
    pool: &PgPool,
    user_id: Uuid,
    items: Vec<NewLineItem>,
) -> sqlx::Result<Order> {
    let mut tx = pool.begin().await?;

    let order = sqlx::query_as!(
        Order,
        r#"INSERT INTO orders (user_id, status) VALUES ($1, 'pending')
           RETURNING id, user_id, total_cents, status"#,
        user_id
    )
    .fetch_one(&mut *tx)
    .await?;

    for item in &items {
        sqlx::query!(
            r#"INSERT INTO line_items (order_id, sku, quantity) VALUES ($1, $2, $3)"#,
            order.id,
            item.sku,
            item.quantity
        )
        .execute(&mut *tx)
        .await?; // any error here leaves tx un-committed; it rolls back on drop
    }

    tx.commit().await?; // only now are the inserts visible to other connections
    Ok(order)
}
```

### Avoiding N+1: fetch in one round trip

```rust
// GOOD: one query for orders, one batched query for all their line items, joined in memory
pub async fn list_orders_with_items(pool: &PgPool, user_id: Uuid) -> sqlx::Result<Vec<OrderWithItems>> {
    let orders = sqlx::query_as!(Order, "SELECT id, user_id, total_cents, status FROM orders WHERE user_id = $1", user_id)
        .fetch_all(pool)
        .await?;

    let order_ids: Vec<Uuid> = orders.iter().map(|o| o.id).collect();

    // = ANY($1) with a Vec binds as a single round trip instead of one query per order
    let items = sqlx::query_as!(
        LineItem,
        r#"SELECT id, order_id, sku, quantity FROM line_items WHERE order_id = ANY($1)"#,
        &order_ids
    )
    .fetch_all(pool)
    .await?;

    let mut items_by_order: HashMap<Uuid, Vec<LineItem>> = HashMap::new();
    for item in items {
        items_by_order.entry(item.order_id).or_default().push(item);
    }

    Ok(orders.into_iter().map(|order| {
        let items = items_by_order.remove(&order.id).unwrap_or_default();
        OrderWithItems { order, items }
    }).collect())
}
```

### Offline mode for CI without a live database

```bash
# Generate .sqlx/ metadata from a real database once, locally, and commit it
cargo sqlx prepare --workspace -- --all-targets

# In CI, build without a live Postgres connection at all
SQLX_OFFLINE=true cargo build
SQLX_OFFLINE=true cargo test --no-run
```

Commit the `.sqlx/` directory. CI pipelines that don't provision a throwaway Postgres just for `cargo check`/`cargo build` can build entirely from this cache; only `sqlx::test`-based integration tests (see `rust-testing-pyramid` skill) need a real database at test-*run* time.

### Explicit tenant scoping despite elevated backend privileges

```rust
// GOOD: the Rust service is a trusted backend context (unlike a browser SPA that must rely
// on Postgres RLS because it can't be trusted to filter correctly), so it's tempting to
// skip WHERE-clause scoping — don't. Bugs and copy-pasted queries still happen.
pub async fn get_invoice(pool: &PgPool, invoice_id: Uuid, tenant_id: Uuid) -> sqlx::Result<Option<Invoice>> {
    sqlx::query_as!(
        Invoice,
        r#"SELECT id, tenant_id, total_cents FROM invoices WHERE id = $1 AND tenant_id = $2"#,
        invoice_id,
        tenant_id // always derived from the authenticated caller (AuthUser), never from a request body/query param
    )
    .fetch_optional(pool)
    .await
}
```

## Why This Works

- **`query!`/`query_as!` connect to the database (or read `.sqlx/`) at compile time** and validate column names, types, and nullability against the actual schema, turning a class of production bugs (renamed column, wrong type, typo) into build failures.
- **A single long-lived `PgPool` reuses TCP/TLS-established connections** instead of paying connection setup cost per request, and its `acquire_timeout` turns pool exhaustion into a fast, visible error instead of unbounded request queueing.
- **Migrations as plain, committed SQL files** make schema history auditable and reviewable the same way application code is, and `sqlx migrate run` applying them idempotently means environments can't silently drift.
- **`= ANY($1)` batching collapses N round trips into one**, which matters more than almost any other single optimization in a service talking to a remote Postgres instance, where network latency (not query execution time) usually dominates N+1 cost.
- **Explicit `tenant_id` (or `user_id`) predicates in every multi-tenant query** are the backend-context equivalent of what Postgres Row-Level Security enforces for a browser SPA talking directly to Postgres (see this plugin's `supabase-rls-client-patterns` skill for that browser-trust-boundary case, where RLS is the primary defense because the client itself cannot be trusted, and `supabase-database` for general query patterns). A trusted Rust backend *can* run with elevated, RLS-bypassing privileges and often does for performance and query-flexibility reasons, but "can" is not "should skip scoping" — RLS's real value is defense in depth against exactly the mistake of a forgotten WHERE clause, and a Rust service connecting without RLS enforced has one less layer of defense than a browser client would, so the explicit predicate discipline matters more here, not less.

## Edge Cases & Pitfalls

### Common Mistakes

- **Using `fetch_one` for a query that may return zero rows.** `fetch_one` errors with `RowNotFound` on an empty result, which then has to be pattern-matched back into a "not found" case anyway — use `fetch_optional` and `.ok_or(AppError::NotFound)?` instead.
- **Rebuilding the `.sqlx` cache inconsistently between local dev and CI.** If a developer forgets `cargo sqlx prepare` after changing a query, CI running in `SQLX_OFFLINE=true` mode will build against stale metadata and can pass CI while being broken against the real, current schema. Add a CI check that runs `cargo sqlx prepare --check` to catch drift.
- **Holding a transaction open across an external network call** (e.g. calling a payment API mid-transaction). This holds Postgres locks for the duration of an unbounded external call and is a common cause of lock contention and connection pool starvation under load; do the external call before or after the transaction, not inside it.
- **Sizing `max_connections` per-instance without accounting for replica count.** Five replicas at `max_connections(20)` each can hit 100 total connections against a Postgres instance whose own `max_connections` might be 100 — leaving zero headroom for migrations, admin connections, or a second service.
- **Binding a `Vec<T>` directly for an `IN (...)`-style query without using `= ANY($1)`.** sqlx doesn't expand a bound `Vec` into `IN ($1, $2, $3, ...)`; use the Postgres `= ANY($1)` array-comparison form instead, which sqlx supports directly for `Vec<T>` bindings.
- **Assuming a single elevated-privilege backend role means tenant isolation is "handled."** It isn't — it means isolation is entirely the application code's responsibility, with no database-level backstop. Treat every query that touches multi-tenant tables as needing an explicit, reviewed tenant predicate.

## Verification

```bash
# Confirm queries are verified against the current schema (fails the build on drift)
DATABASE_URL=postgres://... cargo check

# Confirm offline mode works from the committed cache alone (simulates CI without a DB)
SQLX_OFFLINE=true cargo build

# Detect an out-of-date .sqlx cache before it reaches CI
cargo sqlx prepare --check --workspace

# Watch actual connection counts during a load test
psql -c "SELECT count(*) FROM pg_stat_activity WHERE datname = current_database();"
```

- [ ] `cargo sqlx prepare --check` passes on a clean checkout (no drift between code and committed `.sqlx/`).
- [ ] A load test at expected peak concurrency does not exhaust the pool (`acquire_timeout` errors stay at zero) and does not exceed Postgres's `max_connections` across all replicas combined.
- [ ] The "list with related rows" endpoint issues a fixed, small number of queries regardless of how many parent rows are returned (verify via `tracing`/query logs, not just by reading the code).
- [ ] Every query against a multi-tenant table includes an explicit tenant/user predicate sourced from the authenticated caller, not from a client-supplied parameter.

## References

- [sqlx GitHub / docs](https://docs.rs/sqlx/latest/sqlx/)
- [sqlx compile-time verification](https://docs.rs/sqlx/latest/sqlx/macro.query.html)
- [sqlx offline mode](https://docs.rs/sqlx/latest/sqlx/#compile-time-verification)
- [sqlx PgPoolOptions](https://docs.rs/sqlx/latest/sqlx/postgres/struct.PgPoolOptions.html)
- [PostgreSQL Row-Level Security](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
