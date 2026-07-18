# PLAN — Config-Only Model Onboarding + Hybrid Roster

> Companion to `RESEARCH-hybrid-models.md`. Sequenced, file-by-file.
> Principle: after this, adding/swapping a model = editing `external-tools.yaml` only.

## Implementation status — IMPLEMENTED on branch `feature/hybrid-model-routing`

| WS | Status | Notes |
|----|--------|-------|
| WS0 pricing fail-closed | ✅ done + tested | `estimate-cost.test.sh` 19/19 |
| WS1 config-driven routing | ✅ done + tested | `external-tools-routing.test.sh` 23/23 |
| WS2 `routing.roles` + `resolve-role` | ✅ done + tested | same suite |
| WS3 generic `compat.sh` adapter | ✅ done + offline-tested | `external-tools-compat.test.sh` 14/14. **Live path (claude endpoint-swap → Kimi) needs user verification** — see below |
| WS4 Kimi K3 onboarding | ✅ done (disabled by default) | YAML-only, proved end-to-end offline |
| WS5 Writer → Developer rename | ✅ done | skills/agent/templates/tests/fixtures |
| WS6 reviewer model decoupled | ✅ done + tested | `reviewer-roster.js --model`, default `opus` |
| WS7 opt-in interactive override | ✅ documented | in `external-tools/SKILL.md` |
| WS8 docs + mirror regen | ✅ mirror + AGENTS.md + CHANGELOG | **`docs/configuration.html` doc-site expansion deferred** (authoritative SKILL.md updated) |

Full test suite green (13 suites). No commits made.

**Kimi live-path prerequisites (before flipping `adapters.kimi.enabled: true`):**
1. Export the Moonshot key under the name in `auth_env_var` (`MOONSHOT_API_KEY`) so the adapter's process sees it.
2. Make the real `claude` binary reachable (it is an alias here) — put it on PATH or set `COMPAT_CLI_CMD=/abs/path/to/claude`.
3. Confirm your `claude` CLI exposes `--permission-mode bypassPermissions` and that `--output-format json` carries `.usage` (see the VERIFY header in `compat.sh`).

---

## Outcome

`external-tools.yaml` becomes the single source of truth for **which model plays which role**.
A new model is onboarded by adding one `adapters.*` block + one `pricing` line + referencing it
in `routing.roles`. No edits to dispatcher, adapters, or consumer skills.

## Workstreams (in order)

### WS0 — Fix the $0 pricing trap (independent, ship first)
The estimator silently returns $0 for unknown models, bypassing the budget circuit breaker.
- `scripts/estimate-cost.sh` — the pricing `case` (~L25-38) only matches `gpt-5.3-codex|codex`.
  - **Move pricing OUT of the script into `external-tools.yaml`** (`adapters.<x>.pricing: {input, output}`)
    so a new model's cost is declared where it is registered.
  - Estimator reads pricing from config; **fail-closed** (refuse dispatch, not $0) when a model has
    no declared price. This closes the breaker-bypass permanently.
  - Refresh the GPT-5.6 line so the current Codex pin is priced correctly.

### WS1 — Config-driven routing (remove hardcoded tool set, activate dead keys)
Today the tool set is hardcoded in ~6 spots and `routing.escalation_order`/`default_implementer`
are ignored.
- `scripts/tl-telar-external-tools.sh`:
  - Replace `for tool in codex gemini` (health loop, ~L239) with iteration over `adapters.*` keys.
  - Replace the explicit-tool whitelist `case "$tool" in codex|gemini)` (~L401,430) with a generic
    "is this adapter registered + enabled + healthy" check.
  - Replace the hardcoded auto-routing preference (gemini→codex, ~L357-374) with real consumption of
    `routing.escalation_order` + `fallback_by_health`.
  - Update `usage_err` string (~L49) to stop enumerating a fixed tool list.
- Keep every fail-closed invariant and the budget ledger untouched in behavior.

### WS2 — `routing.roles` schema + role taxonomy
Introduce the "virtual software team" roles as the routing interface.
- `resources/templates/orchestration/external-tools.yaml` — add the `routing.roles` block
  (`architect · moderator · developer · reviewer · tester`) per RESEARCH §3, with the curated
  default roster. Keep legacy `routing.*` keys working (or migrate them).
