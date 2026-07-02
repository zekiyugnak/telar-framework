---
id: rust-deployment
category: skill
impact: HIGH
impactDescription: "Cuts Docker image size from ~1.5GB to under 100MB and CI build times significantly via layer caching; eliminates dropped in-flight requests during rolling deploys"
tags: [rust, docker, deployment, graceful-shutdown, health-check, tracing, observability, cargo-chef]
capabilities:
  - Writing a multi-stage Dockerfile that produces a small release binary
  - Caching dependency compilation with cargo-chef so unrelated code changes don't invalidate it
  - Implementing liveness/readiness health check endpoints for orchestrators
  - Handling SIGTERM and draining in-flight requests before process exit
  - Exporting structured logs and traces for production observability
  - Tuning binary size and build time for CI/CD pipelines
useWhen:
  - Writing or reviewing a Dockerfile for a Rust axum/sqlx service
  - CI build times for the service are dominated by re-compiling dependencies on every change
  - The service is being deployed to Kubernetes or another orchestrator that sends SIGTERM
  - Requests are being dropped during deploys or pod termination
  - Setting up log/trace export for a Rust service running in production
---

# Ship a Rust Service That Builds Fast, Runs Small, and Shuts Down Cleanly

A Rust service that isn't deployment-aware causes three distinct kinds of pain: CI builds that take 10+ minutes because every code change invalidates the entire dependency compilation cache, container images that are needlessly large because build tools ship in the runtime image, and dropped requests during every rolling deploy because the process exits the instant it receives SIGTERM instead of finishing in-flight work. This skill covers a multi-stage Dockerfile with `cargo-chef` caching, health check endpoints, graceful shutdown, and structured observability export — the deployment-facing half of running a Rust service in production.

## Problem

```dockerfile
# BAD: single-stage build — ships the entire Rust toolchain, source tree, and build cache
# in the final image, and re-runs full dependency compilation on every source change
FROM rust:1.82
WORKDIR /app
COPY . .
RUN cargo build --release
CMD ["./target/release/api-service"]
# Final image: 1.5GB+. Every `cargo build` invalidates on any file change because Docker's
# layer cache sees the whole `COPY . .` as one layer with no dependency/source separation.
```

```rust
// BAD: no graceful shutdown — the process exits the moment SIGTERM arrives,
// killing any request that's mid-flight (a common cause of 502s during deploys)
#[tokio::main]
async fn main() {
    let app = build_router();
    let listener = tokio::net::TcpListener::bind("0.0.0.0:8080").await.unwrap();
    axum::serve(listener, app).await.unwrap(); // no shutdown handling at all
}

// BAD: health check that only proves the process is alive, not that it can serve traffic
async fn health() -> StatusCode {
    StatusCode::OK // returns 200 even if the DB pool is exhausted or Postgres is unreachable
}
```

## Solution

### Multi-stage Dockerfile with `cargo-chef` layer caching

```dockerfile
# GOOD: Dockerfile — separate dependency compilation from source compilation, and separate
# the build toolchain from the runtime image entirely.

# Stage 1: compute a recipe of dependencies only (no application source yet)
FROM lukemathwalker/cargo-chef:latest-rust-1 AS chef
WORKDIR /app

FROM chef AS planner
COPY . .
RUN cargo chef prepare --recipe-path recipe.json

# Stage 2: build dependencies from the recipe — this layer is cached and only invalidates
# when Cargo.toml/Cargo.lock change, NOT when application source changes
FROM chef AS builder
COPY --from=planner /app/recipe.json recipe.json
RUN cargo chef cook --release --recipe-path recipe.json
COPY . .
RUN cargo build --release --bin api-service

# Stage 3: minimal runtime image — no Rust toolchain, no source, no build cache
FROM debian:bookworm-slim AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=builder /app/target/release/api-service /usr/local/bin/api-service
COPY migrations ./migrations
# Run as a non-root user
RUN useradd -m appuser
USER appuser
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/api-service"]
```

With this structure, a source-only change (no `Cargo.toml`/`Cargo.lock` change) re-runs only the final `cargo build` step against already-cached dependency artifacts from `cargo chef cook`, turning multi-minute CI builds into ones dominated only by the application's own compile time. The final image contains just the compiled binary, CA certificates (needed for outbound TLS, e.g. to a payment provider), and migration files — routinely under 100MB depending on the binary's own dependencies, versus 1.5GB+ for a single-stage build.

For an even smaller runtime base, `gcr.io/distroless/cc-debian12` or an Alpine + `musl` static-linked build can work, but `debian:bookworm-slim` is the safer default: `musl` builds can surface subtle differences in DNS resolution and TLS behavior that are easy to miss until production.

