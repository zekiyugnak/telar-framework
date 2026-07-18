#!/usr/bin/env bash
# Offline tests for the NATIVE Kimi Code CLI adapter (kimi.sh). The LIVE path
# (kimi implement/review against the real CLI) needs `kimi login`; these cover
# health branches (via a stub kimi) + text/cost extraction from stream-json.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KIMI="$ROOT/skills/orchestration/external-tools/adapters/kimi.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
check() { if [[ "$2" == "$3" ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "  FAIL: $1 — expected '$2' got '$3'"; fi; }
hf() { echo "$OUT" | jq -r "$1"; }

echo "kimi native adapter:"

# Stub kimi: `doctor` exits per DOCTOR_RC; anything else (e.g. --version) prints a version.
mk_stub() { printf '#!/usr/bin/env bash\ncase "$1" in doctor) exit %s;; *) echo "kimi 0.27.0";; esac\n' "$1" > "$TMP/kimi"; chmod +x "$TMP/kimi"; }

# healthy: doctor exits 0
mk_stub 0
OUT=$(KIMI_CLI_CMD="$TMP/kimi" bash "$KIMI" health 2>/dev/null)
check "healthy status"     ready         "$(hf '.status')"
check "healthy auth"       true          "$(hf '.auth_valid')"
check "healthy model"      kimi-code/k3  "$(hf '.model')"
check "healthy tool"       kimi          "$(hf '.tool')"

# doctor fails -> unavailable, auth_valid false
mk_stub 1
OUT=$(KIMI_CLI_CMD="$TMP/kimi" bash "$KIMI" health 2>/dev/null)
check "doctor-fail status" unavailable   "$(hf '.status')"
check "doctor-fail auth"   false         "$(hf '.auth_valid')"

# not installed
OUT=$(KIMI_CLI_CMD="$TMP/does-not-exist-kimi" bash "$KIMI" health 2>/dev/null)
check "missing status"     unavailable   "$(hf '.status')"
check "missing version"    not_installed "$(hf '.version')"

# --- extract_kimi_text (sourced, isolated) ---
cat > "$TMP/stream.jsonl" <<'EOF'
{"role":"assistant","tool_calls":[{"type":"function"}]}
{"role":"tool","content":"Wrote 5 bytes"}
{"role":"assistant","content":"{\"verdict\":\"FAIL\",\"issues\":[]}"}
{"role":"meta","type":"session.resume_hint"}
EOF
TXT=$(bash -c "source '$KIMI'; extract_kimi_text '$TMP/stream.jsonl'")
check "text is verdict json" FAIL "$(echo "$TXT" | jq -r '.verdict' 2>/dev/null)"

# --- extract_cost_kimi: no usage -> zeros ---
COST=$(bash -c "source '$KIMI'; extract_cost_kimi '$TMP/stream.jsonl'")
check "cost input 0"  0 "$(echo "$COST" | jq -r '.input_tokens')"
check "cost output 0" 0 "$(echo "$COST" | jq -r '.output_tokens')"

echo "kimi native adapter: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