- Define resolution: role → model(s), with `panel`/`models` for multi-model roles and `escalation`
  for per-role fallback.

### WS3 — Generic `compat.sh` adapter
One adapter for any OpenAI/Anthropic-compatible provider.
- New `skills/orchestration/external-tools/adapters/compat.sh` — modeled on `codex.sh`/`gemini.sh`
  contract (`health`/`implement`/`review`, source `_common.sh`, emit standard envelope). Reads
  `base_url`, `model`, `auth_env_var`, `api_style` (anthropic|openai) from the dispatched config.
- Cost extraction: add a `extract_cost_compat` for the compat response shape. **Vendored-adapter
  tension**: `_common.sh` is vendored/forbidden-to-modify — put the new extractor in a NON-vendored
  helper (or dispatcher) rather than editing `_common.sh`; if `_common.sh` must change, re-baseline
  its SHA in the CHANGELOG + `THIRD_PARTY_NOTICES.md`.

### WS4 — Onboard Kimi K3 (YAML-only, proves the infra)
- `external-tools.yaml` — add `adapters.kimi` (compat adapter, `base_url: https://api.moonshot.ai/anthropic`,
  `auth_env_var`, `pricing`, `enabled: false` by default) + add `kimi` to `cross_model_review.matrix`
  rows. Do NOT wire K3 into the `developer` role yet (held for ~07-27 verification); reference it as an
  advisory `reviewer` voice at most.

### WS5 — Rename Writer → Developer (consumer + state)
- `skills/orchestration/orchestrated-execution/SKILL.md` (~L88) and
  `skills/orchestration/external-tools/references/state-files.md` (~L63-66): rename the
  `Writer Model` column/concept to `Developer Model`; extend allowed values to include compat models.
- Grep for other `Writer`/`writer` references in orchestration skills and update.

### WS6 — Decouple reviewer model from hardcode
- `scripts/tl-telar-reviewer-roster.js` (~L29 `REVIEWER_MODEL='opus'`) — source the reviewer model(s)
  from `routing.roles.reviewer` instead of the constant, preserving Opus as the default.

### WS7 — Optional interactive override UX
- In interactive `/tl-telar:orchestrate` only: offer a role→model menu when the user wants to deviate;
  the selection is written into the run's `external-tools.yaml`/state. Skipped entirely in headless/
  `resume` runs. (Thin convenience over WS2, not a separate system.)

### WS8 — Docs + mirror regen
- Update `agents/orchestrator.md` preflight prose, `skills/orchestration/adversarial-code-review.md`
  matrix examples, `docs/configuration.html`, and the `external-tools` SKILL to describe roles +
  compat adapter.
- Regenerate the `plugins/tl-telar/**` mirror via `scripts/generate-codex-plugin.js` (never hand-edit
  the mirror).

## Sequencing / milestones

1. **WS0** — ship immediately (bug fix, independent of everything).
2. **WS1 + WS2** — the foundation (routing + roles config-driven). Nothing else lands cleanly without it.
3. **WS3** — generic adapter.
4. **WS4** — Kimi K3 onboarding (validates "YAML-only" end to end).
5. **WS5 + WS6** — rename + reviewer decouple (can parallel WS3/WS4).
6. **WS7** — override UX (after config is the source of truth).
7. **WS8** — docs + mirror (last).

## Explicitly NOT doing

- No forced startup menu; no opaque per-task auto-routing (per locked decision).
- No change to the Codex/`codex exec` path — GPT-5.6 keeps flowing through it.
- No pi.dev dependency now (optional future adapter only).
- No K3 in the developer seat before independent verification (~2026-07-27).

## Risks

- `_common.sh` vendored-modify tension (WS3) — resolve via non-vendored helper or SHA re-baseline.
- Pricing freshness — all figures indicative; WS0 must fail-closed on missing price, not guess.
- Aggregator-dependent benchmarks — re-check role roster when K3 independent numbers land.
