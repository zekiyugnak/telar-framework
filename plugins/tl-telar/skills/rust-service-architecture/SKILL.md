---
name: "rust-service-architecture"
description: "A Rust service that starts as \"handlers that call sqlx directly\" works fine for the first five endpoints and becomes unreviewable by the fiftieth: business rules get duplicated across handlers, tests can't run without a "
source_type: "skill"
source_file: "skills/rust-service-architecture.md"
---

# rust-service-architecture

Migrated from `skills/rust-service-architecture.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Layer a Rust Service So It Stays Testable as It Grows

A Rust service that starts as "handlers that call sqlx directly" works fine for the first five endpoints and becomes unreviewable by the fiftieth: business rules get duplicated across handlers, tests can't run without a live database because there's no seam to mock, and config reads (`std::env::var("DATABASE_URL").unwrap()`) are scattered everywhere with no single source of truth. This skill covers the handler/service/repository split, `AppState`-based dependency sharing, typed configuration, structured errors, workspace splitting, and API versioning — the structural decisions that determine whether a service stays maintainable past its first quarter of active development.

## Problem

```rust
// BAD: handler mixes HTTP parsing, business rules, and raw SQL in one function
// Untestable without spinning up axum + a real Postgres; business logic can't be reused
async fn create_order(
    State(state): State<AppState>,
    user: AuthUser,
    Json(payload): Json<CreateOrderRequest>,
) -> Result<Json<OrderResponse>, AppError> {
    if payload.items.is_empty() {
        return Err(AppError::Validation("order must have at least one item".into()));
    }

    let mut total_cents = 0i64;
    for item in &payload.items {
        // Business rule (pricing) buried inside the handler, duplicated wherever pricing is needed
        let product = sqlx::query!("SELECT price_cents FROM products WHERE id = $1", item.product_id)
            .fetch_one(&state.db)
            .await
            .map_err(AppError::Database)?;
        total_cents += product.price_cents * item.quantity as i64;
    }

    let order = sqlx::query_as!(
        Order,
        "INSERT INTO orders (user_id, total_cents) VALUES ($1, $2) RETURNING id, user_id, total_cents, status",
        user.id, total_cents
    )
    .fetch_one(&state.db)
    .await
    .map_err(AppError::Database)?;

    Ok(Json(order.into()))
}

// BAD: config read ad hoc, scattered, panics on missing env var with no context
let port: u16 = std::env::var("PORT").unwrap().parse().unwrap();
```

## Solution

### Handler → service → repository layering

```rust
// GOOD: handlers/orders.rs — thin HTTP glue only: extract, delegate, map response/errors
pub async fn create(
    State(state): State<AppState>,
    user: AuthUser,
    Json(payload): Json<CreateOrderRequest>,
) -> Result<Json<OrderResponse>, AppError> {
    let order = services::orders::create_order(&state.db, user.id, payload.into()).await?;
    Ok(Json(order.into()))
}
```

```rust
// GOOD: services/orders.rs — business rules, orchestrates repositories, no axum types, no raw SQL
pub struct NewOrder {
    pub items: Vec<NewOrderItem>,
}

