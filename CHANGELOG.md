# Changelog

All notable changes to the telar-framework are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
