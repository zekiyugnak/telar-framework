#!/bin/bash
# kimi.sh — NATIVE Kimi Code CLI adapter for external-tools.
#
# NOT vendored — original to Telar (like compat.sh). Uses the metaswarm-derived
# _common.sh contract but is a first-party file, free to change.
#
# Drives Moonshot's official `kimi` CLI (github.com/MoonshotAI/kimi-code) the same
# way codex.sh drives `codex exec`: a headless agentic coding CLI that reads/writes/
# edits files and runs shell commands. Auth is the CLI's own (OAuth device-code via
# `kimi login`, stored in ~/.kimi-code) — NO API-key env var needed, exactly like
# codex's ChatGPT login. This is the "use Kimi via its own CLI, like codex" path;
# for a raw Anthropic-compatible endpoint instead, use the generic compat.sh adapter.
#
# Cost note: Kimi-for-Coding is a FLAT SUBSCRIPTION (OAuth), not per-token metered,
# and `kimi --output-format stream-json` does not emit token usage. So cost is
# reported as 0 tokens (declare pricing 0 in external-tools.yaml → a known $0, not
# the unknown-pricing fail-closed path).
#
# Commands:
#   health     kimi installed + config/auth valid (`kimi doctor`)
#   implement  kimi -y (yolo/autonomous) writes code on a worktree branch
#   review     kimi --plan (no edits) reviews a diff against rubric/spec
#
# Usage:
#   kimi.sh health
#   kimi.sh implement --worktree <path> --prompt-file <path> [--model M] [--timeout S] [--attempt N] [--context-dir <dir>]
#   kimi.sh review    --worktree <path> --rubric-file <path> --spec-file <path> [--model M] [--timeout S] [--attempt N]

set -euo pipefail

# Locate _common.sh via BASH_SOURCE (works executed OR sourced by a unit test).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

TOOL_NAME="kimi"
KIMI_CLI_CMD="${KIMI_CLI_CMD:-kimi}"     # overridable for tests
DEFAULT_MODEL_ALIAS="kimi-code/k3"       # always full K3 by default

kimi_model() { if [[ -n "${XT_MODEL:-}" ]]; then printf '%s' "$XT_MODEL"; else printf '%s' "$DEFAULT_MODEL_ALIAS"; fi; }

# extract_kimi_text — join assistant message content from a stream-json log.
# Lives here (not vendored _common.sh) by design.
extract_kimi_text() {
  local f="${1:-}"
  if [[ -z "$f" || ! -f "$f" ]] || ! command -v jq >/dev/null 2>&1; then printf ''; return 0; fi
  jq -rs '[ .[] | select(.role=="assistant") | .content ] | map(select(type=="string")) | join("\n")' "$f" 2>/dev/null || printf ''
}

# extract_cost_kimi — stream-json carries no token usage for the subscription CLI;
# return zeros (declared $0 pricing in config makes this a known, correct $0).
extract_cost_kimi() {
  local f="${1:-}"
  if [[ -n "$f" && -f "$f" ]] && command -v jq >/dev/null 2>&1; then
    local u
    u=$(jq -rs '[ .[] | (.usage // empty) ] | last // empty' "$f" 2>/dev/null || true)
    if [[ -n "$u" && "$u" != "null" ]]; then
      echo "$u" | jq -c '{input_tokens:(.input_tokens // .prompt_tokens // 0), output_tokens:(.output_tokens // .completion_tokens // 0)}' 2>/dev/null && return 0
    fi
  fi
  printf '{"input_tokens": 0, "output_tokens": 0}'
}

# ===========================================================================
# health
# ===========================================================================
cmd_health() {
  local model; model="$(kimi_model)"
  if ! command -v "$KIMI_CLI_CMD" >/dev/null 2>&1; then
    printf '{"tool":"%s","status":"unavailable","version":"not_installed","auth_valid":false,"model":"%s","detail":"kimi CLI not found — install github.com/MoonshotAI/kimi-code"}\n' "$TOOL_NAME" "$model"
    return 0
  fi
  local version; version="$("$KIMI_CLI_CMD" --version 2>/dev/null | tr -d '\n' | xargs || printf 'unknown')"
  # `kimi doctor` validates config + auth. Treat exit 0 as authenticated/ready.
  local status="ready" auth_valid=true detail=""
  if ! "$KIMI_CLI_CMD" doctor >/dev/null 2>&1; then
    status="unavailable"; auth_valid=false; detail="kimi doctor failed — run 'kimi login' and check ~/.kimi-code/config.toml"
  fi
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg tool "$TOOL_NAME" --arg status "$status" --arg version "$version" \
      --argjson auth_valid "$auth_valid" --arg model "$model" --arg detail "$detail" \
      '{tool:$tool,status:$status,version:$version,auth_valid:$auth_valid,model:$model} + (if $detail=="" then {} else {detail:$detail} end)'
  else
    printf '{"tool":"%s","status":"%s","version":"%s","auth_valid":%s,"model":"%s"}\n' "$TOOL_NAME" "$status" "$version" "$auth_valid" "$model"
  fi
}