pub async fn create_order(pool: &PgPool, user_id: Uuid, new_order: NewOrder) -> Result<Order, AppError> {
    if new_order.items.is_empty() {
        return Err(AppError::Validation("order must have at least one item".into()));
    }

    let product_ids: Vec<Uuid> = new_order.items.iter().map(|i| i.product_id).collect();
    let prices = repositories::products::get_prices(pool, &product_ids).await?;

    let total_cents = pricing::calculate_total(&new_order.items, &prices)?; // pure function, unit-testable alone

    repositories::orders::insert(pool, user_id, total_cents).await.map_err(Into::into)
}
```

```rust
// GOOD: repositories/orders.rs — sqlx queries only, no business logic, no HTTP types
pub async fn insert(pool: &PgPool, user_id: Uuid, total_cents: i64) -> sqlx::Result<Order> {
    sqlx::query_as!(
        Order,
        r#"INSERT INTO orders (user_id, total_cents, status) VALUES ($1, $2, 'pending')
           RETURNING id, user_id, total_cents, status"#,
        user_id, total_cents
    )
    .fetch_one(pool)
    .await
}
```

The `pricing::calculate_total` function takes plain data in and plain data out — no `PgPool`, no `AppState` — so it can be unit tested with zero I/O (see `rust-testing-pyramid`). This is the concrete payoff of the split: the layer holding business rules is the layer that's cheapest to test exhaustively.

**When to skip the split:** a service with a handful of CRUD endpoints and no meaningful business rules beyond "validate and store" gains little from three layers and mostly gains ceremony. Collapse service+repository into one module per resource until a function is doing enough (orchestrating multiple tables, applying rules, calling out to another service) that separating "what" from "how" earns its keep.

### Dependency sharing via `AppState` and `Arc<T>`

```rust
// GOOD: state.rs — one struct, cheap to Clone, no manual DI container/framework needed
#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,                    // already cheaply cloneable (internal Arc)
    pub config: Arc<Config>,           // Arc because Config itself isn't cheap/necessary to duplicate
    pub email_client: Arc<dyn EmailSender>, // trait object behind Arc enables swapping impls in tests
}
```

Rust's `AppState` + `Arc<T>` pattern *is* the dependency injection this kind of service needs — there's no need to reach for a DI framework/container. Where testability requires substituting an implementation (e.g. a fake email sender in tests), define a small trait and store `Arc<dyn Trait>` in `AppState`; that's the full extent of DI machinery required.

### Configuration with `config`/`envy` and `.env`

```rust
// GOOD: config.rs — one typed struct, one place that reads the environment, fails loudly and early
use serde::Deserialize;

#[derive(Debug, Deserialize, Clone)]
pub struct Config {
    pub database_url: String,
    pub jwt_secret: String,
    #[serde(default = "default_port")]
    pub port: u16,
    #[serde(default)]
    pub allowed_origins: Vec<String>,
}

fn default_port() -> u16 { 8080 }

impl Config {
    pub fn from_env() -> anyhow::Result<Self> {
        dotenvy::dotenv().ok(); // loads .env in local dev; no-op (and harmless) if the file is absent, e.g. in prod
        envy::prefixed("APP_").from_env::<Config>()
            .map_err(|e| anyhow::anyhow!("failed to load config: {e}"))
    }
}

// main.rs
let config = Config::from_env()?; // fails fast at startup with a clear error, not deep inside a handler
```

Load configuration exactly once, at startup, into one typed struct passed around via `AppState`. Never scatter `std::env::var(...)` calls through handler or service code — every additional call site is another place a missing variable becomes a runtime panic instead of a startup-time error.

### Structured errors with `thiserror`

```rust
// GOOD: one error enum per bounded concern, composed via #[from] instead of manual mapping
#[derive(thiserror::Error, Debug)]
pub enum PricingError {
    #[error("product {0} not found")]
    ProductNotFound(Uuid),
    #[error("quantity must be positive")]
    InvalidQuantity,
}

