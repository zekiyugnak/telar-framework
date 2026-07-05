#!/usr/bin/env bash
# APK/IPA size check invoked by .tl-telar-thresholds.json enforcement.size_command.
# MVP stub — see scripts/perf-smoke.sh for the strict-mode contract.

set -euo pipefail

THRESHOLDS=".tl-telar-thresholds.json"
if [[ ! -f "$THRESHOLDS" ]]; then
  echo "size-check: no $THRESHOLDS — advisory pass"
  exit 0
fi

STRICT=$(node -e "try { process.stdout.write(String(JSON.parse(require('fs').readFileSync('$THRESHOLDS','utf8')).enforcement.size_strict)) } catch { process.stdout.write('false') }")

if [[ "$STRICT" != "true" ]]; then
  echo "size-check: size_strict=false (advisory only) — pass"
  exit 0
fi

# Strict mode: need a real build artifact to measure. The orchestrator
# typically runs this after a build step; locate the artifact in the
# project's build/ or android/app/build/outputs/apk/ or ios/build/ tree.
APK=$(find android/app/build/outputs/apk -name "*.apk" 2>/dev/null | head -1 || true)
IPA=$(find ios/build -name "*.ipa" 2>/dev/null | head -1 || true)

failed=0
if [[ -n "$APK" ]]; then
  SIZE_MB=$(( $(stat -f%z "$APK" 2>/dev/null || stat -c%s "$APK") / 1048576 ))
  MAX=$(node -e "process.stdout.write(String(JSON.parse(require('fs').readFileSync('$THRESHOLDS','utf8')).size.max_apk_mb || 50))")
  if (( SIZE_MB > MAX )); then
    echo "size-check: APK $APK is ${SIZE_MB}MB > ${MAX}MB threshold"
    failed=1
  fi
fi
if [[ -n "$IPA" ]]; then
  SIZE_MB=$(( $(stat -f%z "$IPA" 2>/dev/null || stat -c%s "$IPA") / 1048576 ))
  MAX=$(node -e "process.stdout.write(String(JSON.parse(require('fs').readFileSync('$THRESHOLDS','utf8')).size.max_ipa_mb || 60))")
  if (( SIZE_MB > MAX )); then
    echo "size-check: IPA $IPA is ${SIZE_MB}MB > ${MAX}MB threshold"
    failed=1
  fi
fi

if [[ -z "$APK" && -z "$IPA" ]]; then
  echo "size-check: no build artifacts found — run a build first"
  exit 1
fi

exit "$failed"
