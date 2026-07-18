# RESEARCH — Hybrid Multi-Model Roster for Telar

> Status: research complete, decisions locked. Not yet implemented.
> Date: 2026-07-18. Re-evaluate after Kimi K3 independent verification (~2026-07-27).

## 1. Goal

Telar should treat **model onboarding as a config-only edit**, not a multi-file code change,
so the framework keeps pace with the constant stream of new frontier models. Increase model
diversity across pipeline roles while keeping runs deterministic, reproducible, and budget-metered.

Workload profile that drives every model choice: **complex, long-horizon, PARALLEL agentic
coding, heavy BACKEND, MANY frameworks at once** (Rust services, RN/Flutter, Next.js, admin
panels) — not narrow single-pattern front/back snippet work.

## 2. Decisions locked

| Decision | Choice | Why |
|---|---|---|
| Model-selection UX | **Config + optional override** | YAML `routing` block = single source of truth; curated default roster ships; deviation only via optional interactive menu in interactive `/orchestrate` (writes back to YAML); headless/`resume` runs are menu-free + deterministic. Mirrors Aider/OpenCode/Claude-Code `/model`. No forced startup menu, no opaque per-task auto-routing. |
| Auto behavior | **Health-based fallback only** | If a role's preferred adapter is unhealthy, fall down `routing.escalation_order`. Activates the currently-dead routing config. |
| New-model integration | **Config-driven refactor + generic `compat.sh` adapter** | One adapter reads base-URL + model + auth-env + pricing from YAML; covers any OpenAI/Anthropic-compatible provider (Kimi today, most future models) with zero new code, no extra runtime deps. pi.dev kept as an OPTIONAL later adapter for local/niche models only. |
| GPT-5.6 path | **Unchanged** | Already flows via the Codex adapter (`codex exec`). Do not touch. |
| Role taxonomy | **architect · moderator · developer · reviewer · tester** | Small "virtual software team" set mapped to Telar's real pipeline; decoupled from the 48 agents. |

## 3. Role → model roster (as of 2026-07-18)

```yaml
routing:
  roles:
    architect:   { model: "claude-fable-5",  panel: ["gpt-5.6-sol"] }   # RESEARCH/PLAN + design/plan gates
    moderator:   { model: "claude-fable-5" }                              # synthesizes multi-reviewer gate verdicts
    developer:   { model: "claude-sonnet-5", escalation: ["claude-opus-4-8"], options: ["kimi-k3"] }  # Sonnet default, Opus critical, Kimi opt-in cost
    reviewer:    { models: ["claude-opus-4-8", "gpt-5.6-sol"] }           # Opus primary (best-calibrated) + GPT-5.6-sol (sharp second)
    tester:      { model: "claude-sonnet-5" }                             # unit/E2E authoring (aligns with developer default)
  fallback_by_health: true
```

Rationale per role — the **implementation & review roles were revised from the live benchmark (§7)**;
planning roles stay on the verified-index leaders (§4):

- **architect / moderator → Fable 5.** #1 Intelligence Index, #1 agentic GDPval-AA Elo. GPT-5.6 Sol
  sits second on the panel (edges GPQA, adds provider diversity to the planning gate).
- **developer → Sonnet 5 (high) default; Opus 4.8 (high) escalation; Kimi K3 (max) opt-in.** The live
  benchmark (§7) showed Sonnet 5 high **matched** Opus 4.8 high on contract-completeness + self-verification
  at lower cost → Sonnet is the workhorse; Opus escalates for `critical` WUs; Kimi K3 is an opt-in **$0**
  (subscription) cost mode — compact + fast but it left real contract gaps, so keep cross-model review ON
  when using it. (This supersedes the earlier "developer → Opus 4.8" pick.)
- **reviewer → Opus 4.8 + GPT-5.6 Sol (parallel).** The benchmark found **Opus is the best-calibrated
  reviewer** (it compiles/tests the code it reviews and grades severity accurately), while GPT-5.6-sol has
  sharp recall but over-penalizes severity — so Opus is primary, Sol the sharp second. Kimi reviews are
  thorough but lenient → advisory only.
