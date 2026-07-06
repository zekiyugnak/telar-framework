---
name: "orchestration-adversarial-code-review"
description: "`--default-domain` comes from the project-detect framework signal (orchestrator Step 5b / project-context); it only decides how UI files with no strong path marker are classified. The resolver returns JSON `{ domains, re"
source_type: "orchestration"
source_file: "skills/orchestration/adversarial-code-review.md"
---

# orchestration-adversarial-code-review

Migrated from `skills/orchestration/adversarial-code-review.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- Codex compatibility override: references to Claude `Task()` mean Codex subagent workflows. Spawn fresh Codex subagents in parallel when the current Codex surface exposes subagent tools; preserve the same reviewer roles, inputs, and freshness rules.
- If the current Codex surface cannot spawn subagents, stop and report that the full orchestration gate is unavailable in this surface. Do not replace a required multi-reviewer gate with a single inline self-review.
- After each Codex subagent batch returns, close completed subagent handles before starting any retry iteration or later gate; otherwise long orchestration runs can exhaust the local subagent thread limit.
- Treat Claude `Workflow` tool references as unavailable in Codex unless an explicit equivalent tool is present. Use the documented prose fallback path by default.
- Treat `TL_TELAR_ORCHESTRATED=1` as a workflow mode marker in Codex. Do not require a literal Claude slash command to set it.
- Do not pass scheduler `--isolate` merely because Codex is running. Use `--isolate` only after a concrete Codex worktree isolation and merge-back mechanism has been verified for the run; otherwise keep disjoint file-scope serialization.


# Adversarial Code Review (Sidecar)

## Trigger condition (binding)

This skill is loaded only via:

1. `skills/orchestration/orchestrated-execution` Phase 3 (the 4-phase loop dispatches this).
2. The `mobile-orchestrator` agent's workflow when Phase 3 is reached.
3. Explicit user request such as "run adversarial code review on this diff".

This skill is NEVER auto-triggered from legacy mobile commands. `/tl-telar:review-code` continues to use `skills/review-gates.md` (the original, untouched) with its existing P1/P2/P3 block semantics. See master design §2.8 SIDECAR strategy.

## What this skill does

For a given Work Unit (with declared `fileScope`, `dod`, and `diff`):

1. **Determine reviewer roster** with the stack-aware resolver — do NOT hardcode a mobile roster:

   ```bash
   node scripts/tl-telar-reviewer-roster.js --default-domain <mobile|web> <every path in fileScope>
   ```

   `--default-domain` comes from the project-detect framework signal (orchestrator Step 5b / project-context); it only decides how UI files with no strong path marker are classified. The resolver returns JSON `{ domains, reviewers: [{ role, reviewer_key, rubric, model, reason }] }`. Spawn EXACTLY that set — it is stack-aware, so a web/admin or backend WU never gets a mobile rubric:
   - Always: **Code** (generic rubric) + one **Security** reviewer per in-scope domain (`mobile-security` | `web-security` | `backend-data-security` | `rust-safety`).
   - Backend/service in scope → **BackendCorrectness** (data-integrity + reliability + API-contract).
   - UI in scope → **FrontendUX** (states + i18n) + **Accessibility** (per UI domain).
   - Perf-sensitive paths → **Performance** (per UI domain).
   - Every reviewer carries `model: opus` (gate-quality pin) and its own `rubric` path — use those verbatim.
   - Store Compliance is NOT spawned here; it's reserved for `/tl-telar:release-app`-bound work.

   A WU whose fileScope spans many domains (e.g. backend + web) yields a large roster — that is a signal the WU is doing too much and should have been split, not a resolver bug.
2. **Spawn N fresh `Task()` subagents in parallel**, one per active reviewer role. Each gets the corresponding rubric path and the WU context. See `./references/spawn-prompts.md` if you create one; otherwise inline the prompt skeleton below.
3. **Aggregate verdicts**. Any single FAIL → overall FAIL.
4. **Return** to caller (the orchestrator) with the aggregated verdict.

## Spawn invariant (binding)

> **EVERY review pass spawns NEW `Task()` instances. Reviewers MUST be fresh — never reuse a prior reviewer's `Task()` handle, never paste in another reviewer's verdict, never include earlier iteration findings. A reviewer sees ONLY: WU spec + DoD + fileScope + git diff + the relevant rubric file path. This is non-negotiable.**

> **Top-level caller required.** This skill must be loaded by the **main-session** orchestrator (a Claude Code subagent has no `Task` tool and cannot spawn these reviewers — see `agents/mobile-orchestrator.md` → "Execution context"). If `Task` is unavailable, STOP and report — never substitute a single inline self-review for the fresh reviewer spawns. The same applies to the cross-model path: dispatching Codex/Gemini via the external-tools script is only reached from the main-session loop.

## Reviewer spawn skeleton

For each active role, dispatch a `Task()`:

```text
Description: "Adversarial review — <role>"
Subagent type: general-purpose
Model: opus   # binding: EVERY adversarial reviewer runs on Opus regardless of the
              # session model. This gate is the last line of defense — it is pinned
              # to the highest-reasoning tier, never left to inherit a cheaper
              # session model (e.g. Fable/Sonnet). If the running Claude Code build
              # cannot set a per-Task model, STOP and report; do not silently let
              # reviewers inherit the session model.
