---
id: orchestrated-execution
category: skill
impact: HIGH
impactDescription: The 4-phase IMPLEMENT/VALIDATE/REVIEW/COMMIT loop that operationalizes blocking quality gates. Orchestrator-run validation, fresh adversarial reviewers per pass, max-3 retries, then escalation.
tags: [orchestration, execution-loop, multi-agent, 4-phase, quality-gate]
capabilities:
  - Drive one Work Unit through IMPLEMENT → VALIDATE → ADVERSARIAL REVIEW → COMMIT
  - Run validation commands directly (orchestrator-run, never delegated)
  - Spawn fresh adversarial reviewers via adversarial-code-review sidecar
  - Track phase transitions in .tl-telar/context/execution-state.md
  - Escalate after 3 retries with full failure history
useWhen:
  - The orchestrator agent reaches a WU's execution step
  - Direct user request to "run the 4-phase loop on this WU"
---

# Orchestrated Execution (4-Phase Loop)

## Trigger condition (binding)

This skill is loaded only via:

1. The `orchestrator` agent's workflow per active WU.
2. `/tl-telar:orchestrate <task>` (which routes through the orchestrator).
3. Explicit user request to run the 4-phase loop on a specific WU.

This skill is NEVER auto-triggered from legacy mobile commands. `/tl-telar:add-feature`, `/tl-telar:create-app`, etc. continue to use `skills/iterative-build-loop.md` (untouched) for their build loops.

## Inputs

| Input | Source |
|---|---|
| WU object | Parsed from `.tl-telar/plans/active-plan.md` (schema in `./references/work-unit-schema.md`) |
| `.tl-telar-thresholds.json` | Optional. If absent, see Acceptance Criterion #1 — orchestrator wrote a safe no-op default at boot. |
| Iteration counter | Tracked in `.tl-telar/context/execution-state.md`. Starts at 0 per WU. |

## The 4 phases

### Phase 1: IMPLEMENT

**Capture the WU baseline ONCE per WU, before attempt 1 (NOT on retries).** This is what makes file-scope checks correct across a multi-WU run where the user has not yet committed prior WUs (per the `ben yapacagim` git policy, commits may lag behind COMMIT-READY signals).

The baseline is **content-aware** (path + state, where state = content hash for existing files or `__DELETED__` for already-deleted paths), not path-only. A path-only baseline has three holes the state-aware version closes: (a) it can't tell when this WU *edits* a file that an earlier WU already left dirty, (b) re-capturing after a failed attempt would absorb that attempt's stray out-of-scope file into the "pre-existing" set, hiding it forever, and (c) it can't detect when this WU *deletes* a file that was dirty at baseline.

```bash
BASELINE=".tl-telar/context/wu-<id>-baseline.tsv"

# Capture ONCE: only if the baseline doesn't already exist for this WU.
# Retries (Phase 2/3 FAIL → back to Phase 1) MUST reuse the attempt-1 baseline,
# never recapture — otherwise a stray out-of-scope file from a failed attempt
# would be reclassified as pre-existing and escape the scope check.
if [[ ! -f "$BASELINE" ]]; then
  # For every already-dirty path (tracked-modified, staged, deleted, or untracked),
  # record "path<TAB>state" BEFORE this WU's implementer touches anything.
  # state = content hash for existing files, or the literal __DELETED__ for a
  # tracked file that is already deleted at baseline time (an earlier WU's deletion).
  # Recording deletions is required so this WU's OWN deletions are still attributed
  # (a deleted file vanishes from disk, so a bare -f check would skip it — see Phase 2).
  : > "$BASELINE"
  { git diff --name-only;
    git diff --name-only --cached;
    git ls-files --others --exclude-standard; } | sort -u | while IFS= read -r f; do
    if [[ -f "$f" ]]; then
      h=$(git hash-object "$f" 2>/dev/null || shasum -a 256 "$f" 2>/dev/null | cut -d' ' -f1)
      printf '%s\t%s\n' "$f" "$h" >> "$BASELINE"
    else
      # In the dirty set but not on disk → a tracked file deleted before this WU.
      printf '%s\t__DELETED__\n' "$f" >> "$BASELINE"
    fi
  done
fi
```

The baseline records what earlier WUs (or pre-existing user edits) had already changed — including deletions — and the exact state at that moment. Phase 2 and Phase 4 attribute a file to THIS WU when its path is new OR its state (content hash, or deleted-ness) differs from the baseline. This correctly handles: edits to already-dirty files, this WU's own deletions, and ignoring a prior WU's deletion.

