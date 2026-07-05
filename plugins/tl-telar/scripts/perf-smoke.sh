#!/usr/bin/env bash
# Performance smoke test invoked by .tl-telar-thresholds.json enforcement.perf_command.
#
# MVP behavior: exit 0 unconditionally unless `enforcement.perf_strict: true`
# is set in .tl-telar-thresholds.json AND a real perf measurement is wired
# up by the project owner. This stub is the conservative default — better
# to skip the gate than false-fail.
#
# To make this strict for a project:
# 1. Replace this script body with a real perf measurement (e.g., Maestro
#    flow timing, Detox launch timing, custom OTel span aggregation).
# 2. Set `enforcement.perf_strict: true` in .tl-telar-thresholds.json.
# 3. Exit non-zero when measured perf misses the budget in
#    `performance.min_fps` or `performance.max_cold_start_ms`.

set -euo pipefail

THRESHOLDS=".tl-telar-thresholds.json"
if [[ ! -f "$THRESHOLDS" ]]; then
  echo "perf-smoke: no $THRESHOLDS — advisory pass"
  exit 0
fi

STRICT=$(node -e "try { process.stdout.write(String(JSON.parse(require('fs').readFileSync('$THRESHOLDS','utf8')).enforcement.perf_strict)) } catch { process.stdout.write('false') }")

if [[ "$STRICT" != "true" ]]; then
  echo "perf-smoke: perf_strict=false (advisory only) — pass"
  exit 0
fi

# perf_strict=true but this stub has no real measurement. Surface the gap
# loudly instead of false-passing.
echo "perf-smoke: perf_strict=true but no real measurement wired up in scripts/perf-smoke.sh"
echo "perf-smoke: replace the stub body with project-specific perf measurement."
exit 1
