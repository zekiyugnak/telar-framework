---
name: "orchestration-recovery"
description: "If absent: abort with `\"No in-progress plan found at .tl-telar/plans/active-plan.md. Start fresh with /tl-telar:orchestrate <task>.\"`"
source_type: "orchestration"
source_file: "skills/orchestration/recovery/SKILL.md"
---

# orchestration-recovery

Migrated from `skills/orchestration/recovery/SKILL.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- **Codex subagent gate — probe, then use or degrade (fail-closed; never fake).** Claude `Task()` calls map to Codex subagent spawns. Before EVERY multi-reviewer gate: (1) PROBE whether the current Codex surface exposes an agent-spawn tool. (2) If YES → spawn the resolver-selected reviewers as fresh, parallel Codex agent roles; preserve each role, its own rubric, and the freshness rule (no reviewer sees another's verdict or a prior iteration), then close each subagent handle before the next iteration so long runs do not exhaust the local subagent thread limit. (3) If NO → emit a literal `DEGRADED: full multi-reviewer gate unavailable on this Codex surface` line and STOP the gate. Recommend re-running on a Claude Code host or a Codex build that exposes subagent spawning. NEVER substitute a single inline self-review for the independent multi-reviewer gate, and never silently continue as if the gate passed.
- **Stack-aware roster (parity with the Claude path).** Derive the reviewer roster from `scripts/tl-telar-reviewer-roster.js` (packaged at this plugin root) against the WU `file_scope` — do NOT hardcode a mobile roster. It returns the domain-correct Security/BackendCorrectness/FrontendUX/Accessibility/Performance reviewers, each with its own rubric path, for mobile, web, backend-data, and rust changes alike.
- Treat Claude `Workflow` tool references as unavailable in Codex unless an explicit equivalent tool is present. Use the documented prose fallback path by default.
- Treat `TL_TELAR_ORCHESTRATED=1` as a workflow mode marker in Codex. Do not require a literal Claude slash command to set it.
- Do not pass scheduler `--isolate` merely because Codex is running. Use `--isolate` only after a concrete Codex worktree isolation and merge-back mechanism has been verified for the run; otherwise keep disjoint file-scope serialization.


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
3. `.tl-telar/context/execution-state.md` — active work units (0 to max_parallel_wus), each with its own phase + retry count + last validation results. REQUIRED for resuming at the correct frontier; if missing, prompt the user with "execution-state missing; recompute the frontier from active-plan.md, or start fresh?"

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
Resume this plan? ({{N}} active work unit(s): {{list}})
1. Resume (re-run the scheduler and continue the frontier)
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
