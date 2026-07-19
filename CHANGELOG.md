# Changelog

All notable changes to the telar-framework are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.14.0] - 2026-07-19

### Added

- **Dual-host orchestration (Claude + Codex)** — the same project can now be driven natively by EITHER agentic host, with a **symmetric** role roster so neither vendor is permanently secondary (previously the roster hardcoded Claude as moderator/architect and Codex could only be a second-vote reviewer).
  - **`runtime.host` + host resolution** — new `runtime: { host: auto|claude|codex, host_env: TL_TELAR_HOST }` block and a `resolve-host` subcommand in `scripts/tl-telar-external-tools.sh`. Precedence: `--host` > `$TL_TELAR_HOST` > `runtime.host` (≠ `auto`) > runtime detection (`CODEX_*` / `CLAUDECODE`) > legacy `claude`.
  - **Symmetric `routing.profiles.{claude,codex}`** — primary roles (architect/moderator/developer/tester) resolve to the ACTIVE host's own models; `reviewer` lists the independent cross voices. Host-aware `resolve-role --host <h>` reads the active profile and falls back to `routing.roles` when no profiles exist. **Codex can now be moderator/architect/implementer**, with Claude + GPT-5.6 as reviewers.
  - **The anti-nest rule** — `models_registry` entries carry a home `host`; a model whose home host equals the active host runs NATIVELY in-harness (Claude → Task at tier; Codex → in-harness), every other model runs via its adapter. A host never nests its own CLI.
  - **External `claude.sh` adapter** — first-party sibling of `compat.sh` (no endpoint swap) that drives the native `claude` CLI so a **Codex host can call Claude for cross-model review**. Health reports `unavailable` on a Claude host (anti-nest backstop).
  - **New model tiers** — `gpt-5.6-terra` (Sonnet-class; the Codex `developer` default) and `gpt-5.6-luna` (Haiku-class) added to the registry. (`gpt-5.6-codex` was never a real model — Codex is the harness, not a tier — and is gone.)
  - **Orchestration mutex** — `scripts/tl-telar-orchestration-lock.sh` writes `.tl-telar/context/orchestration-lock.json`: atomic acquire, re-entrancy, stale-lock takeover, explicit takeover, heartbeat, and ownership-checked release — so two hosts never orchestrate the same plan at once.
  - **Per-role effort** — profiles set reasoning effort per role (architect + reviewer = `xhigh`, moderator = `high`, developer + tester = `high`), overriding the registry default; the escalation ladder bumps effort before switching models.
  - New offline tests: `external-tools-host.test.sh`, `external-tools-host-scenarios.test.sh`, `external-tools-codex-defaults.test.sh`, `orchestration-lock.test.sh` (host resolution + precedence, symmetric profiles, anti-nest, Codex-as-moderator scenarios, lock lifecycle).

### Changed

- Default reviewer roster is now **Claude Opus 4.8 + GPT-5.6 Sol at `xhigh`** (Gemini stays in the registry but is no longer a default reviewer).

### Backward compatibility

- Fully compatible: a config with no `runtime` + no `routing.profiles` keeps the previous Claude-primary behavior via the `routing.roles` fallback (verified by the existing `external-tools-routing.test.sh`, unchanged and green).

## [0.13.0] - 2026-07-18

### Added

