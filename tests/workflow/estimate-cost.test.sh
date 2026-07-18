#!/usr/bin/env bash
# Tests for scripts/estimate-cost.sh — the USD estimator behind the budget ledger.
# Focus: the fail-closed contract (unknown/undeclared pricing must NOT be $0),
# config-provided pricing overrides, and the built-in model table (incl. gpt-5.6 / kimi-k3).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/scripts/estimate-cost.sh"

pass=0; fail=0
check() { # <desc> <expected> <actual>
  if [[ "$2" == "$3" ]]; then pass=$((pass+1));
  else fail=$((fail+1)); echo "  FAIL: $1 — expected '$2' got '$3'"; fi
}

# Run estimator; capture JSON (stdout) and exit code separately.
run() { # <args...>  -> sets OUT and RC
  set +e
  OUT=$(bash "$SCRIPT" "$@" 2>/dev/null)
  RC=$?
  set -e
}
field() { echo "$OUT" | jq -r "$1"; }

echo "estimate-cost.sh:"

# ---- built-in table: known models price correctly, exit 0, pricing_known=true ----
run --model codex --input-tokens 1000000 --output-tokens 1000000
check "codex exit"            0       "$RC"
check "codex pricing_known"   true    "$(field '.pricing_known')"
check "codex usd (1.50+6.00)" 7.5000  "$(field '.estimated_usd')"

run --model gpt-5.6-codex --input-tokens 1000000 --output-tokens 0
check "gpt-5.6-codex known"   true    "$(field '.pricing_known')"
check "gpt-5.6-codex usd"     1.5000  "$(field '.estimated_usd')"

run --model gpt-5.6-sol --input-tokens 1000000 --output-tokens 1000000
check "sol usd (5+30)"        35.0000 "$(field '.estimated_usd')"

run --model kimi-k3 --input-tokens 1000000 --output-tokens 1000000
check "kimi-k3 usd (3+15)"    18.0000 "$(field '.estimated_usd')"

# ---- THE FIX: unknown model with no override → fail-closed, NOT $0 ----
run --model some-brand-new-model --input-tokens 1000000 --output-tokens 1000000
check "unknown exit 3"        3       "$RC"
check "unknown pricing_known" false   "$(field '.pricing_known')"
check "unknown usd null"      null    "$(field '.estimated_usd')"

# ---- config pricing override wins over table / covers unknown models ----
run --model some-brand-new-model --input-tokens 1000000 --output-tokens 1000000 \
    --input-usd-per-m 2.00 --output-usd-per-m 10.00
check "override exit"         0       "$RC"
check "override known"        true    "$(field '.pricing_known')"
check "override usd (2+10)"   12.0000 "$(field '.estimated_usd')"

# override takes precedence even for a table-known model
run --model codex --input-tokens 1000000 --output-tokens 0 --input-usd-per-m 9.00 --output-usd-per-m 9.00
check "override beats table"  9.0000  "$(field '.estimated_usd')"

# ---- garbage/half-specified override is NOT trusted → falls through ----
# non-numeric override on an unknown model → fail-closed
run --model unknown-x --input-tokens 1000000 --output-tokens 0 --input-usd-per-m abc --output-usd-per-m 5.00
check "garbage override fails" 3      "$RC"
# half-specified override (only input) on unknown model → fail-closed
run --model unknown-y --input-tokens 1000000 --output-tokens 0 --input-usd-per-m 5.00
check "half override fails"    3      "$RC"
# half-specified override on a TABLE-known model → falls back to table (not fail)
run --model codex --input-tokens 1000000 --output-tokens 0 --input-usd-per-m 5.00
check "half override->table"   1.5000 "$(field '.estimated_usd')"

# ---- non-integer token counts are sanitised to 0, not crash ----
run --model codex --input-tokens notanumber --output-tokens 1000000
check "bad tokens exit"        0      "$RC"
check "bad tokens sanitised"   6.0000 "$(field '.estimated_usd')"  # input→0, output 1M*6.00

echo "estimate-cost.sh: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
