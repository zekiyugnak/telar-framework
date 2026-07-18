#!/usr/bin/env bash
# Tests for `parse-verdict` — especially Strategy 0 (unwrap agent-stream envelopes).
# Regression: a live codex review returned a correct {verdict:FAIL} nested inside a
# JSONL agent_message.text string, but parse-verdict reported UNKNOWN because the
# brace-scanner can't see a verdict key buried in an escaped string. Strategy 0
# unwraps codex `.item.text` and claude `.result` first.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DISP="$ROOT/scripts/tl-telar-external-tools.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
check() { if [[ "$2" == "$3" ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "  FAIL: $1 — expected '$2' got '$3'"; fi; }

echo "parse-verdict:"

# --- codex-style: verdict nested in JSONL agent_message.text ---
inner=$(jq -nc '{verdict:"FAIL", issues:[{summary:"divide-by-zero hidden"}]}')
line=$(jq -nc --arg t "$inner" '{type:"item.completed", item:{type:"agent_message", text:$t}}')
jq -nc --arg rl "$line" '{raw_log:$rl}' > "$TMP/codex.json"
OUT=$(bash "$DISP" parse-verdict "$TMP/codex.json")
check "codex verdict"        FAIL "$(echo "$OUT" | jq -r '.verdict')"
check "codex issues"         1    "$(echo "$OUT" | jq -r '.issues | length')"

# --- claude -p style: verdict nested in .result ---
inner2=$(jq -nc '{verdict:"PASS", issues:[]}')
res=$(jq -nc --arg t "$inner2" '{type:"result", result:$t}')
jq -nc --arg rl "$res" '{raw_log:$rl}' > "$TMP/claude.json"
OUT=$(bash "$DISP" parse-verdict "$TMP/claude.json")
check "claude verdict"       PASS "$(echo "$OUT" | jq -r '.verdict')"

# --- already-plain verdict JSON (compat unwraps to .result text) still works ---
jq -nc '{raw_log: ({verdict:"FAIL", issues:[]} | tostring)}' > "$TMP/plain.json"
OUT=$(bash "$DISP" parse-verdict "$TMP/plain.json")
check "plain verdict"        FAIL "$(echo "$OUT" | jq -r '.verdict')"

# --- empty raw_log -> UNKNOWN ---
jq -nc '{raw_log:""}' > "$TMP/empty.json"
OUT=$(bash "$DISP" parse-verdict "$TMP/empty.json")
check "empty -> UNKNOWN"     UNKNOWN "$(echo "$OUT" | jq -r '.verdict')"

echo "parse-verdict: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
