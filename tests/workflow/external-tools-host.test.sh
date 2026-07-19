#!/usr/bin/env bash
# Tests for DUAL-HOST resolution in scripts/tl-telar-external-tools.sh:
#   - resolve-host precedence (--host > $TL_TELAR_HOST > runtime.host > detection > claude)
#   - host-aware resolve-role via routing.profiles (symmetric roster)
#   - the anti-nest rule (a model whose home host == active host runs native; else adapter)
#   - Codex-as-moderator + Claude-reached-via-adapter (the cross-host review direction)
#   - backward compat: a config with NO profiles falls back to routing.roles (Claude-primary)
# No network, no real adapters — pure resolver logic against a temp config.
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

# Full dual-host config: runtime + symmetric profiles + host-tagged registry.
write_dualhost_cfg() {
  cat > "$CFG" <<'EOF'
runtime:
  host: auto
  host_env: TL_TELAR_HOST
adapters:
  codex:  { enabled: false }
  gemini: { enabled: false }
  claude: { enabled: false }
routing:
  roles:
    developer: { model: "claude-sonnet-5", escalation: ["claude-opus-4-8"] }
    reviewer:  { models: ["claude-opus-4-8", "gpt-5.6-sol"] }
  profiles:
    claude:
      moderator: { model: "claude-fable-5",  effort: "high" }
      developer: { model: "claude-sonnet-5", effort: "high", escalation: ["claude-opus-4-8"] }
      reviewer:  { models: ["gpt-5.6-sol", "gemini-pro"], effort: "high" }
    codex:
      moderator: { model: "gpt-5.6-sol",   effort: "high" }
      developer: { model: "gpt-5.6-terra", effort: "medium", escalation: ["gpt-5.6-sol"] }
      reviewer:  { models: ["claude-opus-4-8", "gemini-pro"], effort: "high" }
  models_registry:
    claude-fable-5:  { tier: "fable",  effort: "high",   host: "claude", tool: "claude" }
    claude-opus-4-8: { tier: "opus",   effort: "high",   host: "claude", tool: "claude" }
    claude-sonnet-5: { tier: "sonnet", effort: "high",   host: "claude", tool: "claude" }
    gpt-5.6-sol:     { effort: "xhigh",  host: "codex",  tool: "codex" }
    gpt-5.6-terra:   { effort: "medium", host: "codex",  tool: "codex" }
    gemini-pro:      { effort: "high",   host: "gemini", tool: "gemini" }
EOF
}

# Legacy config: routing.roles only, no runtime + no profiles (pre-dual-host).
write_legacy_cfg() {
  cat > "$CFG" <<'EOF'
adapters:
  codex: { enabled: false }
routing:
  roles:
    developer: { model: "claude-sonnet-5", escalation: ["claude-opus-4-8"] }
  models_registry:
    claude-sonnet-5: { exec: "claude",  tier: "sonnet", effort: "high" }
    claude-opus-4-8: { exec: "claude",  tier: "opus",   effort: "high" }
    gpt-5.6-sol:     { exec: "adapter", tool: "codex",  effort: "xhigh" }
EOF
}

# resolve-role with an explicit host (deterministic; ignores ambient env).
RR() { set +e; OUT=$(CLAUDE_PROJECT_DIR="$TMP" bash "$DISP" resolve-role --host "$1" "$2" 2>/dev/null); RC=$?; set -e; }
f() { echo "$OUT" | jq -r "$1"; }

echo "external-tools dual-host resolution:"

write_dualhost_cfg

# ---- resolve-host precedence ----
OUT=$(CLAUDE_PROJECT_DIR="$TMP" bash "$DISP" resolve-host --host codex 2>/dev/null)
check "host: --host flag wins" codex "$OUT"
OUT=$(CLAUDE_PROJECT_DIR="$TMP" TL_TELAR_HOST=codex bash "$DISP" resolve-host 2>/dev/null)
check "host: \$TL_TELAR_HOST"  codex "$OUT"
OUT=$(CLAUDE_PROJECT_DIR="$TMP" env -u TL_TELAR_HOST -u CODEX_HOME -u CODEX_SANDBOX -u CODEX_MODEL bash "$DISP" resolve-host 2>/dev/null)
check "host: default claude"   claude "$OUT"

# ---- host=claude profile: Claude implements, Codex+Gemini review ----
RR claude developer
check "claude/dev model"  claude-sonnet-5 "$(f '.models[0].model')"
check "claude/dev exec"   claude          "$(f '.models[0].exec')"
check "claude/dev native" true            "$(f '.models[0].native')"
check "claude/dev effort" high            "$(f '.models[0].effort')"
check "claude/dev source" profiles.claude "$(f '.source')"

RR claude reviewer
check "claude/rev[0] model"  gpt-5.6-sol "$(f '.models[0].model')"
check "claude/rev[0] exec"   adapter     "$(f '.models[0].exec')"
check "claude/rev[0] native" false       "$(f '.models[0].native')"
check "claude/rev[1] model"  gemini-pro  "$(f '.models[1].model')"
check "claude/rev[1] tool"   gemini      "$(f '.models[1].tool')"

# ---- host=codex profile: Codex IS moderator/developer; Claude reached via claude adapter ----
RR codex moderator
check "codex/mod model"  gpt-5.6-sol "$(f '.models[0].model')"
check "codex/mod exec"   native      "$(f '.models[0].exec')"
check "codex/mod native" true        "$(f '.models[0].native')"
check "codex/mod run"    codex       "$(f '.models[0].run')"

RR codex developer
check "codex/dev model"  gpt-5.6-terra "$(f '.models[0].model')"
check "codex/dev exec"   native        "$(f '.models[0].exec')"
check "codex/dev effort" medium        "$(f '.models[0].effort')"

RR codex reviewer
check "codex/rev[0] model"  claude-opus-4-8 "$(f '.models[0].model')"
check "codex/rev[0] exec"   adapter         "$(f '.models[0].exec')"
check "codex/rev[0] tool"   claude          "$(f '.models[0].tool')"
check "codex/rev[0] native" false           "$(f '.models[0].native')"

# ---- anti-nest: home-host != active-host is never native (no CLI nesting) ----
RR codex reviewer
check "anti-nest: claude not native on codex host" false "$(f '.models[0].native')"
RR claude reviewer
check "anti-nest: codex not native on claude host" false "$(f '.models[0].native')"

# ---- backward compat: no profiles -> routing.roles (Claude-primary) ----
write_legacy_cfg
RR claude developer
check "legacy/dev model"  claude-sonnet-5 "$(f '.models[0].model')"
check "legacy/dev exec"   claude          "$(f '.models[0].exec')"
check "legacy/dev source" roles           "$(f '.source')"

echo "  $pass passed, $fail failed"
[[ "$fail" -eq 0 ]] || exit 1
