---
id: rust-testing-pyramid
category: skill
impact: HIGH
impactDescription: "Catches routing/auth/query regressions before deploy without needing a full staging environment per PR; isolated per-test databases eliminate test-order flakiness"
tags: [rust, testing, axum, sqlx, tower, mocking, property-testing, ci]
capabilities:
  - Writing fast unit tests for pure business logic with no I/O
  - Testing an axum Router in-process with tower::ServiceExt::oneshot, no bound socket needed
  - Using #[sqlx::test] for isolated, auto-provisioned integration tests against real Postgres
  - Mocking outbound HTTP calls to third-party APIs in tests
  - Deciding when property-based testing is worth the setup cost for critical logic
useWhen:
  - Deciding what layer of a Rust service to test at (unit vs integration vs full-stack)
  - Writing tests for a new axum handler or router
  - Tests are flaky because they share a single database and run in undefined order
  - A service calls an external HTTP API and tests need to run without hitting it
  - Critical logic (pricing, parsing, state machines) needs stronger correctness guarantees than example-based tests provide
---

# Build a Rust Service Test Suite That's Fast at the Base and Real at the Top

The most common testing mistake in a Rust axum/sqlx service is inverting the pyramid: either everything is an integration test that spins up a full server and a shared database (slow, flaky, hard to run in parallel), or everything is a unit test with the database mocked out so thoroughly that a real schema mismatch never gets caught until production. This skill covers the three layers that actually work well together in this stack: pure unit tests for logic, in-process `Router` tests via `tower::ServiceExt::oneshot` for HTTP behavior, and `#[sqlx::test]` for the subset of behavior that genuinely needs a real Postgres — plus mocking external calls and when property-based testing earns its cost.

## Problem

```rust
// BAD: "integration test" that requires a manually running server and a shared, mutable database
// Flaky under parallel `cargo test` runs because every test hits the same `orders` table
#[tokio::test]
async fn test_create_order() {
    let client = reqwest::Client::new();
    let response = client
        .post("http://localhost:8080/api/v1/orders") // assumes a server is already running somewhere
        .json(&serde_json::json!({ "items": [] }))
        .send()
        .await
        .unwrap();
    assert_eq!(response.status(), 422);
    // No cleanup — the next test run inherits whatever this left behind
}

// BAD: pricing logic tested only indirectly, through the full HTTP stack
// A pricing bug surfaces as "test_create_order_total is wrong" with no clue why
```

## Solution

### Layer 1: unit tests for pure logic (fast, no I/O, run on every save)

```rust
// GOOD: services/pricing.rs — pure function, tested directly with plain data, no server, no DB
pub fn calculate_total(items: &[NewOrderItem], prices: &HashMap<Uuid, i64>) -> Result<i64, PricingError> {
    let mut total = 0i64;
    for item in items {
        let price = prices.get(&item.product_id).ok_or(PricingError::ProductNotFound(item.product_id))?;
        if item.quantity == 0 {
            return Err(PricingError::InvalidQuantity);
        }
        total += price * item.quantity as i64;
    }
    Ok(total)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sums_line_items_correctly() {
        let prices = HashMap::from([(PRODUCT_A, 500), (PRODUCT_B, 1200)]);
        let items = vec![
            NewOrderItem { product_id: PRODUCT_A, quantity: 2 },
            NewOrderItem { product_id: PRODUCT_B, quantity: 1 },
        ];
        assert_eq!(calculate_total(&items, &prices).unwrap(), 2200);
    }

    #[test]
    fn rejects_zero_quantity() {
        let prices = HashMap::from([(PRODUCT_A, 500)]);
        let items = vec![NewOrderItem { product_id: PRODUCT_A, quantity: 0 }];
        assert!(matches!(calculate_total(&items, &prices), Err(PricingError::InvalidQuantity)));
    }
}
```

This layer should be the largest by test count and the fastest to run — no `#[tokio::test]` needed at all when the logic itself isn't async.

### Layer 2: axum `Router` tests via `tower::ServiceExt::oneshot`

