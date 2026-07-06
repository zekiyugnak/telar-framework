# Backend & Service Correctness Adversarial Rubric

## Purpose

Used by the always-on Adversarial Backend & Service Correctness Reviewer in `skills/orchestration/adversarial-code-review.md`. Extends the generic adversarial rubric with data-integrity, reliability, and API-contract failure modes for service-layer and database changes.

## Reviewer mode

**Adversarial.** Same discipline as the generic rubric: fresh `Task()` instance, sees only WU spec + DoD + file scope + diff. Binary PASS/FAIL.

## Evaluation criteria

### DI. Data integrity

A WU FAILS data integrity review if any of:

- DI1. A migration that can lose or overwrite existing rows (DROP COLUMN, column type narrowing, UPDATE without WHERE) is introduced without a guard or a backfill that preserves the data invariant stated in the WU spec.
- DI2. An invariant the WU relies on (referential integrity, uniqueness, non-null value, bounded range) is missing a corresponding FK / UNIQUE / NOT NULL / CHECK constraint in the schema.
- DI3. A migration or seed script is non-idempotent or non-reentrant: re-running it produces duplicate rows, constraint violations, or data loss instead of a no-op.
- DI4. A multi-step write that must succeed or fail atomically is not wrapped in a single transaction, leaving a partial-commit window where the data is in an inconsistent intermediate state.
- DI5. A check-then-act business-logic sequence (read a value, decide, write based on it) has no lock, unique constraint, or `SELECT … FOR UPDATE` to prevent a concurrent writer from invalidating the check between the two steps.
- DI6. A column's nullability or default value in the migration contradicts the domain requirement stated in the WU spec (e.g., spec says "required" but column allows NULL with no NOT NULL constraint).

### RL. Reliability & resilience

A WU FAILS reliability & resilience review if any of:

- RL1. A call to an external service, network endpoint, or I/O resource is made with no timeout configured, leaving the caller indefinitely blocked on a slow or unresponsive dependency.
- RL2. A side-effecting endpoint (charge, send, enqueue, provision) is reachable by a retry-capable client but is NOT idempotent — repeated calls produce double-charges, duplicate records, or duplicate side effects.
- RL3. A retry or backoff mechanism is added on a non-idempotent operation, or a transient-failure path has no retry at all when the operation is idempotent and the WU spec requires it.
- RL4. A partial failure (one step of a multi-step operation) leaves the system in an inconsistent state with no compensation, rollback, or saga step defined to restore consistency.
- RL5. A failure path produces no structured error log, metric, or trace span — silent failures make the failure mode unobservable in production.
- RL6. A data structure, queue, connection pool, goroutine, or in-memory collection can grow without bound under sustained load with no eviction policy, cap, or back-pressure mechanism.

### AC. API contract

A WU FAILS API contract review if any of:

- AC1. An existing response field is removed, renamed, or its type is changed (e.g., string → integer, object → array) without a versioning strategy, breaking clients that depend on the current shape.
- AC2. A new field is added to a request as REQUIRED with no default value, breaking existing callers that do not send the field.
- AC3. A new or modified endpoint returns HTTP status codes or an error envelope shape that is inconsistent with the rest of the API (e.g., uses a different top-level error key, wraps errors differently), without the WU spec explicitly defining a new envelope standard.
- AC4. An enum value set or a DB CHECK constraint's allowed values are changed in a way that is not backward-compatible with already-shipped clients that serialized or pinned the old value set.
- AC5. The API contract changed (new field, new route, changed shape, changed auth requirement) with no corresponding update to the OpenAPI spec, JSON schema, or generated types.

## Verdict format

JSON per the schema. Use rule IDs DI1–DI6, RL1–RL6, and AC1–AC5. The reviewer's `reviewer` field is `"backend-correctness"`.
