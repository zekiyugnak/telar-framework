---
name: "orchestrate"
description: "End-to-end orchestrated execution. Takes a feature description and drives the entire pipeline — plan, plan review (3 fresh reviewers), WU decomposition, 4-phase execution loop per WU, final review, COMMIT-READY emit. Honors user's git policy (no auto-commit)."
source_type: "command"
source_file: "commands/orchestrate.md"
---

# orchestrate

Migrated from `commands/orchestrate.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- In Codex, this skill is the replacement for the Claude slash command `/tl-telar:orchestrate`; invoke it as `$orchestrate` or through `@tl-telar`.
- Do not require Claude slash-command dispatch or Claude-only environment setup before following the workflow.
- When the original command says to load `skills/orchestration/<name>`, load the generated Codex skill at `../orchestration-<name>/SKILL.md` first. The original source copy also exists under `../../source/skills/orchestration/<name>/SKILL.md` for exact Telar-source references.
- **Codex subagent gate — probe, then use or degrade (fail-closed; never fake).** Claude `Task()` calls map to Codex subagent spawns. Before EVERY multi-reviewer gate: (1) PROBE whether the current Codex surface exposes an agent-spawn tool. (2) If YES → spawn the resolver-selected reviewers as fresh, parallel Codex agent roles; preserve each role, its own rubric, and the freshness rule (no reviewer sees another's verdict or a prior iteration), then close each subagent handle before the next iteration so long runs do not exhaust the local subagent thread limit. (3) If NO → emit a literal `DEGRADED: full multi-reviewer gate unavailable on this Codex surface` line and STOP the gate. Recommend re-running on a Claude Code host or a Codex build that exposes subagent spawning. NEVER substitute a single inline self-review for the independent multi-reviewer gate, and never silently continue as if the gate passed.
- **Stack-aware roster (parity with the Claude path).** Derive the reviewer roster from `scripts/tl-telar-reviewer-roster.js` (packaged at this plugin root) against the WU `file_scope` — do NOT hardcode a mobile roster. It returns the domain-correct Security/BackendCorrectness/FrontendUX/Accessibility/Performance reviewers, each with its own rubric path, for mobile, web, backend-data, and rust changes alike.
- Treat Claude `Workflow` tool references as unavailable in Codex unless an explicit equivalent tool is present. Use the documented prose fallback path by default.
- Treat `TL_TELAR_ORCHESTRATED=1` as a workflow mode marker in Codex. Do not require a literal Claude slash command to set it.
- Do not pass scheduler `--isolate` merely because Codex is running. Use `--isolate` only after a concrete Codex worktree isolation and merge-back mechanism has been verified for the run; otherwise keep disjoint file-scope serialization.


# /tl-telar:orchestrate

Runs the `mobile-orchestrator` playbook **in this (main) session**. Sets the orchestrated-mode trigger (`TL_TELAR_ORCHESTRATED=1`) so all orchestrated-namespace skills activate per master design §1.1.

## Execution context (binding — do NOT spawn the orchestrator as a subagent)

The orchestrator is a **conductor**: its job is to spawn fresh `Task()` subagents — 3 plan reviewers, 6 design reviewers, per-WU implementers, and 2–4 per-WU adversarial reviewers (master design §2.6 Phase α: "All reviewers, implementers spawned as `Task()`"). A Claude Code subagent **cannot use the `Task` tool** — subagents cannot spawn subagents. Therefore the conductor MUST run at the top level.

**So this command does NOT call `Task(subagent_type=mobile-orchestrator)`.** Instead, the main session itself adopts the orchestrator role: read `agents/mobile-orchestrator.md` and execute that playbook directly, in this session, keeping `Task` available for the reviewer/implementer spawns. Spawning the orchestrator as a subagent silently degrades every multi-reviewer gate to a single inline pass (destroying reviewer independence) and makes per-WU execution impossible.

## Behavior

1. Set orchestrated mode (`TL_TELAR_ORCHESTRATED=1`).
2. Capture the user's input verbatim — either the free-text task description, or the `--epic <path>` / `--plan-file <path>` argument (see "Input modes" below).
3. **Load `agents/mobile-orchestrator.md` and follow it as the main-session conductor** (do NOT spawn it as a subagent). Acting as the orchestrator, you then:
   - Run the boot probe (`.tl-telar/` skeleton, safe-default thresholds).
   - Wait for / produce an implementation plan — UNLESS `--epic`/`--plan-file` was given, in which case that file IS the plan (drafting is skipped).
   - Invoke `skills/orchestration/plan-review-gate` (sub-spec 1 deliverable) — spawning 3 fresh reviewer `Task()`s from this session.
   - On PASS: decompose into WUs, write `.tl-telar/plans/active-plan.md`, wait for user approval.
   - Drive WUs through `skills/orchestration/orchestrated-execution` (4-phase loop) using the **continuous-frontier dispatch loop** (see `agents/mobile-orchestrator.md` → "WU execution — continuous-frontier dispatch"): `scripts/tl-telar-wu-scheduler.js` computes which WUs are ready (deps COMPLETE + `file_scope` disjoint from running WUs), bounded by `execution.max_parallel_wus` (default 3). Up to that many WUs run as concurrent background `Task()`s from this session; the frontier is recomputed on each WU completion.
   - Emit a COMMIT-READY signal for each WU (DOES NOT commit on user's behalf).
   - Final review and "Ready for PR" summary.
   - **Spec Layer archive (conditional).** Run `node scripts/tl-telar-spec-archive.js <change-id>` ONLY if this run actually produced a Spec Layer change — i.e. a `tl-telar-spec/changes/<change-id>/` with a `REQUIREMENTS.delta.md` exists (created when requirements were gathered via `skills/requirements-gather.md` → "Step 0"). It merges the delta(s) into `tl-telar-spec/truth/` and moves the change folder to `tl-telar-spec/changes/archive/<date>-<id>/`. If no such change dir exists, SKIP this step — do not run the archive with an unbound/nonexistent `<change-id>` (it would abort with "change directory not found"). **Note:** the orchestrator's own working artifacts live under `.tl-telar/plans/active-plan.md`, which is NOT a Spec Layer change; automatic creation of a `tl-telar-spec/changes/<id>/` from within the orchestrator playbook is not yet wired (deferred — see `docs/superpowers/specs/2026-07-02-telar-spec-layer-design.md`). Today the Spec Layer is exercised through the legacy `/tl-telar:add-feature` / `/tl-telar:create-app` / `/tl-telar:update-requirement` commands, which invoke Step 0.

## Input modes

The orchestrator accepts the work to do in one of three forms. All three converge on the same pipeline at the Plan Review Gate (Step 4) — the only difference is how the plan gets produced.

| Mode | Invocation | Plan drafting (Step 3) | Best for |
|---|---|---|---|
| **Free-text** | `/tl-telar:orchestrate <description>` | Orchestrator drives/produces a PLAN.md, then reviews it | Quick start; you don't have a plan yet |
| **Epic file** | `/tl-telar:orchestrate --epic <path>` | **Skipped** — the epic file IS the plan; its `## Task` sections decompose 1:1 into WUs | A prepared single-feature epic (authored from `templates/epic.md`) |
| **Plan file** | `/tl-telar:orchestrate --plan-file <path>` | **Skipped** — the PLAN.md is reviewed and decomposed directly | You already maintain a WU-decomposable PLAN.md |