### Health check endpoints for orchestrators

```rust
// GOOD: separate liveness (is the process alive) from readiness (can it serve real traffic)
use axum::{extract::State, http::StatusCode, Json};
use serde_json::json;

// Liveness: orchestrator uses this to decide whether to restart the container.
// Keep this cheap and dependency-free — it should only fail if the process itself is wedged.
pub async fn liveness() -> StatusCode {
    StatusCode::OK
}

// Readiness: orchestrator uses this to decide whether to route traffic to this instance.
// This one SHOULD check real dependencies — a pool with no available connections means
// this instance can't actually serve requests, even though the process is alive.
pub async fn readiness(State(state): State<AppState>) -> Result<Json<serde_json::Value>, StatusCode> {
    let db_ok = sqlx::query("SELECT 1").execute(&state.db).await.is_ok();

    if db_ok {
        Ok(Json(json!({ "status": "ready", "db": "ok" })))
    } else {
        Err(StatusCode::SERVICE_UNAVAILABLE)
    }
}
```

```rust
// routes/mod.rs — wire both under distinct paths; most orchestrators (k8s, ECS) let you
// configure separate liveness and readiness probe paths
Router::new()
    .route("/healthz", get(handlers::health::liveness))
    .route("/readyz", get(handlers::health::readiness))
```

Conflating these into one endpoint is a common mistake: if `/healthz` checks the database and the database has a brief blip, the orchestrator restarts a perfectly healthy process instead of just pausing traffic to it — turning a transient DB hiccup into an unnecessary restart storm.

### Graceful shutdown: drain in-flight requests on SIGTERM

```rust
// GOOD: main.rs — wait for SIGTERM (or Ctrl+C locally), stop accepting new connections,
// let in-flight requests finish, then exit
use tokio::signal;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    telemetry::init();
    let state = build_state().await?;
    let app = routes::build_router(state.clone());

    let listener = tokio::net::TcpListener::bind("0.0.0.0:8080").await?;
    tracing::info!("listening on 0.0.0.0:8080");

    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await?;

    tracing::info!("shutdown complete");
    Ok(())
}

async fn shutdown_signal() {
    let ctrl_c = async {
        signal::ctrl_c().await.expect("failed to install Ctrl+C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        signal::unix::signal(signal::unix::SignalKind::terminate())
            .expect("failed to install SIGTERM handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => tracing::info!("received Ctrl+C, shutting down"),
        _ = terminate => tracing::info!("received SIGTERM, shutting down"),
    }
}
```

`axum::serve(...).with_graceful_shutdown(...)` stops accepting *new* connections the instant the shutdown future resolves, but lets already-accepted requests run to completion before the `await` on `axum::serve(...)` itself returns. Pair this with an orchestrator's `terminationGracePeriodSeconds` (Kubernetes) set comfortably above your slowest expected request duration, and take the readiness probe (`/readyz`) out of rotation *before* SIGTERM is sent if your platform supports a pre-stop hook — that ordering (stop routing new traffic, then terminate) avoids a race where a new request lands on an instance that's already mid-shutdown.

### Structured logging and trace export

```rust
// GOOD: telemetry.rs — JSON logs in production (machine-parseable), human-readable in dev
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

pub fn init() {
    let env_filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));

    let fmt_layer = if std::env::var("APP_ENV").as_deref() == Ok("production") {
        tracing_subscriber::fmt::layer().json().boxed()
    } else {
        tracing_subscriber::fmt::layer().pretty().boxed()
    };

    tracing_subscriber::registry()
        .with(env_filter)
        .with(fmt_layer)
        .init();
}

// Handlers/services log with structured fields, not string interpolation:
tracing::info!(order_id = %order.id, user_id = %user.id, total_cents = order.total_cents, "order created");
```

For distributed tracing across services (mobile client → this Rust service → downstream APIs), export spans via the `tracing-opentelemetry` bridge to an OTLP collector rather than relying on log-line correlation alone; carry a request/correlation ID from the `TraceLayer` (or an incoming `traceparent` header) through every log line in that request's span.

### Binary size and build time tips

```toml
# Cargo.toml — release profile tuning
[profile.release]
opt-level = "z"     # optimize for size; use 3 if raw throughput matters more than image size
lto = true           # link-time optimization: smaller, sometimes faster binary, slower build
codegen-units = 1     # better optimization at the cost of build parallelism
strip = true           # strip debug symbols from the release binary
```

`lto = true` and `codegen-units = 1` trade CI build time for a smaller/faster binary — reasonable for a service built once per release, less so if `cargo build --release` runs on every PR and build time is the bottleneck you're optimizing. Measure both before enabling.

