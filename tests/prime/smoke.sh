#!/usr/bin/env bash
# Smoke tests for scripts/tl-telar-prime.sh.
#
# Each scenario sets up an isolated sandbox via mktemp, exercises one prime
# behaviour, asserts the exit code and key output strings, then tears down.
# Failures aggregate; the script exits non-zero at the end if any scenario
# failed, with a per-scenario PASS/FAIL summary.
#
# Run from the plugin repo root:
#   bash tests/prime/smoke.sh
#
# Add new scenarios by appending a new `run_test 'name' 'function'` invocation
# at the bottom of this file.

set -uo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PRIME="$PLUGIN_ROOT/scripts/tl-telar-prime.sh"

# A valid record we reuse across happy-path scenarios.
VALID_RECORD='{"id":"fact-001","type":"pattern","fact":"Use FlatList for >20 items","recommendation":"Always prefer virtualization","confidence":"high","provenance":[],"tags":{"platform":"both","framework":"react-native","category":"performance","topic":["lists"]},"affectedFiles":["src/screens/Home.tsx"],"createdAt":"2026-05-01T00:00:00Z","updatedAt":"2026-05-01T00:00:00Z","usageCount":0,"helpfulCount":0,"outdatedReports":0}'
JSONL_HEADER='# Schema: patterns.jsonl - Reusable best practices
# Each line is a JSON object per the schema in .tl-telar/knowledge/README.md'

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
  sandbox=$(mktemp -d -t tl-telar-prime-smoke.XXXXXX)
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
  rm -rf "$sandbox"
}

# --- Scenario 1: empty KB ---
test_empty_kb() {
  out=$(bash "$PRIME" --json); exit_code=$?
  [[ "$exit_code" -eq 0 ]] || { echo "    exit $exit_code, expected 0"; return 1; }
  assert "no-KB message" "$out" 'no knowledge base' || return 1
  assert "facts_loaded zero" "$out" '"facts_loaded":[[:space:]]*0' || return 1
}

# --- Scenario 2: malformed JSONL (fail-loud) ---
test_malformed_jsonl() {
  local kb="$1/.tl-telar/knowledge"
  mkdir -p "$kb"
  printf '%s\n%s\n%s\n' "$JSONL_HEADER" "$VALID_RECORD" "{not json" > "$kb/patterns.jsonl"
  out=$(bash "$PRIME" --json); exit_code=$?
  [[ "$exit_code" -eq 1 ]] || { echo "    exit $exit_code, expected 1"; return 1; }
  assert "KB_INVALID_JSONL error" "$out" 'KB_INVALID_JSONL' || return 1
  assert "file:line cited" "$out" 'patterns\.jsonl:' || return 1
}

# --- Scenario 3: schema-invalid record (missing tags.framework) ---
test_schema_invalid() {
  local kb="$1/.tl-telar/knowledge"
  mkdir -p "$kb"
  printf '%s\n%s\n%s\n' \
    "$JSONL_HEADER" \
    "$VALID_RECORD" \
    '{"id":"fact-bad","type":"pattern","fact":"x","tags":{"platform":"ios","category":"build"}}' \
    > "$kb/patterns.jsonl"
  out=$(bash "$PRIME" --json); exit_code=$?
  [[ "$exit_code" -eq 1 ]] || { echo "    exit $exit_code, expected 1"; return 1; }
  assert "KB_SCHEMA_INVALID error" "$out" 'KB_SCHEMA_INVALID' || return 1
  assert "framework field cited" "$out" 'tags\.framework' || return 1
}

