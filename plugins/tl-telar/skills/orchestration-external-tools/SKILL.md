---
name: "orchestration-external-tools"
description: "**Phase β (this sub-spec):** infrastructure ports + dispatcher implementation. NOT auto-invoked anywhere. Default config has `adapters.*.enabled: false`. To activate: user installs the relevant CLI (`codex`, `gemini`), s"
source_type: "orchestration"
source_file: "skills/orchestration/external-tools/SKILL.md"
---

# orchestration-external-tools

Migrated from `skills/orchestration/external-tools/SKILL.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- **Codex subagent gate — probe, then use or degrade (fail-closed; never fake).** Claude `Task()` calls map to Codex subagent spawns. Before EVERY multi-reviewer gate: (1) PROBE whether the current Codex surface exposes an agent-spawn tool. (2) If YES → spawn the resolver-selected reviewers as fresh, parallel Codex agent roles; preserve each role, its own rubric, and the freshness rule (no reviewer sees another's verdict or a prior iteration), then close each subagent handle before the next iteration so long runs do not exhaust the local subagent thread limit. (3) If NO → emit a literal `DEGRADED: full multi-reviewer gate unavailable on this Codex surface` line and STOP the gate. Recommend re-running on a Claude Code host or a Codex build that exposes subagent spawning. NEVER substitute a single inline self-review for the independent multi-reviewer gate, and never silently continue as if the gate passed.
- **Stack-aware roster (parity with the Claude path).** Derive the reviewer roster from `scripts/tl-telar-reviewer-roster.js` (packaged at this plugin root) against the WU `file_scope` — do NOT hardcode a mobile roster. It returns the domain-correct Security/BackendCorrectness/FrontendUX/Accessibility/Performance reviewers, each with its own rubric path, for mobile, web, backend-data, and rust changes alike.
- Treat Claude `Workflow` tool references as unavailable in Codex unless an explicit equivalent tool is present. Use the documented prose fallback path by default.
- Treat `TL_TELAR_ORCHESTRATED=1` as a workflow mode marker in Codex. Do not require a literal Claude slash command to set it.
- Do not pass scheduler `--isolate` merely because Codex is running. Use `--isolate` only after a concrete Codex worktree isolation and merge-back mechanism has been verified for the run; otherwise keep disjoint file-scope serialization.


# External Tools (Phase β)

## Trigger condition (binding)

This skill is loaded only via:

1. `/tl-telar:external-tools-health` (sets TL_TELAR_ORCHESTRATED=1).
2. The `orchestrator` agent when adapter delegation is requested AND `.tl-telar/external-tools.yaml` has `adapters.*.enabled: true` AND health passes.
3. Explicit user request.

This skill is NEVER auto-triggered from legacy mobile commands. Adapters are opt-in.

## Maturity statement

**Phase β (this sub-spec):** infrastructure ports + dispatcher implementation. NOT auto-invoked anywhere. Default config has `adapters.*.enabled: false`. To activate: user installs the relevant CLI (`codex`, `gemini`), sets auth env vars (`OPENAI_API_KEY`, `GEMINI_API_KEY`), and flips `enabled: true` in `.tl-telar/external-tools.yaml`.

**Phase γ (sub-spec 8):** cross-model adversarial review wires this skill into orchestrated-execution Phase 3. Until then, Phase 3 continues to spawn Claude-only Task() reviewers.

## Architecture (two layers)

### Layer A — adapters (vendored verbatim port)

Located at `skills/orchestration/external-tools/adapters/`:

- `_common.sh` — shared helpers (worktree mgmt, secure tmp, env stripping, JSON envelope emitter, classify_error, package_context)
- `codex.sh` — Codex CLI adapter (subcommands: health, implement, review)
- `gemini.sh` — Gemini CLI adapter (same subcommands)

**These files are vendored byte-for-byte from upstream (see THIRD_PARTY_NOTICES.md).** SHA-256 hashes recorded in CHANGELOG. Any modifications belong in Layer B.

### Layer B — dispatcher (new)

Located at `scripts/tl-telar-external-tools.sh`:

- Real YAML config parsing via `yq` or `python3 -c "import yaml"` fallback
- Real health-check protocol (no LLM-judges-status anti-pattern)
- Real routing (cheapest-available default + escalation chain)
- Real budget ledger (`.tl-telar/context/external-tools-budget.jsonl`) with per-task + per-session circuit breakers
- Real verdict parser (extract PASS/FAIL + issues[] from adapter raw_log for review-mode invocations)

## CLI surface

```bash
scripts/tl-telar-external-tools.sh dispatch --task implement|review --tool codex|gemini|auto --worktree <path> [...]
scripts/tl-telar-external-tools.sh health
scripts/tl-telar-external-tools.sh budget-status
scripts/tl-telar-external-tools.sh parse-verdict <envelope-file>
```

## Adapter envelope (Layer A output)

Adapters emit a uniform JSON envelope (defined upstream; preserved here):

```json
{
  "schema_version": "1",
  "tool": "codex|gemini",
  "command": "implement|review",
  "model": "gpt-5.3-codex",
  "attempt": 1,
  "exit_code": 0,
  "branch": "external/codex/task-42",
  "git_sha": "abc123",
  "files_changed": ["src/foo.ts"],
  "diff_stats": {"additions": 42, "deletions": 7},
  "duration_seconds": 87,
  "cost": {"input_tokens": 12340, "output_tokens": 2110},
  "raw_log": "<full stdout>",
  "error_type": null
}
```

Cost is **tokens only** (no USD field). Layer B's `estimate-cost.sh` converts.

## Cross-model review matrix (Phase γ; encoded in YAML config but not yet wired)

```yaml
cross_model_review:
  enabled: false
  matrix:
    codex: ["gemini", "claude"]
    gemini: ["codex", "claude"]
    claude: ["codex", "gemini"]
```

The "writer cannot be reviewer" rule. Sub-spec 8 reads this matrix and routes Phase 3 reviewers accordingly.

## Anti-patterns

1. **Modifying Layer A adapters.** Any change to `_common.sh`/`codex.sh`/`gemini.sh` is forbidden. Logic changes go in Layer B (dispatcher). This preserves upstream-merge potential.
2. **LLM parsing the YAML.** The dispatcher uses `yq` or `python3 yaml`. LLMs parsing config is the anti-pattern this sub-spec fixes.
3. **Soft budget caps.** If the preflight says `cost_limit_exceeded`, the dispatcher MUST NOT invoke the adapter. Falling back to Claude (Task() spawn) is correct; ignoring the cap is not.
4. **Auto-enabling adapters on setup.** `/tl-telar:setup-orchestration` copies the YAML template with `enabled: false`. User opts in explicitly.
5. **Cross-model review in Phase β.** Sub-spec 7 does NOT wire cross-model into Phase 3. The matrix is encoded for sub-spec 8 to consume; Phase 3 continues to use Claude-only Task() spawns.

## Tests / conformance

Run `node scripts/validate-skills.js` (orchestration-namespace checks).

Verify Layer A integrity (portable across macOS/Linux):
```bash
sha256_portable() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@";
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$@";
  else echo "ERROR: install coreutils or shasum"; return 1; fi
}
sha256_portable skills/orchestration/external-tools/adapters/*.sh > /tmp/current_hashes.txt
# Compare against CHANGELOG-recorded hashes
```
