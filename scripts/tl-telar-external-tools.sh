#!/usr/bin/env bash
# Mobile-application-plugin external AI delegation DISPATCHER (Layer B).
# Wraps Layer A adapters in skills/orchestration/external-tools/adapters/.
#
# Responsibilities (master design §2.6 / sub-spec 7 acceptance criteria):
#   1. Parse .tl-telar/external-tools.yaml (real parsing, not LLM prose)
#   2. Health-check candidate adapters (real-time, no cache)
#   3. Route per routing.default_implementer + escalation_order
#   4. Budget preflight: read budget.ledger_file, sum recent USD, compare to per_task/per_session caps
#   5. Invoke chosen adapter via its documented CLI contract (--worktree, --prompt-file, etc.)
#   6. Parse adapter JSON envelope; pull cost {input,output}_tokens; compute USD; append to ledger
#   7. Verdict parser: for review-mode invocations, extract PASS/FAIL from raw_log
#
# Usage:
#   scripts/tl-telar-external-tools.sh dispatch \
#     --task implement|review \
#     --tool codex|gemini|auto \
#     --worktree <path> \
#     [--prompt-file <path> | --rubric-file <path> --spec-file <path>] \
#     [--attempt N]
#
#   scripts/tl-telar-external-tools.sh health
#     → JSON status of all enabled adapters
#
#   scripts/tl-telar-external-tools.sh budget-status
#     → JSON {per_session_usd_spent, per_task_usd_last, remaining_session, ...}

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
ADAPTERS_DIR="$PLUGIN_ROOT/skills/orchestration/external-tools/adapters"
CONFIG="$PROJECT_ROOT/.tl-telar/external-tools.yaml"
LEDGER="$PROJECT_ROOT/.tl-telar/context/external-tools-budget.jsonl"

# NOTE: no mkdir here. Read-only subcommands (health, budget-status,
# parse-verdict) MUST NOT create project state in an un-setup project
# (§1.1 opt-in invariant + the read-only contract in
# commands/external-tools-health.md). The ledger directory is created
# lazily in ledger_append — the only write path.

# ---------- Helpers ----------

# Fail-loud CLI contract (mirrors tl-telar-prime.sh): bad invocations exit 2
# with an ERROR + Usage on stderr instead of being silently dropped or
# crashing on an unbound $2.
usage_err() {
  echo "ERROR: $1" >&2
  echo "Usage: tl-telar-external-tools.sh dispatch --task implement|review --worktree <path> [--tool codex|gemini|auto] [--prompt-file <path>] [--rubric-file <path>] [--spec-file <path>] [--attempt N]" >&2
  echo "       tl-telar-external-tools.sh health | budget-status | parse-verdict <envelope-file>" >&2
  exit 2
}

# Track parser availability once per process. Health command surfaces this.
PARSER_AVAILABLE=""
detect_yaml_parser() {
  if [[ -n "$PARSER_AVAILABLE" ]]; then
    echo "$PARSER_AVAILABLE"
    return
  fi
  if command -v yq >/dev/null 2>&1; then
    PARSER_AVAILABLE="yq"
  elif command -v python3 >/dev/null 2>&1 && python3 -c "import yaml" 2>/dev/null; then
    PARSER_AVAILABLE="python3-yaml"
  else
    PARSER_AVAILABLE="none"
  fi
  echo "$PARSER_AVAILABLE"
}

parse_yaml() {
  # $1 = key path (e.g., "adapters.codex.enabled")
  # Returns the value as a string. Empty string means either:
  #   (a) key not present, OR
  #   (b) no parser available (caller should check detect_yaml_parser).
  # Callers that need to distinguish these MUST check detect_yaml_parser first.
  if [[ ! -f "$CONFIG" ]]; then
    echo ""
    return
  fi
  local parser
  parser=$(detect_yaml_parser)
  case "$parser" in
    yq)
      yq eval ".$1" "$CONFIG" 2>/dev/null | head -1
      ;;
    python3-yaml)
      python3 -c "
import yaml, sys
with open('$CONFIG') as f:
    data = yaml.safe_load(f)
keys = '$1'.split('.')
for k in keys:
    if data is None: print(''); sys.exit(0)
    data = data.get(k) if isinstance(data, dict) else None
