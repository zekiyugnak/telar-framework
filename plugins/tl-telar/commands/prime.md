---
id: prime
name: Prime Knowledge Base
description: Load relevant KB facts into current context. Wraps scripts/tl-telar-prime.sh.
category: command
usage: /tl-telar:prime [--files <glob>] [--keywords <words>] [--work-type <type>]
example: /tl-telar:prime --files "src/lib/auth/**" --work-type implementation
arguments:
  - name: --files
    description: Filter facts whose affectedFiles match the glob.
    optional: true
  - name: --keywords
    description: Space-separated keywords for fact/recommendation/tag matching.
    optional: true
  - name: --work-type
    description: planning | implementation | review | debugging | recovery
    optional: true
---

# /tl-telar:prime

Loads relevant KB facts from `.tl-telar/knowledge/*.jsonl` into conversation context. Wraps `scripts/tl-telar-prime.sh`.

## Behavior

1. Forward args to `scripts/tl-telar-prime.sh`.
2. Capture stdout (5 categories: MUST FOLLOW / GOTCHAS / PATTERNS / DECISIONS / API BEHAVIORS).
3. Present to user (or inject into agent context).

## When to use

- Start of any planning, implementation, review, or debugging task.
- After /tl-telar:resume (recovery already calls prime internally; explicit re-prime is rarely needed).

## When NOT to use

- Mid-implementation in a tight feedback loop. Re-priming pollutes context.