**Sequential-overlap note.** The Work Unit schema forbids overlapping `file_scope` only for *parallel* WUs. Sequential WUs may legitimately touch the same file (e.g., WU-001 creates `RootStack.tsx`, WU-003 adds a route to it). The content-aware baseline handles this: WU-003's edit changes the hash, so it's attributed to WU-003 and checked against WU-003's `file_scope`. If WU-003's scope doesn't include that file, it correctly FAILs — which is the desired behavior.

Then dispatch a fresh `Task()` implementer subagent (this requires the 4-phase loop to be driven by the **main-session** orchestrator — a subagent cannot spawn the implementer/reviewer subagents this loop needs; see `agents/orchestrator.md` → "Execution context") with:
- WU spec, DoD, file scope
- Instruction: "STAY within declared file scope — do not modify files outside it. Do NOT self-certify — the orchestrator will validate independently. Follow TDD where the WU's DoD has a test item."
- Knowledge layer (if present): if the project ships an OKF knowledge bundle (typically `docs/knowledge/`), read the concept for anything you touch before touching it — for a table, its `docs/knowledge/**/tables/<table>.md`; for a domain term or flow, the matching glossary/scenario concept. Honor its documented constraints. Authority is `docs/adr/` + `docs/data_model/`; the bundle is a derived orientation layer, not a second source of truth. No bundle present → skip (no-op).
- Clean code & reuse: before writing a unit, search for an existing shared component/util/hook/RPC/view and reuse it; unify code only when sites change together for the same reason (never force-merge coincidental similarity); apply a design pattern only where it earns its complexity. See the `clean-code` skill.
- Self-review checklist (per the implementer-prompt convention).

The implementer reports back. Status DONE → Phase 2. Status BLOCKED → escalate immediately.

**Developer-model recording (cross-model review wiring).** Before transitioning to Phase 2, append the implementer's model identity to `.tl-telar/context/execution-state.md` under the WU's row, `Developer Model` column (the "developer" role — formerly "writer"). Values: `claude` (the default when the implementer was spawned as Task()) or the adapter name it was dispatched to via tl-telar-external-tools.sh (`codex`, `gemini`, `kimi`, …). This is read by Phase 3's cross-model selection logic to exclude the developer from the reviewer pool.

### Phase 2: VALIDATE (orchestrator-run, never delegated)

The orchestrator agent itself runs validation commands. It does NOT ask the implementer "did the tests pass?" — that violates the doctrine.

**Command execution model (no eval).** Quality-gate commands come from `.tl-telar-thresholds.json`, which lives in the consumer repo and may be edited by anyone with commit access. Treating those commands as shell strings to `eval` would be both a command-injection vector and an accidental-destructive-command vector. Instead:

1. **Read `.tl-telar-thresholds.json`** from consumer repo root (orchestrator wrote a safe no-op default at boot if absent — see boot probe).
2. **Validate each `enforcement.*_command` against the allowlist.** Allowed shapes:
   - **Safe no-op**: a command consisting of `echo <quoted-string>` optionally followed by ` && exit 0`, where `<quoted-string>` is either single-quoted (`'...'`) or double-quoted (`"..."`) and contains only printable ASCII plus spaces — no embedded quote of the same type, no backslash, no `$`, no backtick, no other shell metacharacter (no `;`, `|`, `&`, `>`, `<`). Both quoting styles are accepted to match what `/tl-telar:setup-orchestration` writes (it uses Node `JSON.stringify`, which double-quotes string fields).
   - **Plugin/project script**: `bash <path>` where `<path>` is a relative path matching `^scripts/[a-zA-Z0-9._/-]+\.sh$` and resolves to a real file under either the plugin's `scripts/` or the consumer project's `scripts/`. No shell metacharacters allowed in the path.
   - **Package-runner**: `npx <pkg> [args...]`, `pnpm <args...>`, `npm <args...>`, `yarn <args...>` where `<pkg>` matches `^@?[a-zA-Z0-9._/-]+$` (scoped packages allowed) and each subsequent arg matches `^[a-zA-Z0-9._/=:-]+$` (no shell metacharacters).
   - **Flutter / Dart**: `flutter <args...>` or `dart <args...>` with the same arg constraint as above.
   - **Any other shape** → REFUSE. Log `CONFIG_REJECTED: enforcement.<gate>_command does not match allowed shapes`. Treat the gate as FAIL (fail-closed, never silently advisory). Exception: gates with `*_strict: false` are still flagged as REFUSED in the log but do NOT block (since they're advisory by design).

   **Quoting-style validation reference (the regex the validator implements):**

   ```
   safe_noop_re = ^echo[[:space:]]+("[^"\\$`;|&<>]*"|'[^'\\$`;|&<>]*')([[:space:]]+&&[[:space:]]+exit[[:space:]]+0)?$
   ```

   This accepts `echo 'a11y not configured'`, `echo "a11y not configured"`, `echo 'x' && exit 0`, `echo "x" && exit 0` — all four common shapes that setup might produce. Rejects anything with `$`, backtick, embedded quotes, or other meta.
3. **Execute via argv array, never `eval` or `sh -c`.** Tokenize the validated command into argv (use `node -e "process.stdout.write(JSON.stringify(process.argv.slice(1).join(' ').match(/(?:[^\s'"]+|'[^']*'|"[^"]*")+/g) || []))"` then parse — or use a dedicated shell-words tokenizer). Then invoke as `"${argv[@]}"` directly in bash. Capture stdout/stderr/exit code.
4. **Check file scope — content-aware baseline attribution (the multi-WU correctness mechanism).** Examine the union of current-dirty paths and baseline paths. Attribute a path to THIS WU when it has no baseline entry (and exists now) OR its current state — content hash, or `__DELETED__` if gone from disk — differs from the baseline state. Then verify each attributed path is in the WU's `file_scope`:

   ```bash
   BASELINE=".tl-telar/context/wu-<id>-baseline.tsv"   # path<TAB>state, captured once at Phase 1

   # Examine the UNION of (current dirty paths) ∪ (all baseline paths). Including
   # baseline paths is essential: if this WU DELETED a file that was dirty at
   # baseline (e.g. an untracked file an earlier WU created), that path is now
   # gone from disk AND absent from `git diff`/`git ls-files`, so it would never
   # appear in the current dirty set alone. Pulling baseline paths into the loop
   # lets us detect "was in baseline, now gone" = a deletion by this WU.
   { git diff --name-only;
     git diff --name-only --cached;
     git ls-files --others --exclude-standard;
     cut -f1 "$BASELINE"; } | sort -u | while IFS= read -r f; do
     [[ -n "$f" ]] || continue
     if [[ -f "$f" ]]; then
       cur=$(git hash-object "$f" 2>/dev/null || shasum -a 256 "$f" 2>/dev/null | cut -d' ' -f1)
     else
       cur="__DELETED__"     # not on disk → deleted (whether it was tracked or untracked at baseline)
     fi
     base=$(awk -F'\t' -v p="$f" '$1==p{print $2; exit}' "$BASELINE")
     if [[ -z "$base" ]]; then
       # New path with no baseline entry. Only attribute if it actually exists now
       # (a path that's in neither baseline nor on disk is noise — skip).
       [[ "$cur" != "__DELETED__" ]] && echo "$f"
     elif [[ "$cur" != "$base" ]]; then
       # State changed since baseline (edited, newly-deleted, or re-created) → this WU.
       echo "$f"
     fi
   done > ".tl-telar/context/wu-<id>-changes.txt"
   ```

   Verify every path in `wu-<id>-changes.txt` matches the WU's `file_scope`. A path in this set but NOT in `file_scope` → FAIL with `OUT_OF_SCOPE: <file>`. This catches a file this WU **deleted** out of scope — whether the deleted file was tracked OR an earlier WU's still-uncommitted untracked file (the latter is why the loop examines baseline paths, not just the current dirty set). Paths whose state is unchanged from the baseline (earlier WUs' uncommitted work — edits OR deletions — this WU did not touch) are NOT flagged. The user does NOT have to commit between WUs; attribution is by state (content hash or deleted-ness) over the union of current-dirty and baseline paths.

5. **Capture results** into `.tl-telar/context/execution-state.md` Last validation results section. On `CONFIG_REJECTED`, the captured result includes the rejected command verbatim so the user can see what their config tried to do.

   **Quiet output (keep the terminal clean).** Redirect each gate command's stdout+stderr to a per-WU log file rather than letting it spill into the terminal — append `> .tl-telar/logs/wu-<id>-validate.log 2>&1` to the invocation (create `.tl-telar/logs/` if absent; it is git-ignored runtime state under `.tl-telar/`). Surface ONLY the one-line verdict in the progress tree, with a pointer to the log on failure, e.g. `tsc✓ lint✓ test✗ → .tl-telar/logs/wu-003-validate.log`. The full output stays in the log + `execution-state.md`; do not paste it into the terminal. (The exit code still drives PASS/FAIL exactly as before — redirection changes only what the user sees, never the gate logic.)

**Why not eval.** `eval "$cmd"` passes arbitrary shell to bash. A `.tl-telar-thresholds.json` that contains `"coverage_command": "rm -rf ~"` would execute. Even on a fully trusted team, typos and pasted-from-internet snippets are a real risk. The allowlist + argv-array approach is verbose but auditable.

**Anti-pattern to refuse.** A reviewer or implementer suggesting "let's just use `bash -c "$cmd"` for flexibility" — REJECT. The allowlist is the contract; expanding it requires a new sub-spec, not an in-line workaround.

If any gate FAILs:
- Increment retry count.
- Announce `"VALIDATION FAIL: <gate> — <reason>. Returning to IMPLEMENT (retry <N>/3)."`
- Loop back to Phase 1 with the failure message handed to a NEW implementer Task() (not the prior one — fresh instance avoids the implementer rationalizing its own work).
- After 3 retries: escalate.

If all gates PASS: proceed to Phase 3.

### Phase 3: ADVERSARIAL REVIEW

Load `skills/orchestration/adversarial-code-review` (the SIDECAR — see master design §2.8). It spawns a **risk-tier-scaled**, stack-aware roster in parallel: pass the WU's `risk_tier` as `--risk-tier` to `scripts/tl-telar-reviewer-roster.js` alongside the `file_scope` paths (trivial→Code-only, standard→Code+Maintainability+floor-Security, critical→full roster; a sensitive-path floor forces Security on any tier). Returns aggregated verdict. On iterations 2+, re-review is **incremental (sticky-pass)** — only the FAILing reviewers plus any prior-PASS reviewer whose concern intersects the fix diff re-run; the rest keep their PASS (critical-tier Security is never sticky). See the skill's "Retry economics" and "Critical-tier escalation" sections.

**Cross-model review (sub-spec 8, Phase γ — additive SECOND review).** The adversarial-code-review skill checks `.tl-telar/external-tools.yaml` → `cross_model_review.enabled`:

- **enabled: false (default):** Review 1 only — spawn the risk-tier-scaled fresh Claude `Task()` roster (sub-spec 2 behavior, now sized by `risk_tier`).
- **enabled: true:** run BOTH reviews; BOTH must PASS:
  - **Review 1 (always):** the same fresh Claude reviewer roster as above.
  - **Review 2 (additive, on top of Review 1):** ONE additional review of the WU diff by a model distinct from the writer AND from Claude (per `cross_model_review.matrix`), dispatched via `scripts/tl-telar-external-tools.sh dispatch --task review --tool <model> --worktree <repo> --rubric-file <rubric> --spec-file <wu-spec>`.
  - If no distinct second-review model is available (disabled/unhealthy/over-budget), apply `cross_model_review.on_unavailable` (default `block`): `block` → STOP + escalate (the required second review cannot run; do NOT pass on Review 1 alone); `warn_and_proceed` → skip Review 2, proceed on Review 1, record a LOUD downgrade. NEVER a silent skip. See `adversarial-code-review` → "Required-mode enforcement".
- Aggregate: any FAIL from Review 1 OR Review 2 → overall FAIL.

**Verdict extraction (cross-model).** When a reviewer was an external adapter, the dispatcher's envelope's `raw_log` field contains the model's response. Run `scripts/tl-telar-external-tools.sh parse-verdict <envelope-file>` to extract `{verdict, issues[]}` from the raw_log. When `verdict: "UNKNOWN"` (parser couldn't extract), treat as FAIL with synthetic blocker `{rule: "X1-parse-failure", summary: "Adapter returned unparseable verdict"}`.

