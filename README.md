# Telar

> **The agentic engineering framework** — plan, build, review, and ship, with agents.
> By Zeki Yugnak · v0.13.0 — 48 agents, 122 skills, 24 commands, 4 hooks, 7 rules, 29 scripts

Telar is a multi-agent engineering framework for Claude Code and Codex that takes a feature from idea to production — orchestrated planning, adversarial review gates, a persistent knowledge base, cross-model verification, and a new OKF domain-knowledge layer. It spans cross-platform apps end to end: **mobile** (**React Native** & **Flutter**) with deep native integration, **web** (**Astro**, **Next.js**/Tailwind/shadcn, **Vite**/TanStack admin panels), **Rust** service layers, and **desktop** — with stack-aware orchestration, reviewers, and rubrics across every domain.

**Config-driven hybrid model roster (v0.13):** assign the best model to each pipeline role — `architect` / `moderator` / `developer` / `reviewer` / `tester` — in `external-tools.yaml`, and mix Claude (Sonnet 5 / Opus 4.8 / Fable 5), **GPT-5.6-sol** (via the Codex adapter) and **Kimi K3** (via a native `kimi` CLI adapter or a generic Anthropic-compatible `compat` adapter) freely. Onboarding a new model is a YAML edit, not a code change; pricing is fail-closed and reviews stay cross-model. Benchmark-tuned defaults: **Sonnet 5 (high)** implements, **Opus 4.8 (high)** escalates on critical work, **Kimi K3** is an opt-in `$0`-marginal cost mode, and review runs **Opus + GPT-5.6-sol** in parallel.

## 📖 Full documentation

