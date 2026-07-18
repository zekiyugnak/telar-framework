---
id: external-tools
category: skill
impact: MEDIUM
impactDescription: Layer-B dispatcher contract for Codex/Gemini delegation. In sub-spec 7 (Phase β), infrastructure ships disabled-by-default. Phase γ (sub-spec 8) wires cross-model adversarial review on top.
tags: [orchestration, external-ai, multi-model, dispatcher, phase-beta]
capabilities:
  - Document the Layer A adapter contract (vendored verbatim; see THIRD_PARTY_NOTICES.md)
  - Document the Layer B dispatcher contract (real routing/budget/parsing)
  - Health check and budget reporting
  - Reserved Phase γ integration point (cross-model review)
useWhen:
  - User invokes /tl-telar:external-tools-health
  - orchestrator (sub-spec 8+) wants to delegate implementation or review
  - User explicitly requests "use external tools" / "delegate to codex/gemini"
---

# External Tools (Phase β)

## Trigger condition (binding)

This skill is loaded only via:

1. `/tl-telar:external-tools-health` (sets TL_TELAR_ORCHESTRATED=1).
2. The `orchestrator` agent when adapter delegation is requested AND `.tl-telar/external-tools.yaml` has `adapters.*.enabled: true` AND health passes.
3. Explicit user request.

This skill is NEVER auto-triggered from legacy mobile commands. Adapters are opt-in.

## Maturity statement

**Phase β (this sub-spec):** infrastructure ports + dispatcher implementation. NOT auto-invoked anywhere. Default config has `adapters.*.enabled: false`. To activate: user installs the relevant CLI (`codex`, `gemini`), sets auth env vars (`OPENAI_API_KEY`, `GEMINI_API_KEY`), and flips `enabled: true` in `.tl-telar/external-tools.yaml`.

**Phase γ (sub-spec 8):** cross-model adversarial review wires this skill into orchestrated-execution Phase 3. Until then, Phase 3 continues to spawn Claude-only Task() reviewers.

## Architecture (two layers)

### Layer A — adapters (vendored verbatim port)

Located at `skills/orchestration/external-tools/adapters/`:

- `_common.sh` — shared helpers (worktree mgmt, secure tmp, env stripping, JSON envelope emitter, classify_error, package_context)
- `codex.sh` — Codex CLI adapter (subcommands: health, implement, review)
- `gemini.sh` — Gemini CLI adapter (same subcommands)
- `compat.sh` — **first-party** (NOT vendored) generic adapter for ANY Anthropic-compatible provider. Drives the `claude` CLI headless with a swapped endpoint (`ANTHROPIC_BASE_URL`/`ANTHROPIC_AUTH_TOKEN`), so the full agentic harness runs on a non-Claude model (e.g. Kimi K3). Selected by `adapters.<name>.type: compat`. Its cost extractor lives in this file (not in vendored `_common.sh`) — that is how new providers are onboarded without editing vendored code.

**`_common.sh`, `codex.sh`, `gemini.sh` are vendored byte-for-byte from upstream (see THIRD_PARTY_NOTICES.md).** SHA-256 hashes recorded in CHANGELOG. Any modifications to THOSE belong in Layer B or in the first-party `compat.sh`.

### Layer B — dispatcher (new)

Located at `scripts/tl-telar-external-tools.sh`:

- Real YAML config parsing via `yq` or `python3 -c "import yaml"` fallback
- Real health-check protocol (no LLM-judges-status anti-pattern)
- **Config-driven routing**: the valid tool set is the `adapters.*` keys (no hardcoded `codex|gemini`); `--tool auto` walks `routing.escalation_order`, picking the first enabled+healthy adapter. Adding an adapter is YAML-only.
- **Role resolution** (`resolve-role`): maps a pipeline role (`architect|moderator|developer|reviewer|tester`) to its model(s) + execution path via `routing.roles` + `routing.models_registry`. Fail-closed on undefined role / unregistered model.
- Real budget ledger (`.tl-telar/context/external-tools-budget.jsonl`) with per-task + per-session circuit breakers. Pricing is per-adapter (`adapters.*.pricing`); an unknown/undeclared price is recorded at the conservative per-task cap, never silently $0.
- Real verdict parser (extract PASS/FAIL + issues[] from adapter raw_log for review-mode invocations)

## CLI surface

