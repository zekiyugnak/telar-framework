#!/usr/bin/env bash
# Smoke tests for scripts/tl-telar-spec-archive.js.
#
# Run from the plugin repo root:
#   bash tests/spec-layer/archive-smoke.sh

set -uo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARCHIVE="$PLUGIN_ROOT/scripts/tl-telar-spec-archive.js"

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
  sandbox=$(mktemp -d -t tl-telar-spec-archive-smoke.XXXXXX)
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

make_change() {
  local sandbox="$1" change_id="$2" baseline="$3"
  local dir="$sandbox/tl-telar-spec/changes/$change_id"
  mkdir -p "$dir"
  cat > "$dir/REQUIREMENTS.delta.md" <<EOF
<!-- tl-telar-spec-delta: domain=auth baseline-hash=$baseline -->
## ADDED Requirements
### F-3: Two-Factor Authentication
**Description:** Users can enable TOTP-based 2FA.
**Phase:** 2
EOF
}

test_happy_path_first_delta() {
  make_change "$1" "2026-07-add-2fa" "none"
  out=$(node "$ARCHIVE" "2026-07-add-2fa" 2>&1); exit_code=$?
  [[ "$exit_code" -eq 0 ]] || { echo "    exit $exit_code, expected 0"; return 1; }
  assert "archived message" "$out" 'Archived tl-telar-spec/changes/2026-07-add-2fa' || return 1
  [[ -f "$1/tl-telar-spec/truth/auth/REQUIREMENTS.md" ]] || { echo "    truth file not created"; return 1; }
  grep -q "F-3: Two-Factor Authentication" "$1/tl-telar-spec/truth/auth/REQUIREMENTS.md" || { echo "    F-3 not merged"; return 1; }
  if [[ -d "$1/tl-telar-spec/changes/2026-07-add-2fa" ]]; then echo "    change dir was not moved"; return 1; fi
  return 0
}

test_conflict_stale_baseline() {
  mkdir -p "$1/tl-telar-spec/truth/auth"
  echo "### F-1: Login" > "$1/tl-telar-spec/truth/auth/REQUIREMENTS.md"
  make_change "$1" "2026-07-add-2fa" "none"
  out=$(node "$ARCHIVE" "2026-07-add-2fa" 2>&1); exit_code=$?
  [[ "$exit_code" -eq 1 ]] || { echo "    exit $exit_code, expected 1"; return 1; }
  assert "conflict message" "$out" "changed since this delta's baseline" || return 1
  [[ -d "$1/tl-telar-spec/changes/2026-07-add-2fa" ]] || { echo "    change dir was moved despite conflict"; return 1; }
  if grep -q "F-3" "$1/tl-telar-spec/truth/auth/REQUIREMENTS.md"; then echo "    truth file was modified despite conflict"; return 1; fi
  return 0
}

test_missing_change_dir() {
  out=$(node "$ARCHIVE" "does-not-exist" 2>&1); exit_code=$?
  [[ "$exit_code" -eq 1 ]] || { echo "    exit $exit_code, expected 1"; return 1; }
  assert "not-found message" "$out" 'change directory not found' || return 1
}

test_no_delta_files() {
  mkdir -p "$1/tl-telar-spec/changes/2026-07-empty"
  out=$(node "$ARCHIVE" "2026-07-empty" 2>&1); exit_code=$?
  [[ "$exit_code" -eq 1 ]] || { echo "    exit $exit_code, expected 1"; return 1; }
  assert "no-delta message" "$out" 'no delta files found' || return 1
}

run_test "happy path — first delta for a domain"       test_happy_path_first_delta
run_test "conflict — stale baseline-hash"                test_conflict_stale_baseline
run_test "missing change directory → exit 1"             test_missing_change_dir
run_test "no delta files → exit 1"                        test_no_delta_files

echo ""
echo "─────────────────────────────────────────"
echo "Smoke tests: ${pass_count} passed, ${fail_count} failed"
if [[ "$fail_count" -gt 0 ]]; then
  echo "Failed scenarios:"
  for n in "${failures[@]}"; do echo "  • $n"; done
  exit 1
fi
exit 0