- **Hybrid multi-model roster + config-only model onboarding** — the external-tools layer becomes model-agnostic so onboarding/swapping a frontier model is a YAML edit, not a code change (keeping pace with the constant stream of new models).
  - **Config-driven routing** — the valid external-tool set is now the `adapters.*` keys (the hardcoded `codex|gemini` list is gone from `scripts/tl-telar-external-tools.sh`); `--tool auto` walks `routing.escalation_order` (previously a dead config key) picking the first enabled+healthy adapter.
  - **`routing.roles` + `routing.models_registry`** — a small "virtual software team" role taxonomy (`architect`, `moderator`, `developer`, `reviewer`, `tester`) mapped to models, resolved deterministically via a new `resolve-role` subcommand. Curated default roster ships (Fable 5 → plan/moderation, Opus 4.8 → implementation, Opus 4.8 + GPT-5.6 Sol → review). Config is the single source of truth; interactive `/orchestrate` may offer an opt-in override menu that writes back to the config; headless/`resume` runs never prompt.
  - **Generic `compat.sh` adapter** (first-party, not vendored) — drives the `claude` CLI headless with a swapped Anthropic-compatible endpoint, so any Anthropic-compatible model (e.g. **Kimi K3** via Moonshot) runs the full agentic harness. Its cost extractor lives in the adapter, not in vendored `_common.sh` — new providers onboard without touching vendored code.
  - **Kimi K3 onboarded (disabled by default)** — `adapters.kimi` (type `compat`) + registry entry + cross-model review-matrix row. Held out of the correctness-critical implementer seat pending independent verification (~2026-07-27); available as an advisory reviewer.
  - **Budget $0-trap fixed** — `scripts/estimate-cost.sh` now takes per-adapter pricing (`adapters.*.pricing`) and **fails closed** on unknown/undeclared pricing; the dispatcher records the conservative per-task cap instead of a silent $0 that bypassed the budget circuit breaker. New `gpt-5.6-codex`/`gpt-5.6-sol`/`kimi-k3` price rows.
  - New tests: `estimate-cost.test.sh`, `external-tools-routing.test.sh`, `external-tools-compat.test.sh` (offline coverage of pricing fail-closed, config-driven routing, role resolution, compat health + cost extraction).

### Changed

- Renamed the execution-state `Writer Model` column → `Developer Model` and the "writer-cannot-be-reviewer" rule → "developer-cannot-be-reviewer" across the orchestration skills/agent/templates, aligning with the `developer` routing role.
- `scripts/tl-telar-reviewer-roster.js` no longer hardcodes `opus`; it takes `--model` (default `opus`) so the Claude reviewer tier comes from `routing.roles.reviewer` via `resolve-role`.
- **Benchmark-informed default roster** (see `RESEARCH-hybrid-models.md` §7 live benchmark): implementation `developer` = Sonnet 5 (high) default → Opus 4.8 (high) escalation for critical WUs → Kimi K3 (max) opt-in `$0` cost mode; `reviewer` = Opus (best-calibrated) + GPT-5.6-sol (sharp second). Added an `effort` field to `routing.models_registry` (Sonnet/Opus/Fable → high, GPT-5.6-sol → xhigh, Kimi K3 → max) and an `options` list to roles, both surfaced by `resolve-role`. GPT-5.6-sol needs codex ≥ 0.144 and its effort ladder is low<medium<high<xhigh<max<ultra (default is `low` — set it explicitly).

### Fixed

- `parse-verdict` now unwraps agent-stream envelopes (Strategy 0): a correct `{verdict,…}` nested inside a Codex JSONL `agent_message.text` string (or a claude `-p` `.result`) was previously reported `UNKNOWN` because the brace-scanner cannot see a verdict key buried in an escaped string. Surfaced by a live cross-model review (Codex returned a correct `FAIL` that the gate mis-read). Covered by `external-tools-parse-verdict.test.sh`.

## [0.12.0] - 2026-07-17

### Added