# --- Scenario 4: latest-id reduction (newer updatedAt wins) ---
test_latest_id_reduction() {
  local kb="$1/.tl-telar/knowledge"
  mkdir -p "$kb"
  local old='{"id":"fact-001","type":"pattern","fact":"old text","tags":{"platform":"both","framework":"any","category":"performance"},"updatedAt":"2026-01-01T00:00:00Z"}'
  local new='{"id":"fact-001","type":"pattern","fact":"new text","tags":{"platform":"both","framework":"any","category":"performance"},"updatedAt":"2026-06-01T00:00:00Z"}'
  printf '%s\n%s\n%s\n' "$JSONL_HEADER" "$old" "$new" > "$kb/patterns.jsonl"
  out=$(bash "$PRIME" --json); exit_code=$?
  [[ "$exit_code" -eq 0 ]] || { echo "    exit $exit_code, expected 0"; return 1; }
  assert "facts_loaded is 1 (deduped)" "$out" '"facts_loaded":[[:space:]]*1' || return 1
  assert "new text wins" "$out" 'new text' || return 1
  # old text must NOT appear
  if printf '%s' "$out" | grep -q 'old text'; then
    echo "    old text leaked through reduction"; return 1
  fi
}

# --- Scenario 5: bucket mapping (security → MUST FOLLOW always) ---
test_bucket_mapping_security() {
  local kb="$1/.tl-telar/knowledge"
  mkdir -p "$kb"
  printf '%s\n%s\n' "$JSONL_HEADER" \
    '{"id":"sec-001","type":"security","fact":"Cert pinning required","tags":{"platform":"both","framework":"any","category":"security"}}' \
    > "$kb/security.jsonl"
  out=$(bash "$PRIME" --json); exit_code=$?
  [[ "$exit_code" -eq 0 ]] || { echo "    exit $exit_code (expected 0)"; return 1; }
  # The primer pretty-prints; use jq to inspect the contract regardless of formatting.
  if ! printf '%s' "$out" | jq -e '.must_follow | map(.id) | index("sec-001")' >/dev/null 2>&1; then
    echo "    sec-001 not in must_follow bucket"; return 1
  fi
}

# --- Scenario 6: zero match graceful (no exit 2 from arithmetic crash) ---
test_zero_match_graceful() {
  local kb="$1/.tl-telar/knowledge"
  mkdir -p "$kb"
  printf '%s\n%s\n' "$JSONL_HEADER" "$VALID_RECORD" > "$kb/patterns.jsonl"
  out=$(bash "$PRIME" --json --keywords "zzznevermatches"); exit_code=$?
  [[ "$exit_code" -eq 0 ]] || { echo "    exit $exit_code (expected 0)"; return 1; }
  assert "facts_loaded zero on no match" "$out" '"facts_loaded":[[:space:]]*0' || return 1
}

# --- Scenario 7: globstar src/**/*.ts matches root AND nested ---
test_globstar_zero_or_more() {
  local kb="$1/.tl-telar/knowledge"
  mkdir -p "$kb"
  local r1='{"id":"r1","type":"pattern","fact":"root file","tags":{"platform":"both","framework":"any","category":"navigation"},"affectedFiles":["src/a.ts"]}'
  local r2='{"id":"r2","type":"pattern","fact":"nested file","tags":{"platform":"both","framework":"any","category":"navigation"},"affectedFiles":["src/lib/x/b.ts"]}'
  local r3='{"id":"r3","type":"pattern","fact":"different ext","tags":{"platform":"both","framework":"any","category":"navigation"},"affectedFiles":["src/c.js"]}'
  printf '%s\n%s\n%s\n%s\n' "$JSONL_HEADER" "$r1" "$r2" "$r3" > "$kb/patterns.jsonl"
  out=$(bash "$PRIME" --json --files 'src/**/*.ts'); exit_code=$?
  [[ "$exit_code" -eq 0 ]] || { echo "    exit $exit_code (expected 0)"; return 1; }
  assert "facts_loaded is 2" "$out" '"facts_loaded":[[:space:]]*2' || return 1
  printf '%s' "$out" | grep -q 'r1' || { echo "    r1 (root) missed"; return 1; }
  printf '%s' "$out" | grep -q 'r2' || { echo "    r2 (nested) missed"; return 1; }
  if printf '%s' "$out" | grep -q '"id":"r3"'; then
    echo "    r3 (.js) leaked through .ts filter"; return 1
  fi
}

