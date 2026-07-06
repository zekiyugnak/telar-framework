---
name: "orchestration-prime"
description: "Loadable always (this skill is read-only and applies universally). When invoked via `/tl-telar:prime`, sets `TL_TELAR_ORCHESTRATED=1` to signal orchestrated mode. When invoked from legacy commands the slash command itsel"
source_type: "orchestration"
source_file: "skills/orchestration/prime/SKILL.md"
---

# orchestration-prime

Migrated from `skills/orchestration/prime/SKILL.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- **Codex subagent gate — probe, then use or degrade (fail-closed; never fake).** Claude `Task()` calls map to Codex subagent spawns. Before EVERY multi-reviewer gate: (1) PROBE whether the current Codex surface exposes an agent-spawn tool. (2) If YES → spawn the resolver-selected reviewers as fresh, parallel Codex agent roles; preserve each role, its own rubric, and the freshness rule (no reviewer sees another's verdict or a prior iteration), then close each subagent handle before the next iteration so long runs do not exhaust the local subagent thread limit. (3) If NO → emit a literal `DEGRADED: full multi-reviewer gate unavailable on this Codex surface` line and STOP the gate. Recommend re-running on a Claude Code host or a Codex build that exposes subagent spawning. NEVER substitute a single inline self-review for the independent multi-reviewer gate, and never silently continue as if the gate passed.
- **Stack-aware roster (parity with the Claude path).** Derive the reviewer roster from `scripts/tl-telar-reviewer-roster.js` (packaged at this plugin root) against the WU `file_scope` — do NOT hardcode a mobile roster. It returns the domain-correct Security/BackendCorrectness/FrontendUX/Accessibility/Performance reviewers, each with its own rubric path, for mobile, web, backend-data, and rust changes alike.
- Treat Claude `Workflow` tool references as unavailable in Codex unless an explicit equivalent tool is present. Use the documented prose fallback path by default.
- Treat `TL_TELAR_ORCHESTRATED=1` as a workflow mode marker in Codex. Do not require a literal Claude slash command to set it.
- Do not pass scheduler `--isolate` merely because Codex is running. Use `--isolate` only after a concrete Codex worktree isolation and merge-back mechanism has been verified for the run; otherwise keep disjoint file-scope serialization.


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
