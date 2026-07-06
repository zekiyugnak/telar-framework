# Telar

> **The agentic engineering framework** — plan, build, review, and ship, with agents.
> By Zeki Yugnak · v0.7.0 — 41 agents, 113 skills, 23 commands, 4 hooks, 7 rules, 27 scripts

Telar is a multi-agent engineering framework for Claude Code and Codex that takes a feature from idea to production — orchestrated planning, adversarial review gates, a persistent knowledge base, and cross-model verification. Its first edition targets **cross-platform mobile** (**React Native** & **Flutter**) with deep native integration, plus a companion web stack (**Astro**, **Next.js**/Tailwind/shadcn, **Vite**/TanStack admin panels) and a **Rust** service layer.

## 📖 Full documentation

**[zekiyugnak.github.io/telar-framework →](https://zekiyugnak.github.io/telar-framework/)**

The full reference — every agent, skill, command, and rule, plus the orchestration deep-dive and end-to-end examples — lives on the documentation site. This README is just the entry point.

| | |
|---|---|
| [Getting Started](https://zekiyugnak.github.io/telar-framework/getting-started.html) | Install and run your first command |
| [Agents](https://zekiyugnak.github.io/telar-framework/agents.html) | 41 specialized subagents |
| [Skills](https://zekiyugnak.github.io/telar-framework/skills.html) | 113 reference modules |
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

- **41 specialized agents** — platform experts, native bridges, architecture, security, testing, release, orchestration, and a companion web (Astro/Next.js/Vite-TanStack) and Rust service layer.
- **113 skills** — reusable reference modules, decision frameworks, and ready-to-use feature blueprints for React Native, Flutter, the web stack, and Rust services.
- **Two-stage review gates** — requirement compliance and code quality, with adversarial and collaborative reviewers.
- **Orchestrated mode (opt-in)** — design + plan review gates, a 4-phase IMPLEMENT/VALIDATE/REVIEW/COMMIT loop, and blocking quality gates. Independent Work Units run in parallel — a pure readiness scheduler dispatches concurrent WUs whose dependencies are met and file scopes are disjoint (bounded by `execution.max_parallel_wus`). The orchestrator honors your git policy and never auto-commits.
- **Persistent knowledge base** — typed JSONL facts captured via `/tl-telar:self-reflect` and re-primed into context each session.
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
| `agents/` | 41 agent definitions |
| `skills/` | 113 skill modules (incl. `blueprints/` and `orchestration/`) |
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
