#!/usr/bin/env bash
# USD cost estimator for external adapter invocations.
# Reads input/output token counts from CLI args, returns JSON with estimated USD.
#
# Adapted from dsifry/metaswarm (MIT, (c) 2026 Dave Sifry). See THIRD_PARTY_NOTICES.md.
#
# Pricing table is approximate (~15-30% variance). Update
# as model pricing changes. Pricing is per 1M tokens.

set -euo pipefail

MODEL=""
INPUT_TOKENS=0
OUTPUT_TOKENS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --input-tokens) INPUT_TOKENS="$2"; shift 2 ;;
    --output-tokens) OUTPUT_TOKENS="$2"; shift 2 ;;
    *) shift ;;
  esac
done

case "$MODEL" in
  "gpt-5.3-codex"|"codex")
    INPUT_USD_PER_M="1.50"
    OUTPUT_USD_PER_M="6.00"
    ;;
  "pro"|"gemini-pro"|"gemini-2-pro")
    INPUT_USD_PER_M="1.25"
    OUTPUT_USD_PER_M="5.00"
    ;;
  *)
    INPUT_USD_PER_M="0.00"
    OUTPUT_USD_PER_M="0.00"
    ;;
esac

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
  "estimated_usd": $USD
}
EOF