#[derive(thiserror::Error, Debug)]
pub enum AppError {
    #[error("validation failed: {0}")]
    Validation(String),
    #[error(transparent)]
    Pricing(#[from] PricingError), // service-layer errors convert into AppError automatically via `?`
    #[error(transparent)]
    Database(#[from] sqlx::Error),
}
```

Keep domain-specific error enums (`PricingError`) separate from the top-level `AppError` that implements `IntoResponse`. This lets the pricing module stay a pure, framework-agnostic library internally while still composing cleanly into the HTTP layer's error type via `#[from]`.

### Single crate vs Cargo workspace

| Situation | Recommendation |
|-----------|-----------------|
| One deployable service, moderate size, one team | Single crate with the `routes/handlers/services/repositories` module layout above |
| Business logic (pricing, domain types) is reused by more than one binary (e.g. the API service and a separate batch worker) | Split that logic into a library crate in a workspace; keep each binary as a thin crate depending on it |
| Multiple genuinely independent services deployed separately, sharing some types (e.g. API request/response DTOs) | Workspace with one crate per service plus a shared `types`/`contracts` crate |
| Compile times are dominated by one module recompiling on every unrelated change | Consider splitting that module into its own crate — workspace crates compile independently and are cached separately |

Don't split into a workspace pre-emptively "for organization" — module boundaries (`mod services;`) give most of the organizational benefit for a single-binary service. Reach for a workspace when there's a real reuse or independent-compilation/deployment need.

### API versioning strategy

```rust
// GOOD: URL-path versioning — explicit, cacheable, and simple for mobile clients to target
Router::new()
    .nest("/api/v1", v1::router())
    .nest("/api/v2", v2::router()) // v2 introduced only for endpoints with actual breaking changes
```

For a service backing mobile apps specifically, prefer **URL-path versioning** (`/api/v1/...`) over header-based versioning: mobile app releases are slow to roll out (app store review, staged rollout, users who never update), so old app versions may call `/api/v1` for a long time after `/api/v2` ships. Path versioning makes it trivial to keep both routers alive simultaneously, and to grep logs/metrics for which version is still receiving traffic before deciding it's safe to retire.

- Add a **new field** to a response: not a breaking change, ship it in the existing version.
- **Remove or rename** a field, or change a field's type/meaning: breaking — either ship it under a new version prefix, or (for a large surface) add the change as an *additive* new field and deprecate the old one for a full mobile-release-cycle before removal.
- Track version usage via a `tracing` span field or metric tagged by path prefix so "can we delete `/api/v1`" is a data question, not a guess.

## Why This Works

- **Separating the pure business-rule layer from I/O** means the layer most likely to have bugs (business logic, edge cases in pricing/validation) is also the layer cheapest and fastest to test — no database, no HTTP server, just function calls.
- **`AppState` + `Arc<T>` gives you dependency injection without a DI framework** because Rust's ownership model already makes "share this handle cheaply across tasks" a first-class, compiler-checked operation; adding a DI container on top would be solving a problem Rust's type system already solves.
- **One typed `Config` struct loaded once at startup** turns "missing environment variable" from a 2am production incident (panic deep in a request handler) into a "service refuses to start, with a clear error" — a category of failure that's dramatically cheaper to diagnose.
- **`thiserror` + `#[from]` composition** keeps error handling boilerplate-free (`?` just works across layers) while still preserving enough type information to decide the right HTTP status code at the boundary.
- **URL-path API versioning aligns with mobile release realities** — server-side header-based versioning schemes assume the caller can be told "send this header," which doesn't help when the caller is an app binary already installed on millions of devices that won't update on your schedule.

## Edge Cases & Pitfalls

### Common Mistakes

- **Introducing the full four-layer split for a five-endpoint CRUD service.** This adds indirection without a corresponding testability or reuse win; start simpler and split when a module's responsibilities visibly diverge.
- **Putting `PgPool` or other I/O handles into the "pure" service layer's function signatures "just in case."** Once a function takes a `PgPool`, it can no longer be unit tested without a database — keep the pure/impure boundary sharp.
- **Reading `.env` values in production and expecting them to override real environment variables.** `dotenvy::dotenv()` typically only sets a variable if it isn't already set; relying on `.env` to *override* production env vars (rather than provide local-dev defaults) is a common source of "works locally, wrong in prod" confusion.
- **Bumping the API version prefix for every single change**, including additive, non-breaking ones. This forces mobile clients to track more versions than necessary and fragments traffic across paths for no reason — reserve version bumps for genuinely breaking changes.
- **Splitting into a Cargo workspace before there's a second consumer of the shared code.** A workspace with a single library crate and a single binary crate that depends on it adds build-graph complexity for no present benefit; wait for an actual second consumer (a worker binary, a CLI tool, a second service).

## Verification

```bash
# Confirm the pure business-logic layer has no I/O dependencies (grep for accidental PgPool/reqwest usage)
grep -rn "PgPool\|reqwest::Client" src/services/pricing.rs || echo "clean: no I/O in pricing module"

# Confirm config loads and fails loudly on a missing required variable
APP_DATABASE_URL= cargo run # should exit with a clear config error, not panic mid-request

# Confirm both API versions are independently reachable
curl -s localhost:8080/api/v1/orders -o /dev/null -w "%{http_code}\n"
curl -s localhost:8080/api/v2/orders -o /dev/null -w "%{http_code}\n"
```

- [ ] Business-rule functions in the service layer can be unit tested without `#[sqlx::test]` or a running server.
- [ ] Missing required config fails at process startup with a descriptive error, not inside a request handler.
- [ ] A repository function contains no conditional business logic — only query construction and execution.
- [ ] Both currently-supported API version prefixes are covered by integration tests and neither silently 404s.

## References

- [config crate](https://docs.rs/config/latest/config/)
- [envy crate](https://docs.rs/envy/latest/envy/)
- [dotenvy crate](https://docs.rs/dotenvy/latest/dotenvy/)
- [thiserror crate](https://docs.rs/thiserror/latest/thiserror/)
- [Cargo workspaces](https://doc.rust-lang.org/cargo/reference/workspaces.html)
