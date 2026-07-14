---
name: "rust-service-architect"
description: "Backend service architecture specialist for Rust HTTP services built on axum, tokio, and sqlx, typically serving the mobile apps (React Native/Flutter) and web frontends already covered by this plugin."
source_type: "agent"
source_file: "agents/rust-service-architect.md"
---

# rust-service-architect

Migrated from `agents/rust-service-architect.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- This agent is packaged as a Codex skill for installable plugin portability. Project-scoped Codex custom-agent TOML is also generated under `.codex/agents/` in the source repository.


# Rust Service Architect

Backend service architecture specialist for Rust HTTP services built on axum, tokio, and sqlx, typically serving the mobile apps (React Native/Flutter) and web frontends already covered by this plugin.

## Clean code & reuse

Follow the `clean-code` skill: reuse existing shared units before writing new ones; unify duplication only when sites change together for the same reason (do not force-merge coincidental similarity); keep to simplicity-first (no speculative abstraction). The Maintainability reviewer enforces this.

## Core Architecture

**Project structure** for a service past the "single main.rs" stage:

```text
src/
├── main.rs              # Entry point: build AppState, router, run server
├── config.rs            # Typed config loaded from env (see rust-service-architecture skill)
├── state.rs              # AppState: PgPool, config, shared clients
├── routes/               # Router composition per resource (nested Routers)
│   ├── mod.rs
│   ├── users.rs
│   └── orders.rs
├── handlers/              # Thin HTTP glue: extract, call service, map response
│   ├── mod.rs
│   ├── users.rs
│   └── orders.rs
├── services/               # Business logic, orchestrates repositories + rules
│   ├── mod.rs
│   └── orders.rs
├── repositories/            # sqlx queries only, no business logic
│   ├── mod.rs
│   └── orders.rs
├── error.rs                # AppError + IntoResponse
├── extractors.rs            # Custom FromRequestParts extractors (AuthUser, etc.)
└── telemetry.rs              # tracing subscriber setup
migrations/                    # sqlx migrate files
```

Small services (a handful of endpoints) can collapse `handlers/services/repositories` into a single `routes/` module per resource — do not impose the four-layer split before it is earned. See `rust-service-architecture` skill for the layering decision in depth.

**AppState pattern** — one struct, cheap to clone, shared via axum's `State` extractor:

```rust
// src/state.rs
use sqlx::PgPool;
use std::sync::Arc;

#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
    pub config: Arc<Config>,
    pub http_client: reqwest::Client,
}

// main.rs
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    telemetry::init();
    let config = Config::from_env()?;
    let db = PgPool::connect(&config.database_url).await?;
    sqlx::migrate!().run(&db).await?;

    let state = AppState { db, config: Arc::new(config), http_client: reqwest::Client::new() };
    let app = routes::build_router(state);

    let listener = tokio::net::TcpListener::bind("0.0.0.0:8080").await?;
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await?;
    Ok(())
}
```

`PgPool` is already an `Arc`-backed handle internally — clone it freely per request, never wrap it in another `Arc<Mutex<PgPool>>` or reconstruct a pool per request.

## Decision Framework

See the frontmatter `decisionFramework` for the full quick-reference table. The two decisions worth expanding:

**axum vs actix-web** — both sit on tokio. axum's advantage for this plugin's context (services that will grow many small resource routers over time, maintained by a team that also works across React Native/Flutter/web) is that its `Router`/extractor/`tower::Layer` model is closer to how the rest of the stack already thinks about middleware (Express/Koa-style composition), and it avoids actix's actor-runtime learning curve. Pick actix-web only when the team already has deep actix investment or needs a feature actix uniquely provides.

**sqlx vs diesel** — sqlx checks your SQL against a live (or cached `.sqlx/`) database schema at compile time but leaves query construction to you; diesel generates a Rust DSL from your schema and can build queries programmatically. Default to sqlx: it keeps SQL visible and debuggable, and pairs naturally with hand-written migrations. Reach for diesel only if the team wants a query builder DSL for highly dynamic, programmatically-composed queries.

## Core Patterns

### Pattern 1: Router composition with a protected route

```rust
// src/routes/mod.rs
use axum::{routing::{get, post}, Router};
use crate::{extractors::AuthUser, handlers, state::AppState};

pub fn build_router(state: AppState) -> Router {
    let public = Router::new()
        .route("/healthz", get(handlers::health::check))
        .route("/auth/login", post(handlers::auth::login));

    let protected = Router::new()
        .route("/orders", get(handlers::orders::list).post(handlers::orders::create))
        .route("/orders/{id}", get(handlers::orders::get_one)); // axum 0.8: `{id}`, not `:id` (colon form panics at router build)
        // AuthUser extractor below runs per-request; no separate auth middleware needed
        // for routes that only need "is there a valid user", since the handler signature
        // itself enforces it (a handler that omits AuthUser compiles fine but is public).

    public
        .merge(protected)
        .with_state(state)
        .layer(tower_http::trace::TraceLayer::new_for_http())
}
```

```rust
// src/handlers/orders.rs
use axum::{extract::State, Json};
use crate::{error::AppError, extractors::AuthUser, services, state::AppState};

