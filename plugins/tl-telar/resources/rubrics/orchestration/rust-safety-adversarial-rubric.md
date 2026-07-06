# Rust Service Safety Adversarial Rubric

## Purpose

Used by the always-on Adversarial Rust Safety Reviewer in `skills/orchestration/adversarial-code-review.md`. Extends the generic adversarial rubric with Rust service-layer (axum/tokio/sqlx) failure modes.

## Reviewer mode

**Adversarial.** Same discipline as the generic rubric: fresh `Task()` instance, sees only WU spec + DoD + file scope + diff. Binary PASS/FAIL.

## Evaluation criteria

### RS. Rust service safety failures

A WU FAILS Rust safety review if any of:

- RS1. An `unsafe` block is introduced without an inline soundness justification comment (`// SAFETY: …`) explaining the invariant upheld. A bare `unsafe {}` with no comment, or a justification that merely restates what the code does, → FAIL.
- RS2. `unwrap()`, `expect()`, `panic!()`, or a direct slice/array index (`buf[i]`) appears in a request-handling path (any function reachable from an axum handler, middleware, or extractor). These must be replaced by `?`-propagated `Result`/`Option` or a guard that is provably unreachable. Advisory only for test modules (`#[cfg(test)]`).
- RS3. An error is silently swallowed: `let _ = fallible_call()` or a `.ok()` drop without a log or metric in a path that can affect correctness or data integrity → FAIL.
- RS4. Raw string-interpolated SQL (e.g., `format!("SELECT … {val}")`) is used instead of `sqlx::query!` / `sqlx::query_as!` compile-time macros or positional `$1` bind parameters. Also FAIL if a new migration file is missing from `migrations/` when the diff adds or alters a table/column.
- RS5. A blocking call (`std::fs`, `std::net`, `std::thread::sleep`, heavy CPU loop > O(n log n) on user-controlled n) executes inside an async context without `tokio::task::spawn_blocking`. Running blocking work on the Tokio executor thread pool starves other tasks.
- RS6. A `Mutex` or `RwLock` guard is held across an `.await` point. The guard must be dropped (explicit `drop(guard)` or scope-closed) before the first `.await` in its enclosing async block.
- RS7. Unbounded concurrency: a loop spawns `tokio::spawn` tasks or pushes to a channel without a bound or semaphore, exposing the service to OOM under load → FAIL.
- RS8. A resource is acquired without a guaranteed release path: `Pool::acquire()` result stored in a plain variable without `Drop`-guarantee, a file opened without `BufReader`/RAII wrapper, or a pool acquired inside a loop where early-return paths skip the release → FAIL.
- RS9. An axum handler returns a 500-class response that echoes internal detail (DB error message, file path, stack trace) directly to the client body. Internal errors must be mapped to opaque user-facing messages; detail goes to tracing only.
- RS10. An axum extractor (`Json<T>`, `Path<T>`, `Query<T>`) is used without handling the rejection case — i.e., the handler signature accepts the extractor as a plain argument (auto-rejection) when the WU spec requires custom error shape, or the extractor type `T` derives no validation and accepts unbounded input sizes where the DoD specifies input constraints.

## Verdict format

JSON per the schema. Use rule IDs RS1-RS10. The reviewer's `reviewer` field is `"rust-safety"`.
