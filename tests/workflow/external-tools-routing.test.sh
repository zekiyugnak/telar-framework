#!/usr/bin/env bash
# Tests for config-driven routing (WS1) + routing.roles resolver (WS2) in
# scripts/tl-telar-external-tools.sh. Points CLAUDE_PROJECT_DIR at a temp config;
# never executes real external adapters (all disabled / decisions return before invoke).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DISP="$ROOT/scripts/tl-telar-external-tools.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.tl-telar"
CFG="$TMP/.tl-telar/external-tools.yaml"

pass=0; fail=0
check() { # <desc> <expected> <actual>
  if [[ "$2" == "$3" ]]; then pass=$((pass+1));
  else fail=$((fail+1)); echo "  FAIL: $1 — expected '$2' got '$3'"; fi
}

# A well-formed config: two disabled adapters + a full routing block.
write_good_cfg() {
  cat > "$CFG" <<'EOF'
adapters:
  codex:
    enabled: false
    auth_env_var: "OPENAI_API_KEY"
  gemini:
    enabled: false
    auth_env_var: "GEMINI_API_KEY"
routing:
  roles:
    architect:  { model: "claude-fable-5",  panel: ["gpt-5.6-sol"] }
    developer:  { model: "claude-sonnet-5", escalation: ["claude-opus-4-8"], options: ["kimi-k3"] }
    reviewer:   { models: ["claude-opus-4-8", "gpt-5.6-sol"] }
    tester:     { model: "claude-sonnet-5" }
  models_registry:
    claude-fable-5:  { exec: "claude",  tier: "fable",  effort: "high" }
    claude-opus-4-8: { exec: "claude",  tier: "opus",   effort: "high" }
    claude-sonnet-5: { exec: "claude",  tier: "sonnet", effort: "high" }
    gpt-5.6-sol:     { exec: "adapter", tool: "codex",  effort: "xhigh" }
    kimi-k3:         { exec: "adapter", tool: "kimi",   effort: "max" }
  escalation_order: ["codex", "gemini", "claude"]
EOF
}

R() { set +e; OUT=$(CLAUDE_PROJECT_DIR="$TMP" bash "$DISP" resolve-role "$1" 2>/dev/null); RC=$?; set -e; }
D() { set +e; OUT=$(CLAUDE_PROJECT_DIR="$TMP" bash "$DISP" dispatch "$@" 2>/dev/null); RC=$?; set -e; }
f() { echo "$OUT" | jq -r "$1"; }

echo "external-tools routing + resolve-role:"

# ---- WS2: resolve-role ----
write_good_cfg

R developer
check "developer exit"          0                "$RC"
check "developer model"         claude-sonnet-5  "$(f '.models[0].model')"
check "developer exec"          claude           "$(f '.models[0].exec')"
check "developer tier"          sonnet           "$(f '.models[0].tier')"
check "developer effort"        high             "$(f '.models[0].effort')"
check "developer escalation"    claude-opus-4-8  "$(f '.escalation[0].model')"
check "developer option model"  kimi-k3          "$(f '.options[0].model')"
check "developer option tool"   kimi             "$(f '.options[0].tool')"
check "developer option effort" max              "$(f '.options[0].effort')"

R reviewer
check "reviewer count"        2                "$(f '.models | length')"
check "reviewer[1] model"     gpt-5.6-sol      "$(f '.models[1].model')"
check "reviewer[1] exec"      adapter          "$(f '.models[1].exec')"
check "reviewer[1] tool"      codex            "$(f '.models[1].tool')"

R architect
check "architect panel model" gpt-5.6-sol     "$(f '.panel[0].model')"
check "architect panel exec"  adapter         "$(f '.panel[0].exec')"

R nonexistent-role
check "unknown role exit"      5               "$RC"
check "unknown role error"     role_undefined  "$(f '.error_type')"

# role referencing a model missing from the registry -> fail-closed
cat > "$CFG" <<'EOF'
routing:
  roles:
    developer: { model: "ghost-model-9" }
  models_registry:
    claude-opus-4-8: { exec: "claude", tier: "opus" }
EOF
R developer
check "bad model exit"         5                     "$RC"
check "bad model error"        model_not_in_registry "$(f '.error_type')"
check "bad model unresolved"   ghost-model-9         "$(f '.unresolved[0]')"

# ---- WS1: config-driven dispatch routing ----
write_good_cfg

# --tool auto with all adapters disabled -> no external adapters (exit 2)
D --task review --tool auto --worktree "$TMP"
check "auto all-disabled exit"  2  "$RC"
check "auto all-disabled err"   "no external adapters available" "$(f '.error')"

# --tool <unknown> -> unknown_tool, listing the LIVE adapter set (not a hardcoded enum)
D --task review --tool notarealadapter --worktree "$TMP"
check "unknown tool exit"       5             "$RC"
check "unknown tool error"      unknown_tool  "$(f '.error_type')"
check "unknown tool available"  codex,gemini  "$(f '.available')"

# --tool codex (a known adapter, but disabled) -> adapter_disabled
D --task review --tool codex --worktree "$TMP"
check "disabled adapter exit"   5                "$RC"
check "disabled adapter error"  adapter_disabled "$(f '.error_type')"

echo "external-tools routing + resolve-role: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
