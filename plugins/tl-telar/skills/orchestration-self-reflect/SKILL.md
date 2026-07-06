---
name: "orchestration-self-reflect"
description: "If `gh auth status` succeeds AND `npx` is available: Phase A runs. Otherwise Phase A skips gracefully."
source_type: "orchestration"
source_file: "skills/orchestration/self-reflect/SKILL.md"
---

# orchestration-self-reflect

Migrated from `skills/orchestration/self-reflect/SKILL.md`.

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


# Self-Reflect (KB Capture)

## Trigger condition (binding)

This skill is loaded only via:

1. `/tl-telar:self-reflect` (sets TL_TELAR_ORCHESTRATED=1).
2. The `mobile-orchestrator` agent's Step 7 (pre-PR knowledge capture, multi-WU mandatory).
3. Per-WU opt-in: `.tl-telar-thresholds.json` → `enforcement.self_reflect_per_wu: true` (default false).
4. Explicit user request.

This skill is NEVER auto-triggered from legacy mobile commands.

## Integration policy (binding default)

- **Single-WU orchestration**: fires once before COMMIT signal. One user-approval interaction.
- **Multi-WU orchestration**: fires once **pre-PR, NOT per-WU**. The orchestrator's per-WU COMMIT phases complete without interactive user gates so multi-WU runs don't stall.
- **Per-WU opt-in**: set `enforcement.self_reflect_per_wu: true` in `.tl-telar-thresholds.json`.

## Procedure

### Step 0: Decide what to run

If `gh auth status` succeeds AND `npx` is available: Phase A runs. Otherwise Phase A skips gracefully.

Phase B (conversation mining) always runs. Phase C (config audit) runs only if user opts in or it's the first self-reflect of the project.

### Step 1: Phase A — PR comments

Invoke `scripts/tl-telar-self-reflect.sh <days>` (default 7). It runs `tl-telar-fetch-pr-comments.ts`, lists CodeRabbit "Learning:" lines, and surfaces them to the user as raw candidates.

### Step 2: Phase B — Conversation mining

Scan the current conversation for these phrases (case-insensitive):

| Phrase | Likely insight type |
|---|---|
| `"The problem was..."` | debugging insight (→ gotcha) |
| `"It turns out..."` | discovery (→ code_quirk or api_behavior) |
| `"We decided to..."` / `"The reason we..."` | architectural decision (→ decision) |
| `"Unlike what you'd expect..."` | non-obvious behavior (→ gotcha) |
| `"Never do X because..."` | gotcha (→ gotcha or anti_pattern) |

Extract candidate facts. Don't trust the LLM's paraphrase — quote the original conversation lines as `provenance.reference`.

### Step 3: Phase C — Config reflection (optional)

If the user requests Phase C: audit `CLAUDE.md`, `settings.json`, `.claude/commands/*` for issues that emerged during the session (e.g., a command behaved unexpectedly, a rule was unclear, a hook fired noisily). Present as candidates for amendment, not for the JSONL (Phase C produces file edits, not facts).

### Step 4: User approval gate (binding)

Present candidates to the user as a numbered markdown list:

```markdown
## Candidate Learnings

1. **<Brief title>** — <one-sentence summary>
2. **<Brief title>** — <one-sentence summary>
3. **<Brief title>** — <one-sentence summary>

Which numbers do you want to capture? (all / 1,2,3 / none)
```

Wait for the user's reply. Do NOT proceed until they answer.

### Step 5: Per-accepted classification

For each accepted candidate, present:

```markdown
**Fact**: <extracted core insight (canonicalized)>
**Type**: <pattern|gotcha|decision|api_behavior|security|performance|code_quirk|anti_pattern>
**Tags**:
  - platform: <ios|android|both>
  - framework: <react-native|flutter|native|any>
  - category: <build|store|navigation|state|design-system|security|performance|accessibility|release|ota|testing>
  - topic: [<free-form>]
**Affected files**: <glob or list>
**Confidence**: <high|medium|low>
**Provenance**: <PR #N | conversation | postmortem | etc.>

Does this look right? (yes / edit)
```

If `edit`: re-prompt for which field to change.
If `yes`: append to the appropriate `.tl-telar/knowledge/<file>.jsonl` (file picked by `type`).

### Step 6: Canonicalization rules (applied before append)

1. Strip PR refs from the `fact` (move them to `provenance.reference`).
2. Strip names unless it's a team decision attribution.
3. Generalize paths: `src/lib/foo.ts` → `src/lib/**/*.ts` for `affectedFiles`.
4. Use imperative mood ("Always use X" / "Never do Y").
5. Include the WHY in `recommendation`.
6. Cap `fact` at ~200 chars.

### Step 7: Conflict resolution

Before appending, query existing facts with similar text (substring overlap > 60% on `fact`):

| Situation | Action |
|---|---|
| New is more specific | New supersedes (append new with same `id`, incremented `updatedAt`) |
| Different valid aspects | Keep both (distinct `id`s, related via `topic`) |
| Direct contradiction | Ask user which is correct |
| Old is subset of new | Merge (append new, mark old `outdatedReports++`) |

### Step 8: Write

```bash
echo '<one-line-json>' >> .tl-telar/knowledge/<file>.jsonl
```

### Step 9: Report

```markdown
## Self-reflect summary

- PRs analyzed: <N>
- Candidates surfaced: <N>
- Accepted: <N>
- Rejected: <N>
- Transformed: <N>
- Files updated: <list>
```

## Anti-patterns

1. **Auto-writing without explicit user approval.** Never. Even on `/tl-telar:self-reflect --yes` (no such flag exists; if someone adds one, the skill must error). The approval gate is binding.
2. **Skipping canonicalization.** PR-specific references in the `fact` body pollute future prime calls.
3. **Treating Phase B as exhaustive.** The LLM may miss patterns; the user may have insights the conversation didn't surface. Ask "anything else you want to capture?" at the end of Phase B.
4. **Storing PII or secrets in JSONL.** If a candidate fact contains email addresses, API keys, internal hostnames — strip or refuse.
5. **Per-WU firing on multi-WU runs by default.** Only when `enforcement.self_reflect_per_wu: true`. Otherwise the multi-WU run stalls at every COMMIT.

## Tests / conformance

Run `node scripts/validate-skills.js` (orchestration-namespace checks).
