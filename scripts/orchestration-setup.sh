#!/usr/bin/env bash
# Interactive setup for telar-framework orchestration mode.
# - Detects framework (RN/Expo/Flutter)
# - Writes framework-aware .tl-telar-thresholds.json (replaces sub-spec 2's safe no-op)
# - Creates .tl-telar/{plans,context,temp,knowledge} skeleton
# - Idempotently appends §2.7a hygiene block to .gitignore
#
# CRITICAL: this script operates on the CONSUMER project (the mobile app being
# built), NOT on the plugin's install directory. PLUGIN_ROOT is used only to
# read template files; all writes go to PROJECT_ROOT.

set -euo pipefail

# Plugin install directory — read-only source of templates
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Consumer project directory — destination for all writes
# Prefer CLAUDE_PROJECT_DIR (set by Claude Code when running in a project),
# then PWD, never the plugin directory.
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

# Safety check: refuse to run if PROJECT_ROOT equals PLUGIN_ROOT.
# That means the user invoked setup against the plugin install itself, which
# is meaningless (plugin is not a mobile app) and would dirty the plugin tree.
if [[ "$PROJECT_ROOT" == "$PLUGIN_ROOT" ]]; then
  echo "ERROR: setup-orchestration was invoked against the plugin install directory."
  echo "  PLUGIN_ROOT=$PLUGIN_ROOT"
  echo "  PROJECT_ROOT=$PROJECT_ROOT"
  echo "Run /tl-telar:setup-orchestration from your consumer mobile project, not from the plugin tree."
  exit 1
fi

# --- Preflight: hard dependencies must exist BEFORE any mutation. ---
# Setup writes project-profile.json and .tl-telar-thresholds.json via Node's
# JSON.stringify (the only safe way to escape user-supplied / framework-detected
# strings). Without Node, those writes would fail later and leave the consumer
# with a half-initialised .tl-telar/ (dirs and scripts present, sentinel and
# thresholds missing). Fail fast here so the consumer either has a complete
# setup or no setup at all.
if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: /tl-telar:setup-orchestration requires Node (used to safely emit JSON config)."
  echo "Install Node (https://nodejs.org/, or 'brew install node' on macOS) and re-run."
  echo "No files were created."
  exit 1
fi

# All subsequent file operations are relative to PROJECT_ROOT.
cd "$PROJECT_ROOT"

# --- Framework detection (master design §2.5.1 table) ---
COVERAGE_CMD=""
COVERAGE_STRICT="false"

if [[ -f "pubspec.yaml" ]]; then
  FRAMEWORK="flutter"
  COVERAGE_CMD="flutter test --coverage"
  COVERAGE_STRICT="true"
elif [[ -f "package.json" ]]; then
  if grep -q '"expo"' package.json 2>/dev/null; then
    FRAMEWORK="expo"
  elif grep -q '"react-native"' package.json 2>/dev/null; then
    FRAMEWORK="react-native"
  else
    FRAMEWORK="node"
  fi
  if [[ -f "jest.config.js" || -f "jest.config.ts" || -f "jest.config.json" ]] || grep -q '"jest"' package.json; then
    COVERAGE_CMD="npx jest --coverage"
    COVERAGE_STRICT="true"
  elif grep -q '"vitest"' package.json; then
    COVERAGE_CMD="npx vitest run --coverage"
    COVERAGE_STRICT="true"
  else
    COVERAGE_CMD="echo 'no test runner detected - configure jest or vitest' && exit 0"
    COVERAGE_STRICT="false"
  fi
else
  FRAMEWORK="unknown"
  COVERAGE_CMD="echo 'no framework detected (no package.json or pubspec.yaml)' && exit 0"
  COVERAGE_STRICT="false"
fi

echo "Detected framework: $FRAMEWORK"
echo "Coverage command: $COVERAGE_CMD"
echo "Coverage strict: $COVERAGE_STRICT"

# --- Create .tl-telar/ skeleton ---
mkdir -p .tl-telar/plans .tl-telar/context .tl-telar/temp .tl-telar/knowledge .tl-telar/context/evidence

