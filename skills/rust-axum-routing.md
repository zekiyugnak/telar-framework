---
id: rust-axum-routing
category: skill
impact: HIGH
impactDescription: "Eliminates duplicated auth/validation code across handlers and prevents CORS misconfiguration that silently breaks mobile/web clients"
tags: [rust, axum, routing, extractors, middleware, tower, error-handling]
capabilities:
  - Composing axum routers with nested routes and .merge()
  - Using built-in extractors (Path, Query, Json, State) correctly and in the right order
  - Writing custom extractors via FromRequestParts for cross-cutting concerns like auth
  - Applying tower::Layer middleware for logging, CORS, and rate limiting
  - Designing a single AppError type that implements IntoResponse
  - Validating request bodies before they reach business logic
useWhen:
  - Structuring routes for a growing axum service with multiple resources
  - Implementing an auth extractor shared across many protected routes
  - Adding CORS, rate limiting, or request logging to an axum service
  - Standardizing how handlers return errors to callers (mobile app or web frontend)
  - Debugging why an extractor rejects a request or why middleware isn't running
---

# Structure axum Routers with Extractors, Middleware, and a Single Error Type

axum routes fall apart at scale in a predictable way: auth checks get copy-pasted into every handler, error responses drift into inconsistent shapes across endpoints, and cross-cutting concerns (CORS, logging, rate limits) get bolted onto individual routes instead of applied once. This skill covers router composition, extractor design (built-in and custom), `tower::Layer` middleware, and a single `AppError` type that keeps every endpoint's error shape consistent for the mobile and web clients consuming it.

## Problem

```rust
// BAD: auth check duplicated in every handler, inconsistent error shapes
async fn get_order(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
) -> Result<Json<Order>, (StatusCode, String)> {
    // Every handler re-implements this exact block
    let token = headers.get("authorization")
        .and_then(|v| v.to_str().ok())
        .ok_or((StatusCode::UNAUTHORIZED, "missing token".into()))?;
    let claims = verify_jwt(token).map_err(|_| (StatusCode::UNAUTHORIZED, "bad token".into()))?;

    let order = sqlx::query_as!(Order, "SELECT * FROM orders WHERE id = $1", id)
        .fetch_optional(&state.db)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))? // leaks internal errors to clients
        .ok_or((StatusCode::NOT_FOUND, "not found".into()))?;

    if order.user_id != claims.sub {
        return Err((StatusCode::FORBIDDEN, "not yours".into()));
    }
    Ok(Json(order))
}

// BAD: CORS bolted onto one route instead of applied consistently
let app = Router::new()
    .route("/orders/{id}", get(get_order).layer(CorsLayer::permissive())); // reflects any origin
```

Each handler re-derives the auth logic slightly differently, database errors leak raw messages to clients (a security and stability concern), and middleware applied per-route instead of per-router means it's easy to forget on a new endpoint.

## Solution

### Router composition: nested routers and `.merge()`

```rust
// GOOD: routes/mod.rs — compose per-resource routers, apply shared layers once
use axum::Router;
use tower_http::{cors::CorsLayer, trace::TraceLayer};

pub fn build_router(state: AppState) -> Router {
    let api_v1 = Router::new()
        .nest("/users", users::router())
        .nest("/orders", orders::router())
        .with_state(state.clone());

    Router::new()
        .nest("/api/v1", api_v1)
        .route("/healthz", axum::routing::get(health::check))
        .layer(TraceLayer::new_for_http())      // logs every request once, not per-route
        .layer(cors_layer(&state.config))        // one CORS policy for the whole service
}

fn cors_layer(config: &Config) -> CorsLayer {
    // axum 0.8 route syntax uses `{param}`, not the old `:param` — the pre-0.8 colon
    // form panics at router-build time ("paths must not start with a colon").
    CorsLayer::new()
        .allow_origin(
            config.allowed_origins.iter()
                .map(|o| o.parse().unwrap())
                .collect::<Vec<axum::http::HeaderValue>>(), // element type must be pinned; `Vec<_>` won't infer
        )
        .allow_methods([axum::http::Method::GET, axum::http::Method::POST, axum::http::Method::PATCH])
        .allow_headers([axum::http::header::AUTHORIZATION, axum::http::header::CONTENT_TYPE])
}
```

```rust
// routes/orders.rs — each resource owns its own sub-router; state is threaded via .with_state
use axum::{routing::{get, post}, Router};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/", get(handlers::orders::list).post(handlers::orders::create))
        .route("/{id}", get(handlers::orders::get_one)) // axum 0.8: `{id}`, not `:id`
}
```

### Built-in extractors, in the order axum expects