**Epic / plan-file rules:**
- One feature per file. An epic spanning several independent features is not one plan — split it and run the command per file.
- The file still goes through the mandatory 3-reviewer Plan Review Gate. `--epic`/`--plan-file` skips *drafting*, never *review*.
- Author epics from `templates/epic.md` — its task fields mirror the Work Unit schema, so decomposition is mechanical.
- If the file's `## Intent` (epic) or goal (plan) is missing, the Scope-Alignment reviewer will stop and ask for the original request.

## Autonomy (`autonomy.cycle` in `.tl-telar-thresholds.json`)

- **`interactive`** (default) — the run may pause at `checkpoint: true` WUs and at self-reflect.
- **`unattended`** — exactly ONE human gate: the plan-ready approval (Step 5), which first clarifies UI (ASCII drafts signed off) and collects all secrets/inputs. After "go", the WU cycle runs to PR-ready with no pauses. UI/visual sign-off is hoisted to plan-readiness, never mid-cycle; an uncollected decision STOPs as a pre-flight defect rather than being guessed. See `agents/mobile-orchestrator.md` → "Autonomy model".

## Usage examples

```
/tl-telar:orchestrate Add a login screen with email + password
/tl-telar:orchestrate Wire up Stripe subscription billing for the Pro tier
/tl-telar:orchestrate Refactor the bottom tab navigator to use Material 3 conventions
/tl-telar:orchestrate --epic docs/epics/user-profile.md
/tl-telar:orchestrate --plan-file docs/plans/checkout-flow.md
```

## What this command does NOT do

- Does NOT git add or git commit. User policy is "ben yapacagim" (user handles git manually). The orchestrator emits COMMIT-READY signals with suggested messages.
- Does NOT skip plan review even if the user says "this plan is obviously fine." The 3-reviewer gate is mandatory.
- Does NOT loop past 3 retries on any gate. Escalates to user with structured options.
- Does NOT change legacy commands' *review/build* behavior — `/tl-telar:add-feature`, `/tl-telar:create-app`, and `/tl-telar:update-requirement` still don't route through this orchestrator's plan/design gates. They DO now share the same Spec Layer artifact location (`tl-telar-spec/changes/<id>/`, `tl-telar-spec/truth/<domain>/`) as this command — see `docs/superpowers/specs/2026-07-02-telar-spec-layer-design.md`. (`/tl-telar:migrate-app` is intentionally NOT included — it doesn't invoke `requirements-gather` or produce a REQUIREMENTS.md.)

## Comparison with legacy commands

| Legacy | Orchestrated equivalent |
|---|---|
| `/tl-telar:add-feature <feature>` | `/tl-telar:orchestrate <feature>` |
| `/tl-telar:create-app <description>` | `/tl-telar:orchestrate Create a new app: <description>` (treats whole-app as a single big plan) |
| Manual review at each phase | Automated 3-reviewer gate at plan + automated 2-4 reviewer gate per WU |

Choose orchestrated mode when you want rigorous adversarial review at every gate. Choose legacy when the task is small or the existing flow's UX suits you better.

## Tests / conformance

Sub-spec 2 ships with no scripted end-to-end test of this command (markdown-instruction tooling has no test runner). Verify manually by running on `tests/fixtures/plan-review/sample-good-plan.md`:

```
/tl-telar:orchestrate "Add the CHANGELOG validator from tests/fixtures/plan-review/sample-good-plan.md"
```

Expected: plan-review-gate fires, PASSes, orchestrator decomposes into the 3 WUs (validator file, CLAUDE.md row, smoke test), drives each through the loop, emits COMMIT-READY signals.