# --- Install gate scripts into consumer scripts/ (perf-smoke + size-check) ---
# The .tl-telar-thresholds.json default commands are `bash scripts/perf-smoke.sh`
# and `bash scripts/size-check.sh` (relative to PROJECT_ROOT). Those files only
# exist in the plugin install by default — without this copy step the Phase 2
# VALIDATE allowlist would resolve them via the orchestrator's plugin-or-project
# search, but a manual `bash scripts/perf-smoke.sh` from the consumer terminal
# would exit 127. Copy them so both manual invocation and orchestrator dispatch
# work. Idempotent: never overwrite if user has customized.
mkdir -p scripts
for s in perf-smoke.sh size-check.sh; do
  src="$PLUGIN_ROOT/scripts/$s"
  dst="scripts/$s"
  if [[ ! -f "$dst" ]]; then
    if [[ -f "$src" ]]; then
      cp "$src" "$dst"
      echo "Installed $dst (advisory stub; replace with real measurement when you set *_strict: true)"
    else
      echo "WARNING: plugin source $src missing — gate command will exit 127 until you provide $dst"
    fi
  else
    echo "$dst already present — preserved (run set *_strict: true after replacing with real measurement)"
  fi
done

# --- Write .tl-telar-thresholds.json (framework-aware) ---
THRESHOLDS=".tl-telar-thresholds.json"
if [[ -f "$THRESHOLDS" ]]; then
  # Check if it's still the safe no-op (look for the stub marker)
  if grep -q "coverage not configured" "$THRESHOLDS"; then
    echo "Replacing safe-default thresholds with framework-aware version..."
    REPLACE=true
  else
    echo "$THRESHOLDS already customized by user — leaving untouched. Edit manually if you want to switch."
    REPLACE=false
  fi
else
  REPLACE=true
fi

# --- Setup sentinel: .tl-telar/project-profile.json ---
# This file is the durable setup output per master design §2.3 / §6 (Setup hook
# expects it as a sentinel). The SessionStart hook treats its presence as
# "this project has opted in" and proceeds with normal hook behavior.
# Sub-spec 4's setup script is the canonical writer.
PROFILE=".tl-telar/project-profile.json"
mkdir -p "$(dirname "$PROFILE")"
# Node availability already verified by the preflight at the top of this script.
node -e '
  const fs = require("fs");
  const args = process.argv.slice(1);
  const out = {
    schemaVersion: 1,
    framework: args[0],
    setup_timestamp: new Date().toISOString(),
    setup_via: "/tl-telar:setup-orchestration",
    plugin_version_at_setup: args[1],
    notes: "This file is the setup sentinel. Its presence tells the SessionStart hook that this project has opted in to the orchestration namespace. Delete it (and .tl-telar/) to start fresh."
  };
  fs.writeFileSync(args[2], JSON.stringify(out, null, 2));
' "$FRAMEWORK" "${TL_TELAR_PLUGIN_VERSION:-0.4.0}" "$PROFILE"
echo "Wrote $PROFILE (setup sentinel)"

if [[ "$REPLACE" == "true" ]]; then
  # Build the JSON via Node so user-supplied / framework-detected strings
  # (COVERAGE_CMD especially) get properly JSON-escaped. A heredoc with
  # shell interpolation would produce invalid JSON if the command later
  # contained quotes, backslashes, or newlines — and would be a JSON-
  # injection vector if any of those vars came from untrusted input.
  # (Node availability already checked above for the project-profile write.)
  node -e '
    const fs = require("fs");
    const args = process.argv.slice(1);
    const framework = args[0];
    const coverageCmd = args[1];
    const coverageStrict = args[2] === "true";
    const out = {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      description: "Quality-gate contract — framework-aware defaults written by /tl-telar:setup-orchestration. Detected: " + framework,
      coverage: { lines: 80, branches: 75, functions: 80, statements: 80 },
      performance: { min_fps: 60, max_cold_start_ms: 3000 },
      size: { max_apk_mb: 50, max_ipa_mb: 60 },
      accessibility: { required_audit_pass: false },
      autonomy: {
        cycle: "interactive",
        description: "interactive (default) = orchestrator may pause mid-cycle at checkpoint:true WUs and at self-reflect. unattended = one human gate at plan-ready (Step 5): scope + approved UI ASCII drafts + all secrets/inputs collected up front, then the WU cycle runs to PR-ready with ZERO pauses. UI sign-off is hoisted into plan-readiness, never mid-cycle, and unattended never skips a decision, it makes it earlier. See agents/mobile-orchestrator.md Autonomy model section."
      },
      execution: {
        max_parallel_wus: 3,
        description: "Maximum Work Units the orchestrator runs concurrently. A WU is dispatched only when deps are COMPLETE and file_scope is disjoint from every running WU. Default 3. See scripts/tl-telar-wu-scheduler.js."
      },
      enforcement: {
        coverage_command: coverageCmd,
        coverage_strict: coverageStrict,
        perf_command: "bash scripts/perf-smoke.sh",
        perf_strict: false,
        size_command: "bash scripts/size-check.sh",
        size_strict: false,
        a11y_command: "echo \"a11y audit not configured\" && exit 0",
        a11y_strict: false,
        blockPRCreation: true,
        blockTaskCompletion: true,
        detected_framework: framework
      }
    };
    fs.writeFileSync(args[3], JSON.stringify(out, null, 2));
  ' "$FRAMEWORK" "$COVERAGE_CMD" "$COVERAGE_STRICT" "$THRESHOLDS"
  echo "Wrote $THRESHOLDS (via node JSON.stringify; user-supplied strings safely escaped)"