```rust
// GOOD: Path, Query, and Json extractors — order matters, Json/body extractors must come last
use axum::extract::{Path, Query, State};
use serde::Deserialize;

#[derive(Deserialize)]
pub struct ListOrdersQuery {
    #[serde(default)]
    pub status: Option<String>,
    #[serde(default = "default_page_size")]
    pub page_size: u32,
}

fn default_page_size() -> u32 { 20 }

pub async fn list(
    State(state): State<AppState>,       // extractors that don't consume the body go first
    Query(params): Query<ListOrdersQuery>,
    user: AuthUser,                       // custom extractor, see below
) -> Result<Json<Vec<OrderResponse>>, AppError> {
    let orders = services::orders::list_for_user(&state.db, user.id, params.status, params.page_size).await?;
    Ok(Json(orders.into_iter().map(Into::into).collect()))
}

pub async fn create(
    State(state): State<AppState>,
    user: AuthUser,
    Json(payload): Json<CreateOrderRequest>,  // body-consuming extractor must be the LAST parameter
) -> Result<Json<OrderResponse>, AppError> {
    payload.validate()?;                       // validate before touching the database
    let order = services::orders::create(&state.db, user.id, payload).await?;
    Ok(Json(order.into()))
}
```

Only one extractor per handler can consume the request body (`Json<T>`, `Bytes`, `String`, etc.), and it must be the last argument — axum enforces this at compile time via the `FromRequest` vs `FromRequestParts` trait split.

### Custom extractor for auth (`FromRequestParts`)

```rust
// GOOD: extractors.rs — one implementation, reused by every handler that takes `AuthUser`
use axum::{extract::FromRequestParts, http::request::Parts};

pub struct AuthUser {
    pub id: Uuid,
    pub role: Role,
}

impl FromRequestParts<AppState> for AuthUser {
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, state: &AppState) -> Result<Self, Self::Rejection> {
        let auth_header = parts.headers
            .get(axum::http::header::AUTHORIZATION)
            .and_then(|v| v.to_str().ok())
            .ok_or(AppError::Unauthorized)?;

        let token = auth_header.strip_prefix("Bearer ").ok_or(AppError::Unauthorized)?;
        let claims = crate::auth::verify_jwt(token, &state.config.jwt_secret)
            .map_err(|_| AppError::Unauthorized)?;

        Ok(AuthUser { id: claims.sub, role: claims.role })
    }
}

// A second extractor can require a specific role without duplicating the JWT logic:
pub struct AdminUser(pub AuthUser);

impl FromRequestParts<AppState> for AdminUser {
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, state: &AppState) -> Result<Self, Self::Rejection> {
        let user = AuthUser::from_request_parts(parts, state).await?;
        if user.role != Role::Admin {
            return Err(AppError::Forbidden);
        }
        Ok(AdminUser(user))
    }
}
```

Because `AuthUser` (and `AdminUser`) are ordinary function parameters, a route simply omitting them from its handler signature is public — the type system, not a middleware you might forget to attach, is what enforces the requirement.

### Middleware via `tower::Layer` (rate limiting example)

```rust
// GOOD: apply a rate limiter once, at the router level.
// Do NOT reach for tower::limit::RateLimitLayer here — axum clones the inner
// service per connection, and RateLimitLayer's single-permit poll_ready
// reservation is not Clone-safe across those clones, so it either fails to
// build or silently stops limiting. Use a crate designed for this, like
// tower_governor, which is.
use tower_governor::{governor::GovernorConfigBuilder, GovernorLayer};
use std::sync::Arc;

let governor_conf = Arc::new(
    GovernorConfigBuilder::default()
        .per_second(2)   // steady-state: 2 req/s per client key (IP by default)
        .burst_size(20)  // allow short bursts up to 20 before throttling kicks in
        .finish()
        .expect("valid governor config"),
);

let app = Router::new()
    .nest("/api/v1", api_v1)
    .layer(GovernorLayer { config: governor_conf });

// For per-authenticated-user (not per-IP) limiting, key the governor's
// extractor on a claim from the AuthUser extracted upstream instead of the
// default peer-IP key.
```

### A single `AppError` for consistent responses

