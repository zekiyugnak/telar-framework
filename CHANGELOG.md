# Changelog

All notable changes to the telar-framework are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Five web/desktop agents to balance the mobile-heavy roster: `desktop-expert` (Electron & Tauri), `web-frontend-expert` (framework-agnostic React/TS), `web-security-architect` (opus), `web-performance-optimizer`, `web-accessibility-expert`.
- Three framework-agnostic web skills: `web-state-management`, `web-animations`, `web-testing`.
- Counts synced to 46 agents / 116 skills; orchestrator description de-mobiled.

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