## Why This Works

- **`cargo-chef` splits "compile my dependencies" from "compile my application code" into separate Docker layers**, and Docker's layer cache only invalidates a layer when its inputs (here, `Cargo.toml`/`Cargo.lock` for the chef-cook step) change — so the dependency layer, which is usually the majority of total compile time, survives unchanged across ordinary source edits.
- **A multi-stage build discards the entire Rust toolchain and source tree after compilation**, leaving only the compiled binary and its true runtime needs (CA certs, migration files) in the image that actually ships — smaller images pull faster, which shortens rollout time and reduces the attack surface.
- **Separate liveness and readiness probes let the orchestrator distinguish "restart this" from "stop routing to this for now"** — a transient dependency outage should pause traffic, not cycle the process, since a restart doesn't fix an external Postgres blip and just adds cold-start latency on top of it.
- **`with_graceful_shutdown` closing the listener before existing connections are cut** is what actually prevents dropped requests during a deploy — without it, a rolling deploy's SIGTERM races against in-flight requests with no coordination at all.
- **Structured (JSON) logs in production are what make log aggregation systems (and on-call engineers) able to filter/query by field** (`order_id`, `user_id`) instead of regex-parsing free-text log lines under incident pressure.

## Edge Cases & Pitfalls

### Common Mistakes

- **Forgetting to copy `migrations/` into the runtime image** when the service runs `sqlx::migrate!()` at startup — the binary will fail to find migration files that only existed in the builder stage.
- **Running the container as root.** The example Dockerfile creates and switches to a non-root `appuser`; skipping this is a routine security-review finding and unnecessary risk for a network-facing service.
- **Setting `terminationGracePeriodSeconds` shorter than the slowest realistic request.** If the orchestrator SIGKILLs the process before in-flight requests finish, graceful shutdown code never gets the chance to matter.
- **Checking only liveness in a deploy's readiness gate**, or wiring both probes to the same handler. This collapses the "alive vs able to serve traffic" distinction the two probes exist to preserve.
- **Logging with `println!`/`eprintln!` instead of `tracing`** anywhere in the codebase — these bypass the structured logging pipeline entirely and are invisible to log aggregation filters built around the JSON fields.
- **Enabling `lto = true` and `codegen-units = 1` without measuring the build-time cost** for a codebase where CI build time is already a pain point — these settings are a real tradeoff, not a free win.
- **Not pinning the base image tag** (`rust:1` instead of `rust:1.82-bookworm`, or `debian:bookworm-slim` without a digest pin in a security-sensitive environment) — floating tags mean a "no code change" deploy can still pick up an unexpected toolchain or OS update.

## Verification

```bash
# Build and check the final image size
docker build -t api-service:test .
docker images api-service:test --format "{{.Size}}"

# Confirm a source-only change reuses the cached dependency layer (should be fast)
touch src/main.rs && time docker build -t api-service:test .

# Confirm graceful shutdown: start the service, send an in-flight slow request, then SIGTERM
# the process, and verify the slow request still completes successfully.
docker run -d --name test-svc api-service:test
curl -s http://localhost:8080/slow-endpoint & sleep 0.2 && docker kill -s SIGTERM test-svc
wait # the curl above should still return 200, not a connection reset

# Confirm liveness/readiness respond correctly
curl -i localhost:8080/healthz   # 200 even if DB is down
curl -i localhost:8080/readyz    # 503 if DB is unreachable, 200 otherwise
```

- [ ] Final image size is a small fraction of what a single-stage build would produce (verify with `docker images`).
- [ ] A source-only code change does not trigger recompilation of unrelated dependencies (verify via build timing or `docker build --progress=plain` layer cache hits).
- [ ] Sending SIGTERM mid-request allows that request to complete before the container exits.
- [ ] `/readyz` returns a non-2xx status when the database is unreachable, while `/healthz` still returns 200.
- [ ] Container runs as a non-root user (`docker inspect` shows the configured `User`).

## References

- [cargo-chef](https://github.com/LukeMathWalker/cargo-chef)
- [axum graceful shutdown example](https://docs.rs/axum/latest/axum/serve/struct.WithGracefulShutdown.html)
- [tracing crate](https://docs.rs/tracing/latest/tracing/)
- [tracing-subscriber crate](https://docs.rs/tracing-subscriber/latest/tracing_subscriber/)
- [tracing-opentelemetry crate](https://docs.rs/tracing-opentelemetry/latest/tracing_opentelemetry/)
- [Cargo release profile settings](https://doc.rust-lang.org/cargo/reference/profiles.html)