```rust
// GOOD: error.rs — every handler returns Result<_, AppError>; one IntoResponse impl
use axum::{http::StatusCode, response::{IntoResponse, Response}, Json};
use serde_json::json;

#[derive(thiserror::Error, Debug)]
pub enum AppError {
    #[error("unauthorized")]
    Unauthorized,
    #[error("forbidden")]
    Forbidden,
    #[error("not found")]
    NotFound,
    #[error("validation failed: {0}")]
    Validation(String),
    #[error("database error")]
    Database(#[from] sqlx::Error),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, message) = match &self {
            AppError::Unauthorized => (StatusCode::UNAUTHORIZED, self.to_string()),
            AppError::Forbidden => (StatusCode::FORBIDDEN, self.to_string()),
            AppError::NotFound => (StatusCode::NOT_FOUND, self.to_string()),
            AppError::Validation(_) => (StatusCode::UNPROCESSABLE_ENTITY, self.to_string()),
            AppError::Database(err) => {
                // Log the real error server-side, return a generic message to the client
                tracing::error!(error = %err, "database error");
                (StatusCode::INTERNAL_SERVER_ERROR, "internal server error".to_string())
            }
        };
        (status, Json(json!({ "error": message }))).into_response()
    }
}
```

## Why This Works

- **Extractors put auth in the type system, not in handler bodies.** A handler that requires `AuthUser` cannot compile without providing it; there's no runtime branch to forget.
- **`FromRequestParts` runs before the body is read**, so auth/identity extraction never needs to touch or buffer the request body, keeping it composable with any body-consuming extractor.
- **Layers applied at the router level run for every nested route**, so CORS, tracing, and rate limits can't be accidentally omitted on a new endpoint the way per-route `.layer()` calls can.
- **A single `AppError` with one `IntoResponse` impl** means the response shape (`{"error": "..."}` plus status code) is guaranteed consistent across every endpoint the mobile app and web frontend call, and `#[from]` conversions mean `?` just works across layers without manual `.map_err()` at every call site.
- **Logging the real error and returning a generic message** for `Database` variants prevents leaking schema details, table names, or SQL fragments to API consumers, which is both a security property and a stability one for a public API surface.

## Edge Cases & Pitfalls

### Common Mistakes

- **Putting a body-consuming extractor before other extractors.** `Json<T>` (or any `FromRequest`, as opposed to `FromRequestParts`) must be the last argument in a handler's parameter list, or the code won't compile — the error message ("this type does not implement FromRequestParts") is not always obvious about why.
- **Using `CorsLayer::permissive()` in production.** It reflects any `Origin` header, which combined with credentialed requests (cookies, `Authorization` headers sent by browsers) defeats the purpose of CORS. Always configure an explicit `allow_origin` list from config.
- **Forgetting that `Query<T>` deserialization failures return a generic 400 by default.** For user-facing validation errors, prefer parsing loosely into optional fields and validating explicitly, so you control the error message shape via `AppError::Validation` instead of axum's default rejection body.
- **Reaching for `tower::limit::RateLimitLayer` at all in an axum app.** It's not just "global instead of per-client" — its internal permit reservation isn't safe across axum's per-connection service clones, so it doesn't reliably rate-limit in the first place. Use `tower_governor` (or another axum-aware limiter) instead of the bare `tower::limit` primitives.
- **Returning `impl IntoResponse` from a shared helper called by handlers with different concrete return types.** This frequently fails to compile because `impl Trait` in return position must resolve to exactly one concrete type; return `Response` or a shared enum instead.
- **Not handling extractor rejections consistently.** Built-in extractors like `Json<T>` have their own default rejection types distinct from `AppError`. If the API contract with mobile/web clients requires a uniform error envelope, either use `axum::extract::rejection` handling or wrap deserialization in a custom extractor that converts into `AppError`.

## Verification

```bash
# Confirm the router compiles and the extractor ordering is valid
cargo check

# Exercise middleware ordering and auth rejection without a real server (see rust-testing-pyramid)
cargo test --test router_integration

# Manually verify CORS behavior against a disallowed origin
curl -i -H "Origin: https://not-allowed.example.com" http://localhost:8080/api/v1/orders
# Expect no Access-Control-Allow-Origin header in the response
```

- [ ] A request with no `Authorization` header to a protected route returns 401 with the `AppError` JSON shape, not a panic or a 500.
- [ ] A request from a non-allow-listed origin does not receive `Access-Control-Allow-Origin` in the response.
- [ ] A `sqlx::Error` raised deep in a repository call surfaces as a generic 500 to the client, while the real error appears in server logs via `tracing::error!`.
- [ ] Adding a new nested router under `/api/v1` automatically picks up the `TraceLayer` and CORS policy without any extra `.layer()` calls in the new module.

## References

- [axum routing](https://docs.rs/axum/latest/axum/struct.Router.html)
- [axum extractors](https://docs.rs/axum/latest/axum/extract/index.html)
- [axum error handling](https://docs.rs/axum/latest/axum/error_handling/index.html)
- [tower::Layer](https://docs.rs/tower/latest/tower/trait.Layer.html)
- [tower-http CorsLayer](https://docs.rs/tower-http/latest/tower_http/cors/index.html)