**[zekiyugnak.github.io/telar-framework →](https://zekiyugnak.github.io/telar-framework/)**

The full reference — every agent, skill, command, and rule, plus the orchestration deep-dive and end-to-end examples — lives on the documentation site. This README is just the entry point.

| | |
|---|---|
| [Getting Started](https://zekiyugnak.github.io/telar-framework/getting-started.html) | Install and run your first command |
| [Agents](https://zekiyugnak.github.io/telar-framework/agents.html) | 46 specialized subagents |
| [Skills](https://zekiyugnak.github.io/telar-framework/skills.html) | 116 reference modules |
| [Commands](https://zekiyugnak.github.io/telar-framework/commands.html) | 23 slash-command workflows |
| [Rules](https://zekiyugnak.github.io/telar-framework/rules.html) | 7 always-on standards |
| [Orchestration](https://zekiyugnak.github.io/telar-framework/orchestration.html) | The opt-in pipeline, in depth |
| [Examples](https://zekiyugnak.github.io/telar-framework/examples.html) | End-to-end command flows |
| [Configuration](https://zekiyugnak.github.io/telar-framework/configuration.html) | All config keys — `.tl-telar-thresholds.json` and `external-tools.yaml` (incl. `cc_features`) |

## Installation

### Claude Code

```bash
# Add the marketplace
claude plugin marketplace add zekiyugnak/telar-framework

# Install the plugin
claude plugin install tl-telar@telar
```

After installation, restart Claude Code to load the plugin. All commands are namespaced under `/tl-telar:`.

### Codex

Telar also ships a generated Codex plugin from the same repository. Install it from the GitHub marketplace source, not from a local checkout:

```bash
# Latest development build
codex plugin marketplace add zekiyugnak/telar-framework --ref develop
codex plugin add tl-telar@telar
codex plugin list --marketplace telar
```

For the stable `main` branch, use:

```bash
codex plugin marketplace add zekiyugnak/telar-framework --ref main
codex plugin add tl-telar@telar
```

If you previously added the marketplace with another ref, refresh it before reinstalling:

```bash
codex plugin remove tl-telar@telar
codex plugin marketplace remove telar
codex plugin marketplace add zekiyugnak/telar-framework --ref develop
codex plugin add tl-telar@telar
```

Start a new Codex thread and invoke Telar with `@tl-telar` or specific bundled skills such as `$create-app`, `$review-plan`, or `$orchestrate`.

If you already have a user-level Codex skill with the same name, prefer `@tl-telar` so Codex resolves the Telar plugin context.

Codex plugin installation is separate from the optional `adapters.codex` entry in `.tl-telar/external-tools.yaml`. The plugin loads Telar into Codex; the adapter lets Telar delegate selected orchestration work to the Codex CLI when explicitly enabled.

## Quick start

| Goal | Command |
|------|---------|
| New app from scratch | `/tl-telar:create-app [description]` |
| Add a feature | `/tl-telar:add-feature [feature]` |
| Run tests | `/tl-telar:test-app [scope]` |
| Code review | `/tl-telar:review-code [path]` |
| End-to-end orchestrated build | `/tl-telar:orchestrate <task>` |
| Release to stores | `/tl-telar:release-app` |

See the [command reference](https://zekiyugnak.github.io/telar-framework/commands.html) for all 23 workflows.

## Highlights

- **47 specialized agents** — mobile & native platform experts, native bridges, architecture, security, testing, release, orchestration; a full web stack (Astro/Next.js/Vite-TanStack plus a framework-agnostic React expert and web security/performance/accessibility specialists); Rust services; and desktop (Electron/Tauri).
- **122 skills** — reusable reference modules, decision frameworks, and ready-to-use feature blueprints for React Native, Flutter, the web stack, and Rust services.
- **Two-stage review gates** — requirement compliance and code quality, with adversarial and collaborative reviewers.
- **🆕 Risk-tiered review (new)** — rigor is front-loaded into the plan (mandatory `data_contracts`/`edge_cases`/`test_plan` per Work Unit, enforced by the plan gate), so implementation review stays fast. The per-WU adversarial roster scales with each WU's `risk_tier` — `trivial`→Code-only, `standard`→Code+Maintainability (UI a11y/perf handled by CI lenses), `critical`→full roster + up-front design gate + human checkpoint. A sensitive-path Security floor (auth/token/payment/migration/…) is never droppable by tier, retries re-review incrementally (sticky-pass), and cross-model review stays always-on when configured.
- **Orchestrated mode (opt-in)** — design + plan review gates, a 4-phase IMPLEMENT/VALIDATE/REVIEW/COMMIT loop, and blocking quality gates. Independent Work Units run in parallel — a pure readiness scheduler dispatches concurrent WUs whose dependencies are met and file scopes are disjoint (bounded by `execution.max_parallel_wus`). The orchestrator honors your git policy and never auto-commits.
- **Persistent knowledge base** — typed JSONL facts captured via `/tl-telar:self-reflect` and re-primed into context each session.
- **🆕 OKF knowledge layer (new)** — optional support for the [Open Knowledge Format](https://github.com/GoogleCloudPlatform/knowledge-catalog): a `docs/knowledge/` domain-knowledge bundle agents consult (orientation) before touching a table or schema, while ADRs and the schema spec stay the source of truth. Produced and kept healthy by the `okf-knowledge-curator` agent and the `okf-knowledge-authoring` skill; a no-op in projects without a bundle.
- **Optional external AI** — Codex/Gemini adapters with a budget circuit breaker and cross-model review (disabled by default).

## The workflow

1. **Explore** — read the existing codebase first (`codebase-first` rule)
2. **Requirements** — establish what to build in `REQUIREMENTS.md`
3. **Research** — decide how to build it in `RESEARCH.md`
4. **Plan** — break work into atomic tasks in `PLAN.md` + `PROGRESS.md`
5. **Build** — iterate with simulator verification
6. **Debug** — find the root cause before fixing
7. **Verify** — require fresh evidence before claiming done
8. **Review** — two-stage gates: requirement compliance + code quality

## Repository layout

| Directory | Contents |
|-----------|----------|
| `agents/` | 47 agent definitions |
| `skills/` | 117 skill modules (incl. `blueprints/` and `orchestration/`) |
| `commands/` | 23 slash commands |
| `rules/` | 7 always-on rules |
| `hooks/` | Session and pre-build hooks |
| `scripts/` | Automation and validation utilities |
| `resources/` | Decision trees, platform guides, checklists, rubrics |
| `docs/` | The documentation site (this is also published via GitHub Pages) |

## Contributing

To extend the plugin: add agents in `agents/`, skills in `skills/`, and commands in `commands/`. Validate with the scripts in `scripts/` (`validate-agents.js`, `validate-skills.js`, `validate-blueprints.js`). See [`AGENTS.md`](AGENTS.md) for the auto-generated agent directory.

## License

MIT © 2026 Zeki Yugnak. See [`LICENSE`](LICENSE) and [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
