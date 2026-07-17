# Telar v0.12.0

Agentic engineering framework for Claude Code, spanning cross-platform apps end to end: mobile (React Native, Flutter, native bridges), web (Astro, Next.js/Tailwind/shadcn, Vite/TanStack admin panels), Rust service layers, and desktop. Not mobile-only — the orchestration, reviewer roster, and rubrics are stack-aware across every domain. The per-WU reviewer roster is also **risk-tiered**: rigor is front-loaded into planning, so implementation review stays thin for low-risk work and escalates only where risk warrants it.

## Quick Start

| Goal | Command |
|------|--------|
| New app from scratch | `/tl-telar:create-app [description]` |
| Add feature to existing app | `/tl-telar:add-feature [feature]` |
| Update a requirement mid-project | `/tl-telar:update-requirement [F-x] [change]` |
| Run mobile app tests | `/tl-telar:test-app [scope]` |
| Code review | `/tl-telar:review-code [path]` |
| Review a plan (adversarial gate)  | `/tl-telar:review-plan [--latest]` |
| End-to-end orchestrated build | `/tl-telar:orchestrate <task>` |
| Resume an in-progress orchestrated plan | `/tl-telar:resume` |
| Set up orchestration (framework detection) | `/tl-telar:setup-orchestration` |
| Prime KB facts into context | `/tl-telar:prime [--files <glob>] [--keywords <kw>] [--work-type <t>]` |
| Capture learnings to KB | `/tl-telar:self-reflect [<days>]` |
| External AI tools health check | `/tl-telar:external-tools-health` |
| Design review gate (collaborative, 6 reviewers) | `/tl-telar:review-design [--latest]` |
| Security audit | `/tl-telar:audit-security [scope]` |
| Accessibility audit | `/tl-telar:audit-accessibility [scope]` |
| Performance optimization | `/tl-telar:optimize-perf` |
| Release to stores | `/tl-telar:release-app` |
| Set up CI/CD | `/tl-telar:setup-cicd` |
| Set up E2E tests | `/tl-telar:setup-e2e` |
| Set up web E2E tests | `/tl-telar:setup-web-e2e [app-path]` |
| Migrate native to cross-platform | `/tl-telar:migrate-app` |
| Upgrade dependencies | `/tl-telar:upgrade-deps` |
| Set up OTA updates | `/tl-telar:setup-ota` |
| Design system setup | `/tl-telar:design-system` |

## Workflow

The recommended workflow for building features:

1. **Explore** — Always read the existing codebase first (`codebase-first` rule)
2. **Requirements** — Establish what to build in `REQUIREMENTS.md` (`requirements-gather` skill)
3. **Research** — Decide how to build it technically in `RESEARCH.md` (`brainstorm-first` skill)
4. **Plan** — Break work into atomic tasks in `PLAN.md` + `PROGRESS.md` (`plan-and-track` skill)
5. **Build** — Iterate with simulator verification (`iterative-build-loop` skill)
6. **Debug** — When failures occur, find root cause before fixing (`systematic-debugging` skill)
7. **Verify** — Require fresh evidence before claiming done (`verification-before-completion` skill)
8. **Review** — Two-stage review gates: requirement compliance + code quality (`review-gates` skill)
9. **Commit** — Use mobile-specific conventional commits (`mobile-commit-convention` skill)

## Agent Discovery

**48 agents** organized by domain:

- **Platform experts**: `react-native-expert`, `flutter-expert`
- **Web platform experts**: `astro-web-expert` (SEO/OG marketing sites), `nextjs-web-expert` (authenticated Next.js/Tailwind/shadcn consoles), `admin-panel-architect` (Vite + TanStack Router/Query/Table admin panels), `web-frontend-expert` (framework-agnostic React/TS SPA)
- **Web specialists**: `web-security-architect` (appsec/authz/CSP/threat-modeling), `web-performance-optimizer` (Core Web Vitals/bundle/render), `web-accessibility-expert` (WCAG 2.2 AA)
- **Desktop**: `desktop-expert` (Electron & Tauri — secure IPC, packaging, auto-update)
- **Service layer**: `rust-service-architect` (axum/tokio/sqlx backend services)
- **Native bridges**: `ios-native-bridge`, `android-native-bridge`
- **Architecture**: `mobile-navigation-architect`, `mobile-state-management`, `mobile-backend-architect`, `architect-adversarial`
- **UI/UX**: `mobile-ui-ux-specialist`, `mobile-accessibility-expert`, `mobile-animations-specialist`, `mobile-design-system-architect`, `mobile-screen-builder`
- **Security**: `mobile-security-specialist`, `mobile-security-architect`
- **Performance**: `mobile-performance-optimizer`
- **Offline**: `mobile-offline-architect`
- **CI/CD & Release**: `mobile-cicd-engineer`, `mobile-release-manager`, `mobile-code-signing-expert`, `mobile-ota-updates-specialist`
- **Stores**: `ios-app-store-specialist`, `google-play-specialist`
- **Testing**: `mobile-unit-testing-expert`, `mobile-e2e-testing-expert`, `web-e2e-testing-expert`, `mobile-device-testing`, `mobile-performance-testing`
- **Backend**: `supabase-expert`, `mobile-api-integration`, `mobile-push-notifications`, `mobile-auth-specialist`, `mobile-storage-specialist`
- **Advanced**: `mobile-ai-integration`, `mobile-ar-vr-specialist`, `mobile-realtime-specialist`
- **Orchestration**: `orchestrator`
- **Knowledge**: `knowledge-curator` (JSONL agent-memory KB — `.tl-telar/knowledge/*.jsonl`), `okf-knowledge-curator` (OKF domain-knowledge bundle — `docs/knowledge/`; bulk produce / drift-lint / cross-link; no-op if no bundle)

