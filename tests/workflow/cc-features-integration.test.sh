#!/usr/bin/env bash
# End-to-end integration: config (cc_features) -> resolver decision -> scheduler
# behavior. Proves the FULL gating chain the orchestrator follows at runtime:
#   1. resolver reads worktree_isolation config + capability -> decision
#   2. orchestrator passes --isolate to the scheduler IFF decision == active
#   3. scheduler admits overlapping-scope WUs concurrently only under --isolate
# Exercises enabled {true,false} × capability {true,false} for BOTH features,
# and asserts the two features gate INDEPENDENTLY (cross combinations).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RESOLVER="$ROOT/scripts/tl-telar-cc-features.sh"
SCHED="$ROOT/scripts/tl-telar-wu-scheduler.js"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Two PENDING WUs that OVERLAP on shared.ts (serialized without isolation).
printf '## Work Units\n### WU-001:\n- file_scope:\n  - shared.ts\n### WU-002:\n- file_scope:\n  - shared.ts\n' > "$TMP/plan.md"
printf '## Work Unit Status\n| WU | Status |\n|----|--------|\n| WU-001 | PENDING |\n| WU-002 | PENDING |\n' > "$TMP/state.md"

pass=0; fail=0
check() { if [[ "$2" == "$3" ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "  FAIL: $1 — expected '$2' got '$3'"; fi; }

write_cfg() { # <dw_enabled> <wt_enabled>
  mkdir -p "$TMP/.tl-telar"
  cat > "$TMP/.tl-telar/external-tools.yaml" <<EOF
cc_features:
  dynamic_workflows:
    enabled: $1
    on_unavailable: "warn_and_proceed"
  worktree_isolation:
    enabled: $2
    on_unavailable: "warn_and_proceed"
EOF
}
CFG="$TMP/.tl-telar/external-tools.yaml"

# Simulate the orchestrator: resolve worktree decision, then run scheduler the way
# Step 6 would. Echoes "<dw_decision> <wt_decision> <ready_count>".
run_scenario() { # <dw_enabled> <wt_enabled> <wf_cap> <wt_cap>
  write_cfg "$1" "$2"
  local dw wt ready
  dw=$(bash "$RESOLVER" decision dynamic_workflows --config "$CFG" --workflow-available "$3" --worktree-supported "$4" || true)
  wt=$(bash "$RESOLVER" decision worktree_isolation --config "$CFG" --workflow-available "$3" --worktree-supported "$4" || true)
  if [[ "$wt" == "active" ]]; then
    ready=$(node "$SCHED" --isolate "$TMP/plan.md" "$TMP/state.md" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).ready.length))')
  else
    ready=$(node "$SCHED" "$TMP/plan.md" "$TMP/state.md" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).ready.length))')
  fi
  echo "$dw $wt $ready"
}

echo "cc_features integration (config -> resolver -> scheduler):"

# Both ON + both capable -> dw active, wt active, overlapping WUs BOTH ready (2)
check "both on/capable"        "active active 2"     "$(run_scenario true true true true)"
# Both ON but NEITHER capable -> both fallback, scheduler serializes (1 ready)
check "both on/incapable"      "fallback fallback 1" "$(run_scenario true true false false)"
# Both OFF -> both fallback regardless of capability, serialized (1)
check "both off/capable"       "fallback fallback 1" "$(run_scenario false false true true)"
# CROSS: dw ON+capable, wt OFF -> dw active, wt fallback, serialized (1)
check "cross dw-on wt-off"     "active fallback 1"   "$(run_scenario true false true true)"
# CROSS: dw OFF, wt ON+capable -> dw fallback, wt active, concurrent (2)
check "cross dw-off wt-on"     "fallback active 2"   "$(run_scenario false true true true)"
# CROSS: both ON, only wt capable -> dw fallback (no wf tool), wt active (2)
check "cross wt-cap-only"      "fallback active 2"   "$(run_scenario true true false true)"
# CROSS: both ON, only wf capable -> dw active, wt fallback, serialized (1)
check "cross wf-cap-only"      "active fallback 1"   "$(run_scenario true true true false)"

echo "cc_features integration: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