# --- Scenario 8: trailing ** (src/** matches both root and nested) ---
test_globstar_trailing() {
  local kb="$1/.tl-telar/knowledge"
  mkdir -p "$kb"
  local r1='{"id":"r1","type":"pattern","fact":"root","tags":{"platform":"both","framework":"any","category":"navigation"},"affectedFiles":["src/a.ts"]}'
  local r2='{"id":"r2","type":"pattern","fact":"nested","tags":{"platform":"both","framework":"any","category":"navigation"},"affectedFiles":["src/lib/x/y/b.ts"]}'
  printf '%s\n%s\n%s\n' "$JSONL_HEADER" "$r1" "$r2" > "$kb/patterns.jsonl"
  out=$(bash "$PRIME" --json --files 'src/**'); exit_code=$?
  [[ "$exit_code" -eq 0 ]] || { echo "    exit $exit_code (expected 0)"; return 1; }
  assert "facts_loaded is 2 with trailing **" "$out" '"facts_loaded":[[:space:]]*2' || return 1
}

# --- Scenario 9: missing CLI arg → usage error ---
test_missing_cli_arg() {
  out=$(bash "$PRIME" --files 2>&1); exit_code=$?
  [[ "$exit_code" -eq 2 ]] || { echo "    exit $exit_code (expected 2)"; return 1; }
  assert "usage error message" "$out" '--files requires a value' || return 1
}

# --- Scenario 10: unknown flag → usage error ---
test_unknown_flag() {
  out=$(bash "$PRIME" --filse 'src/**' 2>&1); exit_code=$?
  [[ "$exit_code" -eq 2 ]] || { echo "    exit $exit_code (expected 2; silent typo would be exit 0)"; return 1; }
  assert "unknown flag error" "$out" 'unknown flag' || return 1
}

# --- Scenario 11: invalid --work-type value → usage error ---
test_invalid_work_type() {
  out=$(bash "$PRIME" --work-type debuggign 2>&1); exit_code=$?
  [[ "$exit_code" -eq 2 ]] || { echo "    exit $exit_code (expected 2)"; return 1; }
  assert "invalid work-type error" "$out" 'invalid --work-type' || return 1
}

# --- Scenario 12: unknown type enum → fail-loud ---
test_invalid_type_enum() {
  local kb="$1/.tl-telar/knowledge"
  mkdir -p "$kb"
  printf '%s\n%s\n' "$JSONL_HEADER" \
    '{"id":"x-001","type":"mystery","fact":"bad type","tags":{"platform":"both","framework":"any","category":"build"}}' \
    > "$kb/patterns.jsonl"
  out=$(bash "$PRIME" --json); exit_code=$?
  [[ "$exit_code" -eq 1 ]] || { echo "    exit $exit_code (expected 1)"; return 1; }
  assert "invalid type cited" "$out" 'invalid type' || return 1
  assert "schema-invalid error" "$out" 'KB_SCHEMA_INVALID' || return 1
}

# --- Scenario 13: non-string fact → fail-loud ---
test_non_string_fact() {
  local kb="$1/.tl-telar/knowledge"
  mkdir -p "$kb"
  printf '%s\n%s\n' "$JSONL_HEADER" \
    '{"id":"x-002","type":"pattern","fact":123,"tags":{"platform":"both","framework":"any","category":"build"}}' \
    > "$kb/patterns.jsonl"
  out=$(bash "$PRIME" --json); exit_code=$?
  [[ "$exit_code" -eq 1 ]] || { echo "    exit $exit_code (expected 1)"; return 1; }
  assert "fact must be string" "$out" 'fact must be a string' || return 1
}

# --- Scenario 14: invalid tags.platform enum → fail-loud ---
test_invalid_platform_enum() {
  local kb="$1/.tl-telar/knowledge"
  mkdir -p "$kb"
  printf '%s\n%s\n' "$JSONL_HEADER" \
    '{"id":"x-003","type":"pattern","fact":"x","tags":{"platform":"web","framework":"any","category":"build"}}' \
    > "$kb/patterns.jsonl"
  out=$(bash "$PRIME" --json); exit_code=$?
  [[ "$exit_code" -eq 1 ]] || { echo "    exit $exit_code (expected 1)"; return 1; }
  assert "invalid platform cited" "$out" 'invalid tags\.platform' || return 1
}