Prompt:
  You are the <ROLE> ADVERSARIAL REVIEWER of a software change.

  Mode: Adversarial. Your job is to FIND FAILURES, not to approve, not to
  suggest improvements. You have NO context from previous reviews.

  Read the rubric at: <rubric-path from the resolver's `rubric` field for this reviewer>
  (The resolver selects the domain-correct rubric — generic code, {mobile|web|backend-data|rust}
  security, backend-correctness, frontend-ux, {mobile|web} accessibility, or {mobile|web}
  performance. Never substitute a mobile rubric on a web/backend reviewer.)

  Apply the criteria. Cite findings with rule IDs.

  Output a single JSON object matching the schema at
  skills/orchestration/plan-review-gate/references/verdict-schema.md
  with `reviewer: "<role-key>"`. No prose outside the JSON.

  ---
  WORK UNIT SPEC:
  {{wuSpec}}

  DoD ITEMS:
  {{dodList}}

  FILE SCOPE:
  {{fileScope}}

  DIFF UNDER REVIEW (git diff):
  {{diff}}

  ITERATION: {{iteration}}
  ---
```

## Aggregation

Build the aggregated verdict matching the sub-spec 1 schema's aggregation shape:

```json
{
  "overall_verdict": "PASS|FAIL",
  "iteration": "<N>",
  "blocking_reviewers": ["<role keys with FAIL>"],
  "all_blockers": ["<concatenated>"],
  "all_advisories": ["<concatenated, dedup by rule+file+line>"],
  "max_iterations_reached": "<N >= 3>"
}
```

`overall_verdict` is PASS only when ALL active reviewers returned PASS.

## Per-criterion verification & findings write-back

Two additions that improve traceability without touching the spawn invariant:

1. **Per-criterion DoD verification.** Each reviewer maps every DoD item to an explicit verdict — `met` / `not-met` / `not-verifiable-from-diff` — reported in its JSON (a `dod_verdicts` array alongside the schema's existing fields, or within its findings list). A DoD item is `met` only with evidence in the diff (a code path, test, or assertion). "Looks done" is not evidence — see `verification-before-completion`. A blanket pass that does not address each DoD item individually is itself a defect.
2. **Findings write-back (caller side, after aggregation).** After the verdict is aggregated, the caller (orchestrator) writes a `## Code Review Findings` block under the WU in `.tl-telar/context/execution-state.md` containing: overall verdict, per-reviewer blockers/advisories (with rule IDs and `file:line`), and the merged per-criterion DoD table. Only then tick the DoD checkboxes in `PLAN.md`/`PROGRESS.md` that **every** reviewer marked `met` — never tick a box on a `not-met` or `not-verifiable` criterion. Reviewers never write these files; the caller does, preserving the read-only-reviewer separation.

