---
id: self-reflect
category: skill
impact: HIGH
impactDescription: Captures durable learnings from PR comments and conversation context. Without this, hard-won insights vanish at session end. With this, the KB grows incrementally with every shipped feature.
tags: [orchestration, knowledge-base, capture, self-improvement]
capabilities:
  - Phase A: harvest CodeRabbit/Bugbot/Greptile/Copilot/human PR comments
  - Phase B: mine conversation for tell-tale insight phrases
  - Phase C: audit config files (CLAUDE.md, settings.json, commands/)
  - User-approval gate on every candidate (numbered list + per-candidate yes/edit)
  - Apply canonicalization rules (strip PR refs, generalize paths, imperative mood)
  - Append accepted facts to .tl-telar/knowledge/*.jsonl
useWhen:
  - /tl-telar:self-reflect invoked
  - orchestrator Step 7 (pre-PR, mandatory for multi-WU runs)
  - User explicitly requests "capture learnings"
---

# Self-Reflect (KB Capture)

## Trigger condition (binding)

This skill is loaded only via:

1. `/tl-telar:self-reflect` (sets TL_TELAR_ORCHESTRATED=1).
2. The `orchestrator` agent's Step 7 (pre-PR knowledge capture, multi-WU mandatory).
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
