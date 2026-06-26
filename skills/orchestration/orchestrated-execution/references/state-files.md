# State Files (Sub-spec 2 Subset)

Originally sub-spec 2 wrote two of the three state files; the third (`project-context.md`) plus the status-sentinel lifecycle (in-progress → completed) and recovery were added in sub-spec 4. As of sub-spec 4 all three state files are operational. This reference describes the current shipped behavior.

## `.tl-telar/plans/active-plan.md`

Written by the orchestrator agent ONCE per plan, after the user approves the WU decomposition. Updated only when the plan itself changes (e.g., gate FAIL → plan revision).

```markdown
# Active Plan
<!-- approved: 2026-05-17T12:34:00Z -->
<!-- gate-iterations: 1 -->
<!-- user-approved: true -->
<!-- status: in-progress -->

## Goal
{{user-supplied goal in 1-2 sentences}}

## User request (verbatim)
{{captured at /tl-telar:orchestrate invocation}}

## Work Units

### WU-001: <title>
- spec: ...
- dod:
  - [ ] item 1
  - [ ] item 2
- file_scope:
  - path1
- deps: []
- checkpoint: false

### WU-002: <title>
...
```

The `<!-- status: in-progress -->` HTML comment is the load-bearing recovery sentinel. The `mobile-orchestrator` agent flips it to `completed` at successful Step 8 close (cross-platform `sed`); the `recovery` skill consumes the sentinel on SessionStart and prompts the user when an in-progress plan is found.

## `.tl-telar/context/execution-state.md`

Written after EVERY phase transition. Atomic — the orchestrator writes a complete snapshot, never partial updates.

```markdown
# Execution State
<!-- updated: 2026-05-17T13:00:00Z -->

## Current Position
- Active work unit: WU-002
- Current phase: VALIDATE
- Retry count: 0

## Work Unit Status

| WU     | Status      | Phase     | Retries | Writer Model |
|--------|-------------|-----------|---------|--------------|
| WU-001 | COMPLETE    | COMMITTED | 0       | claude       |
| WU-002 | IN-PROGRESS | VALIDATE  | 1       | codex        |
| WU-003 | PENDING     | —         | 0       | —            |

> The `Writer Model` column records which model implemented each WU. Required for cross-model review (sub-spec 8) to exclude the writer from the reviewer pool. Values: `claude | codex | gemini`.

## Blocked / Escalated
(empty when no escalations)

## Last validation results (most recent VALIDATE phase)
- coverage_command: PASS / `Coverage 87% passes threshold 80%`
- file_scope_check: PASS
- (other gates as configured in `.tl-telar-thresholds.json`)
```

## State writes added in sub-spec 4 (shipped)

- `.tl-telar/context/project-context.md` — orchestrator creates it at Step 5 (WU decomposition) from `resources/templates/orchestration/project-context.md` and appends a completed-WU row at each Phase 4 COMMIT-READY.
- Status flip `in-progress` → `completed` — orchestrator Step 8 (cross-platform sed); execution-state.md is archived as `execution-state-<timestamp>.md` at the same time. Recovery skill consumes the sentinel.

## Still pending (later sub-specs)

- `.tl-telar/context/evidence/<wu>/<phase>.png` — simulator screenshots (sub-spec 4 ships the directory under `.tl-telar/context/evidence/`; actual screenshot capture is deferred — see master design §2.5.1 evidence path note).
