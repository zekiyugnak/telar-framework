# Telar Knowledge Base

Append-only JSONL knowledge files. Each line is one knowledge fact.

## File inventory

| File | Stores | `type` values |
|---|---|---|
| `codebase-facts.jsonl` | How this codebase actually works | `code_quirk`, `dependency` |
| `api-behaviors.jsonl` | External API/SDK quirks | `api_behavior` |
| `patterns.jsonl` | Reusable best practices | `pattern` |
| `anti-patterns.jsonl` | Things to avoid | `anti_pattern` |
| `gotchas.jsonl` | Common pitfalls | `gotcha` |
| `decisions.jsonl` | Architectural decisions | `decision` |
| `performance.jsonl` | Performance findings | `performance` |
| `security.jsonl` | Security findings | `security` |

## Record schema

```json
{
  "id": "fact-abc123",
  "type": "api_behavior|code_quirk|pattern|anti_pattern|gotcha|decision|dependency|performance|security",
  "fact": "Clear description of the knowledge",
  "recommendation": "What to do about it",
  "confidence": "high|medium|low",
  "provenance": [
    {"source": "coderabbit|human|agent|documentation|test|production",
     "reference": "PR #123",
     "date": "2026-05-19"}
  ],
  "tags": {
    "platform": "ios|android|both",
    "framework": "react-native|flutter|native|any",
    "category": "build|store|navigation|state|design-system|security|performance|accessibility|release|ota|testing",
    "topic": ["additional", "free-form", "tags"]
  },
  "affectedFiles": ["src/lib/services/example.ts"],
  "affectedServices": ["ExampleService"],
  "createdAt": "2026-05-19T12:00:00Z",
  "updatedAt": "2026-05-19T12:00:00Z",
  "usageCount": 0,
  "helpfulCount": 0,
  "outdatedReports": 0
}
```

## Mobile tag controlled vocabulary

- `platform`: `ios` | `android` | `both`
- `framework`: `react-native` | `flutter` | `native` | `any`
- `category`: `build` | `store` | `navigation` | `state` | `design-system` | `security` | `performance` | `accessibility` | `release` | `ota` | `testing`
- `topic`: free-form array of additional tags (commit conventions, library names, etc.)

## Confidence levels

- `high`: verified by 3+ provenance sources, or CodeRabbit+human, or production incident postmortem
- `medium`: single source, clear evidence
- `low`: suspected, needs confirmation

The `mobile-knowledge-curator` agent promotes confidence on source accumulation.

## Append protocol

```bash
echo '<one-line-json>' >> .tl-telar/knowledge/<file>.jsonl
```

Append-only. Never edit existing lines in place. To update a fact, append a new record with the same `id` and incremented `updatedAt`; the prime retriever picks the most recent by `updatedAt`.

## File header (first 2 lines)

Each JSONL file begins with two comment lines (not JSON; `tl-telar-prime.sh` skips lines starting with `#`):

```
# Schema: <name>.jsonl - <one-line description>
# Each line is a JSON object per the schema in .tl-telar/knowledge/README.md
```
