#!/usr/bin/env bash
# Smoke tests for scripts/tl-telar-spec-bootstrap.js.
#
# Run from the plugin repo root:
#   bash tests/spec-layer/bootstrap-smoke.sh

set -uo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BOOTSTRAP="$PLUGIN_ROOT/scripts/tl-telar-spec-bootstrap.js"

pass_count=0
fail_count=0
failures=()

assert() {
  local label="$1" actual="$2" expected_pattern="$3"
  if [[ "$actual" =~ $expected_pattern ]]; then
    return 0
  else
    echo "    ASSERT FAIL: $label"
    echo "    expected match: $expected_pattern"
    echo "    actual: $(printf '%s' "$actual" | head -c 240)"
    return 1
  fi
}

run_test() {
  local name="$1" fn="$2"
  echo "▶ $name"
  local sandbox
  sandbox=$(mktemp -d -t tl-telar-spec-bootstrap-smoke.XXXXXX)
  export CLAUDE_PROJECT_DIR="$sandbox"
  pushd "$sandbox" >/dev/null
  if "$fn" "$sandbox"; then
    pass_count=$((pass_count + 1))
    echo "  PASS"
  else
    fail_count=$((fail_count + 1))
    failures+=("$name")
    echo "  FAIL"
  fi
  popd >/dev/null
  unset CLAUDE_PROJECT_DIR
  rm -rf "$sandbox"
}

test_skeleton_only() {
  out=$(node "$BOOTSTRAP" 2>&1); exit_code=$?
  [[ "$exit_code" -eq 0 ]] || { echo "    exit $exit_code, expected 0"; return 1; }
  assert "no-migration message" "$out" 'no root-level REQUIREMENTS.md found' || return 1
  [[ -d "$1/tl-telar-spec/truth" ]] || { echo "    truth/ dir missing"; return 1; }
  [[ -d "$1/tl-telar-spec/changes/archive" ]] || { echo "    changes/archive/ dir missing"; return 1; }
}

test_migration() {
  cat > "$1/REQUIREMENTS.md" <<'EOF'
# Requirements: Demo App
### F-1: Login
EOF
  cat > "$1/PLAN.md" <<'EOF'
tasks:
  - id: WU-001
    file_scope:
      - src/screens/auth/LoginScreen.tsx
      - src/screens/auth/__tests__/LoginScreen.test.tsx
EOF
  out=$(node "$BOOTSTRAP" 2>&1); exit_code=$?
  [[ "$exit_code" -eq 0 ]] || { echo "    exit $exit_code, expected 0"; return 1; }
  assert "migration message" "$out" 'Migrated REQUIREMENTS.md' || return 1
  [[ -f "$1/tl-telar-spec/truth/auth/REQUIREMENTS.md" ]] || { echo "    truth/auth/REQUIREMENTS.md missing"; return 1; }
  if [[ -f "$1/REQUIREMENTS.md" ]]; then echo "    root REQUIREMENTS.md was not removed"; return 1; fi
  return 0
}

test_migration_conflict() {
  mkdir -p "$1/tl-telar-spec/truth/auth"
  echo "# existing truth" > "$1/tl-telar-spec/truth/auth/REQUIREMENTS.md"
  cat > "$1/REQUIREMENTS.md" <<'EOF'
# Requirements: Demo App
### F-1: Login
EOF
  cat > "$1/PLAN.md" <<'EOF'
tasks:
  - id: WU-001
    file_scope:
      - src/screens/auth/LoginScreen.tsx
EOF
  out=$(node "$BOOTSTRAP" 2>&1); exit_code=$?
  [[ "$exit_code" -eq 1 ]] || { echo "    exit $exit_code, expected 1"; return 1; }
  assert "already-exists error" "$out" 'already exists' || return 1
  [[ -f "$1/REQUIREMENTS.md" ]] || { echo "    root REQUIREMENTS.md was deleted despite abort"; return 1; }
  grep -q "existing truth" "$1/tl-telar-spec/truth/auth/REQUIREMENTS.md" || { echo "    existing truth file was clobbered"; return 1; }
}

run_test "no root file → skeleton only"                   test_skeleton_only
run_test "root REQUIREMENTS.md + PLAN.md → migrated"       test_migration
run_test "existing truth destination → abort, no clobber"  test_migration_conflict

echo ""
echo "─────────────────────────────────────────"
echo "Smoke tests: ${pass_count} passed, ${fail_count} failed"
if [[ "$fail_count" -gt 0 ]]; then
  echo "Failed scenarios:"
  for n in "${failures[@]}"; do echo "  • $n"; done
  exit 1
fi
exit 0
