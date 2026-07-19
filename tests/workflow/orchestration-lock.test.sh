#!/usr/bin/env bash
# Tests for scripts/tl-telar-orchestration-lock.sh — the single-holder orchestration mutex:
# atomic acquire, re-entrancy, foreign-lock refusal, stale takeover, heartbeat/release ownership,
# explicit takeover, status. No network; pure file-state logic in a temp project.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCK="$ROOT/scripts/tl-telar-orchestration-lock.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.tl-telar/context"
export CLAUDE_PROJECT_DIR="$TMP"

pass=0; fail=0
check() { if [[ "$2" == "$3" ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "  FAIL: $1 — expected '$2' got '$3'"; fi; }
L() { set +e; OUT=$(bash "$LOCK" "$@" 2>/dev/null); RC=$?; set -e; }
f() { echo "$OUT" | jq -r "$1"; }

echo "orchestration lock:"

# 1. acquire on empty project
L acquire --host claude --session S1 --plan PLAN-A
check "acquire created"   true    "$(f '.acquired')"
check "acquire action"    created "$(f '.action')"
check "holder host"       claude  "$(f '.holder.host')"
check "holder session"    S1      "$(f '.holder.session_id')"

# 2. re-entrant: same session re-acquires
L acquire --host claude --session S1 --plan PLAN-A
check "reentrant acquired" true      "$(f '.acquired')"
check "reentrant action"   reentrant "$(f '.action')"

# 3. foreign LIVE lock -> refused, exit 3, holder unchanged
L acquire --host codex --session S2 --plan PLAN-B
check "foreign refused"   false          "$(f '.acquired')"
check "foreign action"    live_lock_held "$(f '.action')"
check "foreign exit"      3              "$RC"
check "holder unchanged"  S1             "$(f '.holder.session_id')"

# 4. STALE takeover (force age>stale via --stale-seconds -1)
L acquire --host codex --session S2 --plan PLAN-B --stale-seconds -1
check "stale acquired"    true           "$(f '.acquired')"
check "stale action"      takeover_stale "$(f '.action')"
check "stale new holder"  S2             "$(f '.holder.session_id')"
check "stale new host"    codex          "$(f '.holder.host')"

# 5. heartbeat: holder ok, foreigner not
L heartbeat --session S2
check "hb holder ok"      true  "$(f '.ok')"
L heartbeat --session S1
check "hb foreigner"      false "$(f '.ok')"

# 6. release: foreigner refused, holder ok, then re-acquire free
L release --session S1
check "release foreigner" false "$(f '.released')"
L release --session S2
check "release holder"    true  "$(f '.released')"
L acquire --host claude --session S3 --plan PLAN-C
check "acquire after rel" created "$(f '.action')"

# 7. explicit takeover overrides a live lock
L takeover --host codex --session S4 --plan PLAN-D
check "takeover action"   takeover_forced "$(f '.action')"
check "takeover holder"   S4              "$(f '.holder.session_id')"

# 8. status reflects current holder
L status
check "status host"       codex "$(f '.host')"
check "status held"       true  "$(f '.held')"

echo "  $pass passed, $fail failed"
[[ "$fail" -eq 0 ]] || exit 1
