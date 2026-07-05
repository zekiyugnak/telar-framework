#!/usr/bin/env bash
# SessionStart hook for the telar-framework orchestration namespace.
#
# Registered for SessionStart only (matcher: startup|resume|clear|compact).
# The `compact` matcher value covers post-compaction re-prime; PreCompact is
# NOT registered because in the Claude Code Hooks contract PreCompact is for
# blocking/controlling compaction, not injecting additionalContext (see
# https://code.claude.com/docs/en/hooks#precompact). The `case` over
# HOOK_EVENT_NAME below still tolerates PreCompact defensively in case a
# future registration adds it, but the shipped settings.json does not.
#
# Responsibilities (master design §2.7, narrowed from the original orchestration
# pattern to honor §1.1 opt-in invariant — NO silent writes):
#   1. Self-locate plugin root.
#   2. Detect un-opted-in project (no setup sentinel anywhere) → emit a
#      one-line suggestion prompt pointing at /tl-telar:setup-orchestration
#      and EXIT. Write nothing.
#   3. On opted-in projects with missing .tl-telar-thresholds.json → emit
#      a regeneration prompt. Do NOT silently write thresholds. (The
#      orchestrator agent's boot probe writes a safe no-op default when it
#      starts, so /tl-telar:orchestrate can still run.)
#   4. Run scripts/tl-telar-prime.sh --json and inject into
#      hookSpecificOutput.additionalContext.
#   5. Detect <!-- status: in-progress --> in .tl-telar/plans/active-plan.md
#      → emit recovery prompt.
#
# Command-shim installation under .claude/commands/ is NOT a hook
# responsibility (and not a setup responsibility either — the plugin's own
# commands/*.md are the canonical entries via /tl-telar:*).

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-${extensionPath:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

# Determine which event invoked us so the response can echo the same
# hookEventName back (Claude Code Hooks contract:
# hookSpecificOutput.hookEventName must equal the triggering event).
# Claude Code sends a JSON payload on stdin that includes hook_event_name.
# Read it non-blockingly; fall back to SessionStart when no stdin payload
# is provided (manual invocation, tests).
HOOK_EVENT_NAME="SessionStart"
if [[ ! -t 0 ]]; then
  STDIN_PAYLOAD=$(cat 2>/dev/null || true)
  if [[ -n "$STDIN_PAYLOAD" ]] && command -v node >/dev/null 2>&1; then
    PARSED=$(node -e "
      try {
        const d = JSON.parse(process.argv[1] || '{}');
        process.stdout.write(d.hook_event_name || '');
      } catch (e) { process.stdout.write(''); }
    " "$STDIN_PAYLOAD" 2>/dev/null || true)
    if [[ -n "$PARSED" ]]; then HOOK_EVENT_NAME="$PARSED"; fi
  fi
fi
# Accept the two events this hook is registered for. Anything else: still
# emit the literal event name so the response matches the trigger.
case "$HOOK_EVENT_NAME" in
  SessionStart|PreCompact) ;;
  "" ) HOOK_EVENT_NAME="SessionStart" ;;
esac

cd "$PROJECT_ROOT"

context_parts=()

# --- Setup-sentinel detection ---
# The hook NEVER writes files into a project that hasn't explicitly opted in.
# Setup is detected by ANY of:
#   1. .tl-telar/project-profile.json (written by /tl-telar:setup-orchestration)
#   2. .tl-telar/ directory exists with at least one tracked subdir
#   3. .tl-telar-thresholds.json exists (legacy detect — user may have it from an earlier sub-spec)
#   4. .tl-telar/plans/active-plan.md exists (recovery scenario)
# If NONE of these hold, the hook emits a single suggestion prompt and exits.
# It does NOT silently create files. This honors master design §1.1 opt-in invariant.
SETUP_DETECTED=false
if [[ -f ".tl-telar/project-profile.json" ]] \
   || [[ -d ".tl-telar" && -n "$(find .tl-telar -mindepth 1 -maxdepth 2 -type d -print -quit 2>/dev/null)" ]] \
   || [[ -f ".tl-telar-thresholds.json" ]] \
   || [[ -f ".tl-telar/plans/active-plan.md" ]]; then
  SETUP_DETECTED=true
fi

