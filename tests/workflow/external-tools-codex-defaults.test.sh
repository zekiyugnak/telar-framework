#!/usr/bin/env bash
# Locks (and displays) the SHIPPED codex-host default roster: reads the real template
# resources/templates/orchestration/external-tools.yaml, resolves every role for host=codex,
# prints the model+exec+tool+effort roster, and asserts the defaults. Guards against drift
# in profiles.codex / models_registry. No network.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DISP="$ROOT/scripts/tl-telar-external-tools.sh"
TEMPLATE="$ROOT/resources/templates/orchestration/external-tools.yaml"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.tl-telar"
cat "$TEMPLATE" > "$TMP/.tl-telar/external-tools.yaml"   # test the ACTUAL shipped defaults

pass=0; fail=0
check() { if [[ "$2" == "$3" ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "  FAIL: $1 — expected '$2' got '$3'"; fi; }
RR() { OUT=$(CLAUDE_PROJECT_DIR="$TMP" bash "$DISP" resolve-role --host codex "$1" 2>/dev/null); }
f() { echo "$OUT" | jq -r "$1"; }

echo "codex-host default roster (from shipped template):"
for role in architect moderator developer reviewer tester; do
  RR "$role"
  echo "$OUT" | jq -r '
    "  " + (.role|.[0:9]) + "\t" +
    (.models | map(.model + " [" + .exec + (if .tool then "/"+.tool else "" end) + ", " + (.effort//"?") + "]") | join(", ")) +
    (if (.escalation|length)>0 then "   esc→" + (.escalation|map(.model+"("+.effort+")")|join(",")) else "" end)'
done

echo "  --- assertions ---"
RR architect
check "architect model"  gpt-5.6-sol "$(f '.models[0].model')"
check "architect exec"   native      "$(f '.models[0].exec')"
check "architect effort" xhigh       "$(f '.models[0].effort')"

RR moderator
check "moderator model"  gpt-5.6-sol "$(f '.models[0].model')"
check "moderator exec"   native      "$(f '.models[0].exec')"
check "moderator effort" high        "$(f '.models[0].effort')"

RR developer
check "developer model"     gpt-5.6-terra "$(f '.models[0].model')"
check "developer exec"      native        "$(f '.models[0].exec')"
check "developer effort"    high          "$(f '.models[0].effort')"
check "developer escalation" gpt-5.6-sol  "$(f '.escalation[0].model')"

RR reviewer
check "reviewer[0] model"  claude-opus-4-8 "$(f '.models[0].model')"
check "reviewer[0] exec"   adapter         "$(f '.models[0].exec')"
check "reviewer[0] tool"   claude          "$(f '.models[0].tool')"
check "reviewer[0] effort" xhigh           "$(f '.models[0].effort')"
check "reviewer[1] model"  gpt-5.6-sol     "$(f '.models[1].model')"
check "reviewer[1] exec"   native          "$(f '.models[1].exec')"
check "reviewer[1] effort" xhigh           "$(f '.models[1].effort')"

RR tester
check "tester model"  gpt-5.6-terra "$(f '.models[0].model')"
check "tester exec"   native        "$(f '.models[0].exec')"
check "tester effort" high          "$(f '.models[0].effort')"

echo "  $pass passed, $fail failed"
[[ "$fail" -eq 0 ]] || exit 1