## Skill Discovery

**122 skills** including:

- **Blueprints** (`skills/blueprints/`): auth-flow, crud-list, chat-feature, settings-screen, onboarding-flow
- **Astro**: astro-seo-og, astro-content-performance
- **Next.js/Tailwind/shadcn**: shadcn-component-patterns, tailwind-v4-design-tokens, nextjs-auth-app-router
- **Admin panel (Vite + TanStack)**: tanstack-router-patterns, tanstack-query-patterns, tanstack-table-patterns, supabase-rls-client-patterns, supabase-tus-resumable-upload, command-palette-cmdk, tremor-dashboard-charts, i18n-rtl-formatjs-lingui
- **Web E2E**: supabase-e2e-harness, web-e2e-locators, web-e2e-catalog, web-e2e-review
- **Rust service**: rust-axum-routing, rust-sqlx-patterns, rust-service-architecture, rust-testing-pyramid, rust-deployment
- **Web (framework-agnostic)**: web-state-management, web-animations, web-testing
- **Workflow**: requirements-gather, brainstorm-first, plan-and-track, review-gates, iterative-build-loop, mobile-commit-convention, systematic-debugging, verification-before-completion
  - `plan-review-gate` — adversarial 3-reviewer gate on PLAN.md (orchestration namespace, sub-spec 1)
  - `orchestrated-execution` — 4-phase IMPLEMENT/VALIDATE/REVIEW/COMMIT loop (orchestration namespace, sub-spec 2)
  - `adversarial-code-review` — SIDECAR for review-gates; a risk-tier-scaled fresh-reviewer roster per WU (trivial→Code-only, standard→Code+Maintainability+floor-Security, critical→full roster), a never-droppable sensitive-path Security floor, and incremental sticky-pass retries (sub-spec 2)
  - `mobile-adversarial-review` — specialist spawn template for a11y/perf reviewers (sub-spec 2)
  - `recovery` — compaction + cross-session resume; reads 3-file state (orchestration namespace, sub-spec 4)
  - `prime` — KB retrieval primer; emits 5-category facts (orchestration namespace, sub-spec 5)
  - `self-reflect` — 3-phase KB capture with user-approval gate (orchestration namespace, sub-spec 5)
  - `design-review-gate` — 6-reviewer collaborative gate on RESEARCH.md/design docs (PM/Architect/Designer/Security-Design/CTO/Mobile-Platform) (orchestration namespace, sub-spec 6)
  - `external-tools` — Layer A/B external AI delegation (Codex/Gemini adapters + dispatcher); Phase β, disabled by default (orchestration namespace, sub-spec 7)
- **Knowledge (OKF)**: `okf-knowledge-authoring` — author/maintain `docs/knowledge/` concepts (OKF format + one-way authority + PII contract); paired with the `okf-knowledge-curator` agent
- **Quality**: `clean-code` — literature-grounded DRY/SOLID/reuse authoring contract (Metz wrong-abstraction test + do-not-over-apply guardrails); enforced by the always-on Maintainability reviewer
- **Requirements**: requirements-gather, requirements-traceability, update-requirement (command)
- **Design**: design-system-persistence, component-scaffolding, prompt-to-screen, mobile-design-system
- **Platform**: rn-navigation, flutter-navigation, rn-state-management, flutter-state-management, ...
- **Meta**: create-skill (for adding new skills to this plugin)

## Active Rules (always applied)