## Anti-patterns (do NOT do these)

1. **Spawning reviewers in series instead of parallel.** They are independent; use parallel `Task()` calls. Serial dispatch wastes wall time and may cause one verdict to leak into another via shared conversation state.
2. **Reusing a reviewer Task() on retry.** Same as sub-spec 1's discipline — fresh instance every time.
3. **Including the WU's previous diff or prior findings in the spawn prompt.** Reviewers see only the current diff.
4. **Skipping conditional reviewers because "the diff doesn't look UI-y to me".** The file-scope intersection is the authoritative trigger. If `screens/Login.tsx` is in scope, a11y reviewer fires even if the diff happens to only change a util.
5. **Returning a "soft pass" when 1 of 3 reviewers fails.** Any FAIL → overall FAIL.

## Cross-model review — additive SECOND review (sub-spec 8, Phase γ)

**This does NOT replace the main-model review above — it ADDS a second, independent one.** When `.tl-telar/external-tools.yaml` → `cross_model_review.enabled: true`, every orchestrated WU gets TWO reviews and BOTH must PASS:

- **Review 1 — main model (always runs):** the fresh Claude reviewer roster determined above (Code Quality + Mobile Security + any conditional roles). Existing sub-spec 2 behavior; runs whether or not cross-model is enabled.
- **Review 2 — cross-model (only when enabled):** ONE additional review of the WU diff by a model different from both the writer AND Claude, dispatched through the external-tools adapter. A genuinely independent second opinion.

Overall verdict = PASS **iff Review 1 PASSES AND Review 2 PASSES**. Any FAIL from either → overall FAIL → loop back to Phase 1. When `enabled: false`, only Review 1 runs (unchanged from sub-spec 2).

### Selecting the Review 2 model

1. Read the writer model from `.tl-telar/context/execution-state.md` (default `claude`).
2. Candidates = `cross_model_review.matrix[<writer>]` MINUS `claude` (already used by Review 1) MINUS the writer itself. So writer=`claude` → candidates `[codex, gemini]`; writer=`codex` → `[gemini]`.
3. Pick the first candidate whose adapter is `enabled: true` AND health passes AND budget allows, then dispatch the WU diff:
   `scripts/tl-telar-external-tools.sh dispatch --task review --tool <model> --rubric-file <rubric> --spec-file <wu-spec> ...`
4. If NO candidate is available (none enabled/healthy/in-budget, or the only other model is Claude itself), apply `cross_model_review.on_unavailable` (default `block`) — see enforcement below.

### Recording both reviews

Record both in `.tl-telar/context/execution-state.md` under the WU, e.g. `Reviews: R1 claude (Code-Quality PASS, Mobile-Security PASS); R2 codex (PASS)`, so "did the second model actually review?" is auditable from state — not merely inferable from the budget ledger.

### Required-mode enforcement (`enabled: true` ⇒ the SECOND review is REQUIRED)

`on_unavailable` decides what happens when the Review 2 model cannot run:

- **`block` (default):** STOP the gate and escalate — the required second review cannot run, so the WU does NOT pass on Review 1 alone:
  > "Cross-model (second) review is required (`cross_model_review.enabled: true`) but no distinct reviewer model is available: `<health/budget reason>`. Options: (1) fix the adapter (auth/budget); (2) set `cross_model_review.on_unavailable: warn_and_proceed` to accept Review-1-only for this run (logged); (3) set `cross_model_review.enabled: false` to disable the second review. Do not proceed silently."
- **`warn_and_proceed`:** SKIP Review 2 (do NOT re-review with Claude — Review 1 already is Claude), proceed on Review 1 alone, and record a LOUD downgrade in execution-state "Cross-model fallbacks" + the WU's COMMIT-READY line. Never silent.

