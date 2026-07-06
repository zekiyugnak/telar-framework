---
id: self-reflect
name: Self-Reflect (KB Capture)
description: Capture durable learnings from recent PRs + current conversation + optional config audit. User-approval gate on every candidate. Writes to .tl-telar/knowledge/*.jsonl.
category: command
usage: /tl-telar:self-reflect [<days>]
example: /tl-telar:self-reflect 14
arguments:
  - name: <days>
    description: Look back N days for PR comments (default 7).
    optional: true
---

# /tl-telar:self-reflect

Loads `skills/orchestration/self-reflect`. Runs Phase A (PR comments) + Phase B (conversation mining) + optionally Phase C (config audit). Every candidate goes through an explicit user-approval gate.

## When fires automatically

- `orchestrator` Step 7 (pre-PR) on multi-WU runs.
- Per-WU if `enforcement.self_reflect_per_wu: true` in `.tl-telar-thresholds.json`.

## When fires manually

- Explicit `/tl-telar:self-reflect` invocation.
- After a significant debugging session, before closing the conversation.
- Weekly retrospective.

## What this command does NOT do

- Does NOT auto-write facts without user approval (binding gate at Step 4 of the skill).
- Does NOT migrate old `.claude/skills/learned/*.md` files (manual migration documented but not run automatically).
- Does NOT commit the JSONL changes (per user's `ben yapacagim` git policy).