# Run kimi headless in <workdir>. $1=workdir $2=timeout $3=stdout $4=stderr $5=prompt; rest=extra flags.
# NOTE: `-p` cannot combine with -y/--auto/--plan (kimi errors). `-p` is already
# autonomous for implement; for review we isolate by choosing an EMPTY workdir so
# kimi has no repo to edit (the diff is inlined in the prompt), instead of --plan.
run_kimi() {
  local workdir="$1" timeout_secs="$2" stdout_file="$3" stderr_file="$4" prompt="$5"; shift 5
  local exit_code=0
  ( cd "$workdir" && \
    safe_invoke "$timeout_secs" "$stdout_file" "$stderr_file" \
      env -i HOME="$HOME" PATH="$PATH" \
      "$KIMI_CLI_CMD" -m "$(kimi_model)" -p "$prompt" --output-format stream-json "$@" \
  ) || exit_code=$?
  return "$exit_code"
}

# ===========================================================================
# implement
# ===========================================================================
cmd_implement() {
  parse_args "$@"
  local model; model="$(kimi_model)"
  [[ -n "$XT_WORKTREE" ]]    || { printf 'Error: --worktree is required\n' >&2; return 1; }
  [[ -n "$XT_PROMPT_FILE" ]] || { printf 'Error: --prompt-file is required\n' >&2; return 1; }
  [[ -d "$XT_WORKTREE" ]]    || { printf 'Error: worktree does not exist: %s\n' "$XT_WORKTREE" >&2; return 1; }
  [[ -f "$XT_PROMPT_FILE" ]] || { printf 'Error: prompt file does not exist: %s\n' "$XT_PROMPT_FILE" >&2; return 1; }

  local tmp_dir; tmp_dir="$(create_secure_tmp)"
  local stdout_file="${tmp_dir}/stdout.jsonl" stderr_file="${tmp_dir}/stderr.log"
  local prompt_content; prompt_content="$(cat "$XT_PROMPT_FILE")"

  local start_time; start_time="$(date +%s)"
  local exit_code=0
  # `-p` (prompt/headless) mode is already autonomous — it applies tool calls
  # without approval. It CANNOT be combined with -y/--auto (kimi errors), so pass
  # no extra permission flag for implement. Run IN the worktree so edits land there.
  run_kimi "$XT_WORKTREE" "$XT_TIMEOUT" "$stdout_file" "$stderr_file" "$prompt_content" || exit_code=$?
  local duration=$(( $(date +%s) - start_time ))

  mkdir -p "$LOG_DIR"
  local raw_log_file="${LOG_DIR}/${TOOL_NAME}-implement-$(date +%Y%m%dT%H%M%S)-$$.jsonl"
  [[ -f "$stdout_file" ]] && cp "$stdout_file" "$raw_log_file"

  if [[ "$exit_code" -ne 0 ]]; then
    local ej; ej="$(emit_error "$TOOL_NAME" "implement" "$model" "$XT_ATTEMPT" "$exit_code" "$stderr_file" "$duration" "$raw_log_file")"
    log_session "$ej"; printf '%s\n' "$ej"; rm -rf "$tmp_dir"; return 1
  fi

  local branch="" git_sha=""
  if [[ -d "$XT_WORKTREE" ]]; then
    git -C "$XT_WORKTREE" add -A 2>/dev/null || true
    if ! git -C "$XT_WORKTREE" diff --cached --quiet 2>/dev/null; then
      git -C "$XT_WORKTREE" commit -m "feat: kimi implement (attempt ${XT_ATTEMPT})" --author="Kimi Code CLI <kimi@moonshot.ai>" >/dev/null 2>&1 || true
    fi
    if [[ -n "$XT_CONTEXT_DIR" ]] && ! verify_scope "$XT_WORKTREE" "$XT_CONTEXT_DIR"; then
      git -C "$XT_WORKTREE" add -A 2>/dev/null || true
      git -C "$XT_WORKTREE" diff --cached --quiet 2>/dev/null || git -C "$XT_WORKTREE" commit -m "fix: revert out-of-scope changes" --author="Kimi Code CLI <kimi@moonshot.ai>" >/dev/null 2>&1 || true
    fi
    branch="$(git -C "$XT_WORKTREE" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    git_sha="$(git -C "$XT_WORKTREE" rev-parse HEAD 2>/dev/null || true)"
  fi

  local cost_json; cost_json="$(extract_cost_kimi "$stdout_file")"
  local files_changed_json; files_changed_json="$(get_changed_files "$XT_WORKTREE")"
  local diff_stats_json; diff_stats_json="$(get_diff_stats "$XT_WORKTREE")"
  local rj; rj="$(emit_json "$TOOL_NAME" "implement" "$model" "$XT_ATTEMPT" "$exit_code" "$branch" "$git_sha" "$files_changed_json" "$diff_stats_json" "$duration" "$cost_json" "$raw_log_file")"
  log_session "$rj"; printf '%s\n' "$rj"; rm -rf "$tmp_dir"
}

