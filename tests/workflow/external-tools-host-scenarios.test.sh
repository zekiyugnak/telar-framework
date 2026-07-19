#!/usr/bin/env bash
# Codex-as-MODERATOR scenarios (host=codex in ALL of them), varying where Claude sits:
#   S1: Claude is implementer AND reviewer (Codex only moderates)
#   S2: Claude is reviewer ONLY           (Codex moderates + implements)
#   S3: NO Claude at all                  (Codex everything; Gemini reviews)
# Proves: moderator is ALWAYS Codex (native gpt-5.6-sol); Claude, when present, is reached
# via the claude adapter (exec=adapter, tool=claude); and a Claude-free roster resolves with
# zero claude-tool models. Pure resolver logic, no network.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DISP="$ROOT/scripts/tl-telar-external-tools.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.tl-telar"
CFG="$TMP/.tl-telar/external-tools.yaml"

pass=0; fail=0
check() { if [[ "$2" == "$3" ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "  FAIL: $1 — expected '$2' got '$3'"; fi; }

# mk_cfg <developer-model> <reviewer-models-inner-json>
mk_cfg() {
  cat > "$CFG" <<EOF
runtime:
  host: auto
  host_env: TL_TELAR_HOST
adapters:
  codex:  { enabled: false }
  gemini: { enabled: false }
  claude: { enabled: false }
routing:
  profiles:
    codex:
      moderator: { model: "gpt-5.6-sol",  effort: "high" }
      developer: { model: "$1", effort: "medium" }
      reviewer:  { models: [$2], effort: "high" }
  models_registry:
    claude-opus-4-8: { tier: "opus",   effort: "high",   host: "claude", tool: "claude" }
    claude-sonnet-5: { tier: "sonnet", effort: "high",   host: "claude", tool: "claude" }
    gpt-5.6-sol:     { effort: "xhigh",  host: "codex",  tool: "codex" }
    gpt-5.6-terra:   { effort: "medium", host: "codex",  tool: "codex" }
    gemini-pro:      { effort: "high",   host: "gemini", tool: "gemini" }
EOF
}

RR() { set +e; OUT=$(CLAUDE_PROJECT_DIR="$TMP" bash "$DISP" resolve-role --host codex "$1" 2>/dev/null); RC=$?; set -e; }
f() { echo "$OUT" | jq -r "$1"; }
claude_count() { echo "$OUT" | jq '[.models[] | select(.tool=="claude")] | length'; }

echo "codex-as-moderator scenarios:"

# ============ S1: Claude implements AND reviews; Codex ONLY moderates ============
mk_cfg "claude-sonnet-5" '"claude-opus-4-8", "gemini-pro"'
RR moderator
check "S1 moderator model"  gpt-5.6-sol "$(f '.models[0].model')"
check "S1 moderator exec"   native      "$(f '.models[0].exec')"   # Codex IS the moderator
check "S1 moderator run"    codex       "$(f '.models[0].run')"
RR developer
check "S1 dev model"        claude-sonnet-5 "$(f '.models[0].model')"
check "S1 dev exec"         adapter         "$(f '.models[0].exec')"  # Claude implements externally
check "S1 dev tool"         claude          "$(f '.models[0].tool')"  # -> claude.sh
check "S1 dev native"       false           "$(f '.models[0].native')"
RR reviewer
check "S1 rev[0] model"     claude-opus-4-8 "$(f '.models[0].model')"
check "S1 rev[0] tool"      claude          "$(f '.models[0].tool')"
check "S1 rev[1] tool"      gemini          "$(f '.models[1].tool')"

# ============ S2: Claude reviews ONLY; Codex moderates + implements ============
mk_cfg "gpt-5.6-terra" '"claude-opus-4-8", "gemini-pro"'
RR moderator
check "S2 moderator exec"   native "$(f '.models[0].exec')"
RR developer
check "S2 dev model"        gpt-5.6-terra "$(f '.models[0].model')"
check "S2 dev exec"         native        "$(f '.models[0].exec')"   # Codex implements natively
check "S2 dev native"       true          "$(f '.models[0].native')"
RR reviewer
check "S2 rev[0] model"     claude-opus-4-8 "$(f '.models[0].model')"
check "S2 rev[0] exec"      adapter         "$(f '.models[0].exec')"  # Claude review via adapter
check "S2 rev[0] tool"      claude          "$(f '.models[0].tool')"

# ============ S3: NO Claude at all; Codex everything, Gemini reviews ============
mk_cfg "gpt-5.6-terra" '"gemini-pro"'
RR moderator
check "S3 moderator model"  gpt-5.6-sol "$(f '.models[0].model')"
check "S3 moderator exec"   native      "$(f '.models[0].exec')"
RR developer
check "S3 dev exec"         native      "$(f '.models[0].exec')"
RR reviewer
check "S3 rev count"        1           "$(f '.models | length')"
check "S3 rev[0] model"     gemini-pro  "$(f '.models[0].model')"
check "S3 rev[0] tool"      gemini      "$(f '.models[0].tool')"
check "S3 no claude models" 0           "$(claude_count)"

echo "  $pass passed, $fail failed"
[[ "$fail" -eq 0 ]] || exit 1