print(data if data is not None else '')
"
      ;;
    none|*)
      # No parser. Return empty; callers will see parser=none via detect_yaml_parser.
      echo ""
      ;;
  esac
}

run_adapter_health() {
  # $1 = tool name (codex|gemini)
  local adapter="$ADAPTERS_DIR/$1.sh"
  if [[ ! -f "$adapter" ]]; then
    echo "{\"tool\":\"$1\",\"status\":\"unavailable\",\"reason\":\"adapter file missing\"}"
    return
  fi
  bash "$adapter" health 2>/dev/null || echo "{\"tool\":\"$1\",\"status\":\"unavailable\",\"reason\":\"health command failed\"}"
}

budget_session_total() {
  # Sum USD spent in current session (last 1 hour heuristic).
  # Returns numeric string. FAIL-CLOSED on missing dependencies — if we can't
  # read the ledger reliably, callers must treat the result as "unknown high"
  # and refuse to dispatch.
  if [[ ! -f "$LEDGER" ]]; then
    echo "0.0000"
    return 0
  fi
  if ! command -v jq >/dev/null 2>&1; then
    # FAIL-CLOSED: without jq we can't sum the ledger reliably. Refuse to
    # report a number; caller will see "UNKNOWN" and skip dispatch.
    echo "UNKNOWN"
    return 1
  fi

  local cutoff
  cutoff=$(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "1970-01-01T00:00:00Z")

  jq -s --arg c "$cutoff" '[.[] | select(.timestamp >= $c) | .usd] | add // 0' "$LEDGER" 2>/dev/null | head -1
}

# Dependency-free USD comparison via Node. Returns 0 if $1 > $2, else 1.
# Avoids bc/awk dependency assumptions; Node ships with the toolchain we
# already require for the rest of the plugin (validate-skills.js, etc.).
usd_gt() {
  if ! command -v node >/dev/null 2>&1; then
    # FAIL-CLOSED: without Node we can't compare floats safely. Caller must
    # treat this as "comparison failed → refuse dispatch".
    echo "ERROR: node not available for USD comparison — failing closed" >&2
    return 0  # exit 0 from this function means "treat as exceeded" — fail-closed
  fi
  node -e "process.exit(Number(process.argv[1]) > Number(process.argv[2]) ? 0 : 1)" "$1" "$2"
}

budget_preflight() {
  # $1 = estimated USD for this task
  # Returns 0 on OK, non-zero on cost_limit_exceeded. Echoes a reason
  # string on failure. FAIL-CLOSED if any dependency is missing.
  local est="$1"
  local per_task per_sess sess_total
  per_task=$(parse_yaml "budget.per_task_usd")
  per_sess=$(parse_yaml "budget.per_session_usd")
  sess_total=$(budget_session_total)

  # If parse_yaml returned empty (no yq, no python3, or missing key),
  # use defaults from master design.
  per_task="${per_task:-1.00}"
  per_sess="${per_sess:-10.00}"

  # FAIL-CLOSED if session total is UNKNOWN (jq missing).
  if [[ "$sess_total" == "UNKNOWN" ]]; then
    echo "cost_limit_exceeded:dependency_missing:reason=jq required for budget ledger sum"
    return 1
  fi

  if usd_gt "$est" "$per_task"; then
    echo "cost_limit_exceeded:per_task:est=$est:cap=$per_task"
    return 1
  fi

  # sess_total + est > per_sess
  local projected
  if command -v node >/dev/null 2>&1; then
    projected=$(node -e "process.stdout.write(String(Number(process.argv[1]) + Number(process.argv[2])))" "$sess_total" "$est")
  else
    echo "cost_limit_exceeded:dependency_missing:reason=node required for budget projection"
    return 1
  fi

  if usd_gt "$projected" "$per_sess"; then
    echo "cost_limit_exceeded:per_session:total=$sess_total:est=$est:projected=$projected:cap=$per_sess"
    return 1
  fi
  return 0
}