# --- Scenario 15: invalid tags.framework enum → fail-loud ---
test_invalid_framework_enum() {
  local kb="$1/.tl-telar/knowledge"
  mkdir -p "$kb"
  printf '%s\n%s\n' "$JSONL_HEADER" \
    '{"id":"x-004","type":"pattern","fact":"x","tags":{"platform":"both","framework":"angular","category":"build"}}' \
    > "$kb/patterns.jsonl"
  out=$(bash "$PRIME" --json); exit_code=$?
  [[ "$exit_code" -eq 1 ]] || { echo "    exit $exit_code (expected 1)"; return 1; }
  assert "invalid framework cited" "$out" 'invalid tags\.framework' || return 1
}

# --- Scenario 16: invalid tags.category enum → fail-loud ---
test_invalid_category_enum() {
  local kb="$1/.tl-telar/knowledge"
  mkdir -p "$kb"
  printf '%s\n%s\n' "$JSONL_HEADER" \
    '{"id":"x-005","type":"pattern","fact":"x","tags":{"platform":"both","framework":"any","category":"unknown"}}' \
    > "$kb/patterns.jsonl"
  out=$(bash "$PRIME" --json); exit_code=$?
  [[ "$exit_code" -eq 1 ]] || { echo "    exit $exit_code (expected 1)"; return 1; }
  assert "invalid category cited" "$out" 'invalid tags\.category' || return 1
}

# --- Scenario 17: affectedFiles non-array → fail-loud ---
test_affected_files_non_array() {
  local kb="$1/.tl-telar/knowledge"
  mkdir -p "$kb"
  printf '%s\n%s\n' "$JSONL_HEADER" \
    '{"id":"x-006","type":"pattern","fact":"x","tags":{"platform":"both","framework":"any","category":"build"},"affectedFiles":"src/a.ts"}' \
    > "$kb/patterns.jsonl"
  out=$(bash "$PRIME" --json); exit_code=$?
  [[ "$exit_code" -eq 1 ]] || { echo "    exit $exit_code (expected 1)"; return 1; }
  assert "affectedFiles must be array" "$out" 'affectedFiles must be array' || return 1
}

# --- Driver ---
run_test "empty KB → graceful empty"                       test_empty_kb
run_test "malformed JSONL → KB_INVALID_JSONL + file:line"  test_malformed_jsonl
run_test "schema-invalid record → KB_SCHEMA_INVALID"       test_schema_invalid
run_test "latest-id reduction by updatedAt"                test_latest_id_reduction
run_test "bucket mapping: security → MUST FOLLOW"          test_bucket_mapping_security
run_test "zero match → exit 0 facts_loaded 0"              test_zero_match_graceful
run_test "globstar src/**/*.ts root + nested"              test_globstar_zero_or_more
run_test "globstar trailing src/** root + nested"          test_globstar_trailing
run_test "missing CLI arg → exit 2 usage"                  test_missing_cli_arg
run_test "unknown flag → exit 2 usage"                     test_unknown_flag
run_test "invalid --work-type value → exit 2 usage"        test_invalid_work_type
run_test "unknown type enum → KB_SCHEMA_INVALID"           test_invalid_type_enum
run_test "non-string fact → KB_SCHEMA_INVALID"             test_non_string_fact
run_test "invalid tags.platform enum → KB_SCHEMA_INVALID"  test_invalid_platform_enum
run_test "invalid tags.framework enum → KB_SCHEMA_INVALID" test_invalid_framework_enum
run_test "invalid tags.category enum → KB_SCHEMA_INVALID"  test_invalid_category_enum
run_test "affectedFiles non-array → KB_SCHEMA_INVALID"     test_affected_files_non_array

echo ""
echo "─────────────────────────────────────────"
echo "Smoke tests: ${pass_count} passed, ${fail_count} failed"
if [[ "$fail_count" -gt 0 ]]; then
  echo "Failed scenarios:"
  for n in "${failures[@]}"; do echo "  • $n"; done
  exit 1
fi
exit 0
