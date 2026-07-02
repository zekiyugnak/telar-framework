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

test_plan_warnings_emitted() {
  # Ambiguous plan: two independent WUs with same file_scope, no dep edge
  cat > "$1/active-plan.md" <<'EOF'
## Work Units
### WU-001: A
- file_scope:
  - src/shared.ts
- deps: []
### WU-002: B
- file_scope:
  - src/shared.ts
- deps: []
EOF
  cat > "$1/execution-state.md" <<'EOF'
## Work Unit Status
| WU | Status | Phase | Retries | Writer Model |
|----|--------|-------|---------|--------------|
EOF
  out=$(node "$SCHED" "$1/active-plan.md" "$1/execution-state.md"); rc=$?
  [[ $rc -eq 0 ]] || { echo "    exit $rc"; return 1; }
  echo "$out" | grep -q '"plan_warnings":\[[^]]' || { echo "    no plan_warnings: $out"; return 1; }
  return 0
}

test_usage_exit_two() {
  out=$(node "$SCHED" 2>&1); rc=$?
  [[ $rc -eq 2 ]] || { echo "    expected exit 2, got $rc"; return 1; }
  return 0
}

test_cap_read_from_thresholds() {
  # A thresholds file with max_parallel_wus=2 must be honored: 3 independent WUs
  # -> only 2 ready, the third blocked concurrency_cap. Exercises readMaxParallel's
  # file-read branch (the default-3 case above only covers the absent-file branch).
  cat > "$1/.tl-telar-thresholds.json" <<'EOF'
{ "execution": { "max_parallel_wus": 2 } }
EOF
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
### WU-003: C
- file_scope:
  - src/c.ts
- deps: []
EOF
  cat > "$1/execution-state.md" <<'EOF'
## Work Unit Status
| WU | Status | Phase | Retries | Writer Model |
|----|--------|-------|---------|--------------|
EOF
  out=$(node "$SCHED" "$1/active-plan.md" "$1/execution-state.md"); rc=$?
  [[ $rc -eq 0 ]] || { echo "    exit $rc"; return 1; }
  # exactly two ready
  local nready
  nready=$(echo "$out" | grep -o '"ready":\[[^]]*\]' | grep -o 'WU-[0-9]*' | wc -l | tr -d ' ')
  [[ "$nready" -eq 2 ]] || { echo "    expected 2 ready, got $nready: $out"; return 1; }
  echo "$out" | grep -q '"reason":"concurrency_cap"' || { echo "    no concurrency_cap block: $out"; return 1; }
  echo "$out" | grep -q 'max_parallel_wus=2' || { echo "    cap value not 2 in detail: $out"; return 1; }
  return 0
}

run "ready after dep COMPLETE"        test_ready_after_complete
run "cap defaults to 3 (no thresholds)" test_cap_default_three
run "cycle -> exit 1"                  test_cycle_exits_nonzero
run "missing file -> exit 1"           test_missing_file_exits_nonzero
run "ambiguous plan -> plan_warnings emitted" test_plan_warnings_emitted
run "no args -> exit 2 usage"          test_usage_exit_two
run "cap read from thresholds file"    test_cap_read_from_thresholds

echo ""
echo "Workflow CLI smoke: ${pass} passed, ${fail} failed"
[[ $fail -eq 0 ]] || exit 1
exit 0