ledger_append() {
  # Append a JSONL row for accounting.
  # $1=tool $2=command $3=tokens_in $4=tokens_out $5=usd $6=exit_code
  # The ONLY write path in this script — directory creation lives here so
  # read-only subcommands never mutate the project.
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  mkdir -p "$(dirname "$LEDGER")"
  echo "{\"timestamp\":\"$ts\",\"tool\":\"$1\",\"command\":\"$2\",\"input_tokens\":$3,\"output_tokens\":$4,\"usd\":$5,\"exit_code\":$6}" >> "$LEDGER"
}

# ---------- Subcommands ----------

cmd_health() {
  # Build the response as a structured object via Node so trailing-comma /
  # JSON-shape bugs cannot occur even on the common path where no adapters
  # are enabled (default config).
  local parser
  parser=$(detect_yaml_parser)

  if [[ "$parser" == "none" ]]; then
    cat <<'EOF'
{
  "error": "parser_unavailable",
  "detail": "No YAML parser found (need yq OR python3 with PyYAML). External-tools config cannot be read; adapters will appear disabled regardless of their actual state.",
  "remediation": "Install yq (brew install yq / apt install yq) OR run: pip install pyyaml"
}
EOF
    return 0
  fi

  if ! command -v node >/dev/null 2>&1; then
    # Without node we cannot reliably emit valid JSON. Surface the issue.
    cat <<'EOF'
{
  "error": "node_unavailable",
  "detail": "node is required to emit health response JSON. Install Node.",
  "remediation": "brew install node / apt install nodejs"
}
EOF
    return 0
  fi

  # Collect per-adapter health into a temp file as one JSON line per enabled tool.
  local tmp
  tmp=$(mktemp -t tl-telar-health.XXXXXX)
  trap 'rm -f "$tmp"' RETURN
  for tool in codex gemini; do
    local enabled
    enabled=$(parse_yaml "adapters.$tool.enabled")
    if [[ "$enabled" != "true" ]]; then continue; fi
    run_adapter_health "$tool" >> "$tmp"
    echo "" >> "$tmp"
  done

  # Have Node read the adapter chunks, parse each as JSON, and build the response object.
  # Each adapter appends ONE JSON object (which may be PRETTY-PRINTED across multiple
  # lines) followed by a blank-line separator, so split on blank lines — NOT per line.
  # A per-line parse fails on every line of a multi-line adapter health object (e.g.
  # codex.sh emits indented JSON), which would drop a perfectly healthy adapter.
  node -e '
    const fs = require("fs");
    const chunks = fs.readFileSync(process.argv[1], "utf8")
      .split(/\n\s*\n/).map(c => c.trim()).filter(Boolean);
    const adapters = {};
    for (const chunk of chunks) {
      try {
        const parsed = JSON.parse(chunk);
        if (parsed && parsed.tool) adapters[parsed.tool] = parsed;
      } catch (e) { /* skip malformed adapter chunk */ }
    }
    const out = { parser: process.argv[2], adapters };
    process.stdout.write(JSON.stringify(out, null, 2));
  ' "$tmp" "$parser"
  echo ""
}

cmd_budget_status() {
  local sess_total per_task per_sess
  # set -e safe capture: budget_session_total returns non-zero (UNKNOWN) when
  # jq is missing and a ledger exists. A bare assignment would silently exit
  # this function under errexit with no output — fail LOUD instead.
  sess_total=$(budget_session_total) || true
  if [[ "$sess_total" == "UNKNOWN" || -z "$sess_total" ]]; then
    sess_total="${sess_total:-UNKNOWN}"
    echo '{"error_type":"dependency_missing","detail":"jq is required to sum the budget ledger. Install jq (brew install jq / apt install jq).","session_total_usd":"UNKNOWN"}'
    return 4
  fi
  per_task=$(parse_yaml "budget.per_task_usd")
  per_sess=$(parse_yaml "budget.per_session_usd")
  cat <<EOF
{
  "per_task_cap_usd": "${per_task:-1.00}",
  "per_session_cap_usd": "${per_sess:-10.00}",
  "session_total_usd": "$sess_total",
  "ledger_file": "$LEDGER"
}
EOF
}

