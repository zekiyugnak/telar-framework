---
name: "external-tools-health"
description: "Reports real-time health of Codex and Gemini adapters. Wraps scripts/tl-telar-external-tools.sh health."
source_type: "command"
source_file: "commands/external-tools-health.md"
---

# external-tools-health

Migrated from `commands/external-tools-health.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- In Codex, this skill is the replacement for the Claude slash command `/tl-telar:external-tools-health`; invoke it as `$external-tools-health` or through `@tl-telar`.
- Do not require Claude slash-command dispatch or Claude-only environment setup before following the workflow.
- When the original command says to load `skills/orchestration/<name>`, load the generated Codex skill at `../orchestration-<name>/SKILL.md` first. The original source copy also exists under `../../source/skills/orchestration/<name>/SKILL.md` for exact Telar-source references.


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