fi

# --- Idempotent .gitignore reconcile (master design §2.7a) ---
# Per-line reconcile so upgrades pick up newly-required ignore entries even
# when the marker block already exists. A marker-only check (the previous
# implementation) silently left old consumers without new mandatory ignore
# lines, allowing the orchestrator's own scratch files (wu-*-baseline.tsv,
# wu-*-changes.txt) to leak into git ls-files --others and self-lock the
# Phase 2 scope check.
MARKER="# tl-telar orchestrator state"
GITIGNORE=".gitignore"
REQUIRED_IGNORES=(
  ".tl-telar/context/execution-state.md"
  ".tl-telar/context/execution-state-*.md"
  ".tl-telar/context/project-context.md"
  ".tl-telar/context/evidence/"
  ".tl-telar/context/external-tools-budget.jsonl"
  ".tl-telar/context/wu-*-baseline.tsv"
  ".tl-telar/context/wu-*-changes.txt"
  ".tl-telar/context/active-change.txt"
  ".tl-telar/temp/"
)

# Ensure file + marker exist (creates them on a fresh project).
touch "$GITIGNORE"
if ! grep -qF "$MARKER" "$GITIGNORE"; then
  printf '\n%s (working files, not durable)\n' "$MARKER" >> "$GITIGNORE"
fi

# Add each required ignore line that isn't already present (exact-string match).
added=0
for line in "${REQUIRED_IGNORES[@]}"; do
  if ! grep -qxF "$line" "$GITIGNORE"; then
    echo "$line" >> "$GITIGNORE"
    added=$((added + 1))
  fi
done
if (( added > 0 )); then
  echo "Reconciled $GITIGNORE: appended $added new orchestrator ignore line(s)."
else
  echo "$GITIGNORE already complete for §2.7a (all ${#REQUIRED_IGNORES[@]} required ignore lines present)."
fi

# --- Knowledge base seed (sub-spec 5 addition) ---
# KB_DIR is relative to PROJECT_ROOT (the consumer mobile project). Templates
# come from PLUGIN_ROOT. Both vars are set by orchestration-setup.sh prologue
# (sub-spec 4 added the PROJECT_ROOT vs PLUGIN_ROOT split).
KB_DIR=".tl-telar/knowledge"
mkdir -p "$KB_DIR"
PLUGIN_KB_TEMPLATE="$PLUGIN_ROOT/resources/templates/orchestration/knowledge"

if [[ -d "$PLUGIN_KB_TEMPLATE" ]]; then
  for f in README.md codebase-facts.jsonl api-behaviors.jsonl patterns.jsonl anti-patterns.jsonl gotchas.jsonl decisions.jsonl performance.jsonl security.jsonl; do
    if [[ ! -f "$KB_DIR/$f" ]]; then
      cp "$PLUGIN_KB_TEMPLATE/$f" "$KB_DIR/$f"
    fi
  done
  echo "Knowledge base initialized at $KB_DIR (8 JSONL files + README)"
else
  echo "Plugin KB template missing at $PLUGIN_KB_TEMPLATE — KB seed skipped"
fi

# --- External tools config seed (sub-spec 7) ---
# Path is relative to PROJECT_ROOT (consumer project). Template lives at PLUGIN_ROOT.
# Both vars are set by orchestration-setup.sh prologue from sub-spec 4.
ETOOLS_YAML=".tl-telar/external-tools.yaml"
ETOOLS_TEMPLATE="$PLUGIN_ROOT/resources/templates/orchestration/external-tools.yaml"
if [[ ! -f "$ETOOLS_YAML" && -f "$ETOOLS_TEMPLATE" ]]; then
  cp "$ETOOLS_TEMPLATE" "$ETOOLS_YAML"
  echo "External tools config initialized at $ETOOLS_YAML (adapters disabled by default — set adapters.*.enabled: true to activate)"
fi

echo ""
echo "Setup complete. Now you can run /tl-telar:orchestrate <task>."
exit 0