cmd_dispatch() {
  local task="" tool="auto" worktree="" prompt_file="" rubric_file="" spec_file="" attempt=1
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --task)
        [[ $# -ge 2 ]] || usage_err "--task requires a value"
        task="$2"
        case "$task" in
          implement|review) ;;
          *) usage_err "invalid --task value: $task (allowed: implement, review)" ;;
        esac
        shift 2 ;;
      --tool)
        [[ $# -ge 2 ]] || usage_err "--tool requires a value"
        tool="$2"
        case "$tool" in
          codex|gemini|auto) ;;
          *) usage_err "invalid --tool value: $tool (allowed: codex, gemini, auto)" ;;
        esac
        shift 2 ;;
      --worktree)
        [[ $# -ge 2 ]] || usage_err "--worktree requires a value"
        worktree="$2"; shift 2 ;;
      --prompt-file)
        [[ $# -ge 2 ]] || usage_err "--prompt-file requires a value"
        prompt_file="$2"; shift 2 ;;
      --rubric-file)
        [[ $# -ge 2 ]] || usage_err "--rubric-file requires a value"
        rubric_file="$2"; shift 2 ;;
      --spec-file)
        [[ $# -ge 2 ]] || usage_err "--spec-file requires a value"
        spec_file="$2"; shift 2 ;;
      --attempt)
        [[ $# -ge 2 ]] || usage_err "--attempt requires a value"
        attempt="$2"
        [[ "$attempt" =~ ^[0-9]+$ ]] || usage_err "invalid --attempt value: $attempt (must be a non-negative integer)"
        shift 2 ;;
      --*)
        usage_err "unknown flag: $1" ;;
      *)
        usage_err "unexpected positional argument: $1" ;;
    esac
  done

  if [[ -z "$task" ]]; then
    usage_err "dispatch requires --task"
  fi
  if [[ -z "$worktree" ]]; then
    usage_err "dispatch requires --worktree"
  fi

  # Fail-closed dependency check.  jq is needed for adapter envelope parsing
  # (cost extraction) and for budget ledger sum. node is needed for safe
  # USD comparison and JSON shape construction.  Missing either tool means
  # we cannot account for the dispatch reliably, which would silently
  # undercount the ledger and bypass the budget circuit breaker.  Refuse.
  if ! command -v jq >/dev/null 2>&1; then
    echo '{"error_type":"dependency_missing","detail":"jq is required for envelope parsing and budget ledger sums. Install jq (brew install jq / apt install jq) before invoking external adapters."}'
    return 4
  fi
  if ! command -v node >/dev/null 2>&1; then
    echo '{"error_type":"dependency_missing","detail":"node is required for safe USD comparison and JSON shape construction in the dispatcher. Install Node before invoking external adapters."}'
    return 4
  fi

  # Resolve auto-routing
  if [[ "$tool" == "auto" ]]; then
    local codex_ok="" gemini_ok=""
    if [[ "$(parse_yaml 'adapters.codex.enabled')" == "true" ]]; then
      codex_ok=$(bash "$ADAPTERS_DIR/codex.sh" health 2>/dev/null | jq -r '.status' 2>/dev/null || echo "unavailable")
    fi
    if [[ "$(parse_yaml 'adapters.gemini.enabled')" == "true" ]]; then
      gemini_ok=$(bash "$ADAPTERS_DIR/gemini.sh" health 2>/dev/null | jq -r '.status' 2>/dev/null || echo "unavailable")
    fi

    # cheapest-available: prefer gemini (free tier), then codex
    if [[ "$gemini_ok" == "ready" ]]; then tool="gemini"
    elif [[ "$codex_ok" == "ready" ]]; then tool="codex"
    else
      echo '{"error":"no external adapters available","fallback":"use claude (the orchestrator should fall back to Task() spawn)"}'
      return 2
    fi
  fi

  # Tool-selection invariant (resolved external tool path).
  #
  # Reached only when `tool` has been resolved to a concrete external adapter
  # name (codex | gemini). Two ways we get here:
  #   1. Auto-routing above picked codex or gemini after passing its own
  #      enabled+health probes. In that case the invariant below re-confirms
  #      what auto-routing already verified — defense in depth.
  #   2. Caller passed --tool codex|gemini explicitly. In that case the
  #      invariant below is the ONLY gate enforcing the "adapters disabled
  #      by default; user opts in" contract for explicit dispatches.
  #
  # If we got here via auto-routing with `tool` still equal to a non-external
  # value (which shouldn't happen — auto either resolves to codex/gemini or
  # returns the "no external adapters available" error earlier), we skip the
  # invariant (the `case` block below would have caught it).
  #
  # Auto-routing with no YAML parser returns "no external adapters available"
  # (exit 2), not parser_unavailable (exit 5). That's intentional: auto-mode
  # semantically means "use an external tool if one is ready, else fall back
  # to Claude". A missing parser is one valid way to be "not ready" — the
  # caller (orchestrator) handles exit 2 by falling back to Task() spawn.
  # Explicit-tool callers don't get this leniency: they asked for a specific
  # adapter, so an unreadable config is a hard error.
  if [[ "$tool" != "auto" ]]; then
    case "$tool" in
      codex|gemini)
        # Parser available?
        local parser
        parser=$(detect_yaml_parser)
        if [[ "$parser" == "none" ]]; then
          echo "{\"error_type\":\"parser_unavailable\",\"detail\":\"No YAML parser (yq or python3+PyYAML) — cannot read .tl-telar/external-tools.yaml to validate $tool enablement\"}"
          return 5
        fi
        # Enabled in config?
        local enabled
        enabled=$(parse_yaml "adapters.$tool.enabled")
        if [[ "$enabled" != "true" ]]; then
          echo "{\"error_type\":\"adapter_disabled\",\"tool\":\"$tool\",\"detail\":\"adapters.$tool.enabled is not true in .tl-telar/external-tools.yaml — opt in explicitly before dispatching to this adapter\"}"
          return 5
        fi
        # Adapter file present?
        if [[ ! -f "$ADAPTERS_DIR/$tool.sh" ]]; then
          echo "{\"error_type\":\"adapter_missing\",\"tool\":\"$tool\",\"detail\":\"$ADAPTERS_DIR/$tool.sh not found\"}"
          return 5
        fi
        # Health ready?
        local health_status
        health_status=$(bash "$ADAPTERS_DIR/$tool.sh" health 2>/dev/null | jq -r '.status' 2>/dev/null || echo "unavailable")
        if [[ "$health_status" != "ready" ]]; then
          echo "{\"error_type\":\"adapter_unhealthy\",\"tool\":\"$tool\",\"status\":\"$health_status\",\"detail\":\"adapter $tool reports status != ready; check auth and CLI install\"}"
          return 5
        fi
        ;;
      *)
        echo "{\"error_type\":\"unknown_tool\",\"tool\":\"$tool\",\"detail\":\"--tool must be one of: auto, codex, gemini\"}"
        return 5
        ;;
    esac
  fi

  # Budget preflight (estimate USD from a rough heuristic — actual cost computed post-invocation)
  local est_usd="0.10"  # placeholder for preflight; refine when we know context size
  if ! preflight_msg=$(budget_preflight "$est_usd"); then
    echo "{\"error_type\":\"cost_limit_exceeded\",\"detail\":\"$preflight_msg\"}"
    return 3
  fi

  # Invoke adapter
  local adapter="$ADAPTERS_DIR/$tool.sh"
  local args=("$task" "--worktree" "$worktree" "--attempt" "$attempt")
  if [[ -n "$prompt_file" ]]; then args+=("--prompt-file" "$prompt_file"); fi
  if [[ -n "$rubric_file" ]]; then args+=("--rubric-file" "$rubric_file"); fi
  if [[ -n "$spec_file" ]]; then args+=("--spec-file" "$spec_file"); fi

  # Model + reasoning-effort overrides from config. BLANK (or absent => yq "null")
  # means "respect the tool's own config" (e.g. ~/.codex/config.toml) — pass nothing.
  local cfg_model cfg_effort cfg_timeout
  cfg_model=$(parse_yaml "adapters.$tool.model")
  cfg_effort=$(parse_yaml "adapters.$tool.reasoning_effort")
  cfg_timeout=$(parse_yaml "adapters.$tool.timeout_seconds")
  if [[ -n "$cfg_model"   && "$cfg_model"   != "null" ]]; then args+=("--model"            "$cfg_model");   fi
  if [[ -n "$cfg_effort"  && "$cfg_effort"  != "null" ]]; then args+=("--reasoning-effort" "$cfg_effort");  fi
  # Pass timeout to adapter so safe_invoke uses the YAML value, not its 300s default.
  # Validate: must be a positive integer; fall back to 300 on garbage input.
  if [[ -n "$cfg_timeout" && "$cfg_timeout" != "null" ]] && [[ "$cfg_timeout" =~ ^[0-9]+$ ]] && (( cfg_timeout > 0 )); then
    args+=("--timeout" "$cfg_timeout")
  else
    cfg_timeout=300
    args+=("--timeout" "$cfg_timeout")
  fi

  # Layer-B hard timeout: wrap the entire adapter invocation so a hung adapter
  # (e.g. codex exec with MCP transport glitch) cannot block indefinitely.
  # Uses system timeout/gtimeout when available; falls back to adapter's own
  # safe_invoke (which already has the timeout we just passed via --timeout).
  local envelope exit_code
  if command -v timeout >/dev/null 2>&1; then
    envelope=$(timeout "$cfg_timeout" bash "$adapter" "${args[@]}" 2>&1) && exit_code=0 || exit_code=$?
  elif command -v gtimeout >/dev/null 2>&1; then
    envelope=$(gtimeout "$cfg_timeout" bash "$adapter" "${args[@]}" 2>&1) && exit_code=0 || exit_code=$?
  else
    envelope=$(bash "$adapter" "${args[@]}" 2>&1) && exit_code=0 || exit_code=$?
  fi
  # Normalise timeout exit code: both system timeout (124) and adapter safe_invoke
  # (also 124) surface as error_type=timeout in the envelope. If the outer wrapper
  # killed the process before the adapter could emit JSON, synthesise a minimal
  # error envelope so callers always get parseable output.
  if [[ "$exit_code" -eq 124 ]] && ! echo "$envelope" | jq -e '.tool' >/dev/null 2>&1; then
    envelope=$(jq -n \
      --arg tool "$tool" \
      --arg task "$task" \
      --argjson timeout "$cfg_timeout" \
      '{"schema_version":"1","tool":$tool,"command":$task,"model":"unknown","attempt":1,
        "exit_code":124,"branch":"","git_sha":"","files_changed":[],"diff_stats":{"additions":0,"deletions":0},
        "duration_seconds":$timeout,"cost":{"input_tokens":0,"output_tokens":0},
        "raw_log":"","error_type":"timeout"}')
  fi

  # Parse envelope to extract cost
  local in_tok out_tok model
  in_tok=$(echo "$envelope" | jq -r '.cost.input_tokens // 0' 2>/dev/null || echo 0)
  out_tok=$(echo "$envelope" | jq -r '.cost.output_tokens // 0' 2>/dev/null || echo 0)
  model=$(echo "$envelope" | jq -r '.model // "unknown"' 2>/dev/null || echo "unknown")

  # Compute USD
  local usd
  usd=$(bash "$PLUGIN_ROOT/scripts/estimate-cost.sh" --model "$model" --input-tokens "$in_tok" --output-tokens "$out_tok" | jq -r '.estimated_usd' 2>/dev/null || echo "0.00")

  # Append to ledger
  ledger_append "$tool" "$task" "$in_tok" "$out_tok" "$usd" "$exit_code"

  # Echo envelope (caller parses it)
  echo "$envelope"
  return $exit_code
}

cmd_parse_verdict() {
  local envelope_file="$1"
  if [[ ! -f "$envelope_file" ]]; then
    echo '{"verdict":"UNKNOWN","reason":"envelope file not found"}' >&2
    return 1
  fi

  local raw_log
  raw_log=$(jq -r '.raw_log // ""' "$envelope_file" 2>/dev/null)

  if [[ -z "$raw_log" ]]; then
    echo '{"verdict":"UNKNOWN","reason":"empty raw_log","issues":[]}'
    return 0
  fi

  # Strategy 1: raw_log is itself valid JSON with {verdict, issues}.
  if echo "$raw_log" | jq -e '.verdict' >/dev/null 2>&1; then
    local v issues
    v=$(echo "$raw_log" | jq -r '.verdict')
    issues=$(echo "$raw_log" | jq -c '.issues // []')
    # Normalize verdict to PASS|FAIL|UNKNOWN
    case "$v" in
      PASS|pass) v="PASS" ;;
      FAIL|fail) v="FAIL" ;;
      *) v="UNKNOWN" ;;
    esac
    echo "{\"verdict\":\"$v\",\"issues\":$issues,\"source\":\"json_parse\"}"
    return 0
  fi

  # Strategy 2: raw_log contains JSON embedded in prose. We need a proper
  # brace-balanced extractor (regex {[^{}]*} fails on nested objects like
  # {"verdict":"FAIL","issues":[{"rule":"G3"}]}). Delegate to Node for a
  # correctness-first scan that respects strings and escapes.
  local extracted
  if command -v node >/dev/null 2>&1; then
    extracted=$(node -e '
      const s = process.argv[1];
      // Find the first JSON object that contains a "verdict" key.
      // Scan for { ... } honoring nested braces, string literals, and escapes.
      function scan(s, startIdx) {
        let i = startIdx, depth = 0, inStr = false, esc = false, start = -1;
        for (; i < s.length; i++) {
          const c = s[i];
          if (esc) { esc = false; continue; }
          if (inStr) {
            if (c === "\\") esc = true;
            else if (c === "\"") inStr = false;
            continue;
          }
          if (c === "\"") { inStr = true; continue; }
          if (c === "{") { if (depth === 0) start = i; depth++; continue; }
          if (c === "}") {
            depth--;
            if (depth === 0 && start >= 0) {
              const candidate = s.slice(start, i + 1);
              try {
                const parsed = JSON.parse(candidate);
                if (parsed && typeof parsed === "object" && "verdict" in parsed) {
                  return candidate;
                }
              } catch (e) { /* not valid JSON; keep scanning */ }
              start = -1;
            }
            continue;
          }
        }
        return "";
      }
      const out = scan(s, 0);
      process.stdout.write(out);
    ' "$raw_log" 2>/dev/null)
  else
    # Fallback when Node unavailable: try the regex (will still fail on
    # nested objects but better than nothing). Caller will likely land in
    # the grep_fallback path on failure.
    extracted=$(echo "$raw_log" | grep -o '{[^{}]*"verdict"[^{}]*}' | head -1 || true)
  fi

  if [[ -n "$extracted" ]] && echo "$extracted" | jq -e '.verdict' >/dev/null 2>&1; then
    local v issues
    v=$(echo "$extracted" | jq -r '.verdict')
    issues=$(echo "$extracted" | jq -c '.issues // []' 2>/dev/null || echo '[]')
    case "$v" in
      PASS|pass) v="PASS" ;;
      FAIL|fail) v="FAIL" ;;
      *) v="UNKNOWN" ;;
    esac
    echo "{\"verdict\":\"$v\",\"issues\":$issues,\"source\":\"embedded_json\"}"
    return 0
  fi

  # Strategy 3: grep fallback. Best-effort PASS/FAIL detection.
  if echo "$raw_log" | grep -qiE 'verdict["[:space:]]*[:=][[:space:]]*"?FAIL"?\b|^FAIL\b|\bFAIL$'; then
    echo '{"verdict":"FAIL","issues":[{"summary":"raw_log grep-detected FAIL — review manually"}],"source":"grep_fallback"}'
    return 0
  fi
  if echo "$raw_log" | grep -qiE 'verdict["[:space:]]*[:=][[:space:]]*"?PASS"?\b|^PASS\b|\bPASS$'; then
    echo '{"verdict":"PASS","issues":[],"source":"grep_fallback"}'
    return 0
  fi

  echo '{"verdict":"UNKNOWN","reason":"could not parse raw_log via any strategy","issues":[]}'
}

# ---------- Main ----------

case "${1:-}" in
  dispatch) shift; cmd_dispatch "$@" ;;
  health) cmd_health ;;
  budget-status) cmd_budget_status ;;
  parse-verdict) shift; cmd_parse_verdict "$@" ;;
  *) echo "Usage: $0 dispatch|health|budget-status|parse-verdict <args>"; exit 1 ;;
esac
