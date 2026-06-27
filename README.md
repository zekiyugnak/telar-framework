# Telar

> **The agentic engineering framework** — plan, build, review, and ship, with agents.
> By Zeki Yugnak · v0.1.0 — 37 agents, 95 skills, 23 commands, 4 hooks, 7 rules, 19 scripts

Telar is a multi-agent engineering framework for Claude Code that takes a feature from idea to production — orchestrated planning, adversarial review gates, a persistent knowledge base, and cross-model verification. Its first edition targets **cross-platform mobile** (**React Native** & **Flutter**) with deep native integration.

## 📖 Full documentation

**[zekiyugnak.github.io/telar-framework →](https://zekiyugnak.github.io/telar-framework/)**

The full reference — every agent, skill, command, and rule, plus the orchestration deep-dive and end-to-end examples — lives on the documentation site. This README is just the entry point.

| | |
|---|---|
| [Getting Started](https://zekiyugnak.github.io/telar-framework/getting-started.html) | Install and run your first command |
| [Agents](https://zekiyugnak.github.io/telar-framework/agents.html) | 37 specialized subagents |
| [Skills](https://zekiyugnak.github.io/telar-framework/skills.html) | 95 reference modules |
| [Commands](https://zekiyugnak.github.io/telar-framework/commands.html) | 23 slash-command workflows |
| [Rules](https://zekiyugnak.github.io/telar-framework/rules.html) | 7 always-on standards |
| [Orchestration](https://zekiyugnak.github.io/telar-framework/orchestration.html) | The opt-in pipeline, in depth |
| [Examples](https://zekiyugnak.github.io/telar-framework/examples.html) | End-to-end command flows |

## Installation

```bash
# Add the marketplace
claude plugin marketplace add zekiyugnak/telar-framework

# Install the plugin
claude plugin install tl-telar@telar
```

After installation, restart Claude Code to load the plugin. All commands are namespaced under `/tl-telar:`.

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

- **37 specialized agents** — platform experts, native bridges, architecture, security, testing, release, and orchestration.
- **95 skills** — reusable reference modules, decision frameworks, and ready-to-use feature blueprints for React Native and Flutter.
- **Two-stage review gates** — requirement compliance and code quality, with adversarial and collaborative reviewers.
- **Orchestrated mode (opt-in)** — design + plan review gates, a 4-phase IMPLEMENT/VALIDATE/REVIEW/COMMIT loop, and blocking quality gates. The orchestrator honors your git policy and never auto-commits.
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
| `agents/` | 37 agent definitions |
| `skills/` | 95 skill modules (incl. `blueprints/` and `orchestration/`) |
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
