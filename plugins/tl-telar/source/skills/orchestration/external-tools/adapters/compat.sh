#!/bin/bash
# compat.sh — Generic adapter for ANY Anthropic-compatible provider endpoint.
#
# NOT adapted from metaswarm — original to Telar. It reuses the metaswarm-derived
# _common.sh contract (parse_args/safe_invoke/emit_json/…) but is a first-party file,
# so it is free to change (unlike the vendored codex.sh/gemini.sh/_common.sh). The
# per-provider cost extractor lives HERE (extract_cost_compat), NOT in the vendored
# _common.sh — that is the deliberate resolution of the "don't modify vendored
# adapters" constraint for onboarding new providers.
#
# HOW IT WORKS
#   A raw messages API cannot autonomously edit files. To get a non-Claude model to
#   IMPLEMENT agentically we drive the Claude Code CLI (`claude`) in headless mode
#   with its endpoint swapped to an Anthropic-compatible provider:
#       ANTHROPIC_BASE_URL=<base_url> ANTHROPIC_AUTH_TOKEN=<token> claude -p ...
#   This is Moonshot's documented "Kimi in Claude Code" path and generalizes to any
#   Anthropic-compatible endpoint. The full agentic harness (read/write/edit/bash)
#   runs, but the underlying model is the provider's (e.g. kimi-k3).
#
#   One config block => one model. A new Anthropic-compatible model is onboarded by
#   adding an adapters.<name> block with type: compat (no new shell script).
#
# ⚠️ VERIFY BEFORE ENABLING (live path is provider/CLI-version dependent):
#   - `claude -p --output-format json` returns a single JSON object with a `.usage`
#     object (input_tokens/output_tokens[/cache_*]). Confirm the shape for your CLI.
#   - The autonomous-edit permission flag is `--permission-mode bypassPermissions`.
#     Confirm your `claude --help` exposes it; adjust PERM_FLAG below if it differs.
#   - Only api_style: anthropic is supported (endpoint-swapped claude). OpenAI-style
#     endpoints would need a different harness and return unavailable here.
#
# Commands:
#   health     Binary present + endpoint configured + auth token env var set
#   implement  Drive claude headless with autonomous edits on a worktree branch
#   review     Drive claude headless (no edits) to review a diff against rubric/spec
#
# Usage (invoked by the Layer-B dispatcher, which supplies the compat-specific flags):
#   compat.sh health    --tool-name <name> --base-url <url> --auth-env-var <ENV> [--api-style anthropic]
#   compat.sh implement --tool-name <name> --base-url <url> --auth-env-var <ENV> --worktree <path> --prompt-file <path> [--model M] [--timeout S] [--attempt N] [--context-dir <dir>]
#   compat.sh review    --tool-name <name> --base-url <url> --auth-env-var <ENV> --worktree <path> --rubric-file <path> --spec-file <path> [--model M] [--timeout S] [--attempt N]

set -euo pipefail

# Locate _common.sh via BASH_SOURCE (works whether this file is executed OR sourced
# by a unit test — $0 would point at the sourcing shell, not this file).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

# The underlying agentic CLI. Overridable for tests via COMPAT_CLI_CMD.
CLAUDE_CMD="${COMPAT_CLI_CMD:-claude}"
# Autonomous-edit permission flag for headless implement. See VERIFY note above.
PERM_FLAG="--permission-mode"
PERM_MODE="bypassPermissions"

# ---------------------------------------------------------------------------
# parse_compat_args() — capture the compat-specific flags the dispatcher passes.
#   Sets: COMPAT_TOOL_NAME, COMPAT_BASE_URL, COMPAT_AUTH_ENV_VAR, COMPAT_API_STYLE
#   Leaves the standard flags for parse_args (which ignores unknown flags).
# ---------------------------------------------------------------------------
parse_compat_args() {
  COMPAT_TOOL_NAME="compat"
  COMPAT_BASE_URL=""
  COMPAT_AUTH_ENV_VAR=""
  COMPAT_API_STYLE="anthropic"
  local prev=""
  for arg in "$@"; do
    case "$prev" in
      --tool-name)    COMPAT_TOOL_NAME="$arg" ;;
      --base-url)     COMPAT_BASE_URL="$arg" ;;
      --auth-env-var) COMPAT_AUTH_ENV_VAR="$arg" ;;
      --api-style)    COMPAT_API_STYLE="$arg" ;;
    esac
    prev="$arg"
  done
}

