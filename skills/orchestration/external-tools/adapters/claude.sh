#!/bin/bash
# claude.sh — EXTERNAL Claude adapter. Drives the local `claude` CLI headlessly so a
# NON-Claude host (e.g. host=codex) can use Claude as a cross-model reviewer/implementer.
#
# First-party file (like compat.sh), NOT vendored — free to change. Reuses the
# _common.sh contract (parse_args/safe_invoke/emit_json/emit_error/log_session/…).
# Unlike compat.sh it does NOT swap the endpoint: it runs the ambient `claude` with the
# user's own Claude auth (native tier), just from OUTSIDE the Claude harness.
#
# THE ANTI-NEST RULE: this adapter must NEVER be used when the active host IS claude —
# there Claude runs natively in-harness and re-invoking `claude` would nest a second CLI.
# The dispatcher enforces this (resolve-role marks claude models native on a claude host,
# so they never dispatch to an adapter). As a defensive backstop, health reports
# `unavailable` when TL_TELAR_HOST=claude.
#
# Commands (same envelope contract as codex.sh / compat.sh):
#   claude.sh health    --tool-name claude [--model opus]
#   claude.sh implement --tool-name claude --worktree <path> --prompt-file <path> [--model M] [--timeout S] [--attempt N] [--context-dir <dir>]
#   claude.sh review    --tool-name claude --worktree <path> --rubric-file <path> --spec-file <path> [--model M] [--timeout S] [--attempt N]

set -euo pipefail

# Locate _common.sh via BASH_SOURCE (works when executed OR sourced by a unit test).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

# The Claude CLI. Overridable for tests via CLAUDE_ADAPTER_CMD (COMPAT_CLI_CMD honored for parity).
CLAUDE_CMD="${CLAUDE_ADAPTER_CMD:-${COMPAT_CLI_CMD:-claude}}"
# Autonomous-edit permission flag for headless implement (see compat.sh VERIFY note).
PERM_FLAG="--permission-mode"
PERM_MODE="bypassPermissions"

# ---------------------------------------------------------------------------
# parse_claude_args() — capture the claude-specific flags. Leaves the standard
# flags for parse_args (which ignores unknown flags).
# ---------------------------------------------------------------------------
parse_claude_args() {
  CLAUDE_TOOL_NAME="claude"
  local prev=""
  for arg in "$@"; do
    case "$prev" in
      --tool-name) CLAUDE_TOOL_NAME="$arg" ;;
    esac
    prev="$arg"
  done
}

