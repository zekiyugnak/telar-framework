#!/usr/bin/env bash
# tl-telar-cc-features.sh — deterministic resolver for cc_features gating.
#
# Turns the PROSE gating rule ("enabled is intent, not capability; fail-closed")
# into an executable decision so the orchestrator/skills call ONE tested code path
# instead of re-reasoning it. Reads cc_features.* from .tl-telar/external-tools.yaml,
# takes the runtime capability probe RESULT as input (the agent supplies it — only
# the agent can see whether the Workflow tool / worktree isolation is actually
# available), and emits the resolved decision.
#
# Decision per feature ∈ { active | fallback | blocked }:
#   active   = enabled AND capability confirmed          → use the new path
#   fallback = disabled, OR capability unconfirmed with on_unavailable=warn_and_proceed
#              → run the current-behavior path (never wrong, maybe slower)
#   blocked  = enabled AND capability unconfirmed AND on_unavailable=block
#              → STOP; surface the missing capability
#
# FAIL-CLOSED: capability is "available" ONLY when the probe input is exactly
# "true". Anything else (false / unknown / missing) is treated as unavailable, so
# a silently-ignored feature on an older Claude Code never activates.
#
# Usage:
#   tl-telar-cc-features.sh resolve [--config <path>] \
#       --workflow-available <true|false|unknown> \
#       --worktree-supported <true|false|unknown>
#   tl-telar-cc-features.sh decision <dynamic_workflows|worktree_isolation> [...same flags]
#
# resolve: prints a JSON object for both features. Exit 0 normally, 3 if ANY
#          feature resolved to "blocked" (so the caller can STOP).
# decision: prints just the decision word for one feature (active|fallback|blocked).

set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
CONFIG="$PROJECT_ROOT/.tl-telar/external-tools.yaml"

WORKFLOW_AVAILABLE="unknown"
WORKTREE_SUPPORTED="unknown"

PARSER_AVAILABLE=""
detect_yaml_parser() {
  if [[ -n "$PARSER_AVAILABLE" ]]; then echo "$PARSER_AVAILABLE"; return; fi
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
  # $1 = key path. Empty string => key absent OR no parser OR no file.
  if [[ ! -f "$CONFIG" ]]; then echo ""; return; fi
  local parser
  parser=$(detect_yaml_parser)
  case "$parser" in
    yq)
      # `yq` prints literal "null" for a missing key — normalize to empty.
      local v
      v=$(yq eval ".$1" "$CONFIG" 2>/dev/null | head -1)
      [[ "$v" == "null" ]] && v=""
      echo "$v"
      ;;
    python3-yaml)
      python3 -c "
import yaml, sys
with open('$CONFIG') as f:
    data = yaml.safe_load(f)
keys = '$1'.split('.')
for k in keys:
    if not isinstance(data, dict): print(''); sys.exit(0)
    data = data.get(k)
print(data if data is not None else '')
"
      ;;
    none|*)
      echo ""
      ;;
  esac
}

# Read one feature's config with defaults. Echoes "enabled|on_unavailable".
read_feature_config() {
  local feature="$1"
  local enabled on_unavailable
  enabled=$(parse_yaml "cc_features.$feature.enabled")
  on_unavailable=$(parse_yaml "cc_features.$feature.on_unavailable")
  # Default enabled=true when absent (key/file/parser missing) — matches the
  # documented default. Only an explicit "false" disables.
  case "$enabled" in
    false|False|FALSE) enabled="false" ;;
    *) enabled="true" ;;
  esac
  case "$on_unavailable" in
    block) on_unavailable="block" ;;
    *) on_unavailable="warn_and_proceed" ;;
  esac
  echo "$enabled|$on_unavailable"
}

# resolve_feature <enabled> <on_unavailable> <capability_raw> -> "decision|reason"
resolve_feature() {
  local enabled="$1" on_unavailable="$2" capability_raw="$3"
  # Fail-closed: available ONLY if probe result is exactly "true".
  local capability="unavailable"
  [[ "$capability_raw" == "true" ]] && capability="available"

  if [[ "$enabled" != "true" ]]; then
    echo "fallback|disabled by config (enabled: false)"
    return
  fi
  if [[ "$capability" == "available" ]]; then
    echo "active|enabled and capability confirmed"
    return
  fi
  if [[ "$on_unavailable" == "block" ]]; then
    echo "blocked|enabled but capability not confirmed; on_unavailable=block"
  else
    echo "fallback|enabled but capability not confirmed; running current-behavior path (on_unavailable=warn_and_proceed)"
  fi
}

capability_for() {
  case "$1" in
    dynamic_workflows) echo "$WORKFLOW_AVAILABLE" ;;
    worktree_isolation) echo "$WORKTREE_SUPPORTED" ;;
    *) echo "unknown" ;;
  esac
}

# Emits the JSON fragment for one feature and returns 1 if blocked.
emit_feature_json() {
  local feature="$1"
  local cfg enabled on_unavailable capability_raw res decision reason cap_norm
  cfg=$(read_feature_config "$feature")
  enabled="${cfg%%|*}"; on_unavailable="${cfg##*|}"
  capability_raw=$(capability_for "$feature")
  cap_norm="unavailable"; [[ "$capability_raw" == "true" ]] && cap_norm="available"
  res=$(resolve_feature "$enabled" "$on_unavailable" "$capability_raw")
  decision="${res%%|*}"; reason="${res##*|}"
  printf '"%s":{"enabled":%s,"capability":"%s","on_unavailable":"%s","decision":"%s","reason":"%s"}' \
    "$feature" "$enabled" "$cap_norm" "$on_unavailable" "$decision" "$reason"
  [[ "$decision" == "blocked" ]] && return 1 || return 0
}

parse_common_flags() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config) CONFIG="$2"; shift 2 ;;
      --workflow-available) WORKFLOW_AVAILABLE="$2"; shift 2 ;;
      --worktree-supported) WORKTREE_SUPPORTED="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
}

cmd_resolve() {
  parse_common_flags "$@"
  local blocked=0 dw wt
  dw=$(emit_feature_json "dynamic_workflows") || blocked=1
  wt=$(emit_feature_json "worktree_isolation") || blocked=1
  printf '{%s,%s}\n' "$dw" "$wt"
  [[ "$blocked" -eq 1 ]] && exit 3 || exit 0
}

cmd_decision() {
  local feature="$1"; shift
  parse_common_flags "$@"
  local cfg enabled on_unavailable res decision
  cfg=$(read_feature_config "$feature")
  enabled="${cfg%%|*}"; on_unavailable="${cfg##*|}"
  res=$(resolve_feature "$enabled" "$on_unavailable" "$(capability_for "$feature")")
  decision="${res%%|*}"
  echo "$decision"
  [[ "$decision" == "blocked" ]] && exit 3 || exit 0
}

main() {
  local sub="${1:-}"
  [[ $# -gt 0 ]] && shift || true
  case "$sub" in
    resolve) cmd_resolve "$@" ;;
    decision) cmd_decision "$@" ;;
    *)
      echo "Usage: tl-telar-cc-features.sh <resolve|decision> [--config <path>] --workflow-available <t/f> --worktree-supported <t/f>" >&2
      exit 2
      ;;
  esac
}

main "$@"