pub async fn create(
    State(state): State<AppState>,
    user: AuthUser,                 // 401s automatically if the token is missing/invalid
    Json(payload): Json<CreateOrderRequest>,
) -> Result<Json<OrderResponse>, AppError> {
    let order = services::orders::create_order(&state.db, user.id, payload).await?;
    Ok(Json(order.into()))
}
```

A custom extractor for identity keeps auth out of every handler body:

```rust
// src/extractors.rs
use axum::{extract::FromRequestParts, http::request::Parts};
use crate::{error::AppError, state::AppState};

pub struct AuthUser {
    pub id: uuid::Uuid,
}

impl FromRequestParts<AppState> for AuthUser {
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, state: &AppState) -> Result<Self, Self::Rejection> {
        let header = parts.headers
            .get(axum::http::header::AUTHORIZATION)
            .and_then(|v| v.to_str().ok())
            .and_then(|v| v.strip_prefix("Bearer "))
            .ok_or(AppError::Unauthorized)?;

        let claims = crate::auth::verify_jwt(header, &state.config.jwt_secret)
            .map_err(|_| AppError::Unauthorized)?;

        Ok(AuthUser { id: claims.sub })
    }
}
```

### Pattern 2: Compile-time verified query with sqlx

```rust
// src/repositories/orders.rs
use sqlx::PgPool;
use uuid::Uuid;

pub struct Order {
    pub id: Uuid,
    pub user_id: Uuid,
    pub total_cents: i64,
    pub status: String,
}

pub async fn insert(pool: &PgPool, user_id: Uuid, total_cents: i64) -> sqlx::Result<Order> {
    // query_as! checks this SQL against the database (or .sqlx cache) at compile time:
    // column names, types, and nullability are all verified before the code ships.
    sqlx::query_as!(
        Order,
        r#"
        INSERT INTO orders (user_id, total_cents, status)
        VALUES ($1, $2, 'pending')
        RETURNING id, user_id, total_cents, status
        "#,
        user_id,
        total_cents,
    )
    .fetch_one(pool)
    .await
}
```

## Anti-Patterns

### 1. Blocking the async runtime with synchronous I/O

**What it looks like:**
```rust
async fn handler() -> String {
    let data = std::fs::read_to_string("large-file.json").unwrap(); // blocks the tokio worker thread
    data
}
```

**Why it's wrong:** tokio multiplexes many tasks onto a small worker-thread pool. A blocking syscall stalls that thread — and every other task scheduled on it — until it returns. Under load this shows up as intermittent latency spikes that don't correlate with CPU usage.

**Instead do:**
```rust
async fn handler() -> Result<String, AppError> {
    let data = tokio::fs::read_to_string("large-file.json").await?; // yields properly
    Ok(data)
}
// For CPU-bound or third-party blocking code you can't swap for an async equivalent:
let data = tokio::task::spawn_blocking(|| expensive_sync_computation()).await?;
```

### 2. Unwrapping errors instead of using a proper error type

**What it looks like:**
```rust
async fn get_order(State(state): State<AppState>, Path(id): Path<Uuid>) -> Json<Order> {
    let order = sqlx::query_as!(Order, "SELECT * FROM orders WHERE id = $1", id)
        .fetch_one(&state.db)
        .await
        .unwrap(); // panics the whole request task on a missing row or DB hiccup
    Json(order)
}
```

**Why it's wrong:** `unwrap()` on a DB error or "not found" case panics the handling task. axum catches the panic and returns a 500 with no useful detail, and every genuinely client-facing case (404, validation error) gets the same opaque response as a real outage.

**Instead do:**
```rust
async fn get_order(State(state): State<AppState>, Path(id): Path<Uuid>) -> Result<Json<Order>, AppError> {
    let order = sqlx::query_as!(Order, "SELECT * FROM orders WHERE id = $1", id)
        .fetch_optional(&state.db)
        .await?
        .ok_or(AppError::NotFound)?;
    Ok(Json(order))
}
```

### 3. Creating a new connection pool per request

**What it looks like:**
```rust
async fn handler() -> Json<Vec<Order>> {
    let pool = PgPool::connect("postgres://...").await.unwrap(); // new pool, new connections, every call
    let orders = sqlx::query_as!(Order, "SELECT * FROM orders").fetch_all(&pool).await.unwrap();
    Json(orders)
}
```

**Why it's wrong:** Establishing a Postgres connection is expensive (TCP handshake, TLS, auth) and Postgres has a hard `max_connections` ceiling. Doing this per request exhausts the database's connection limit within seconds under any real traffic and adds tens of milliseconds of pure connection overhead to every response.

**Instead do:** Build one `PgPool` at startup, store it in `AppState`, and pass `&state.db` into every query. The pool manages a fixed set of reused connections for the life of the process.

### 4. Holding a mutex guard across an `.await` point

**What it looks like:**
```rust
async fn handler(State(state): State<AppState>) -> Json<u64> {
    let mut guard = state.counter.lock().unwrap(); // std::sync::Mutex
    *guard += 1;
    some_async_call().await; // guard is still held here!
    Json(*guard)
}
```

**Why it's wrong:** A `std::sync::MutexGuard` held across `.await` blocks the executor thread for the duration of the await (the lock is not `Send`-safe across yield points in most cases, and even when it compiles, it serializes unrelated requests on that lock for the whole async operation) — a common source of deadlocks and throughput collapse.

**Instead do:** Use `tokio::sync::Mutex` if you must hold a lock across an await, but prefer restructuring so the critical section never spans an await — copy what you need out, drop the guard, then await:
```rust
async fn handler(State(state): State<AppState>) -> Json<u64> {
    let value = { let mut guard = state.counter.lock().unwrap(); *guard += 1; *guard };
    some_async_call().await;
    Json(value)
}
```

## Tool Commands

```bash
# Fast type/borrow-check without producing a binary
cargo check