**Proof-of-execution (audit — catches a bypassed or silently-skipped second review).** When `enabled: true` and `on_unavailable: block`, after Phase 3 confirm `.tl-telar/context/external-tools-budget.jsonl` gained an entry for this WU (proof Review 2 ran) OR a logged downgrade exists. If neither → the required second review did not run: defect, STOP and report. (A WU "reviewed" only by a generic `comprehensive-review:code-reviewer`, bypassing this skill, leaves no ledger entry — this assertion would have caught the E50 silent-skip.)

### Writer-cannot-be-reviewer rule

The matrix encodes this:
```yaml
cross_model_review:
  matrix:
    codex: ["gemini", "claude"]
    gemini: ["codex", "claude"]
    claude: ["codex", "gemini"]
```

A reviewer is never the same model as the writer. Additionally, **Review 2 must differ from Claude** (Review 1's model) — never let the second review collapse onto Claude (that would just be Review 1 twice). The implementation MUST verify both invariants — if the matrix is misconfigured (e.g., user adds `claude` to claude's list), reject the config at startup with an error message.

### Verdict parsing (cross-model)

External-adapter reviewers return the JSON envelope from `scripts/tl-telar-external-tools.sh dispatch`. The actual model verdict is inside the envelope's `raw_log` field. Pipe through:

```bash
echo "$envelope" > /tmp/envelope.json
bash $PLUGIN_ROOT/scripts/tl-telar-external-tools.sh parse-verdict /tmp/envelope.json
```

The output is `{verdict: "PASS"|"FAIL"|"UNKNOWN", issues: [...], reason?: "..."}`. UNKNOWN → treat as FAIL with synthetic blocker.

### Budget circuit breaker integration

Each Review 2 dispatch hits the dispatcher's budget preflight (sub-spec 7). On `cost_limit_exceeded`, treat it as "Review 2 model unavailable" and apply `on_unavailable` (default `block`):
- `block` (default): STOP + escalate per "Required-mode enforcement" — over-budget never becomes a silent single-review pass.
- `warn_and_proceed`: skip Review 2, proceed on Review 1, log the cost-cap reason LOUDLY under "Cross-model fallbacks".
- Either way: NEVER silently degrade — the user must see that the second review did not run.

### Anti-patterns specific to cross-model

1. **Treating Review 2 as a REPLACEMENT for Review 1.** It is ADDITIVE. The main-model Claude roster (Review 1) always runs; Review 2 is an extra independent pass on top. Never drop Review 1 because "Codex reviewed".
2. **Silently skipping Review 2 when enabled.** With `on_unavailable: block` (default) a missing second-review model BLOCKS; with `warn_and_proceed` it is loudly logged — never silent.
3. **Letting Review 2 collapse onto Claude.** Review 2 must be distinct from the writer AND from Claude. "Fallback to Claude" for Review 2 is meaningless (Review 1 is already Claude) — the correct degradation is skip-with-warning or block.
4. **Letting a generic reviewer stand in for this skill in orchestrated mode.** Per-WU review MUST go through this skill (Review 1 + cross-model Review 2). A generic `comprehensive-review:code-reviewer` that never reads `external-tools.yaml` silently skips Review 2 — forbidden.
5. **Sending the writer's diff to the writer's own model.** The matrix enforces exclusion; never bypass.
6. **Treating adapter raw_log as the verdict directly.** Always pass through `parse-verdict`; envelope and model verdict are distinct contracts.
7. **Ignoring the writer-cannot-be-reviewer / distinct-second-model invariant.** Validate at the startup preflight and on first cross-model invocation.

## Tests / conformance

Run `node scripts/validate-skills.js` (validates this skill's structure including the orchestration namespace checks). Run `bash scripts/check-sidecar-routing.sh` to assert legacy `/tl-telar:review-code` does not load this skill.