```rust
// GOOD: exercises real routing, extractors, and middleware — without binding a socket or
// spawning a real server process. `oneshot` sends one request straight into the tower Service.
use axum::{body::Body, http::{Request, StatusCode}};
use tower::ServiceExt; // for `oneshot`

#[tokio::test]
async fn create_order_rejects_empty_items() {
    let state = test_state().await; // builds AppState against a test DB, see Layer 3
    let app = routes::build_router(state);

    let request = Request::builder()
        .method("POST")
        .uri("/api/v1/orders")
        .header("content-type", "application/json")
        .header("authorization", format!("Bearer {}", test_jwt()))
        .body(Body::from(serde_json::json!({ "items": [] }).to_string()))
        .unwrap();

    let response = app.oneshot(request).await.unwrap();

    assert_eq!(response.status(), StatusCode::UNPROCESSABLE_ENTITY);
}

#[tokio::test]
async fn create_order_without_auth_header_is_rejected() {
    let state = test_state().await;
    let app = routes::build_router(state);

    let request = Request::builder()
        .method("POST")
        .uri("/api/v1/orders")
        .header("content-type", "application/json")
        .body(Body::from(serde_json::json!({ "items": [] }).to_string()))
        .unwrap();

    let response = app.oneshot(request).await.unwrap();

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED); // proves the AuthUser extractor is wired up
}
```

This is the layer that catches routing mistakes, missing middleware, and extractor wiring bugs — the things unit tests on `services::` functions can't see, without paying for a real bound TCP listener or a separately-run process.

### Layer 3: `#[sqlx::test]` for behavior that genuinely needs Postgres

```rust
// GOOD: #[sqlx::test] creates a fresh, isolated database per test (from your migrations),
// runs the test against it, and tears it down — no shared state, no manual cleanup, safe to
// run fully in parallel with `cargo test`.
#[sqlx::test(migrations = "./migrations")]
async fn insert_order_persists_correct_total(pool: PgPool) -> sqlx::Result<()> {
    let user_id = seed_user(&pool).await?;

    let order = repositories::orders::insert(&pool, user_id, 2200).await?;

    let fetched = sqlx::query_as!(Order, "SELECT id, user_id, total_cents, status FROM orders WHERE id = $1", order.id)
        .fetch_one(&pool)
        .await?;

    assert_eq!(fetched.total_cents, 2200);
    assert_eq!(fetched.status, "pending");
    Ok(())
}

#[sqlx::test(migrations = "./migrations")]
async fn list_orders_scopes_to_the_correct_tenant(pool: PgPool) -> sqlx::Result<()> {
    let tenant_a = seed_user(&pool).await?;
    let tenant_b = seed_user(&pool).await?;
    repositories::orders::insert(&pool, tenant_a, 1000).await?;
    repositories::orders::insert(&pool, tenant_b, 2000).await?;

    let orders = repositories::orders::list_for_user(&pool, tenant_a).await?;

    assert_eq!(orders.len(), 1); // proves the tenant predicate from rust-sqlx-patterns actually filters
    Ok(())
}
```

`#[sqlx::test]` needs `DATABASE_URL` pointing at a Postgres server it's allowed to create/drop throwaway databases against (a local dev instance or a CI service container) — it does not need the same production database, and it does not reuse tables between tests, which is what eliminates the test-order flakiness of Layer-2-only approaches.

### Mocking external HTTP calls

```rust
// GOOD: don't hit the real third-party API in tests. Inject the base URL via config/AppState
// and point it at a local mock server for tests.
use wiremock::{MockServer, Mock, ResponseTemplate};
use wiremock::matchers::{method, path};

#[tokio::test]
async fn charges_payment_provider_and_records_order() {
    let mock_server = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/v1/charges"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({ "id": "ch_123", "status": "succeeded" })))
        .mount(&mock_server)
        .await;

    let mut config = test_config();
    config.payment_provider_base_url = mock_server.uri(); // service reads this from AppState, not a hardcoded URL

    // ... build AppState with this config, call the service function, assert on the outcome
}
```

Never let a test suite depend on network access to a real third-party API — it's slow, it costs money against a real provider account, and it fails the whole suite when that provider has an outage unrelated to your code.

### When property-based testing earns its cost

Reach for `proptest` (or `quickcheck`) for logic where the *set* of edge cases isn't obvious upfront and getting it wrong is costly — parsers, money/rounding arithmetic, serialization round-trips, and state machines are the classic candidates. Skip it for straightforward CRUD validation where a handful of example-based cases already cover the realistic input space; property tests add setup and CI time that isn't worth it for logic that isn't combinatorially tricky.