1. `mobile-security.md` — Security best practices
2. `quality-gates.md` — Pre-commit, pre-PR, pre-release quality checks
3. `performance-standards.md` — Performance budgets and thresholds
4. `codebase-first.md` — Explore project before generating code
5. `platform-conventions.md` — Apple HIG + Material Design 3 compliance
6. `requirements-first.md` — REQUIREMENTS.md must exist before implementing features
7. `simplicity-first.md` — Minimum code that solves the problem; no speculative abstractions

## Scripts

| Script | Usage |
|--------|-------|
| `scripts/sim-control.sh` | Simulator/emulator automation: `list`, `boot`, `screenshot`, `install`, `launch` |
| `scripts/project-detect.sh` | Detect project type, framework, nav, state mgmt (JSON output) |
| `scripts/validate-skills.js` | Validate all skill frontmatter and structure |
| `scripts/validate-agents.js` | Validate all agent frontmatter and structure |
| `scripts/validate-blueprints.js` | Validate blueprints have RN + Flutter + tests + a11y |
| `scripts/compile-agents-md.js` | Regenerate AGENTS.md from agent files |
| `scripts/build-helper.js` | Build utilities |
| `scripts/store-assets-generator.js` | Generate store asset templates |
| `scripts/perf-smoke.sh` | Performance smoke stub (advisory; flip `enforcement.perf_strict: true` to enable blocking) |
| `scripts/size-check.sh` | APK/IPA size check stub (advisory; flip `enforcement.size_strict: true` to enable blocking) |
| `scripts/orchestration-setup.sh` | Framework detection + .tl-telar/ skeleton + idempotent .gitignore append (sub-spec 4) |
| `scripts/tl-telar-prime.sh` | KB retrieval primer. Reads `.tl-telar/knowledge/*.jsonl`, applies file/keyword/work-type filters via jq, emits 5-category facts (MUST FOLLOW / GOTCHAS / PATTERNS / DECISIONS / API BEHAVIORS). `--json` mode for SessionStart hook injection. |
| `scripts/tl-telar-fetch-pr-comments.ts` | Pure data fetcher for PR comments (CodeRabbit / Bugbot / Greptile / Copilot / human). Writes `.tl-telar/temp/pr-comments.json`. Phase A of `/tl-telar:self-reflect`. Graceful degrade when no `gh auth`. |
| `scripts/tl-telar-self-reflect.sh` | Phase A/B/C driver for `/tl-telar:self-reflect`. Phase A: harvest PR comments via the fetcher above; Phase B/C handed off to the LLM via the skill prompt. |
| `scripts/tl-telar-wu-scheduler.js` | Pure WU readiness scheduler for `/tl-telar:orchestrate`. Reads `.tl-telar/plans/active-plan.md` + `.tl-telar/context/execution-state.md`, returns JSON `{ready, blocked, running, occupied_files, plan_warnings}` — the WUs whose `deps` are COMPLETE and whose `file_scope` is disjoint from every running WU, bounded by `execution.max_parallel_wus` (default 3). Deadlock-free (atomic all-or-nothing file-set acquisition); flags ambiguous plans (two dep-unordered WUs writing the same path). |
| `scripts/tl-telar-external-tools.sh` | Layer B dispatcher: dispatch/health/budget-status/parse-verdict subcommands; real YAML parsing (yq or python3+PyYAML), cheapest-available routing + escalation, budget ledger (`.tl-telar/context/external-tools-budget.jsonl`) with fail-closed circuit breakers. |
| `scripts/estimate-cost.sh` | USD estimator for external adapter invocations. |
| `scripts/tl-telar-cc-features.sh` | Deterministic `cc_features` gating resolver. `resolve`/`decision` subcommands read `cc_features.*` from `external-tools.yaml`, take the runtime capability probe result, and emit `active｜fallback｜blocked` (fail-closed: `active` requires the probe to confirm the capability). Called by the plan-review gate and orchestrator Step 5b so gating is one tested path, not prose. |

## Resources

- `resources/decision-trees/` — Framework, state management, and backend selection guides
- `resources/platform-guides/` — iOS and Android platform-specific references
- `resources/checklists/` — Release, security, and accessibility checklists
- `resources/reasoning-rules/` — Agent reasoning patterns

## Authoring Templates (`templates/`)

Author-facing inputs for `/tl-telar:orchestrate`. See README → "Authoring inputs for `/tl-telar:orchestrate`".

- `templates/requirements.md` — program-level requirements (what & why; F-x + acceptance + UI-x + NFR + decisions)
- `templates/epic.md` — single-feature epic; each `## Task` decomposes 1:1 into a Work Unit (the `--epic` input)
- `templates/examples/` — generic worked example (email/password login) showing a requirements slice + a ready `--epic` file