- **Risk-tiered per-WU review** — the adversarial code-review roster now scales with each Work Unit's `risk_tier` instead of firing the full lens set on every change. The philosophy: front-load rigor into the plan (where a defect is cheap to fix), keep implementation review thin, and escalate only where risk warrants it.
  - **`risk_tier` (trivial | standard | critical)** on the Work Unit schema, derived at decomposition from blast radius + `file_scope` sensitivity + size. `scripts/tl-telar-reviewer-roster.js` gained `--risk-tier`: `trivial` → Code-only; `standard` (default) → Code + Maintainability + Security (only on the sensitive-path floor or a high-stakes backend/Rust/desktop domain) + BackendCorrectness; `critical` → the full roster (adds FrontendUX + Accessibility + Performance). A pure UI change drops from ~6 reviewers to 1–2 at standard tier while a critical change keeps the full set.
  - **Sensitive-path Security floor** — any `file_scope` path touching auth / oauth / session / token / jwt / password / secret / crypto / payment / billing / migration / `.sql` / rls / acl / access-control (matched camelCase-aware) forces a Security reviewer on **every** tier, never droppable — the guardrail against a small diff to critical code being under-reviewed.
  - **Mandatory plan-rigor fields** — `data_contracts`, `edge_cases`, and `test_plan` are now required on every code-bearing Work Unit; the `plan-review-gate` Completeness reviewer FAILs a plan that leaves them vacuous, and rejects an under-tagged `critical` WU (RISK-TIER HONESTY gate).
  - **Incremental sticky-pass retries** — on a review FAIL, only the failing reviewer(s) plus any prior-PASS reviewer whose concern intersects the fix diff re-run; the rest keep their PASS. `critical`-tier Security is never sticky. Cross-model (Codex/Gemini) second review re-runs targeted at the fix.
  - **Critical-tier qualitative escalation** — a `critical` WU adds an up-front design-review gate, mandatory negative/adversarial tests, CI lenses flipped strict, an adversarial cross-model prompt, and a forced human checkpoint (four-eyes) — escalating the *quality* of scrutiny, not just the reviewer count.
  - New `review` block + `enforcement.security_command`/`security_strict` in `tl-telar-thresholds.json` documenting the tier policy and the Katman-1 CI lenses (axe / perf-budget / semgrep) that standard-tier review relies on instead of LLM specialists.
  - Cross-model second review remains config-gated (`external-tools.yaml`), **not** tier-gated: when enabled it runs on every WU regardless of tier.

### Changed

- `adversarial-code-review`, `orchestrated-execution`, and the `orchestrator` agent updated to thread `risk_tier` into the Phase-3 roster and to run incremental (not full-roster) re-review on retry. Docs (`README`, `docs/orchestration.html`, `CLAUDE.md`) updated to describe the risk-tiered roster.

## [0.11.0] - 2026-07-14

### Added

- **Web E2E testing capability** — a reusable, stack-aware end-to-end testing capability for the modern React web stack (React 19 + Vite + Refine / TanStack Router + TanStack Table + shadcn/ui + Supabase + Playwright), codifying proven, ADR-backed harness patterns rather than importing generic tooling.
  - New skills: **`supabase-e2e-harness`** (the Arrange/Act test-data model — `service_role` provisions data, every act runs through real UI + RLS; plain-`fetch` factory instead of `supabase-js`; `runId` namespacing instead of teardown), **`web-e2e-locators`** (stable `data-testid`/role locators + no-fixed-sleep waiting for shadcn/Radix, TanStack Table/Query, react-hook-form/zod), **`web-e2e-catalog`** (scenario matrix + `@smoke`/`@basic`/`@full` tag taxonomy + phased regression orchestrator + multi-baseURL Playwright config), and **`web-e2e-review`** (24-pattern P0/P1/P2 silent-always-pass anti-pattern gate, including a `service_role`-in-act violation check).
  - New agent **`web-e2e-testing-expert`** (a web sibling of `mobile-e2e-testing-expert`) driving the four skills, with Refine/TanStack route discovery and the official Playwright agents (Planner/Generator/Healer) + MCP live-verification engine.
  - New command **`/tl-telar:setup-web-e2e`** — a 4-phase scaffold (detect stack → scaffold factory + config → generate first scenario → wire CI + review).
  - `web-testing` skill extended with an E2E-engine section (official Playwright agents vs MCP live-verify); `setup-e2e` now routes web apps to `setup-web-e2e`; `iterative-build-loop` gained a browser-verification path (Playwright MCP) alongside simulator verification.

## [0.10.0] - 2026-07-14

### Added

- **Maintainability reviewer + `clean-code` skill** — a software-design-literature-grade code-quality gate. New always-on `Maintainability` reviewer (rubric `maintainability-design-adversarial-rubric.md`) catches duplication (textual + semantic), bloat, Fowler smells, and SOLID/coupling defects as BLOCKING failures and surfaces reuse/refactor suggestions (e.g. "extract this widget to `common`") as non-blocking ADVISORY findings — balanced by binding do-not-over-apply guardrails (Metz wrong-abstraction, YAGNI scope, Muratori). Shared `clean-code` authoring skill wired into the orchestrated-execution IMPLEMENT preamble and 14 code-writing agents; FrontendUX + BackendCorrectness rubrics, the `review-code` command, and review-gates Stage 2 gained reuse/duplication checks; advisories are surfaced to the user (non-blocking).

