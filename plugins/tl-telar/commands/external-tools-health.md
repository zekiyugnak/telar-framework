---
id: external-tools-health
name: External AI Tools — Health Check
description: Reports real-time health of Codex and Gemini adapters. Wraps scripts/tl-telar-external-tools.sh health.
category: command
usage: /tl-telar:external-tools-health
example: /tl-telar:external-tools-health
---

# /tl-telar:external-tools-health

Sets TL_TELAR_ORCHESTRATED=1 (for symmetry with other orchestration commands). Loads `skills/orchestration/external-tools`. Runs the dispatcher's `health` subcommand which invokes each enabled adapter's `health` subcommand and aggregates results.

## Output shape

One of three shapes, depending on environment:

```json
{
  "parser": "yq|python3-yaml",
  "adapters": {
    "codex": {"tool":"codex","status":"ready|unavailable", "...": "adapter-reported fields"},
    "gemini": {"tool":"gemini","status":"ready|unavailable", "...": "adapter-reported fields"}
  }
}
```

When no adapters are enabled (the default config), `adapters` is an empty object: `{"parser":"...","adapters":{}}`.

When no YAML parser is installed (neither `yq` nor python3+PyYAML), a top-level error object is emitted instead:

```json
{
  "error": "parser_unavailable",
  "detail": "No YAML parser found (need yq OR python3 with PyYAML). ...",
  "remediation": "Install yq (brew install yq / apt install yq) OR run: pip install pyyaml"
}
```

A parallel `{"error":"node_unavailable", ...}` object is emitted when Node (required to build the response JSON) is missing.

Adapters with `adapters.<tool>.enabled: false` in `.tl-telar/external-tools.yaml` are not invoked and not included in `adapters`.

## When to use

- Diagnosing why `/tl-telar:orchestrate` isn't delegating to external tools.
- After installing/configuring `codex` or `gemini` CLI to verify the dispatcher sees them.
- Before opting in to Phase γ cross-model review (sub-spec 8+).

## What it does NOT do

- Does NOT mutate config. Read-only diagnostic.
- Does NOT auth-test. Adapters' `health` subcommand handles auth probing; this just aggregates their reports.