if [[ "$SETUP_DETECTED" != "true" ]]; then
  # No setup detected → emit ONLY a suggestion prompt; do NOT write any files.
  # The user must explicitly run /tl-telar:setup-orchestration before this
  # plugin makes any changes to the consumer project.
  context_parts+=("The telar-framework orchestration mode is available, but this project hasn't opted in. Run \`/tl-telar:setup-orchestration\` to detect framework and configure quality-gate defaults. No files will be created until you do.")
  # Emit context and exit — skip the rest of the hook for un-opted-in projects.
  if [[ ${#context_parts[@]} -gt 0 ]]; then
    if command -v node >/dev/null 2>&1; then
      node -e "
        const ctx = process.argv[1];
        const evt = process.argv[2] || 'SessionStart';
        console.log(JSON.stringify({hookSpecificOutput:{hookEventName:evt,additionalContext:ctx}}));
      " "${context_parts[0]}" "$HOOK_EVENT_NAME"
    else
      ESCAPED=$(printf '%s' "${context_parts[0]}" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
      echo "{\"hookSpecificOutput\":{\"hookEventName\":\"$HOOK_EVENT_NAME\",\"additionalContext\":\"$ESCAPED\"}}"
    fi
  fi
  exit 0
fi

# --- Setup detected: proceed with normal hook responsibilities (no silent writes) ---

# --- Phase 2: Self-heal mandatory files ---
# Only fires when the user has already opted in (SETUP_DETECTED above). Even
# then, the hook prefers prompting over writing — we only auto-write when
# .tl-telar/ exists but the thresholds file was lost (typical post-rebase or
# accidental delete scenario).
if [[ ! -f ".tl-telar-thresholds.json" ]] && [[ -d ".tl-telar" ]]; then
  # User has .tl-telar/ but thresholds went missing. Emit a prompt, don't write.
  context_parts+=("Project has .tl-telar/ but .tl-telar-thresholds.json is missing. The orchestrator's boot probe will recreate a safe no-op default (all gates advisory, exit-0 stubs) so /tl-telar:orchestrate can still run; for framework-aware defaults (real coverage command, strict mode), run \`/tl-telar:setup-orchestration\`.")
fi

# --- Phase 3: Knowledge priming (sub-spec 5 ships the real implementation) ---
# Capture exit code separately from stdout. The primer is fail-loud on
# malformed JSONL / schema violations / dependency-missing — when it exits
# non-zero, its stdout already contains the structured error JSON
# (KB_INVALID_JSONL / KB_SCHEMA_INVALID / etc.). Appending a literal
# `{"facts_loaded":0}` fallback in that case would produce TWO concatenated
# JSON blobs in the hook output, which breaks any consumer that JSON-parses
# the `additionalContext` field. So: use the fallback ONLY when stdout is
# empty (truly catastrophic failure with no message).
if [[ -f "$PLUGIN_ROOT/scripts/tl-telar-prime.sh" ]]; then
  PRIME_OUT=$(bash "$PLUGIN_ROOT/scripts/tl-telar-prime.sh" --json 2>/dev/null) || PRIME_EXIT=$?
  PRIME_EXIT=${PRIME_EXIT:-0}
  if [[ -z "${PRIME_OUT//[[:space:]]/}" ]]; then
    PRIME_OUT='{"facts_loaded":0,"message":"prime produced no output"}'
  fi
  if [[ "$PRIME_EXIT" -ne 0 ]]; then
    context_parts+=("KB prime FAILED (exit $PRIME_EXIT): $PRIME_OUT")
  else
    context_parts+=("KB prime result: $PRIME_OUT")
  fi
fi

# --- Phase 4: Recovery detection ---
ACTIVE_PLAN=".tl-telar/plans/active-plan.md"
if [[ -f "$ACTIVE_PLAN" ]] && grep -q "<!-- status: in-progress -->" "$ACTIVE_PLAN"; then
  context_parts+=(
    "RECOVERY: an in-progress orchestrated plan exists at $ACTIVE_PLAN. Run \`/tl-telar:resume\` to continue execution, or mark the plan abandoned to start fresh."
  )
fi

# --- Phase 5: Emit hookSpecificOutput JSON ---
if [[ ${#context_parts[@]} -eq 0 ]]; then
  exit 0
fi

# Join context_parts with real double newlines (ANSI-C $'...' quoting expands
# escapes; plain "\n\n" inside a normal string would be the literal characters
# backslash-n and would leak into the JSON as escaped chars).
SEP=$'\n\n'
JOINED=""
for p in "${context_parts[@]}"; do
  if [[ -z "$JOINED" ]]; then JOINED="$p"; else JOINED="${JOINED}${SEP}${p}"; fi
done

if command -v node >/dev/null 2>&1; then
  node -e "
    const ctx = process.argv[1];
    const evt = process.argv[2] || 'SessionStart';
    console.log(JSON.stringify({hookSpecificOutput:{hookEventName:evt,additionalContext:ctx}}));
  " "$JOINED" "$HOOK_EVENT_NAME"
else
  # Fallback: minimal escape (no embedded quotes in our content).
  # Newlines are JSON-escaped to \n; same as Node's JSON.stringify would do.
  ESCAPED=$(printf '%s' "$JOINED" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk 'BEGIN{ORS=""} {if(NR>1) printf "\\n"; print}')
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"$HOOK_EVENT_NAME\",\"additionalContext\":\"$ESCAPED\"}}"
fi
exit 0
