#!/usr/bin/env bash
# /self-reflect driver. Runs Phase A (PR comments), Phase B (conversation
# mining is done by the LLM reading conversation context — this script
# only fetches PR comments), and produces a candidate list for the
# user-approval gate.
#
# Output: a markdown candidate list to stdout. The skill prompt then
# instructs the LLM to walk through Phase B + Phase C with the user
# and append accepted candidates to .tl-telar/knowledge/*.jsonl.

set -euo pipefail

DAYS="${1:-7}"

KB_DIR=".tl-telar/knowledge"
if [[ ! -d "$KB_DIR" ]]; then
  echo "No KB at $KB_DIR — run /tl-telar:setup-orchestration first."
  exit 0
fi

OUT=".tl-telar/temp/pr-comments.json"
mkdir -p "$(dirname "$OUT")"

echo "## Phase A — PR comment fetch (last $DAYS days)"
echo ""

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
FETCHER="$PLUGIN_ROOT/scripts/tl-telar-fetch-pr-comments.ts"

if [[ ! -f "$FETCHER" ]]; then
  echo "Fetcher not found at $FETCHER — Phase A skipped."
elif ! command -v npx >/dev/null 2>&1; then
  echo "npx not available — Phase A skipped (requires Node tooling)."
elif ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI not available — Phase A skipped."
else
  if GITHUB_TOKEN=$(gh auth token 2>/dev/null) npx tsx "$FETCHER" --days "$DAYS" --out "$OUT" 2>&1 | tail -5; then
    echo ""
    echo "Phase A: PR comments cached at $OUT."

    if command -v jq >/dev/null 2>&1; then
      TOTAL=$(jq '.totalComments' "$OUT")
      CODERABBIT_COUNT=$(jq '[.comments[] | select(.reviewerType=="coderabbit")] | length' "$OUT")
      echo "Phase A: $TOTAL total comments, $CODERABBIT_COUNT from CodeRabbit."

      if [[ "$CODERABBIT_COUNT" -gt 0 ]]; then
        echo ""
        echo "Phase A: CodeRabbit 'Learning:' lines (raw, before triage):"
        jq -r '.comments[] | select(.reviewerType=="coderabbit") | .body' "$OUT" \
          | grep -A5 "^Learnt from:" 2>/dev/null \
          | grep "^Learning:" 2>/dev/null \
          | sed 's/^Learning: //' \
          | sort -u || echo "  (none)"
      else
        echo "Phase A: no CodeRabbit comments in window — Phase A yields no candidates."
      fi
    else
      echo "jq not installed — cannot triage CodeRabbit lines automatically."
    fi
  else
    echo "Phase A: fetcher returned non-zero — Phase A skipped (no GitHub access or no recent PRs)."
  fi
fi

echo ""
echo "---"
echo ""
echo "## Phase B + C will be driven by the self-reflect skill"
echo ""
echo "The LLM running this skill will now:"
echo "  - Phase B: mine the current conversation for 'The problem was…', 'We decided to…', etc."
echo "  - Phase C: optionally audit CLAUDE.md / settings.json / .claude/commands/*"
echo "  - Present candidates to you in a numbered list with explicit ACCEPT/REJECT gate."
exit 0