- **tester → Sonnet 5** (aligns with the developer default; own routing key so it can diverge later).

## 4. Verified benchmark table (2026-07-18)

Independent = Artificial Analysis + vals.ai (evaluators the vendor does not control).
Vendor/aggregator-shaky numbers are flagged — small gaps there are directional only.

| Axis (what it measures) | Fable 5 | Opus 4.8 | GPT-5.6 Sol | Kimi K3 | Source class |
|---|---|---|---|---|---|
| Intelligence Index (general reasoning) | **59.9 #1** | 55.7 | 58.9 | 57.1 | ✅ independent (AA) |
| GDPval-AA Elo (agentic, shell+web, real work) | **1760–1818 #1** | 1600–1638 | ~1745 | ~1668–1685 | ✅ independent (AA) |
| SWE-Bench Verified (repo-scale correctness) | **95% #1** | 88.6% | — absent | — absent | ✅ independent (vals.ai corrob.) |
| Coding Agent Index (sustained tool loop) | — | — | **80 #1** | — | ✅ independent (AA) |
| Terminal-Bench 2.1 (long-horizon agent) | 84.6 | 84.6 | **~88.8 #1** | 88.3 vendor / **84.6 common-harness** | ⚠️ K3 vendor; Sol independent |
| GPQA Diamond (science reasoning) | 92.6 | 93.6 | **94.1** | — | ✅ but saturated (all 92–95) |
| SWE-Bench Pro (multi-language repos) | 0.800 | 0.692 | 0.646 | — absent | ⚠️ vendor-scaffold, aggregator-dependent |
| Cost / task (GDPval) | **$3.25** | **$1.78** | ~mid | cheap | ✅ (AA) |

Best proxies for Telar's workload (complex/parallel/backend/multi-framework): **SWE-Bench
Verified/Pro** (repo-scale correctness) + **GDPval-AA** (real agentic work). No verified
polyglot/Rust-specific benchmark exists for these four; backend strength is inferred from
SWE-Bench Pro (includes multi-language repos).

### Kimi K3 caveat (load-bearing)
Released 2026-07-16. Ranks #3–4 overall and beats Opus 4.8 on the Index, **but essentially all
its coding/agentic scores are Moonshot self-reported**; independent verification (weights to
evaluators) expected **~2026-07-27**. No published SWE-Bench Pro or Verified score. AA's
common-harness Terminal-Bench (84.6%) already undercut its vendor claim (88.3%). Do not put K3
in a correctness-critical seat until verified. A "K3 = 58.4% SWE-Bench" figure seen online
actually belongs to GLM-5.1 — do not attribute it to K3.

### Rejected during verification (do NOT cite)
- "Kimi K3 ranks #4 on AA Index with 57 behind Fable 60 / Sol 59 / Opus 56" — refuted 0-3.
- "Fable 5 80% vs Sol 64.6% SWE-Bench Pro (+15.4)" — refuted 0-3.
- "Terminal-Bench 2.0 Sol 91.9 vs Fable 84.3" — refuted 0-3.

## 5. Pricing (indicative — verify at source before committing to budget config)

No per-token price survived adversarial verification; treat as directional, refresh from
Moonshot / OpenAI / Anthropic official pages.

| Model | Input $/1M | Output $/1M | Note |
|---|---|---|---|
| Kimi K3 | ~3.00 | ~15.00 | cache-hit ~0.30; ≈ Claude Sonnet 5 to the cent |
| GPT-5.6 (Codex, current pin) | 1.50* | 6.00* | *`estimate-cost.sh` still keys `gpt-5.3-codex` — see PLAN gap #1 |
| GPT-5.6 Sol | ~5.00 | ~30.00 | premium reasoning |
| Claude Opus 4.8 / Fable 5 | per Anthropic | per Anthropic | GDPval cost/task: Opus $1.78, Fable $3.25 |

## 6. Integration options considered

