#!/usr/bin/env bash
# tl-telar-orchestration-lock.sh — single-holder mutex over one orchestration plan.
#
# WHY: the same project can be driven by EITHER host (Claude or Codex), but the shared
# state files (.tl-telar/context/execution-state.md, .tl-telar/plans/active-plan.md) and
# the git working tree must not be mutated by two orchestrators at once. This lock lets a
# session claim "I am orchestrating this project"; a second session must wait, take over a
# STALE lock, or run as a reviewer instead. It is a mutex, not concurrency arbitration —
# by design two orchestrators never run the same plan simultaneously.
#
# Lock file: .tl-telar/context/orchestration-lock.json
#   { host, session_id, plan, pid, started_at, heartbeat_at }
#
# Subcommands:
#   acquire  --host <h> --session <id> --plan <p> [--stale-seconds N]  (default 900)
#            -> JSON {acquired:bool, action, holder}. Re-entrant for the same session;
#               takes over a STALE lock (heartbeat older than N); refuses a LIVE foreign lock.
#   heartbeat --session <id>          -> refresh heartbeat_at iff this session holds it
#   release   --session <id>          -> remove the lock iff this session holds it
#   takeover  --host <h> --session <id> --plan <p>   -> force-acquire (explicit override)
#   status                            -> JSON current lock, or {held:false}
#
# Atomic acquire uses `set -o noclobber` (O_EXCL create). Exit codes: 0 ok, 3 lock held
# by another live session, 2 bad args.
set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
LOCK_DIR="$PROJECT_ROOT/.tl-telar/context"
LOCK="$LOCK_DIR/orchestration-lock.json"
DEFAULT_STALE=900

now() { date +%s; }
have_jq() { command -v jq >/dev/null 2>&1; }

die_args() { echo "{\"error\":\"bad_args\",\"detail\":\"$1\"}" >&2; exit 2; }

# Read a field from the current lock file (empty if no lock / no jq).
lock_field() {
  [[ -f "$LOCK" ]] || { printf ''; return; }
  if have_jq; then jq -r --arg k "$1" '.[$k] // ""' "$LOCK" 2>/dev/null || printf ''
  else printf ''; fi
}

emit_lock() { # prints the lock JSON (or {held:false})
  if [[ -f "$LOCK" ]] && have_jq; then jq -c '{held:true} + .' "$LOCK" 2>/dev/null || cat "$LOCK"
  else echo '{"held":false}'; fi
}

write_lock() { # $1 host $2 session $3 plan [$4 started_at]
  local host="$1" session="$2" plan="$3" started="${4:-$(now)}" t; t="$(now)"
  mkdir -p "$LOCK_DIR"
  if have_jq; then
    jq -n --arg host "$host" --arg s "$session" --arg p "$plan" \
       --argjson start "$started" --argjson hb "$t" --argjson pid "$$" \
       '{host:$host, session_id:$s, plan:$p, pid:$pid, started_at:$start, heartbeat_at:$hb}' > "$LOCK"
  else
    printf '{"host":"%s","session_id":"%s","plan":"%s","pid":%s,"started_at":%s,"heartbeat_at":%s}\n' \
      "$host" "$session" "$plan" "$$" "$started" "$t" > "$LOCK"
  fi
}

cmd_acquire() {
  local host="" session="" plan="" stale="$DEFAULT_STALE" force="${FORCE:-0}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --host) host="${2:-}"; shift 2 ;;
      --session) session="${2:-}"; shift 2 ;;
      --plan) plan="${2:-}"; shift 2 ;;
      --stale-seconds) stale="${2:-}"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -n "$host" && -n "$session" && -n "$plan" ]] || die_args "acquire needs --host --session --plan"
  mkdir -p "$LOCK_DIR"

  # Atomic create when no lock exists (O_EXCL via noclobber).
  if [[ ! -f "$LOCK" ]]; then
    if ( set -o noclobber; : > "$LOCK" ) 2>/dev/null; then
      write_lock "$host" "$session" "$plan"
      echo "{\"acquired\":true,\"action\":\"created\",\"holder\":$(emit_lock)}"; return 0
    fi
    # lost the race — fall through to inspect the winner
  fi

  local h_session h_hb age
  h_session="$(lock_field session_id)"; h_hb="$(lock_field heartbeat_at)"
  [[ -z "$h_hb" ]] && h_hb=0
  age=$(( $(now) - h_hb ))

  if [[ "$force" == "1" ]]; then
    write_lock "$host" "$session" "$plan"
    echo "{\"acquired\":true,\"action\":\"takeover_forced\",\"holder\":$(emit_lock)}"; return 0
  fi
  if [[ "$h_session" == "$session" ]]; then
    write_lock "$host" "$session" "$plan" "$(lock_field started_at)"   # re-entrant: refresh heartbeat
    echo "{\"acquired\":true,\"action\":\"reentrant\",\"holder\":$(emit_lock)}"; return 0
  fi
  if [[ "$age" -gt "$stale" ]]; then
    write_lock "$host" "$session" "$plan"
    echo "{\"acquired\":true,\"action\":\"takeover_stale\",\"stale_age_seconds\":$age,\"holder\":$(emit_lock)}"; return 0
  fi
  echo "{\"acquired\":false,\"action\":\"live_lock_held\",\"holder\":$(emit_lock)}"; return 3
}

cmd_heartbeat() {
  local session=""
  while [[ $# -gt 0 ]]; do case "$1" in --session) session="${2:-}"; shift 2 ;; *) shift ;; esac; done
  [[ -n "$session" ]] || die_args "heartbeat needs --session"
  [[ -f "$LOCK" ]] || { echo '{"ok":false,"reason":"no_lock"}'; return 0; }
  if [[ "$(lock_field session_id)" == "$session" ]]; then
    write_lock "$(lock_field host)" "$session" "$(lock_field plan)" "$(lock_field started_at)"
    echo "{\"ok\":true,\"holder\":$(emit_lock)}"
  else
    echo "{\"ok\":false,\"reason\":\"not_holder\",\"holder\":$(emit_lock)}"; return 3
  fi
}

cmd_release() {
  local session=""
  while [[ $# -gt 0 ]]; do case "$1" in --session) session="${2:-}"; shift 2 ;; *) shift ;; esac; done
  [[ -n "$session" ]] || die_args "release needs --session"
  [[ -f "$LOCK" ]] || { echo '{"released":false,"reason":"no_lock"}'; return 0; }
  if [[ "$(lock_field session_id)" == "$session" ]]; then
    rm -f "$LOCK"; echo '{"released":true}'
  else
    echo "{\"released\":false,\"reason\":\"not_holder\",\"holder\":$(emit_lock)}"; return 3
  fi
}

cmd_takeover() { FORCE=1 cmd_acquire "$@"; }
cmd_status()   { emit_lock; }

case "${1:-}" in
  acquire)   shift; cmd_acquire "$@" ;;
  heartbeat) shift; cmd_heartbeat "$@" ;;
  release)   shift; cmd_release "$@" ;;
  takeover)  shift; cmd_takeover "$@" ;;
  status)    shift; cmd_status "$@" ;;
  *) echo "Usage: $0 acquire|heartbeat|release|takeover|status [--host --session --plan --stale-seconds]" >&2; exit 2 ;;
esac