# ---------------------------------------------------------------------------
# extract_cost_claude() — parse `claude -p --output-format json` for token usage.
#   Returns {"input_tokens": N, "output_tokens": N}. Input folds in cache tokens.
# ---------------------------------------------------------------------------
extract_cost_claude() {
  local json_file="${1:-}"
  if [[ -z "$json_file" || ! -f "$json_file" ]] || ! command -v jq >/dev/null 2>&1; then
    printf '{"input_tokens": 0, "output_tokens": 0}'
    return 0
  fi
  jq -s '
    (map(select(.usage != null)) | last) as $r
    | if $r == null then {input_tokens: 0, output_tokens: 0}
      else {
        input_tokens: (($r.usage.input_tokens // 0)
                       + ($r.usage.cache_read_input_tokens // 0)
                       + ($r.usage.cache_creation_input_tokens // 0)),
        output_tokens: ($r.usage.output_tokens // 0)
      } end
  ' "$json_file" 2>/dev/null || printf '{"input_tokens": 0, "output_tokens": 0}'
}

# Effective reporting model label (what shows up in the envelope + ledger).
claude_model_label() {
  if [[ -n "${XT_MODEL:-}" ]]; then printf '%s' "$XT_MODEL"; else printf '%s' "claude-default"; fi
}

# ===========================================================================
# health
# ===========================================================================
cmd_health() {
  parse_claude_args "$@"
  local tool="$CLAUDE_TOOL_NAME"
  local model; model="$(claude_model_label)"
  local status="ready" version="unknown" auth_valid=false detail=""

  # Anti-nest backstop: never advertise ready when Claude IS the active host.
  if [[ "${TL_TELAR_HOST:-}" == "claude" ]]; then
    printf '{"tool":"%s","status":"unavailable","version":"n/a","auth_valid":false,"model":"%s","detail":"external claude adapter must not run on a claude host — native Claude is used instead (anti-nest rule)"}\n' \
      "$tool" "$model"
    return 0
  fi

  if ! command -v "$CLAUDE_CMD" >/dev/null 2>&1; then
    printf '{"tool":"%s","status":"unavailable","version":"not_installed","auth_valid":false,"model":"%s","detail":"claude CLI not found (set CLAUDE_ADAPTER_CMD or put claude on PATH)"}\n' \
      "$tool" "$model"
    return 0
  fi
  version="$("$CLAUDE_CMD" --version 2>/dev/null | tr -d '\n' | xargs || printf 'unknown')"
  # Native Claude uses the CLI's own login; a present binary reporting a version is our readiness signal.
  auth_valid=true

  if command -v jq >/dev/null 2>&1; then
    jq -n --arg tool "$tool" --arg status "$status" --arg version "$version" \
      --argjson auth_valid "$auth_valid" --arg model "$model" --arg detail "$detail" \
      '{tool:$tool,status:$status,version:$version,auth_valid:$auth_valid,model:$model} + (if $detail=="" then {} else {detail:$detail} end)'
  else
    printf '{"tool":"%s","status":"%s","version":"%s","auth_valid":%s,"model":"%s"}\n' \
      "$tool" "$status" "$version" "$auth_valid" "$model"
  fi
}

# Shared: run claude headless inside the worktree. Args after the prompt are extra claude flags.
run_claude() {
  local timeout_secs="$1" stdout_file="$2" stderr_file="$3" prompt="$4"; shift 4
  local exit_code=0
  # Run inside the worktree so edits land there. No endpoint swap — native Claude auth.
  ( cd "$XT_WORKTREE" && \
    safe_invoke "$timeout_secs" "$stdout_file" "$stderr_file" \
      "$CLAUDE_CMD" -p "$prompt" --output-format json "$@" \
  ) || exit_code=$?
  return "$exit_code"
}

# ===========================================================================
# implement
# ===========================================================================
cmd_implement() {
  parse_claude_args "$@"
  parse_args "$@"
  local tool="$CLAUDE_TOOL_NAME"
  local model; model="$(claude_model_label)"

  [[ -n "$XT_WORKTREE" ]]    || { printf 'Error: --worktree is required\n' >&2; return 1; }
  [[ -n "$XT_PROMPT_FILE" ]] || { printf 'Error: --prompt-file is required\n' >&2; return 1; }
  [[ -d "$XT_WORKTREE" ]]    || { printf 'Error: worktree does not exist: %s\n' "$XT_WORKTREE" >&2; return 1; }
  [[ -f "$XT_PROMPT_FILE" ]] || { printf 'Error: prompt file does not exist: %s\n' "$XT_PROMPT_FILE" >&2; return 1; }

  local tmp_dir; tmp_dir="$(create_secure_tmp)"
  local stdout_file="${tmp_dir}/stdout.json" stderr_file="${tmp_dir}/stderr.log"
  local prompt_content; prompt_content="$(cat "$XT_PROMPT_FILE")"

  local model_flags=()
  [[ -n "${XT_MODEL:-}" ]] && model_flags+=(--model "$XT_MODEL")

  local start_time; start_time="$(date +%s)"
  local exit_code=0
  run_claude "$XT_TIMEOUT" "$stdout_file" "$stderr_file" "$prompt_content" \
    "$PERM_FLAG" "$PERM_MODE" "${model_flags[@]+"${model_flags[@]}"}" || exit_code=$?
  local duration=$(( $(date +%s) - start_time ))

  mkdir -p "$LOG_DIR"
  local raw_log_file="${LOG_DIR}/${tool}-implement-$(date +%Y%m%dT%H%M%S)-$$.json"
  [[ -f "$stdout_file" ]] && cp "$stdout_file" "$raw_log_file"

  if [[ "$exit_code" -ne 0 ]]; then
    local error_json; error_json="$(emit_error "$tool" "implement" "$model" "$XT_ATTEMPT" "$exit_code" "$stderr_file" "$duration" "$raw_log_file")"
    log_session "$error_json"; printf '%s\n' "$error_json"; rm -rf "$tmp_dir"; return 1
  fi

  local branch="" git_sha=""
  if [[ -d "$XT_WORKTREE" ]]; then
    git -C "$XT_WORKTREE" add -A 2>/dev/null || true
    if ! git -C "$XT_WORKTREE" diff --cached --quiet 2>/dev/null; then
      git -C "$XT_WORKTREE" commit -m "feat: ${tool} implement (attempt ${XT_ATTEMPT})" \
        --author="${tool} (external) <external-tools@telar>" >/dev/null 2>&1 || true
    fi
    if [[ -n "$XT_CONTEXT_DIR" ]]; then
      if ! verify_scope "$XT_WORKTREE" "$XT_CONTEXT_DIR"; then
        git -C "$XT_WORKTREE" add -A 2>/dev/null || true
        if ! git -C "$XT_WORKTREE" diff --cached --quiet 2>/dev/null; then
          git -C "$XT_WORKTREE" commit -m "fix: revert out-of-scope changes" \
            --author="${tool} (external) <external-tools@telar>" >/dev/null 2>&1 || true
        fi
      fi
    fi
    branch="$(git -C "$XT_WORKTREE" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    git_sha="$(git -C "$XT_WORKTREE" rev-parse HEAD 2>/dev/null || true)"
  fi

  local cost_json; cost_json="$(extract_cost_claude "$stdout_file")"
  local files_changed_json; files_changed_json="$(get_changed_files "$XT_WORKTREE")"
  local diff_stats_json; diff_stats_json="$(get_diff_stats "$XT_WORKTREE")"

  local result_json; result_json="$(emit_json "$tool" "implement" "$model" "$XT_ATTEMPT" "$exit_code" \
    "$branch" "$git_sha" "$files_changed_json" "$diff_stats_json" "$duration" "$cost_json" "$raw_log_file")"
  log_session "$result_json"; printf '%s\n' "$result_json"; rm -rf "$tmp_dir"
}

# ===========================================================================
# review
# ===========================================================================
cmd_review() {
  parse_claude_args "$@"
  parse_args "$@"
  local tool="$CLAUDE_TOOL_NAME"
  local model; model="$(claude_model_label)"

  [[ -n "$XT_WORKTREE" ]]    || { printf 'Error: --worktree is required\n' >&2; return 1; }
  [[ -n "$XT_RUBRIC_FILE" ]] || { printf 'Error: --rubric-file is required\n' >&2; return 1; }
  [[ -n "$XT_SPEC_FILE" ]]   || { printf 'Error: --spec-file is required\n' >&2; return 1; }
  [[ -d "$XT_WORKTREE" ]]    || { printf 'Error: worktree does not exist: %s\n' "$XT_WORKTREE" >&2; return 1; }
  [[ -f "$XT_RUBRIC_FILE" ]] || { printf 'Error: rubric file does not exist: %s\n' "$XT_RUBRIC_FILE" >&2; return 1; }
  [[ -f "$XT_SPEC_FILE" ]]   || { printf 'Error: spec file does not exist: %s\n' "$XT_SPEC_FILE" >&2; return 1; }

  local tmp_dir; tmp_dir="$(create_secure_tmp)"
  local stdout_file="${tmp_dir}/stdout.json" stderr_file="${tmp_dir}/stderr.log"

  local diff_content; diff_content="$(git -C "$XT_WORKTREE" diff HEAD 2>/dev/null || true)"
  [[ -z "$diff_content" ]] && diff_content="$(git -C "$XT_WORKTREE" diff HEAD~1 HEAD 2>/dev/null || true)"
  local rubric_content; rubric_content="$(cat "$XT_RUBRIC_FILE")"
  local spec_content; spec_content="$(cat "$XT_SPEC_FILE")"

  local review_prompt
  review_prompt="You are a code reviewer. Review the following code changes against the rubric and specification. Do NOT edit any files."$'\n\n## Git Diff\n```diff\n'"${diff_content}"$'\n```\n\n## Review Rubric\n'"${rubric_content}"$'\n\n## Specification\n'"${spec_content}"$'\n\n## Instructions\nEvaluate each rubric criterion against the diff/spec. Output structured JSON with keys: "verdict" (PASS|FAIL), "issues" (array), "summary". FAIL if any BLOCKING issue is found.\n'

  local model_flags=()
  [[ -n "${XT_MODEL:-}" ]] && model_flags+=(--model "$XT_MODEL")

  local start_time; start_time="$(date +%s)"
  local exit_code=0
  # Review is read-only: plan permission mode, no autonomous edits.
  run_claude "$XT_TIMEOUT" "$stdout_file" "$stderr_file" "$review_prompt" \
    "$PERM_FLAG" "plan" "${model_flags[@]+"${model_flags[@]}"}" || exit_code=$?
  local duration=$(( $(date +%s) - start_time ))

  mkdir -p "$LOG_DIR"
  local raw_log_file="${LOG_DIR}/${tool}-review-$(date +%Y%m%dT%H%M%S)-$$.json"
  [[ -f "$stdout_file" ]] && cp "$stdout_file" "$raw_log_file"

  if [[ "$exit_code" -ne 0 ]]; then
    local error_json; error_json="$(emit_error "$tool" "review" "$model" "$XT_ATTEMPT" "$exit_code" "$stderr_file" "$duration" "$raw_log_file")"
    log_session "$error_json"; printf '%s\n' "$error_json"; rm -rf "$tmp_dir"; return 1
  fi

  # parse-verdict scans .raw_log; claude wraps the model's text in .result, so surface .result.
  local review_text_file="${tmp_dir}/review.txt"
  if command -v jq >/dev/null 2>&1 && [[ -f "$stdout_file" ]]; then
    jq -rs '(map(select(.result != null)) | last | .result) // (.[-1].result // "")' "$stdout_file" 2>/dev/null > "$review_text_file" || cp "$stdout_file" "$review_text_file"
  else
    [[ -f "$stdout_file" ]] && cp "$stdout_file" "$review_text_file"
  fi

  local cost_json; cost_json="$(extract_cost_claude "$stdout_file")"
  local branch="" git_sha=""
  if [[ -d "$XT_WORKTREE" ]]; then
    branch="$(git -C "$XT_WORKTREE" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    git_sha="$(git -C "$XT_WORKTREE" rev-parse HEAD 2>/dev/null || true)"
  fi

  local result_json; result_json="$(emit_json "$tool" "review" "$model" "$XT_ATTEMPT" "$exit_code" \
    "$branch" "$git_sha" "[]" '{"additions": 0, "deletions": 0}' "$duration" "$cost_json" "$review_text_file")"
  log_session "$result_json"; printf '%s\n' "$result_json"; rm -rf "$tmp_dir"
}

# ===========================================================================
# Command dispatch (skipped when the file is sourced, e.g. by unit tests)
# ===========================================================================
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  return 0 2>/dev/null || true
fi

command="${1:-}"
shift || true
case "$command" in
  health)    cmd_health "$@" ;;
  implement) cmd_implement "$@" ;;
  review)    cmd_review "$@" ;;
  *)
    cat >&2 <<USAGE
Usage: $(basename "$0") <health|implement|review> [options]

External Claude adapter (drives the native claude CLI from a non-Claude host).
  --tool-name <name>      Reporting name (default "claude")
  --worktree <path>       Git worktree (implement/review)
  --prompt-file <path>    Prompt (implement); --rubric-file/--spec-file (review)
  --model <id>            Claude tier (opus|sonnet|fable)
  --timeout <seconds>     Timeout (default 300); --attempt N; --context-dir <dir>
NOTE: never used when the active host is claude (native Claude is used instead).
USAGE
    exit 1
    ;;
esac
