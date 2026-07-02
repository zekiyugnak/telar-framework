---
id: recovery
category: skill
impact: HIGH
impactDescription: Restores orchestrator state after compaction or cross-session resume. Reads the 3 state files, runs bd-prime-equivalent retrieval, resumes from the recorded WU+phase. Without this, compaction during a long orchestrated run loses all in-flight context.
tags: [orchestration, recovery, state-machine, resilience]
capabilities:
  - Detect <!-- status: in-progress --> sentinel in .tl-telar/plans/active-plan.md
  - Read project-context.md, execution-state.md to reconstruct in-flight state
  - Call scripts/tl-telar-prime.sh --work-type recovery for KB facts
  - Announce resume position to user and await confirmation
  - Hand control back to mobile-orchestrator at the recorded phase
useWhen:
  - SessionStart hook flagged an in-progress plan
  - User invoked /tl-telar:resume explicitly
  - mobile-orchestrator agent boots and finds the in-progress sentinel
---

# Recovery (Orchestrated Mode)

## Trigger condition (binding)

This skill is loaded only via:

1. `/tl-telar:resume` (sets TL_TELAR_ORCHESTRATED=1).
2. The `mobile-orchestrator` agent at boot when it detects `<!-- status: in-progress -->` in `.tl-telar/plans/active-plan.md` AND no plan in current conversation context.
3. SessionStart hook prompted the user to recover and the user confirmed.

This skill is NEVER auto-triggered from legacy mobile commands.

## Procedure

### Step 1: Sentinel check

```bash
[[ -f .tl-telar/plans/active-plan.md ]] && grep -q '<!-- status: in-progress -->' .tl-telar/plans/active-plan.md
```

If absent: abort with `"No in-progress plan found at .tl-telar/plans/active-plan.md. Start fresh with /tl-telar:orchestrate <task>."`

### Step 2: Read 3 state files

In order:

1. `.tl-telar/plans/active-plan.md` — the approved plan + WU list. REQUIRED. If missing, abort recovery (no in-progress plan to resume).
2. `.tl-telar/context/project-context.md` — tooling, completed WUs, patterns. **Tolerated when missing**: orchestrator should create this at Step 5 (WU decomposition) so recovery during WU-001 finds it, but if absent (e.g., orchestrator died between Step 4 and Step 5), recovery treats it as an empty template — Tooling unknown, no completed WUs, no patterns — and continues. Do NOT abort recovery on this file alone.
3. `.tl-telar/context/execution-state.md` — current WU + phase + retry count + last validation results. REQUIRED for resuming at the correct phase; if missing, prompt the user with "execution-state missing; resume from WU-001 Phase 1, or start fresh?"

Quote each file's metadata block back to the user so they can verify the recovery is targeting the right plan:

```markdown
## Recovery candidate

- Plan approved: {{<!-- approved: ... --> from active-plan.md}}
- Gate iterations: {{<!-- gate-iterations: N -->}}
- Status: {{<!-- status: in-progress -->}}
- Last execution-state update: {{<!-- updated: ... -->}}
- Active Work Units: {{list from 'Active Work Units' section — each entry's WU id, phase, and retry count}}
```

### Step 3: KB priming

```bash
bash $PLUGIN_ROOT/scripts/tl-telar-prime.sh --work-type recovery --json
```

In sub-spec 4 this is a stub (returns empty facts). Sub-spec 5 fills it in.

### Step 4: User confirmation

Ask the user:

```
Resume from WU-<id>, Phase <phase>, retry <N>?
1. Resume (continue from the recorded position)
2. Start fresh (mark this plan abandoned, archive it, return to /tl-telar:orchestrate)
3. Inspect first (open the state files for me; do not advance)

Choice [1/2/3]?
```

### Step 5a: Resume

Flip back to the mobile-orchestrator agent's main flow (Step 6 — WU execution — continuous-frontier dispatch). Do NOT jump to a single recorded WU+phase — re-run `scripts/tl-telar-wu-scheduler.js` against the current `active-plan.md` + `execution-state.md` to reconstruct the ready frontier and occupied-file set from scratch. Any row still marked IN-PROGRESS whose background task no longer exists is reconciled per Step 6 step 5 (reset to PENDING for retry, or escalated) rather than resumed in place. Spawn FRESH `Task()` instances for whatever the recomputed frontier says to dispatch next — never reuse a pre-compaction/pre-session agent ID for ANY WU, in-flight or not.

> Recovery runs in the **main session** (via `/tl-telar:resume`, or the main-session conductor detecting the sentinel at boot) — that is why these `Task()` spawns work. Never run recovery or the orchestrator as a subagent; a subagent has no `Task` tool and cannot resume the WU cycle. See `agents/mobile-orchestrator.md` → "Execution context".

### Step 5b: Start fresh

```bash
# Cross-platform sed for the status flip (macOS BSD vs GNU)
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' 's/<!-- status: in-progress -->/<!-- status: abandoned -->/' .tl-telar/plans/active-plan.md
else
  sed -i 's/<!-- status: in-progress -->/<!-- status: abandoned -->/' .tl-telar/plans/active-plan.md
fi
# Archive the old execution-state.md
TS=$(date -u +%Y%m%dT%H%M%SZ)
mv .tl-telar/context/execution-state.md .tl-telar/context/execution-state-$TS.md 2>/dev/null || true
```

Then prompt user for a new `/tl-telar:orchestrate <task>`.

### Step 5c: Inspect

Open each state file via Read tool (or `cat` and show contents). Do not advance. Let the user decide what to do next.

## Anti-patterns

1. **Reusing a pre-compaction Task() agent ID via SendMessage.** Compaction-recovery means the conversation context is degraded; reviewers/implementers spawned via old agent IDs may have stale or missing context. Always FRESH.
2. **Auto-resuming without user confirmation.** Even when SessionStart prompted recovery, the user must explicitly choose Resume. Silent resumption surprises the user when they meant to start fresh.
3. **Modifying the plan during recovery.** Recovery is read+confirm only. If the plan needs changes, choose "start fresh" or revise via `/tl-telar:review-plan --iteration N+1`.
4. **Skipping the KB prime call.** Even when sub-spec 4's prime is a stub, the call is part of the contract — sub-spec 5's implementation must work without retro-fitting recovery skill.

## Tests / conformance

Run `node scripts/validate-skills.js` (orchestration-namespace checks). Manual verification: simulate recovery by leaving an in-progress plan, then running `/tl-telar:resume`.
