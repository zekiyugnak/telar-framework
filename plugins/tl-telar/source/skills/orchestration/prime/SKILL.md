---
id: prime
category: skill
impact: MEDIUM
impactDescription: Injects relevant KB facts into the current task's context. Closes the self-improvement loop — captured learnings re-surface on the next task that needs them.
tags: [orchestration, knowledge-base, retrieval, priming]
capabilities:
  - Wrap scripts/tl-telar-prime.sh CLI for slash-command invocation
  - Resolve file globs / keywords / work-type into KB queries
  - Emit 5 fixed categories (MUST FOLLOW / GOTCHAS / PATTERNS / DECISIONS / API BEHAVIORS)
  - Support --json mode for hook consumption
useWhen:
  - /tl-telar:prime invoked by user or agent
  - mobile-orchestrator boots and wants relevant facts
  - SessionStart hook (matcher startup|resume|clear|compact — `compact` covers post-compaction re-prime; no PreCompact registration per Claude Code Hooks reference) injects facts
---

# Prime (KB Retrieval)

## Trigger condition

Loadable always (this skill is read-only and applies universally). When invoked via `/tl-telar:prime`, sets `TL_TELAR_ORCHESTRATED=1` to signal orchestrated mode. When invoked from legacy commands the slash command itself is the trigger — calling `/tl-telar:prime` directly is always safe.

This skill is NEVER auto-triggered from legacy mobile commands without an explicit user invocation. Legacy commands continue to use prose-level codebase-first rules unchanged.

## What it does

Wraps `scripts/tl-telar-prime.sh`. Forwards args to the script, captures output, presents to user.

## Inputs

| Arg | Description |
|---|---|
| `--files <glob>` | Filter facts whose `affectedFiles` match the glob |
| `--keywords <words>` | Space-separated keywords; matches `fact` / `recommendation` / `tags.topic` |
| `--work-type <type>` | One of: planning, implementation, review, debugging, recovery |
| `--json` | Emit JSON for programmatic consumption |

All args optional. Bare invocation returns all facts in 5 categories.

## Anti-patterns

1. **Calling prime in a loop.** Once per task context is enough. Re-priming on every prompt pollutes the conversation with the same facts repeatedly.
2. **Filtering too aggressively.** When in doubt, broaden the keyword set or omit `--work-type`. Missing a relevant fact is worse than reading one irrelevant.
3. **Replacing prime output with the LLM's own summary in conversation.** Quote what prime returned verbatim — the rule IDs and fact IDs are load-bearing for `usageCount` accounting (sub-spec future).

## Tests / conformance

Run `node scripts/validate-skills.js` (orchestration-namespace checks).
