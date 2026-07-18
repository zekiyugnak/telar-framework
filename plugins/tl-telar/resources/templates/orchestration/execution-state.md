# Execution State
<!-- updated: {{TIMESTAMP_ISO8601}} -->

## Active Work Units

(none yet — populated once WU dispatch begins; one line per running WU)
- {{WU-ID}} (phase {{IMPLEMENT|VALIDATE|REVIEW|COMMIT}}, retry {{0-3}})

> The orchestrator may run up to `execution.max_parallel_wus` WUs concurrently
> (default 3). Each active WU is a background subagent with its own phase and
> retry count; the 4-phase loop is per-WU, not global. A WU is dispatched only
> when its `deps` are all COMPLETE and its `file_scope` is disjoint from every
> currently-running WU — computed by `scripts/tl-telar-wu-scheduler.js`.

## Work Unit Status

| WU     | Status      | Phase     | Retries | Developer Model |
|--------|-------------|-----------|---------|-----------------|
| WU-001 | PENDING     | —         | 0       | claude          |

## Blocked / Escalated

(empty when no escalations)

## Last validation results (most recent VALIDATE phase)

- {{gate_name}}: {{PASS|FAIL}} / {{message}}
