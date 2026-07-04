# Work Unit Schema

A Work Unit (WU) is the atomic unit of execution in the 4-phase loop. Each WU is independently verifiable, has a declared file scope, and either succeeds or fails as a whole.

## Schema

```yaml
id: WU-001                 # unique within the active plan
title: "Add LoginScreen component"
spec: |                     # 1-3 sentence problem statement
  Add a LoginScreen at src/screens/LoginScreen.tsx that
  renders email+password fields and calls existing loginUser().
dod:                        # Definition of Done — verifiable checkboxes
  - "Component renders email TextInput, password TextInput (secureTextEntry), and Submit button"
  - "Submit calls existing loginUser() from src/api/auth.ts"
  - "Empty fields show inline error 'Required'"
  - "Failure response shows 'Invalid credentials' alert"
file_scope:                 # whitelisted paths the implementer may modify
  - src/screens/LoginScreen.tsx
  - src/screens/__tests__/LoginScreen.test.tsx
deps: []                    # other WU IDs this depends on (DAG)
checkpoint: false           # if true: interactive mode waits for user after Phase 4; unattended mode resolves the validation up front in plan-readiness (no mid-cycle pause)
```

## Constraints

- **Single responsibility.** A WU does ONE thing. If you cannot describe the WU in a 1-3 sentence `spec` without conjunctions, split it.
- **Non-overlapping file scopes for parallel WUs.** Two WUs with deps satisfied may run in parallel only if their `file_scope` arrays are disjoint.
- **Verifiable DoD.** Each DoD item must be machine- or human-verifiable. "Works correctly" is not verifiable.
- **Explicit deps.** If WU-002 depends on a file WU-001 creates, declare `deps: [WU-001]`.
- **Checkpoint sparingly.** Use `checkpoint: true` only when a human must validate (e.g., visual design, store metadata, security-sensitive defaults). Every checkpoint is a workflow pause in `interactive` mode. Under `autonomy.cycle = unattended`, these validations are hoisted into the plan-ready pre-flight (Step 5a) rather than pausing mid-cycle — see `agents/mobile-orchestrator.md` → "Autonomy model".

## How the orchestrator consumes this

The `mobile-orchestrator` agent decomposes a plan into WUs at the start of execution. It writes the WU list into `.tl-telar/plans/active-plan.md` (see `./state-files.md`) and tracks per-WU phase in `.tl-telar/context/execution-state.md`.

Phase 2 VALIDATE uses `file_scope` to bound the file-scope check. **The check is content-aware baseline attribution, NOT a bare `git diff --name-only`** (see `../SKILL.md` Phase 1 baseline capture + Phase 2 step 4). A per-WU baseline of **path + state** (state = content hash for existing files, or `__DELETED__` for already-deleted paths) is captured once before attempt 1. Attribution examines the union of current-dirty paths AND baseline paths; a path is attributed to this WU when it has no baseline entry (and exists now) OR its current state differs from baseline (edited, newly-deleted, or re-created). This lets a multi-WU run proceed without committing between WUs and still correctly attribute edits AND deletions (including deletion of an earlier WU's still-untracked file). A bare `git diff --name-only`, or path-only subtraction, would self-lock the loop and miss edits/deletions — never use them for scope checks.

Phase 3 ADVERSARIAL REVIEW uses `file_scope` to determine which conditional reviewers fire (UI dirs → a11y, perf-heavy code → perf).

For the state-sentinel lifecycle (`<!-- status: in-progress -->` → `completed`), see `./state-files.md`: sub-spec 2 leaves the sentinel `in-progress`; the completed-flip + recovery lifecycle is owned by sub-spec 4.

### Parallel dispatch (the disjointness rule, enforced)

The "Non-overlapping file scopes for parallel WUs" constraint above is enforced
mechanically by `scripts/tl-telar-wu-scheduler.js`. Given `active-plan.md` +
`execution-state.md`, it returns the set of WUs whose `deps` are COMPLETE AND
whose `file_scope` is disjoint from every running WU (and internally disjoint
from each other), bounded by `execution.max_parallel_wus`. The scheduler is pure
(fs-read only); the orchestrator does the dispatch. It also flags, at plan time,
any two dependency-unordered WUs that declare the same path — an ambiguous plan
the plan-review-gate must resolve. No schema field changes: `deps` + `file_scope`
already carry everything the scheduler needs.