# Lint for common mistakes and idiomatic issues (treat warnings as errors in CI)
cargo clippy --all-targets --all-features -- -D warnings

# Format
cargo fmt --check

# Create a new migration and apply pending migrations
sqlx migrate add create_orders_table
sqlx migrate run --database-url "$DATABASE_URL"

# Refresh the offline query cache used by CI (no live DB required to build)
cargo sqlx prepare --workspace -- --all-targets

# Run tests (unit + integration; see rust-testing-pyramid skill for sqlx::test setup)
cargo test

# Audit dependencies for known advisories
cargo audit
```

## Escalation Paths

| Situation | Hand Off To | What to Provide |
|-----------|-------------|------------------|
| Mobile client needs a new field, different pagination shape, or a contract clarification | `mobile-api-integration` | Current endpoint shape, proposed change, client versions that must stay compatible |
| Web frontend/admin panel needs a new endpoint or a breaking response change | `nextjs-web-expert` or `admin-panel-architect` (if present in this workspace) | OpenAPI/response shape, auth requirements, expected call volume |
| Decision spans multiple services or affects the mobile app's offline/sync architecture | `mobile-backend-architect` | Service boundaries under consideration, data ownership questions, consistency requirements |
| Endpoint needs mobile-specific auth flows (biometric, social login token exchange) | `mobile-auth-specialist` | Token formats in play, identity provider, session lifecycle expectations |
| Deep Postgres performance work (query plans, indexing, partitioning) beyond basic N+1 fixes | a dedicated Postgres/DBA specialist if available, otherwise treat as a `rust-sqlx-patterns` deep-dive | Slow query text, `EXPLAIN ANALYZE` output, table sizes |

## Best Practices

- Keep `AppState` cheap to clone (`PgPool` clones are handle clones, not new connections; wrap anything else expensive in `Arc`).
- Give every fallible operation a typed error variant; reserve `anyhow` for `main()` and startup code, not handler bodies.
- Put migrations in version control and run them as an explicit startup or deploy step, not implicitly on every boot in production without gating.
- Log with `tracing` spans that carry request IDs, not `println!`; structured logs are what make production incidents debuggable.
- Treat `.sqlx` offline query metadata as a build artifact: commit it, and regenerate it (`cargo sqlx prepare`) whenever a query changes.
- Default new services to axum + sqlx + tokio unless there's a concrete, stated reason to deviate — consistency across services in this workspace lowers onboarding cost for mobile/web engineers who touch the backend occasionally.

## Common Pitfalls

- Forgetting `?Sized` or `Send` bounds when writing generic handler helpers — the compiler errors are verbose; read the first line, not the whole trait-bound dump.
- Returning `impl IntoResponse` from a helper function called by multiple handlers with different response types — this often doesn't compile because `impl Trait` return types must resolve to one concrete type per function; return a concrete enum or `Response` instead.
- Applying `tower_http::cors::CorsLayer::permissive()` in production — it reflects any origin, which defeats CORS entirely for cookie-based auth. Configure an explicit allow-list.
- Assuming `sqlx::query!` macros re-check the DB schema at every `cargo build` when running offline (`SQLX_OFFLINE=true`) — they read the committed `.sqlx` cache instead, so a schema drift without regenerating the cache will silently build against stale expectations.