## [0.9.0] - 2026-07-08

### Added

- **OKF knowledge layer** — first-class support for the newly announced [Open Knowledge Format](https://github.com/GoogleCloudPlatform/knowledge-catalog) (OKF v0.1): an optional `docs/knowledge/` domain-knowledge bundle that agents read for orientation before touching a table or schema, while ADRs and the schema spec remain the source of truth.
  - `okf-knowledge-curator` agent — cross-cutting campaign work (bulk-produce concepts, drift-lint, cross-link the concept graph); routes high-stakes concepts (Access Policy / Invariant / Compliance Control) to adversarial review; no-op if the project ships no bundle.
  - `okf-knowledge-authoring` skill — the shared authoring contract (frontmatter + required non-empty `type`, `# Citations` origin, one-way authority, PII boundary, cross-linking, pre-merge validation checklist).
  - Consumer rule wired once into the orchestrated-execution IMPLEMENT preamble — every Work Unit implementer reads the relevant concept before touching a table; generic and conditional (no-op without a bundle), never duplicated per-agent.

### Changed

- Counts synced to 47 agents / 117 skills across manifests, README, CLAUDE.md, and the documentation site (agent + skill cards).

## [0.8.0] - 2026-07-06

### Added

- Five web/desktop agents to balance the mobile-heavy roster: `desktop-expert` (Electron & Tauri), `web-frontend-expert` (framework-agnostic React/TS), `web-security-architect` (opus), `web-performance-optimizer`, `web-accessibility-expert`.
- Three framework-agnostic web skills: `web-state-management`, `web-animations`, `web-testing`.

### Changed

- Counts synced to 46 agents / 116 skills across manifests, README, CLAUDE.md, and the documentation site (agent cards + skill entries); `orchestrator` description de-mobiled.

## [0.7.0] - 2026-07-06

### Added

- Per-agent model tiering (frontmatter `model:`; opus/sonnet/haiku) and Opus-pinned adversarial reviewers, plus Codex per-agent `model_reasoning_effort` tiering.
- Stack-aware adversarial reviewer roster resolver (`scripts/tl-telar-reviewer-roster.js`) that selects reviewers by Work-Unit file scope across mobile, web, backend-data, rust, and desktop domains.
- Domain review rubrics: web-security, backend-data-security, web-accessibility, rust-safety, web-performance, backend-correctness, frontend-ux, and desktop-security; generic code rubric extended with simplicity/coupling criteria.
- CI workflow (`.github/workflows/ci.yml`) on pull requests to `main`/`develop`: unit test suites, agent/skill/blueprint validation, and a Codex-artifact drift guard that regenerates `.agents/`, `.codex/`, and `plugins/tl-telar/` and fails if they diverge from source.

### Changed

- De-mobiled the framework identity across the README, docs site, and manifests — Telar is a multi-domain (mobile/web/Rust/desktop) framework, not mobile-only.
- Renamed cross-cutting agents to drop the misleading `mobile-` prefix: `orchestrator`, `architect-adversarial`, `knowledge-curator` (genuine mobile specialists keep the prefix).
- Codex plugin curation: internal-only agents excluded from the installable skill channel; trimmed the `source/skills` copy to the referenced orchestration subtree.
- Honest Codex-host gate degradation: probe for subagent support, else emit a DEGRADED banner instead of a faked single-reviewer pass.
- Finalized Codex install guidance across the README and documentation site (marketplace ref commands; plugin install distinguished from the optional `adapters.codex` delegation).

## [0.6.0] - 2026-07-05

### Added

- Codex-compatible plugin distribution generated from the same Telar source files as the Claude plugin.
- Codex marketplace metadata, installable plugin manifest, generated skills, and generated custom-agent TOML files.
- README and documentation-site installation guidance for both Claude Code and Codex, including repository-based Codex marketplace commands.

### Fixed

- External-tools health now works in Codex read-only sandbox mode without creating temporary project files.
- Codex orchestration packaging now includes the source agents, commands, scripts, resources, rules, hooks, templates, and original Telar orchestration skill sources needed by workflow gates.

## [0.5.0] - 2026-07-03

Adds opt-in adoption of newer Claude Code native capabilities (Dynamic Workflows for the plan-review gate, git-worktree isolation for parallel Work Units), all capability-gated and fail-closed so older Claude Code degrades to the current behavior with no change.

### Added

- **`cc_features` config block** (`.tl-telar/external-tools.yaml`): opt-in adoption of newer Claude Code native capabilities, following the existing adapters idiom. `enabled` is *intent*, not capability — a feature activates only when `enabled: true` **and** a runtime capability probe confirms it, otherwise the orchestrator falls back to the current-behavior path (fail-closed), logs a one-line advisory, and never hard-fails on absence. Defaults are `true` because every path degrades gracefully on older Claude Code. Keys: `cc_features.dynamic_workflows.{enabled,on_unavailable}`, `cc_features.worktree_isolation.{enabled,on_unavailable}`.
- **`scripts/tl-telar-cc-features.sh`** — deterministic gating resolver that turns the prose "enabled-is-intent, fail-closed" rule into one tested code path. `resolve`/`decision` subcommands take the runtime capability probe result (only the agent can see tool/worktree availability) and emit `active | fallback | blocked`. The plan-review skill and the orchestrator's Step 5b now call it instead of hand-reasoning the flag/capability logic. Matrix-tested: `tests/workflow/cc-features.test.sh` (21 cases: enabled × capability × on_unavailable) and `tests/workflow/cc-features-integration.test.sh` (7 cases chaining config → resolver → scheduler `--isolate`, proving the two features gate independently).
- **Plan review gate — Dynamic Workflow path** (`skills/orchestration/plan-review-gate/workflow/plan-review.mjs`): a deterministic Workflow script that runs the 3 adversarial reviewers via `parallel()` with schema-validated verdicts and returns the identical aggregated verdict object the prose gate produces. The skill now selects a prefer-workflow-else-prompt substrate: when the `Workflow` tool is available and `cc_features.dynamic_workflows.enabled` is true it uses the script; otherwise it runs the unchanged agent-prompt path. `references/reviewer-prompts.md` and `references/verdict-schema.md` remain the single source of truth for both paths.
- **Worktree isolation for parallel WU execution** (`cc_features.worktree_isolation`): when active, each Work Unit runs in its own git worktree so WUs with **overlapping** `file_scope` run concurrently — relaxing the disjoint-file-scope constraint that previously serialized them. The scheduler (`tl-telar-wu-scheduler.js`) gains a pure `isolateFileScope` mode (opt-in via `--isolate`; default off, existing tests unchanged) that skips only the file-conflict gate — deps, concurrency cap, critical-path order, and cycle detection are identical. The orchestrator adds a fail-closed capability preflight (Step 5b), spawns WU Tasks with `isolation: worktree`, and merge-backs each WU's `wu-<id>` branch with `git merge --squash` (staged, uncommitted — `ben yapacagim` preserved), routing merge conflicts through the existing retry/escalate loop. New `.worktreeinclude` template + `.claude/worktrees/` gitignore entry. New `tests/workflow/isolation.test.js`.

### Notes

- **Min Claude Code version:** the Dynamic Workflows path requires a Claude Code build that exposes the `Workflow` tool; worktree isolation requires `isolation: worktree` support. Both are **capability-gated and fail-closed** — on older builds the plan gate runs the prose path and WU execution runs disjoint-scope serialization, with no behavior change. Defaults are `enabled: true` because absence degrades safely.

## [0.3.1] - 2026-07-03

### Added

- **Configuration reference** (`docs/configuration.md`): comprehensive single-source doc covering every key in `.tl-telar-thresholds.json` (coverage, performance, size, accessibility, autonomy, execution, enforcement) and `.tl-telar/external-tools.yaml` (adapters, routing, budget, cross-model review matrix), plus hardcoded values and auto-managed state files.
- Link to configuration reference from README.

### Fixed

- **Dispatcher timeout bug**: `timeout_seconds` from `external-tools.yaml` was read but never forwarded to the adapter — adapters always used the 300 s default regardless of config. The dispatcher now reads `adapters.<tool>.timeout_seconds`, validates it, and passes `--timeout` to the adapter.
- **Layer-B hard timeout wrapper**: dispatcher wraps the adapter invocation with system `timeout`/`gtimeout` when available, so a hung adapter process (e.g. MCP transport glitch) cannot block indefinitely even if the adapter's own `safe_invoke` fails to fire.
- **Timeout envelope synthesis**: when the outer wrapper kills the adapter before it can emit JSON, the dispatcher synthesises a well-formed `error_type: "timeout"` envelope so callers always receive parseable output.

## [0.3.0] - 2026-07-02

Adds Work Unit-level parallelism to orchestrated mode — independent Work Units now run concurrently.

### Added

- **Work Unit-level parallelism for orchestrated mode.** A portable, pure Node scheduler (`scripts/tl-telar-wu-scheduler.js`) computes a readiness frontier from each WU's existing `deps` and `file_scope`, so independent Work Units run as concurrent background `Task()`s instead of one at a time. Deadlock-free by construction (atomic, all-or-nothing file-scope acquisition), with critical-path ordering and a plan-time ambiguity check (two dependency-unordered WUs writing the same path). The orchestrator recomputes the frontier on every WU completion.
- `execution.max_parallel_wus` threshold (default 3) to cap orchestrator concurrency, in `.tl-telar-thresholds.json` and the framework-aware `setup-orchestration` output.
- Multi-WU execution-state format (`## Active Work Units`, multiple `IN-PROGRESS` rows) with scheduler-driven resume and crash reclamation of orphaned WUs.
- `tests/workflow/` suite (parse, readiness, diamond-DAG integration, CLI smoke) covering the scheduler end to end.

### Changed

- The orchestrator's WU execution step is now a continuous-frontier dispatch loop; the `recovery` skill and `execution-state.md` template were reconciled to the multi-WU model. Single-WU plans behave exactly as before.

## [0.2.0] - 2026-07-02

Adds a companion web stack and a Rust service layer alongside the existing mobile agents.

### Added

- 4 new agents: `astro-web-expert`, `nextjs-web-expert`, `admin-panel-architect`, `rust-service-architect`.
- 18 new skills covering Astro (SEO/OG, content performance), Next.js/Tailwind/shadcn, a Vite + TanStack Router/Query/Table admin panel with Supabase (anon key + RLS only, TUS resumable uploads, Tremor charts, FormatJS/Lingui i18n with RTL-readiness), and a narrow-topic Rust/axum/sqlx service breakdown (routing, sqlx patterns, service architecture, testing pyramid, deployment).
- Totals: 41 agents (was 37), 113 skills (was 95).

## [0.1.0] - 2026-06-25

Initial release.

Telar is a multi-agent engineering framework for Claude Code that takes a feature
from idea to production — orchestrated planning, adversarial review gates, a
persistent knowledge base, and cross-model verification. Its first edition targets
cross-platform mobile (React Native & Flutter) with deep native integration.

### Added

- 37 agents, 95 skills, 23 commands, 4 hooks, 7 rules, 19 scripts.
- Orchestrated 4-phase execution loop (IMPLEMENT / VALIDATE / REVIEW / COMMIT) per work unit.
- Adversarial plan review gate (3 fresh reviewers) and collaborative 6-reviewer design gate.
- Knowledge base: typed JSONL facts auto-primed into context each session; populated via `/tl-telar:self-reflect`.
- 3-file state persistence under `.tl-telar/` with a SessionStart hook that re-primes context after compaction or restart.
- Authoring kit under `templates/` (requirements, epic, worked example) for `/tl-telar:orchestrate` inputs.
- External AI layer (Codex/Gemini adapters) with a budget circuit breaker and cross-model review — disabled by default.
