#!/usr/bin/env bash
# USD cost estimator for external adapter invocations.
# Reads input/output token counts from CLI args, returns JSON with estimated USD.
#
# Adapted from dsifry/metaswarm (MIT, (c) 2026 Dave Sifry). See THIRD_PARTY_NOTICES.md.
#
# Pricing precedence (per 1M tokens):
#   1. Explicit --input-usd-per-m / --output-usd-per-m overrides. These come from
#      external-tools.yaml `adapters.<tool>.pricing` and are MODEL-AGNOSTIC (keyed
#      by adapter), so accounting stays correct even when an adapter runs a model
#      string the built-in table has never heard of (e.g. codex running gpt-5.6).
#   2. Built-in model table below (approximate, ~15-30% variance; verify at source).
#   3. FAIL-CLOSED. An unknown/undeclared model NO LONGER returns $0 — that would
#      silently bypass the budget circuit breaker. It returns
#      estimated_usd:null, pricing_known:false and exits 3 so the dispatcher can
#      record a conservative cost instead of undercounting the ledger.

set -euo pipefail

MODEL=""
INPUT_TOKENS=0
OUTPUT_TOKENS=0
INPUT_OVERRIDE=""
OUTPUT_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --input-tokens) INPUT_TOKENS="$2"; shift 2 ;;
    --output-tokens) OUTPUT_TOKENS="$2"; shift 2 ;;
    --input-usd-per-m) INPUT_OVERRIDE="$2"; shift 2 ;;
    --output-usd-per-m) OUTPUT_OVERRIDE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

is_num() { [[ "$1" =~ ^[0-9]+(\.[0-9]+)?$ ]]; }

# Sanitise token counts (they arrive via jq of an adapter envelope; a non-integer
# would break the Node arithmetic below). Default to 0 on anything unexpected.
[[ "$INPUT_TOKENS"  =~ ^[0-9]+$ ]] || INPUT_TOKENS=0
[[ "$OUTPUT_TOKENS" =~ ^[0-9]+$ ]] || OUTPUT_TOKENS=0

INPUT_USD_PER_M=""
OUTPUT_USD_PER_M=""

# Precedence 1: explicit per-adapter config pricing overrides. Both must be
# present and numeric; garbage or half-specified pricing falls through to the
# table / fail-closed rather than being trusted.
if [[ -n "$INPUT_OVERRIDE" && "$INPUT_OVERRIDE" != "null" \
   && -n "$OUTPUT_OVERRIDE" && "$OUTPUT_OVERRIDE" != "null" ]] \
   && is_num "$INPUT_OVERRIDE" && is_num "$OUTPUT_OVERRIDE"; then
  INPUT_USD_PER_M="$INPUT_OVERRIDE"
  OUTPUT_USD_PER_M="$OUTPUT_OVERRIDE"
else
  # Precedence 2: built-in model table.
  case "$MODEL" in
    "gpt-5.3-codex"|"gpt-5.6-codex"|"codex")
      INPUT_USD_PER_M="1.50";  OUTPUT_USD_PER_M="6.00"  ;;
    "gpt-5.6-sol"|"gpt-5.6"|"sol")
      INPUT_USD_PER_M="5.00";  OUTPUT_USD_PER_M="30.00" ;;
    "pro"|"gemini-pro"|"gemini-2-pro")
      INPUT_USD_PER_M="1.25";  OUTPUT_USD_PER_M="5.00"  ;;
    "kimi-k3"|"kimi")
      INPUT_USD_PER_M="3.00";  OUTPUT_USD_PER_M="15.00" ;;
    *) : ;;  # unknown → stays empty → fail-closed below
  esac
fi

# Precedence 3: FAIL-CLOSED on unknown/undeclared pricing.
if ! is_num "$INPUT_USD_PER_M" || ! is_num "$OUTPUT_USD_PER_M"; then
  cat <<EOF
{
  "model": "$MODEL",
  "input_tokens": $INPUT_TOKENS,
  "output_tokens": $OUTPUT_TOKENS,
  "estimated_usd": null,
  "pricing_known": false
}
EOF
  exit 3
fi

USD=$(node -e "
const input = $INPUT_TOKENS / 1_000_000 * $INPUT_USD_PER_M;
const output = $OUTPUT_TOKENS / 1_000_000 * $OUTPUT_USD_PER_M;
process.stdout.write((input + output).toFixed(4));
")

cat <<EOF
{
  "model": "$MODEL",
  "input_tokens": $INPUT_TOKENS,
  "output_tokens": $OUTPUT_TOKENS,
  "estimated_usd": $USD,
  "pricing_known": true
}
EOF
