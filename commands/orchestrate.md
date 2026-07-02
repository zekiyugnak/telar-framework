---
id: orchestrate
name: Mobile Orchestrator (Full Pipeline)
description: End-to-end orchestrated execution. Takes a feature description and drives the entire pipeline — plan, plan review (3 fresh reviewers), WU decomposition, 4-phase execution loop per WU, final review, COMMIT-READY emit. Honors user's git policy (no auto-commit).
category: command
usage: /tl-telar:orchestrate <task description> | --epic <path> | --plan-file <path>
example: /tl-telar:orchestrate Add a login screen with email + password
arguments:
  - name: <task description>
    description: Free-text description of the feature/task to orchestrate. Provide this OR --epic OR --plan-file.
    optional: true
  - name: --epic <path>
    description: Path to a pre-authored epic file (from templates/epic.md). Its `## Task` sections decompose 1:1 into Work Units. Skips plan drafting.
    optional: true
  - name: --plan-file <path>
    description: Path to an existing PLAN.md whose tasks are already WU-decomposable. Skips plan drafting.
    optional: true
---

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
   - Drive each WU through `skills/orchestration/orchestrated-execution` (4-phase loop) — spawning implementer/reviewer `Task()`s from this session.
   - Emit a COMMIT-READY signal for each WU (DOES NOT commit on user's behalf).
   - Final review and "Ready for PR" summary.
   - Run `node scripts/tl-telar-spec-archive.js <change-id>` (Spec Layer archive step) to merge this change's delta(s) into `tl-telar-spec/truth/` and move `tl-telar-spec/changes/<id>/` to `tl-telar-spec/changes/archive/<date>-<id>/`.

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
- Does NOT change legacy commands' *review/build* behavior — `/tl-telar:add-feature`, `/tl-telar:create-app`, etc. still don't route through this orchestrator's plan/design gates. They DO now share the same Spec Layer artifact location (`tl-telar-spec/changes/<id>/`, `tl-telar-spec/truth/<domain>/`) as this command — see `docs/superpowers/specs/2026-07-02-telar-spec-layer-design.md`.

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