- **Overall PASS**: proceed to Phase 4.
- **Overall FAIL**: increment retry count, announce blockers, loop back to Phase 1 with the failure summary. NEW implementer Task() — never reuse the prior one.
- **After 3 retries**: escalate to user with Override / Revise-with-help / Simplify / Cancel options (same shape as sub-spec 1's plan-review-gate escalation).

The rest of Phase 3 is unchanged from sub-spec 2 except roster sizing and retry scope: max 3 retries, FAIL → loop back to Phase 1 with fresh implementer (which may itself be a different model based on routing), then the next Phase-3 pass re-reviews INCREMENTALLY (sticky-pass — only the FAILing reviewers + fix-intersecting prior-PASS reviewers; critical Security always re-runs), PASS → Phase 4 COMMIT.

### Phase 4: COMMIT

The implementer subagent does NOT commit. The orchestrator agent itself:

1. Re-runs the content-aware baseline attribution from Phase 2 step 4 (recompute `wu-<id>-changes.txt` against the once-per-WU baseline; confirm all attributed paths are in `file_scope`) — defense in depth. Do NOT use a bare `git diff --name-only` here; that would re-introduce the multi-WU self-lock bug (earlier WUs' uncommitted files would look out-of-scope).
2. (In this sub-spec, the orchestrator does NOT git-add or git-commit because the user's policy is "ben yapacagim". Instead, the orchestrator emits a COMMIT-READY signal with:
   - Suggested commit message: `feat(wu-<id>): <title>\n\nImplements: <DoD list>\nReviewed-by: <actual reviewers from execution-state, e.g. "R1 claude (PASS), R2 codex (PASS)">` — name the models that actually reviewed; if cross-model was enabled but Review 2 was downgraded, include `⚠ second (cross-model) review SKIPPED: <reason>` so the absence is visible in the commit trail.
   - List of files in scope
2a. **(worktree isolation only)** When this WU ran with `isolation: worktree` (orchestrator Step 5b `isolationActive`), commit the in-scope changes to the current `wu-<id>` branch inside the worktree so the orchestrator's Step 6.4 merge-back (`git merge --squash`) has a branch to integrate. This is the SOLE exception to "the orchestrator does not commit": the commit lands on a **throwaway `wu-<id>` branch** that is removed right after merge-back — it never touches the user's branch, so the `ben yapacagim` policy (the user authors the final commit on their own branch) is preserved. Conflict resolution against already-integrated WUs happens at the orchestrator's squash-merge, not here. In the non-isolated (shared-tree) mode this step is skipped and changes stay uncommitted in the working tree exactly as before.
3. Update `.tl-telar/context/execution-state.md` marking WU status COMPLETE / phase COMMITTED.
3a. **Update `.tl-telar/context/project-context.md` (sub-spec 4 wiring)**: read or create from the template at `resources/templates/orchestration/project-context.md`; append a row to the **Completed Work Units** table (`| WU-<id> | <title> | <key files> | <new services/modules> |`); if new patterns emerged, add a bullet under **Established Patterns**. File is git-ignored per §2.7a — orchestrator scratchpad, NOT a durable artifact, but recovery and subsequent WU implementers read it for cross-WU coherence.
3b. **Conditional `/tl-telar:self-reflect` (sub-spec 5 wiring).** Fire the self-reflect skill here when EITHER (a) this is a single-WU run (the orchestrator's plan decomposed into exactly one WU and this is it), OR (b) `.tl-telar-thresholds.json` → `enforcement.self_reflect_per_wu == true`. The orchestrator agent's Step 7.5 handles the multi-WU-without-opt-in case (one capture pre-PR); this Phase 4 hook handles the other two cases. If neither condition holds, SKIP and let Step 7.5 cover it post-WU-loop. The single-WU case is detected by: `.tl-telar/plans/active-plan.md` lists exactly one WU AND this WU's status flipped to COMPLETE in step 3.
4. Remove this WU's baseline artifacts (`.tl-telar/context/wu-<id>-baseline.tsv`, `wu-<id>-changes.txt`) — they were per-WU scratch. (All under `.tl-telar/context/`, already git-ignored per §2.7a, so this is hygiene not correctness.)
5. If WU `checkpoint: true`: when `autonomy.cycle = interactive` (default), present a checkpoint report and WAIT for user. When `autonomy.cycle = unattended`, do NOT pause — the human validation was hoisted to the orchestrator's Step 5a plan-readiness pre-flight; proceed using the pre-approved artifact (see `agents/orchestrator.md` → "Autonomy model"). A checkpoint reached in unattended mode with no pre-flight artifact is a pre-flight defect: STOP and report, do not guess.

## Anti-patterns (do NOT do these)

1. **Delegating VALIDATE to the implementer subagent.** "Did the tests pass?" answers are forbidden. The orchestrator runs `tsc`, `eslint`, test command, coverage command itself.
2. **Reusing a Task() handle on retry.** Fresh implementer AND fresh reviewer instances on every loop iteration.
3. **Inlining prior failure findings into the new implementer's prompt verbatim.** Summarize them as actionable instructions ("the previous attempt failed VALIDATE because X — fix Y"), but do not paste prior reviewer JSON dumps. Verbose paste degrades implementer focus.
4. **Allowing the implementer to write outside `file_scope`.** Even with good intent. Out-of-scope changes → FAIL.
5. **Skipping Phase 4 when checkpoint:true.** A checkpoint is a gate, not a notification. In `interactive` mode, wait for user. In `unattended` mode the gate is satisfied up front in plan-readiness (Step 5a), NOT skipped — "unattended" never means "skip the human decision", it means "make it earlier". Reaching an unattended checkpoint with no pre-flight artifact = STOP and report.
6. **Treating advisory M-rule findings as blocking.** Sub-spec 1's `plan-review-gate` advisories (M1-M4) propagate to Phase 3 in some scenarios — they remain advisory, not blocking.
7. **Hard-failing on missing `.tl-telar-thresholds.json`.** The orchestrator's boot probe writes a safe no-op default. Phase 2 reads from that default.
8. **Substituting a generic reviewer for the Phase 3 gate, or treating Review 2 as replacing Review 1.** In orchestrated mode, Phase 3 MUST go through `adversarial-code-review`. When `cross_model_review.enabled: true`, BOTH Review 1 (main-model Claude) AND Review 2 (cross-model) run and both must pass — Review 2 is additive, never a swap. Using a generic `comprehensive-review:code-reviewer` (which never reads `external-tools.yaml`) silently skips Review 2 — forbidden. Verify the budget ledger gained an entry as proof Review 2 ran.

## Progress rendering (in-session view)

Keep the terminal a **glance view, not a log**. Full detail already lives in `.tl-telar/context/execution-state.md`; the terminal shows a compact progress tree so the user sees steps + cycles without scrolling through diffs and prose.

**Fixed glyph set** (do not vary): `✓` done/passed · `▸` active · `·` pending · `✗` failed-this-attempt · `⚠` blocked/escalated.

**What to emit, and when:**

- **Phase line — on EVERY phase transition** (exactly one line):
  ```
  ⟳ WU-003/007 · REVIEW · try 1/3 · gates: tsc✓ lint✓ · done 2/7
  ```
- **WU tree — at run start, on each WU start/complete, and at run end:**
  ```
  orchestrate ▸ <feature>
    gates: Design ✓   Plan ✓ (1 iter)
    WU-001 ✓  WU-002 ✓  WU-003 ▸REVIEW(1/3)  WU-004 ·  WU-005 ·  WU-006 ·  WU-007 ·
  ```

**Rules:**
- Render strictly from `execution-state.md` (current WU/phase/retry + the WU status table). Never invent or guess state.
- One phase line per transition; reprint the full WU tree only at WU boundaries (start/complete) — not on every phase — to keep noise low.
- On FAIL/escalation, the phase line carries `✗`/`⚠` plus the gate name/reason; the full reason stays in `execution-state.md`.
- This **replaces** verbose per-phase narration — do not also dump full diffs or tool logs to the terminal; point to the state file instead.
- **Quiet contract:** during the loop the orchestrator's ONLY terminal output is the progress line / WU tree above plus the final per-WU summary. No play-by-play narration, no pasted diffs, no raw command output (VALIDATE output is redirected to `.tl-telar/logs/` per Phase 2). All detail lives in `execution-state.md` and the logs. Heavy work (implementation, the 2–4 adversarial reviews) runs in `Task()` subagents whose internals never reach the main terminal — only their short returned verdict does.
- In-session terminal output only; it appends per transition (Claude Code cannot repaint a panel in place). No settings, hooks, or external processes are involved — so it cannot fail.

## Outputs

For each WU:
- A compact progress render per the **Progress rendering** section above (phase line per transition; WU tree at WU boundaries).
- Updated `.tl-telar/plans/active-plan.md` (WU status flip post-COMMIT).
- Updated `.tl-telar/context/execution-state.md` (every transition).
- COMMIT-READY signal to the orchestrator (or user, if standalone).

## Tests / conformance

Run `node scripts/validate-skills.js` (orchestration-namespace checks). Run `bash scripts/check-sidecar-routing.sh` (legacy commands stay clean).
