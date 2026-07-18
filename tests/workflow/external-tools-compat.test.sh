#!/usr/bin/env bash
# Tests for the generic compat adapter (WS3) + Kimi onboarding (WS4), offline only.
# The LIVE path (compat.sh driving `claude` against Moonshot) is NOT exercised here
# — it needs a real endpoint/key. These cover health branches, cost extraction,
# dispatcher recognition of a compat adapter, and role resolution to it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DISP="$ROOT/scripts/tl-telar-external-tools.sh"
COMPAT="$ROOT/skills/orchestration/external-tools/adapters/compat.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
check() { if [[ "$2" == "$3" ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "  FAIL: $1 — expected '$2' got '$3'"; fi; }

# Stub "claude" so health's `--version` succeeds without the real CLI.
STUB="$TMP/fakeclaude"
printf '#!/usr/bin/env bash\necho "stub-claude 1.0.0"\n' > "$STUB"
chmod +x "$STUB"

echo "compat adapter + kimi onboarding:"

# ---- compat health branches ----
H() { set +e; OUT=$(COMPAT_CLI_CMD="$STUB" env "$@" 2>/dev/null); RC=$?; set -e; }  # placeholder, redefined below
hf() { echo "$OUT" | jq -r "$1"; }

# api_style openai -> unavailable
set +e; OUT=$(COMPAT_CLI_CMD="$STUB" bash "$COMPAT" health --tool-name kimi --base-url https://x --auth-env-var MYKEY --api-style openai 2>/dev/null); set -e
check "api_style openai"        unavailable "$(hf '.status')"

# missing base_url -> unavailable
set +e; OUT=$(COMPAT_CLI_CMD="$STUB" bash "$COMPAT" health --tool-name kimi --auth-env-var MYKEY 2>/dev/null); set -e
check "missing base_url"        unavailable "$(hf '.status')"

# base_url set but auth var unset -> unavailable
set +e; OUT=$(COMPAT_CLI_CMD="$STUB" bash "$COMPAT" health --tool-name kimi --base-url https://x --auth-env-var UNSET_XYZ 2>/dev/null); set -e
check "auth var unset"          unavailable "$(hf '.status')"

# everything present -> ready + auth_valid true
set +e; OUT=$(MYKEY=secret COMPAT_CLI_CMD="$STUB" bash "$COMPAT" health --tool-name kimi --base-url https://x --auth-env-var MYKEY 2>/dev/null); set -e
check "healthy status"          ready       "$(hf '.status')"
check "healthy auth_valid"      true        "$(hf '.auth_valid')"
check "healthy tool name"       kimi        "$(hf '.tool')"

# ---- extract_cost_compat (sourced; isolated subshell) ----
cat > "$TMP/usage.json" <<'EOF'
{"type":"result","total_cost_usd":0.01,"usage":{"input_tokens":100,"cache_read_input_tokens":900,"output_tokens":50},"result":"done"}
EOF
COST=$(bash -c "source '$COMPAT'; extract_cost_compat '$TMP/usage.json'")
check "cost input (100+900)"    1000 "$(echo "$COST" | jq -r '.input_tokens')"
check "cost output"             50   "$(echo "$COST" | jq -r '.output_tokens')"
# missing file -> zeros, no crash
COST0=$(bash -c "source '$COMPAT'; extract_cost_compat '$TMP/nope.json'")
check "cost missing file"       0    "$(echo "$COST0" | jq -r '.input_tokens')"

# ---- dispatcher recognizes a compat adapter (kimi) as a known adapter ----
mkdir -p "$TMP/.tl-telar"
cat > "$TMP/.tl-telar/external-tools.yaml" <<'EOF'
adapters:
  codex:
    enabled: false
  kimi:
    enabled: false
    type: "compat"
    api_style: "anthropic"
    base_url: "https://api.moonshot.ai/anthropic"
    model: "kimi-k3"
    auth_env_var: "MOONSHOT_API_KEY"
routing:
  roles:
    developer: { model: "kimi-k3" }
  models_registry:
    kimi-k3: { exec: "adapter", tool: "kimi" }
EOF

set +e; OUT=$(CLAUDE_PROJECT_DIR="$TMP" bash "$DISP" dispatch --task review --tool kimi --worktree "$TMP" 2>/dev/null); RC=$?; set -e
# kimi is KNOWN (compat) but disabled -> adapter_disabled, NOT unknown_tool
check "kimi recognized exit"    5                "$RC"
check "kimi recognized error"   adapter_disabled "$(echo "$OUT" | jq -r '.error_type')"

# ---- resolve-role resolves a role to the compat adapter ----
set +e; OUT=$(CLAUDE_PROJECT_DIR="$TMP" bash "$DISP" resolve-role developer 2>/dev/null); set -e
check "role->kimi exec"         adapter "$(echo "$OUT" | jq -r '.models[0].exec')"
check "role->kimi tool"         kimi    "$(echo "$OUT" | jq -r '.models[0].tool')"
check "role->kimi model"        kimi-k3 "$(echo "$OUT" | jq -r '.models[0].model')"

echo "compat adapter + kimi onboarding: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