# ===========================================================================
# review
# ===========================================================================
cmd_review() {
  parse_args "$@"
  local model; model="$(kimi_model)"
  [[ -n "$XT_WORKTREE" ]]    || { printf 'Error: --worktree is required\n' >&2; return 1; }
  [[ -n "$XT_RUBRIC_FILE" ]] || { printf 'Error: --rubric-file is required\n' >&2; return 1; }
  [[ -n "$XT_SPEC_FILE" ]]   || { printf 'Error: --spec-file is required\n' >&2; return 1; }
  [[ -d "$XT_WORKTREE" ]]    || { printf 'Error: worktree does not exist: %s\n' "$XT_WORKTREE" >&2; return 1; }
  [[ -f "$XT_RUBRIC_FILE" ]] || { printf 'Error: rubric file does not exist: %s\n' "$XT_RUBRIC_FILE" >&2; return 1; }
  [[ -f "$XT_SPEC_FILE" ]]   || { printf 'Error: spec file does not exist: %s\n' "$XT_SPEC_FILE" >&2; return 1; }

  local tmp_dir; tmp_dir="$(create_secure_tmp)"
  local stdout_file="${tmp_dir}/stdout.jsonl" stderr_file="${tmp_dir}/stderr.log"

  local diff_content; diff_content="$(git -C "$XT_WORKTREE" diff HEAD 2>/dev/null || true)"
  [[ -z "$diff_content" ]] && diff_content="$(git -C "$XT_WORKTREE" diff HEAD~1 HEAD 2>/dev/null || true)"
  local rubric_content; rubric_content="$(cat "$XT_RUBRIC_FILE")"
  local spec_content; spec_content="$(cat "$XT_SPEC_FILE")"
  local review_prompt
  review_prompt="You are a code reviewer. Review the following diff against the rubric and spec. Do NOT edit any files — output ONLY the review."$'\n\n## Git Diff\n```diff\n'"${diff_content}"$'\n```\n\n## Rubric\n'"${rubric_content}"$'\n\n## Spec\n'"${spec_content}"$'\n\n## Instructions\nEvaluate each rubric criterion. Output a SINGLE JSON object with keys "verdict" (PASS|FAIL), "issues" (array), "summary". FAIL if any BLOCKING issue.\n'

  # Isolate the review in an EMPTY dir (the diff is inline in the prompt) so kimi
  # has no repo to modify — `-p` can't take a read-only flag, so isolation is how
  # we keep review non-mutating.
  local review_workdir="${tmp_dir}/scratch"; mkdir -p "$review_workdir"
  local start_time; start_time="$(date +%s)"
  local exit_code=0
  run_kimi "$review_workdir" "$XT_TIMEOUT" "$stdout_file" "$stderr_file" "$review_prompt" || exit_code=$?
  local duration=$(( $(date +%s) - start_time ))

  mkdir -p "$LOG_DIR"
  local raw_log_file="${LOG_DIR}/${TOOL_NAME}-review-$(date +%Y%m%dT%H%M%S)-$$.jsonl"
  [[ -f "$stdout_file" ]] && cp "$stdout_file" "$raw_log_file"

  if [[ "$exit_code" -ne 0 ]]; then
    local ej; ej="$(emit_error "$TOOL_NAME" "review" "$model" "$XT_ATTEMPT" "$exit_code" "$stderr_file" "$duration" "$raw_log_file")"
    log_session "$ej"; printf '%s\n' "$ej"; rm -rf "$tmp_dir"; return 1
  fi

  # Surface the assistant text (holds the verdict JSON) as raw_log for parse-verdict.
  local review_text_file="${tmp_dir}/review.txt"
  extract_kimi_text "$stdout_file" > "$review_text_file"
  [[ -s "$review_text_file" ]] || cp "$stdout_file" "$review_text_file"

  local cost_json; cost_json="$(extract_cost_kimi "$stdout_file")"
  local branch="" git_sha=""
  if [[ -d "$XT_WORKTREE" ]]; then
    branch="$(git -C "$XT_WORKTREE" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    git_sha="$(git -C "$XT_WORKTREE" rev-parse HEAD 2>/dev/null || true)"
  fi
  local rj; rj="$(emit_json "$TOOL_NAME" "review" "$model" "$XT_ATTEMPT" "$exit_code" "$branch" "$git_sha" "[]" '{"additions": 0, "deletions": 0}' "$duration" "$cost_json" "$review_text_file")"
  log_session "$rj"; printf '%s\n' "$rj"; rm -rf "$tmp_dir"
}

# ===========================================================================
# Command dispatch (skipped when sourced by unit tests)
# ===========================================================================
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  return 0 2>/dev/null || true
fi

command="${1:-}"
shift || true
case "$command" in
  health)    cmd_health ;;
  implement) cmd_implement "$@" ;;
  review)    cmd_review "$@" ;;
  *)
    cat >&2 <<USAGE
Usage: $(basename "$0") <health|implement|review> [options]
Native Kimi Code CLI adapter (drives \`kimi\`; auth via \`kimi login\`, no API key env).
  --worktree <path>  --prompt-file <path> (implement) | --rubric-file/--spec-file (review)
  --model <alias>    default kimi-code/k3   --timeout <s>   --attempt <N>   --context-dir <dir>
USAGE
    exit 1
    ;;
esac