```rust
// GOOD: proptest generates many quantity/price combinations to check an invariant that should
// always hold, instead of relying on the test author to think of every edge case by hand
use proptest::prelude::*;

proptest! {
    #[test]
    fn total_is_never_negative(quantity in 1u32..10_000, price_cents in 0i64..1_000_000) {
        let items = vec![NewOrderItem { product_id: PRODUCT_A, quantity }];
        let prices = HashMap::from([(PRODUCT_A, price_cents)]);
        let total = calculate_total(&items, &prices).unwrap();
        prop_assert!(total >= 0);
    }
}
```

## Why This Works

- **Pure unit tests need no `#[tokio::test]`, no database, and no server**, so they run in milliseconds and can be the tight feedback loop developers actually run on every save — this only works because the pricing/validation logic was deliberately kept free of I/O (see `rust-service-architecture`).
- **`tower::ServiceExt::oneshot` drives the real `Router` — the same value passed to `axum::serve` in production — through one request/response cycle in-process.** Every extractor, every `tower::Layer`, every route match runs for real; nothing about routing or middleware is mocked, but there's no socket, no port conflicts between parallel test runs, and no separate server process to manage.
- **`#[sqlx::test]` provisions a fresh database per test function** (typically by templating off a migrated template database, which is fast) so tests never observe each other's data and can run with `cargo test`'s default parallelism instead of needing `--test-threads=1` to avoid collisions.
- **Mocking the external HTTP boundary (not the database) keeps tests both fast and honest**: the database is real, so schema/query bugs are still caught; only calls that would leave the process — to a third-party API — are faked.

## Edge Cases & Pitfalls

### Common Mistakes

- **Skipping Layer 2 entirely and relying only on unit tests + `#[sqlx::test]` repository tests.** This misses an entire class of bugs — wrong route path, forgotten middleware, an extractor returning the wrong status code — because nothing ever sends a request through the actual `Router`.
- **Running `#[sqlx::test]` against the same `DATABASE_URL` used for local development without realizing it creates/drops databases.** Point it at a disposable local Postgres instance or a CI service container, never at a database with data you care about.
- **Forgetting that `#[sqlx::test]`'s automatic migrations run from the `migrations/` directory relative to the crate**, so tests in a workspace member crate may need an explicit `migrations = "../../migrations"` path if migrations live elsewhere.
- **Asserting only on HTTP status codes in Layer 2 tests and never on response bodies.** A 200 with the wrong payload shape (e.g., a renamed field the mobile client depends on) passes a status-only test and breaks the app in production.
- **Reaching for `proptest` on simple, already-well-covered validation logic** — the setup and mental overhead isn't worth it when five example-based cases already give full confidence.
- **Not cleaning up `wiremock` mock servers or reusing one across unrelated tests** — each test needing external-call mocking should get its own `MockServer::start()` to avoid cross-test interference and unclear failures.

## Verification

```bash
# Run the full suite; unit + Layer 2 tests should complete in well under a minute for a mid-sized service
cargo test

# Run only #[sqlx::test]-backed tests, confirming they don't require --test-threads=1
DATABASE_URL=postgres://localhost/postgres cargo test --test integration -- --test-threads=8

# Confirm no test suite makes a real outbound network call to a non-localhost host
cargo test 2>&1 | grep -iE "connection refused|dns error" # should show nothing tied to a third-party domain
```

- [ ] Pure business-logic modules have unit tests that run without `tokio::test` or a database.
- [ ] At least one Layer 2 test exists per route verifying both the success path and an auth/validation failure path.
- [ ] `#[sqlx::test]` tests pass when run with full parallelism (`cargo test` default), proving isolation.
- [ ] No test in the suite makes a network call to a real third-party service.

## References

- [tower::ServiceExt::oneshot](https://docs.rs/tower/latest/tower/trait.ServiceExt.html#method.oneshot)
- [sqlx::test macro](https://docs.rs/sqlx/latest/sqlx/attr.test.html)
- [wiremock crate](https://docs.rs/wiremock/latest/wiremock/)
- [proptest crate](https://docs.rs/proptest/latest/proptest/)
- [axum testing examples](https://github.com/tokio-rs/axum/tree/main/examples/testing)
