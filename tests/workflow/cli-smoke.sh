#!/usr/bin/env bash
# Smoke tests for the tl-telar-wu-scheduler CLI.
# Run from the plugin repo root: bash tests/workflow/cli-smoke.sh
set -uo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCHED="$PLUGIN_ROOT/scripts/tl-telar-wu-scheduler.js"
pass=0; fail=0

run() { # name, fn
  echo "▶ $1"
  local sandbox; sandbox=$(mktemp -d -t tl-telar-wu-sched.XXXXXX)
  export CLAUDE_PROJECT_DIR="$sandbox"
  if "$2" "$sandbox"; then pass=$((pass+1)); echo "  PASS"; else fail=$((fail+1)); echo "  FAIL"; fi
  unset CLAUDE_PROJECT_DIR; rm -rf "$sandbox"
}

write_plan() {
  cat > "$1/active-plan.md" <<'EOF'
# Active Plan
## Work Units

### WU-001: A
- file_scope:
  - src/a.ts
- deps: []

### WU-002: B
- file_scope:
  - src/b.ts
- deps: [WU-001]
EOF
}

write_state() { # dir, wu001status
  cat > "$1/execution-state.md" <<EOF
# Execution State

## Work Unit Status

| WU     | Status   | Phase | Retries | Writer Model |
|--------|----------|-------|---------|--------------|
| WU-001 | $2 | —     | 0       | claude       |
EOF
}

test_ready_after_complete() {
  write_plan "$1"; write_state "$1" "COMPLETE"
  out=$(node "$SCHED" "$1/active-plan.md" "$1/execution-state.md"); rc=$?
  [[ $rc -eq 0 ]] || { echo "    exit $rc"; return 1; }
  echo "$out" | grep -q '"ready":\[[^]]*"WU-002"' || { echo "    WU-002 not ready: $out"; return 1; }
  return 0
}

test_cap_default_three() {
  # No thresholds file -> default 3; both independent WUs ready when none running
  cat > "$1/active-plan.md" <<'EOF'
## Work Units
### WU-001: A
- file_scope:
  - src/a.ts
- deps: []
### WU-002: B
- file_scope:
  - src/b.ts
- deps: []
EOF
  cat > "$1/execution-state.md" <<'EOF'
## Work Unit Status
| WU | Status | Phase | Retries | Writer Model |
|----|--------|-------|---------|--------------|
EOF
  out=$(node "$SCHED" "$1/active-plan.md" "$1/execution-state.md"); rc=$?
  [[ $rc -eq 0 ]] || { echo "    exit $rc"; return 1; }
  echo "$out" | grep -q '"WU-001"' && echo "$out" | grep -q '"WU-002"' || { echo "    both not ready: $out"; return 1; }
  return 0
}

test_cycle_exits_nonzero() {
  cat > "$1/active-plan.md" <<'EOF'
## Work Units
### WU-001: A
- file_scope:
  - src/a.ts
- deps: [WU-002]
### WU-002: B
- file_scope:
  - src/b.ts
- deps: [WU-001]
EOF
  cat > "$1/execution-state.md" <<'EOF'
## Work Unit Status
| WU | Status | Phase | Retries | Writer Model |
|----|--------|-------|---------|--------------|
EOF
  out=$(node "$SCHED" "$1/active-plan.md" "$1/execution-state.md" 2>&1); rc=$?
  [[ $rc -eq 1 ]] || { echo "    expected exit 1, got $rc"; return 1; }
  echo "$out" | grep -qi "cycle" || { echo "    no cycle message: $out"; return 1; }
  return 0
}

test_missing_file_exits_nonzero() {
  out=$(node "$SCHED" "$1/nope.md" "$1/also-nope.md" 2>&1); rc=$?
  [[ $rc -eq 1 ]] || { echo "    expected exit 1, got $rc"; return 1; }
  return 0
}

run "ready after dep COMPLETE"        test_ready_after_complete
run "cap defaults to 3 (no thresholds)" test_cap_default_three
run "cycle -> exit 1"                  test_cycle_exits_nonzero
run "missing file -> exit 1"           test_missing_file_exits_nonzero

echo ""
echo "Workflow CLI smoke: ${pass} passed, ${fail} failed"
[[ $fail -eq 0 ]] || exit 1
exit 0