```bash
scripts/tl-telar-external-tools.sh dispatch --task implement|review --tool auto|<adapter> --worktree <path> [...]
scripts/tl-telar-external-tools.sh health
scripts/tl-telar-external-tools.sh budget-status
scripts/tl-telar-external-tools.sh parse-verdict <envelope-file>
scripts/tl-telar-external-tools.sh resolve-role <architect|moderator|developer|reviewer|tester>
```

## Model selection & roles (config-first, opt-in override)

Model selection is **config-first**: `routing.roles` in `.tl-telar/external-tools.yaml` is the single source of truth for which model plays each pipeline role, and `routing.models_registry` says how each model runs (native Claude tier vs an external adapter). Consumers NEVER hardcode a model — they call `resolve-role <role>` and use the result.

- **Curated defaults ship** (architect/moderator→Fable 5, developer→Opus 4.8, reviewer→Opus 4.8 + GPT-5.6 Sol, tester→Opus 4.8), so a new project gets a sensible roster with zero choices.
- **Headless / `resume` runs never prompt** — they read `routing.roles` as-is. Deterministic and reproducible.
- **Interactive `/tl-telar:orchestrate` MAY offer an opt-in override menu**: present the resolved role→model roster and let the user reassign a role for this project; the choice is written back into `routing.roles` in `.tl-telar/external-tools.yaml` (so it persists and stays the single source of truth). This is a convenience over the config, never a required step, and never runs unattended.
- **Onboarding a new model** = add a `routing.models_registry` entry (+ an `adapters.<tool>` block if external) and reference it from a role. No dispatcher or skill code changes.
- **Health-based fallback** (`routing.fallback_by_health: true`): a role whose adapter is unhealthy falls to its `escalation` list.

## Adapter envelope (Layer A output)

Adapters emit a uniform JSON envelope (defined upstream; preserved here):

```json
{
  "schema_version": "1",
  "tool": "codex|gemini",
  "command": "implement|review",
  "model": "gpt-5.3-codex",
  "attempt": 1,
  "exit_code": 0,
  "branch": "external/codex/task-42",
  "git_sha": "abc123",
  "files_changed": ["src/foo.ts"],
  "diff_stats": {"additions": 42, "deletions": 7},
  "duration_seconds": 87,
  "cost": {"input_tokens": 12340, "output_tokens": 2110},
  "raw_log": "<full stdout>",
  "error_type": null
}
```

Cost is **tokens only** (no USD field). Layer B's `estimate-cost.sh` converts.

## Cross-model review matrix (Phase γ; encoded in YAML config but not yet wired)

```yaml
cross_model_review:
  enabled: false
  matrix:
    codex: ["gemini", "claude"]
    gemini: ["codex", "claude"]
    claude: ["codex", "kimi"]
    kimi: ["codex", "claude"]
```

The "developer cannot be reviewer" rule (the WU's developer is its writer). The cross-model review logic reads this matrix and routes Phase 3 reviewers accordingly.

## Anti-patterns

1. **Modifying Layer A adapters.** Any change to `_common.sh`/`codex.sh`/`gemini.sh` is forbidden. Logic changes go in Layer B (dispatcher). This preserves upstream-merge potential.
2. **LLM parsing the YAML.** The dispatcher uses `yq` or `python3 yaml`. LLMs parsing config is the anti-pattern this sub-spec fixes.
3. **Soft budget caps.** If the preflight says `cost_limit_exceeded`, the dispatcher MUST NOT invoke the adapter. Falling back to Claude (Task() spawn) is correct; ignoring the cap is not.
4. **Auto-enabling adapters on setup.** `/tl-telar:setup-orchestration` copies the YAML template with `enabled: false`. User opts in explicitly.
5. **Cross-model review in Phase β.** Sub-spec 7 does NOT wire cross-model into Phase 3. The matrix is encoded for sub-spec 8 to consume; Phase 3 continues to use Claude-only Task() spawns.

## Tests / conformance

Run `node scripts/validate-skills.js` (orchestration-namespace checks).

Verify Layer A integrity (portable across macOS/Linux):
```bash
sha256_portable() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@";
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$@";
  else echo "ERROR: install coreutils or shasum"; return 1; fi
}
sha256_portable skills/orchestration/external-tools/adapters/*.sh > /tmp/current_hashes.txt
# Compare against CHANGELOG-recorded hashes
```