| Option | Verdict |
|---|---|
| A. Moonshot Anthropic-compatible endpoint via `claude -p` subprocess | Fast PoC, but foreign to Telar's envelope/budget system. Not the durable path. |
| B. One bespoke bash adapter per new CLI | Fits existing pattern but multi-touch every time (tool set hardcoded in ~6 spots). Rejected as the general mechanism. |
| **C1. Generic `compat.sh` adapter (chosen)** | Base-URL + model + auth-env + pricing from YAML. New model = YAML only. No new deps. |
| C2. pi.dev unified harness (`pi -p --mode json --model provider/name`) | MIT, BYOK, lists "Kimi For Coding", widest provider list incl. local/Ollama. **Optional later** adapter; adds Node dep + young project. |

## 7. Sources

Independent evaluators: artificialanalysis.ai (Intelligence Index v4.1, Coding Agent Index,
GDPval-AA v2, GPQA Diamond), vals.ai. Aggregators (weaker, list some dubious models):
benchlm.ai, llm-stats.com, codingfleet.com. Launch/press: officechai, the-decoder,
venturebeat, codersera. Integration: code.claude.com/docs/en/headless,
platform.kimi.ai/docs/guide/claude-code-kimi, github.com/openai/codex, pi.dev,
github.com/badlogic/pi-mono, github.com/aliou/pi-harness, aider.chat,
github.com/beehiveinnovations/zen-mcp-server, github.com/musistudio/claude-code-router.

## 7. Live benchmark (2026-07-18) — what actually revised the roster

Ran the same specs through the Telar dispatcher/harness across real backend frameworks
(**Rust/axum**, **TS/Hono**), plus an earlier LRU-cache round. Every model ran through the
same pipeline (implement + full cross-review); verdicts, cost, and speed were measured live.

### Implementation (Kimi K3 max · Sonnet 5 high · Opus 4.8 high · GPT-5.6-sol xhigh)
- **Both Claude models (Sonnet 5 high AND Opus 4.8 high) independently produced the
  contract-complete design** — in Rust they rejected the typed `Json<T>` extractor for manual
  `Bytes → serde_json::Value` parsing so malformed/missing/wrong-typed bodies still return the
  `{errors:[...]}` contract; in TS they rejected negative/NaN/empty `minPrice`. Both self-verified
  (`cargo build` / `tsc --strict` / runtime smoke). **Sonnet 5 high matched Opus 4.8 high** on
  correctness → Sonnet is the value default, Opus the critical-tier escalation.
- **Kimi K3 (max)** was the most compact + fast and even compiled its Rust, but left two real
  contract gaps (typed extractor; TS `minPrice` missing the `>=0`/finite guards) → opt-in cost mode,
  keep review ON. Marginal cost **$0** (Kimi-for-Coding flat subscription).
- **GPT-5.6-sol@xhigh** was the most thorough (wrote a full unprompted test suite) but the slowest
  (timed out at 300s on Rust; needs a higher `timeout_seconds`) and by far the most **expensive**
  (agentic implements accrued 300k–950k input tokens → $1.7–$5.2 each; total codex spend for the run
  ~$11) → not the pick for high-volume implementation.

### Reviewer calibration (cross-review, developer≠reviewer)
- **Opus = best-calibrated reviewer**: it compiled + ran the code under review (`cargo test`, `tsc`,
  runtime smoke), caught subtle real issues (e.g. a `tokio::sync` feature-unification fragility no one
  else saw), and graded severity accurately (PASS + WARNING).
- **GPT-5.6-sol@xhigh**: sharp recall (caught Kimi's real `minPrice` bug) but **over-strict** — it
  FAILed on a contract nuance its own code shares.
- **Kimi K3**: thorough edge-tracing but lenient (passed everything).
- ⇒ reviewer panel = **Opus primary + GPT-5.6-sol sharp-second**.

### Cost reality (per this run)
Kimi K3 = $0 (subscription) · Claude (Sonnet/Opus) = Claude-session (no external meter) ·
GPT-5.6-sol@xhigh = metered and pricey. This is exactly why implementation defaults to
Sonnet/Kimi and GPT-5.6-sol is reserved for (cheap, low-token) review.

## 8. Re-evaluation triggers

- **~2026-07-27** — Kimi K3 independent scores land → decide K3 promotion (developer seat / reviewer voice).
- Any new frontier model → because onboarding is config-only, re-tune the `routing.roles` block, no code change.
