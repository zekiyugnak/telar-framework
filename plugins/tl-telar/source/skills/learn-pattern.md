---
id: learn-pattern
category: skill
impact: MEDIUM
impactDescription: Captures hard-won mobile debugging knowledge so the next session does not redo the same investigation. As of sub-spec 5 this skill delegates to /tl-telar:self-reflect, which writes typed JSONL knowledge that /tl-telar:prime re-injects into later tasks.
tags: [meta, knowledge-capture, learning, debugging, patterns, post-incident, deprecated-wrapper]
capabilities:
  - Point users at /tl-telar:self-reflect for KB capture
  - Document one-time migration from .claude/skills/learned/*.md to .tl-telar/knowledge/*.jsonl
useWhen:
  - User invokes this skill from habit (legacy)
  - User asks "how do I capture a pattern?"
  - After resolving a non-obvious debugging session and wanting to persist the insight
---

# Learn Pattern (Deprecated — Delegates to /tl-telar:self-reflect)

## Status

As of sub-spec 5 of the orchestration initiative, this skill is a thin delegator. The capture flow now lives at `/tl-telar:self-reflect` (`skills/orchestration/self-reflect/SKILL.md`), which writes to typed JSONL knowledge files (`.tl-telar/knowledge/*.jsonl`) that `/tl-telar:prime` retrieves at the start of any subsequent task.

The previous markdown-per-pattern store under `.claude/skills/learned/` was write-only: facts vanished into a directory with no retrieval mechanism. The new JSONL + `/tl-telar:prime` flow is a closed loop — capture → store typed → re-inject on the next task that needs it.

## What to do instead

When you finish a debugging session, an investigation, or a non-obvious feature implementation and want to capture the insight, run:

```
/tl-telar:self-reflect
```

That command will:

1. Optionally fetch CodeRabbit / Bugbot / Greptile / Copilot / human PR comments from the last 7 days (Phase A — gracefully skips when no GitHub auth or no CodeRabbit reviewers).
2. Mine the current conversation for tell-tale insight phrases (Phase B): `"The problem was..."`, `"It turns out..."`, `"We decided to..."`, `"Unlike what you'd expect..."`, `"Never do X because..."`.
3. Optionally audit `CLAUDE.md` / `settings.json` / `.claude/commands/*` for issues that emerged during the session (Phase C).
4. Present candidates to you in a numbered list with explicit ACCEPT/REJECT per candidate.
5. Classify each accepted fact (type / tags / confidence) with your confirmation.
6. Append to `.tl-telar/knowledge/*.jsonl` — typed: `pattern`, `gotcha`, `decision`, `api_behavior`, `security`, `performance`, `code_quirk`, `anti_pattern`.

The next task that runs `/tl-telar:prime` will see your captured fact and surface it back into context — a closed loop instead of a notes-folder.

## Migration from old `.claude/skills/learned/*.md` files

Old captures are NOT auto-migrated (intentional — drift between the freeform markdown notes and the typed JSONL schema needs human judgment). To migrate manually:

1. Open the old `.md` file you want to migrate.
2. Run `/tl-telar:self-reflect` and, in the user-approval phase, paste the relevant content as a candidate insight.
3. The skill canonicalizes (strip PR refs, generalize paths, imperative mood, ≤200 chars) and appends to the appropriate JSONL.
4. Once migrated, archive the old `.md` file: `mv .claude/skills/learned/<file>.md .claude/skills/learned/_archive/`.

There is no migration script — each old capture deserves the user-approval gate of the new flow, so a batch migration would either lose accuracy or smuggle low-quality facts into the KB.

## Why the change (the closed-loop argument)

The old `.claude/skills/learned/<name>.md` store was write-only-into-the-void. Facts went into a directory and were never re-surfaced. The new flow:

- **Capture** (`/tl-telar:self-reflect`) — 3-phase pipeline with user-approval gate, canonicalization, typed JSONL storage.
- **Storage** (`.tl-telar/knowledge/*.jsonl`) — 8 typed files (codebase-facts, api-behaviors, patterns, anti-patterns, gotchas, decisions, performance, security) with provenance, confidence, mobile tags (platform/framework/category).
- **Retrieval** (`/tl-telar:prime`) — auto-invoked at the start of any orchestrated task (and on demand), returns 5-category facts (`MUST FOLLOW`, `GOTCHAS`, `PATTERNS`, `DECISIONS`, `API BEHAVIORS`) filtered by file glob / keyword / work-type.
- **Curation** (`agents/mobile-knowledge-curator.md`) — periodic dedup, confidence promotion (3+ provenance → high), staleness sweep. Suggestion-driven; never autonomous mutation.

If you only have time to do ONE thing from this skill, run `/tl-telar:self-reflect` after your next debugging session. The rest of the loop runs itself once facts are in the KB.

## Backward-compatibility note

The `learn-pattern` skill name is preserved so workflows that load it (or hooks that mention it) still resolve. The skill no longer writes anything — it just routes users to the modern flow.

## See also

- `skills/orchestration/self-reflect/SKILL.md` — capture flow
- `skills/orchestration/prime/SKILL.md` — retrieval flow
- `.tl-telar/knowledge/README.md` (created by `/tl-telar:setup-orchestration`) — schema doc + tag controlled vocabulary
- `agents/mobile-knowledge-curator.md` — periodic curation
- `commands/self-reflect.md` (`/tl-telar:self-reflect`) — slash-command entry
- `commands/prime.md` (`/tl-telar:prime`) — slash-command entry