# ---------------------------------------------------------------------------
# extract_cost_compat() — parse `claude -p --output-format json` for token usage.
#   Lives here (not in vendored _common.sh) by design. Returns
#   {"input_tokens": N, "output_tokens": N}. Input folds in cache tokens.
# ---------------------------------------------------------------------------
extract_cost_compat() {
  local json_file="${1:-}"
  if [[ -z "$json_file" || ! -f "$json_file" ]] || ! command -v jq >/dev/null 2>&1; then
    printf '{"input_tokens": 0, "output_tokens": 0}'
    return 0
  fi
  # `--output-format json` is a single object; be tolerant of a JSONL stream too
  # (take the last object carrying a .usage) via jq -s.
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
compat_model_label() {
  if [[ -n "${XT_MODEL:-}" ]]; then printf '%s' "$XT_MODEL"; else printf '%s' "provider-default"; fi
}

# ===========================================================================
# health
# ===========================================================================
cmd_health() {
  parse_compat_args "$@"
  local tool="$COMPAT_TOOL_NAME"
  local model; model="$(compat_model_label)"
  local status="ready" version="unknown" auth_valid=false detail=""

  if [[ "$COMPAT_API_STYLE" != "anthropic" ]]; then
    printf '{"tool":"%s","status":"unavailable","version":"n/a","auth_valid":false,"model":"%s","detail":"compat adapter supports only api_style: anthropic (endpoint-swapped claude)"}\n' \
      "$tool" "$model"
    return 0
  fi

  if ! command -v "$CLAUDE_CMD" >/dev/null 2>&1; then
    printf '{"tool":"%s","status":"unavailable","version":"not_installed","auth_valid":false,"model":"%s","detail":"claude CLI not found"}\n' \
      "$tool" "$model"
    return 0
  fi
  version="$("$CLAUDE_CMD" --version 2>/dev/null | tr -d '\n' | xargs || printf 'unknown')"

  if [[ -z "$COMPAT_BASE_URL" ]]; then
    status="unavailable"; detail="base_url not configured (adapters.$tool.base_url)"
  elif [[ -z "$COMPAT_AUTH_ENV_VAR" ]]; then
    status="unavailable"; detail="auth_env_var not configured (adapters.$tool.auth_env_var)"
  elif [[ -z "${!COMPAT_AUTH_ENV_VAR:-}" ]]; then
    status="unavailable"; detail="auth token env var '$COMPAT_AUTH_ENV_VAR' is empty/unset"
  else
    auth_valid=true
  fi

  if command -v jq >/dev/null 2>&1; then
    jq -n --arg tool "$tool" --arg status "$status" --arg version "$version" \
      --argjson auth_valid "$auth_valid" --arg model "$model" --arg detail "$detail" \
      '{tool:$tool,status:$status,version:$version,auth_valid:$auth_valid,model:$model} + (if $detail=="" then {} else {detail:$detail} end)'
  else
    printf '{"tool":"%s","status":"%s","version":"%s","auth_valid":%s,"model":"%s"}\n' \
      "$tool" "$status" "$version" "$auth_valid" "$model"
  fi
}

# Shared: assemble env + run claude headless. Args after the marker are extra claude flags.
# Echoes nothing; writes to the provided stdout/stderr files; returns claude's exit code.
run_claude() {
  local timeout_secs="$1" stdout_file="$2" stderr_file="$3" prompt="$4"; shift 4
  local token="${!COMPAT_AUTH_ENV_VAR:-}"
  local exit_code=0
  # Run inside the worktree so edits land there. Minimal, explicit environment.
  ( cd "$XT_WORKTREE" && \
    safe_invoke "$timeout_secs" "$stdout_file" "$stderr_file" \
      env -i \
        HOME="$HOME" \
        PATH="$PATH" \
        ANTHROPIC_BASE_URL="$COMPAT_BASE_URL" \
        ANTHROPIC_AUTH_TOKEN="$token" \
      "$CLAUDE_CMD" -p "$prompt" --output-format json "$@" \
  ) || exit_code=$?
  return "$exit_code"
}

# ===========================================================================
# implement
# ===========================================================================
cmd_implement() {
  parse_compat_args "$@"
  parse_args "$@"
  local tool="$COMPAT_TOOL_NAME"
  local model; model="$(compat_model_label)"

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
        --author="${tool} (compat) <external-tools@telar>" >/dev/null 2>&1 || true
    fi
    if [[ -n "$XT_CONTEXT_DIR" ]]; then
      if ! verify_scope "$XT_WORKTREE" "$XT_CONTEXT_DIR"; then
        git -C "$XT_WORKTREE" add -A 2>/dev/null || true
        if ! git -C "$XT_WORKTREE" diff --cached --quiet 2>/dev/null; then
          git -C "$XT_WORKTREE" commit -m "fix: revert out-of-scope changes" \
            --author="${tool} (compat) <external-tools@telar>" >/dev/null 2>&1 || true
        fi
      fi
    fi
    branch="$(git -C "$XT_WORKTREE" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    git_sha="$(git -C "$XT_WORKTREE" rev-parse HEAD 2>/dev/null || true)"
  fi

  local cost_json; cost_json="$(extract_cost_compat "$stdout_file")"
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
  parse_compat_args "$@"
  parse_args "$@"
  local tool="$COMPAT_TOOL_NAME"
  local model; model="$(compat_model_label)"

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

  # The verdict parser reads .raw_log; claude's json wraps the model's text in
  # .result, so surface .result as the raw_log for parse-verdict to scan.
  local review_text_file="${tmp_dir}/review.txt"
  if command -v jq >/dev/null 2>&1 && [[ -f "$stdout_file" ]]; then
    jq -rs '(map(select(.result != null)) | last | .result) // (.[-1].result // "")' "$stdout_file" 2>/dev/null > "$review_text_file" || cp "$stdout_file" "$review_text_file"
  else
    [[ -f "$stdout_file" ]] && cp "$stdout_file" "$review_text_file"
  fi

  local cost_json; cost_json="$(extract_cost_compat "$stdout_file")"
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

Generic Anthropic-compatible adapter (drives the claude CLI with a swapped endpoint).
  --tool-name <name>      Reporting name (the adapters.<name> key)
  --base-url <url>        Anthropic-compatible endpoint (adapters.<name>.base_url)
  --auth-env-var <ENV>    Name of the env var holding the provider auth token
  --api-style anthropic   Only "anthropic" is supported
  --worktree <path>       Git worktree (implement/review)
  --prompt-file <path>    Prompt (implement); --rubric-file/--spec-file (review)
  --model <id>            Provider model id (e.g. kimi-k3)
  --timeout <seconds>     Timeout (default 300); --attempt N; --context-dir <dir>
USAGE
    exit 1
    ;;
esac
