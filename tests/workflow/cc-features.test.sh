#!/usr/bin/env bash
# Full-matrix test for scripts/tl-telar-cc-features.sh (cc_features gating resolver).
# Covers enabled {true,false} × capability {true,false,unknown} × on_unavailable
# {warn_and_proceed,block}, plus cross combinations where the two features resolve
# independently, plus the no-config-file default.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/scripts/tl-telar-cc-features.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
check() { # <desc> <expected> <actual>
  if [[ "$2" == "$3" ]]; then pass=$((pass+1));
  else fail=$((fail+1)); echo "  FAIL: $1 — expected '$2' got '$3'"; fi
}

# Write a cc_features config with the given enabled/on_unavailable per feature.
write_cfg() { # <dw_enabled> <dw_onunavail> <wt_enabled> <wt_onunavail>
  mkdir -p "$TMP/.tl-telar"
  cat > "$TMP/.tl-telar/external-tools.yaml" <<EOF
cc_features:
  dynamic_workflows:
    enabled: $1
    on_unavailable: "$2"
  worktree_isolation:
    enabled: $3
    on_unavailable: "$4"
EOF
}

CFG="$TMP/.tl-telar/external-tools.yaml"
D() { # decision for a feature: <feature> <workflow_avail> <worktree_supp>
  bash "$SCRIPT" decision "$1" --config "$CFG" --workflow-available "$2" --worktree-supported "$3" || true
}

echo "cc_features resolver matrix:"

# ---- dynamic_workflows: enabled=true × capability ----
write_cfg true warn_and_proceed true warn_and_proceed
check "dw enabled+cap=true"          active   "$(D dynamic_workflows true  false)"
check "dw enabled+cap=false"         fallback "$(D dynamic_workflows false false)"
check "dw enabled+cap=unknown"       fallback "$(D dynamic_workflows unknown false)"   # fail-closed
check "wt enabled+cap=true"          active   "$(D worktree_isolation false true)"
check "wt enabled+cap=false"         fallback "$(D worktree_isolation false false)"
check "wt enabled+cap=unknown"       fallback "$(D worktree_isolation false unknown)"  # fail-closed

# ---- enabled=false overrides capability (disabled beats capable) ----
write_cfg false warn_and_proceed false warn_and_proceed
check "dw disabled+cap=true"         fallback "$(D dynamic_workflows true  true)"
check "wt disabled+cap=true"         fallback "$(D worktree_isolation true true)"

# ---- on_unavailable=block: enabled + capability missing -> blocked ----
write_cfg true block true block
check "dw block+cap=false"           blocked  "$(D dynamic_workflows false false)"
check "wt block+cap=false"           blocked  "$(D worktree_isolation false false)"
check "dw block+cap=true"            active   "$(D dynamic_workflows true  false)"      # capable => still active

# ---- CROSS: features resolve INDEPENDENTLY ----
# dw enabled+capable (active) while wt disabled (fallback)
write_cfg true warn_and_proceed false warn_and_proceed
check "cross dw active"              active   "$(D dynamic_workflows true false)"
check "cross wt fallback(disabled)"  fallback "$(D worktree_isolation true true)"
# dw disabled (fallback) while wt enabled+capable (active)
write_cfg false warn_and_proceed true warn_and_proceed
check "cross dw fallback(disabled)"  fallback "$(D dynamic_workflows true true)"
check "cross wt active"              active   "$(D worktree_isolation true true)"
# dw block+missing (blocked) while wt warn+missing (fallback) — mixed policies
write_cfg true block true warn_and_proceed
check "cross dw blocked"             blocked  "$(D dynamic_workflows false false)"
check "cross wt fallback(warn)"      fallback "$(D worktree_isolation false false)"

# ---- resolve subcommand: exit code 3 when ANY feature blocked ----
write_cfg true block false warn_and_proceed
set +e
bash "$SCRIPT" resolve --config "$CFG" --workflow-available false --worktree-supported false >/dev/null
rc=$?
set -e
check "resolve exit 3 on blocked"    3        "$rc"

write_cfg true warn_and_proceed true warn_and_proceed
set +e
bash "$SCRIPT" resolve --config "$CFG" --workflow-available true --worktree-supported true >/dev/null
rc=$?
set -e
check "resolve exit 0 no block"      0        "$rc"

# ---- no config file: default enabled=true, capability still gates ----
NOCFG="$TMP/does-not-exist.yaml"
check "no-cfg default+cap=true"      active   "$(bash "$SCRIPT" decision dynamic_workflows --config "$NOCFG" --workflow-available true  --worktree-supported false || true)"
check "no-cfg default+cap=false"     fallback "$(bash "$SCRIPT" decision dynamic_workflows --config "$NOCFG" --workflow-available false --worktree-supported false || true)"

echo "cc_features resolver: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
