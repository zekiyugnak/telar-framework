# Changelog

All notable changes to the telar-framework are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
