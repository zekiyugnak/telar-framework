#!/usr/bin/env bash
# KB retrieval primer. Real implementation (replaces sub-spec 4 stub).
# CLI contract (binding — sub-spec 4 stub used this):
#   --json                emit JSON for SessionStart hook additionalContext
#   --files <glob>        filter by affectedFiles glob (converted to regex internally)
#   --keywords <words>    filter by tags.topic / tags.category / fact substring (OR)
#   --work-type <type>    filter by intent: planning|implementation|review|debugging|recovery
# Output: 5 fixed categories — MUST FOLLOW / GOTCHAS / PATTERNS / DECISIONS / API BEHAVIORS
#
# Bucket assignment for the 8 KB types (every type lands in exactly ONE bucket,
# unless it also matches MUST FOLLOW heuristics):
#   gotcha, code_quirk        → GOTCHAS
#   pattern, anti_pattern     → PATTERNS
#   decision, dependency      → DECISIONS
#   api_behavior              → API BEHAVIORS
#   security, performance     → MUST FOLLOW (always; these are project-critical)
# Additionally: any fact whose text contains MUST/ALWAYS/NEVER also surfaces
# in MUST FOLLOW. A fact may appear in MUST FOLLOW AND its primary bucket.

set -euo pipefail

JSON_MODE=false
FILES=""
KEYWORDS=""
WORK_TYPE=""

# --- Arg parsing (no unbound-variable crashes on missing values; clear errors) ---
usage_err() {
  echo "ERROR: $1" >&2
  echo "Usage: tl-telar-prime.sh [--json] [--files <glob>] [--keywords <words>] [--work-type <planning|implementation|review|debugging|recovery>]" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      JSON_MODE=true; shift ;;
    --files)
      [[ $# -ge 2 ]] || usage_err "--files requires a value"
      FILES="$2"; shift 2 ;;
    --keywords)
      [[ $# -ge 2 ]] || usage_err "--keywords requires a value"
      KEYWORDS="$2"; shift 2 ;;
    --work-type)
      [[ $# -ge 2 ]] || usage_err "--work-type requires a value"
      WORK_TYPE="$2"
      case "$WORK_TYPE" in
        planning|implementation|review|debugging|recovery) ;;
        *) usage_err "invalid --work-type value: $WORK_TYPE (allowed: planning, implementation, review, debugging, recovery)" ;;
      esac
      shift 2 ;;
    --help|-h)
      usage_err "" ;;
    --*)
      usage_err "unknown flag: $1" ;;
    *)
      usage_err "unexpected positional argument: $1" ;;
  esac
done

KB_DIR=".tl-telar/knowledge"

# --- emit_empty: jq-free literal JSON so this path works on fresh consumers
#     without jq installed yet (sub-spec 5 graceful-degrade case). ---
emit_empty() {
  local msg="$1"
  if [[ "$JSON_MODE" == "true" ]]; then
    # Hand-built JSON; msg is the only dynamic field, JSON-escape via Node if
    # available, else use a sed pipeline that escapes the four characters that
    # JSON cares about. msg contains no newlines in our call sites.
    local safe
    if command -v node >/dev/null 2>&1; then
      safe=$(node -e 'process.stdout.write(JSON.stringify(process.argv[1]))' "$msg")
    else
      # Escape: backslash, double-quote, control chars (none expected); convert
      # any literal newline to \n. (Bash strings here are single-line.)
      safe='"'$(printf '%s' "$msg" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g')'"'
    fi
    printf '{"facts_loaded":0,"message":%s,"must_follow":[],"gotchas":[],"patterns":[],"decisions":[],"api_behaviors":[]}\n' "$safe"
  else
    echo "$msg"
  fi
}

# --- emit_fatal: structured JSON error + exit 1 (data-loss conditions). ---
emit_fatal() {
  local code="$1" msg="$2"
  if [[ "$JSON_MODE" == "true" ]]; then
    local safe_msg safe_code
    if command -v node >/dev/null 2>&1; then
      safe_msg=$(node -e 'process.stdout.write(JSON.stringify(process.argv[1]))' "$msg")
      safe_code=$(node -e 'process.stdout.write(JSON.stringify(process.argv[1]))' "$code")
    else
      safe_msg='"'$(printf '%s' "$msg" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')'"'
      safe_code='"'$(printf '%s' "$code")'"'
    fi
    printf '{"facts_loaded":0,"error":%s,"message":%s}\n' "$safe_code" "$safe_msg"
  else
    echo "ERROR [$code]: $msg" >&2
  fi
  exit 1
}

if [[ ! -d "$KB_DIR" ]]; then
  emit_empty "no knowledge base — run /tl-telar:setup-orchestration"
  exit 0
fi

# jq is required for filtering/bucketing. KB-present-but-jq-missing is a hard
# error (not graceful-empty) because the user opted into the KB and we'd be
# silently hiding facts.
if ! command -v jq >/dev/null 2>&1; then
  emit_fatal "JQ_MISSING" "jq is required for prime filtering. Install via 'brew install jq' or 'apt install jq'."
fi

# --- Collect and validate KB facts (fail-loud on bad JSONL) ---
# Stream each non-comment line through `jq -e` to detect malformed JSON before
# any silent || fallback can swallow it. Track invalid lines with file:line
# coordinates so the user can find the broken record.
INVALID_LINES_FILE=$(mktemp -t tl-telar-prime-bad-lines.XXXXXX)
trap 'rm -f "$INVALID_LINES_FILE"' EXIT

RAW_FILE=$(mktemp -t tl-telar-prime-raw.XXXXXX)
trap 'rm -f "$INVALID_LINES_FILE" "$RAW_FILE"' EXIT

for f in "$KB_DIR"/*.jsonl; do
  [[ -f "$f" ]] || continue
  lineno=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno + 1))
    # Skip blank and comment lines.
    [[ -z "${line//[[:space:]]/}" ]] && continue
    [[ "${line#\#}" != "$line" ]] && continue
    if ! printf '%s\n' "$line" | jq -e . >/dev/null 2>&1; then
      printf '%s:%d\n' "$f" "$lineno" >> "$INVALID_LINES_FILE"
    else
      printf '%s\n' "$line" >> "$RAW_FILE"
    fi
  done < "$f"
done

if [[ -s "$INVALID_LINES_FILE" ]]; then
  bad_count=$(wc -l < "$INVALID_LINES_FILE" | tr -d '[:space:]')
  bad_list=$(paste -sd';' "$INVALID_LINES_FILE")
  emit_fatal "KB_INVALID_JSONL" "$bad_count malformed JSONL record(s) in KB; fix or remove these lines before priming. Locations: $bad_list"
fi

if [[ ! -s "$RAW_FILE" ]]; then
  emit_empty "KB is empty — run /tl-telar:self-reflect after work to populate"
  exit 0
fi

# --- Schema validation (fail-loud on missing or wrong-type fields) ---
# README.md §record schema says every record MUST have: id, type, fact, and
# tags.{platform,framework,category} with controlled-vocabulary values, and
# typed optional fields. JSON-syntactic validity (verified earlier) is not
# enough — a parseable record with wrong types or unknown enum values silently
# fails to match buckets/filters (data-loss class of bug). This validator
# enforces the README contract end-to-end: every accepted record will land in
# at least one bucket and survive jq type-coercions during filtering.
SCHEMA_PROBLEMS=$(jq -sR '
  # Controlled vocabularies (must match README.md §tags + §record schema)
  ["api_behavior","code_quirk","pattern","anti_pattern","gotcha","decision","dependency","performance","security"] as $TYPES |
  ["ios","android","both"] as $PLATFORMS |
  ["react-native","flutter","native","any"] as $FRAMEWORKS |
  ["build","store","navigation","state","design-system","security","performance","accessibility","release","ota","testing"] as $CATEGORIES |

  split("\n") | map(select(length > 0)) |
  to_entries |
  map(
    .key as $idx |
    (.value | fromjson) as $r |
    $r |
    if type != "object" then
      {pos: ($idx+1), issue: "record is not a JSON object", preview: (.value[0:80])}
    elif (.id // null) == null or (.id | type != "string") then
      {pos: ($idx+1), issue: "missing or non-string required field: id", preview: (.value[0:80])}
    elif (.type // null) == null then
      {pos: ($idx+1), id: .id, issue: "missing required field: type"}
    elif (.type | IN($TYPES[]) | not) then
      {pos: ($idx+1), id: .id, issue: ("invalid type: " + (.type|tostring) + " (allowed: " + ($TYPES|join("|")) + ")")}
    elif (.fact // null) == null then
      {pos: ($idx+1), id: .id, issue: "missing required field: fact"}
    elif (.fact | type != "string") then
      {pos: ($idx+1), id: .id, issue: ("fact must be a string, got " + (.fact|type))}
    elif (.tags // null) == null or (.tags | type != "object") then
      {pos: ($idx+1), id: .id, issue: "missing or invalid required field: tags (must be an object)"}
    elif (.tags.platform // null) == null then
      {pos: ($idx+1), id: .id, issue: "missing required field: tags.platform"}
    elif (.tags.platform | IN($PLATFORMS[]) | not) then
      {pos: ($idx+1), id: .id, issue: ("invalid tags.platform: " + (.tags.platform|tostring) + " (allowed: " + ($PLATFORMS|join("|")) + ")")}
    elif (.tags.framework // null) == null then
      {pos: ($idx+1), id: .id, issue: "missing required field: tags.framework"}
    elif (.tags.framework | IN($FRAMEWORKS[]) | not) then
      {pos: ($idx+1), id: .id, issue: ("invalid tags.framework: " + (.tags.framework|tostring) + " (allowed: " + ($FRAMEWORKS|join("|")) + ")")}
    elif (.tags.category // null) == null then
      {pos: ($idx+1), id: .id, issue: "missing required field: tags.category"}
    elif (.tags.category | IN($CATEGORIES[]) | not) then
      {pos: ($idx+1), id: .id, issue: ("invalid tags.category: " + (.tags.category|tostring) + " (allowed: " + ($CATEGORIES|join("|")) + ")")}
    elif (.tags.topic != null) and ((.tags.topic | type != "array") or ((.tags.topic | map(type) | unique) != ["string"] and (.tags.topic | length) > 0)) then
      {pos: ($idx+1), id: .id, issue: ("tags.topic must be array<string> if present, got " + (.tags.topic|type))}
    elif (.affectedFiles != null) and ((.affectedFiles | type != "array") or ((.affectedFiles | map(type) | unique) != ["string"] and (.affectedFiles | length) > 0)) then
      {pos: ($idx+1), id: .id, issue: ("affectedFiles must be array<string> if present, got " + (.affectedFiles|type))}
    elif (.recommendation != null) and (.recommendation | type != "string") then
      {pos: ($idx+1), id: .id, issue: ("recommendation must be a string if present, got " + (.recommendation|type))}
    else empty end
  )
' "$RAW_FILE" 2>/dev/null) || SCHEMA_PROBLEMS="[]"

if [[ "$SCHEMA_PROBLEMS" != "[]" ]] && [[ -n "$SCHEMA_PROBLEMS" ]]; then
  PROBLEM_COUNT=$(printf '%s' "$SCHEMA_PROBLEMS" | jq 'length' 2>/dev/null || echo 0)
  if [[ "${PROBLEM_COUNT:-0}" -gt 0 ]]; then
    SUMMARY=$(printf '%s' "$SCHEMA_PROBLEMS" | jq -r 'map((.id // ("pos " + (.pos|tostring))) + ": " + .issue) | join("; ")' 2>/dev/null || echo "schema validation failed but summary unavailable")
    emit_fatal "KB_SCHEMA_INVALID" "$PROBLEM_COUNT record(s) violate the KB schema (id, type, fact, tags.{platform,framework,category} required). Fix or remove: $SUMMARY"
  fi
fi

# --- Append-only update reduction ---
# Same `id` with newer `updatedAt` supersedes older. After schema validation
# every record is guaranteed to have id; reduce to one record per id (latest
# updatedAt → createdAt → file order).
REDUCED=$(jq -s '
  group_by(.id) |
  map(
    sort_by(.updatedAt // .createdAt // "")
    | reverse
    | .[0]
  )
' "$RAW_FILE" 2>/dev/null) || REDUCED=""

if [[ -z "$REDUCED" ]]; then
  emit_fatal "KB_REDUCE_FAILED" "Could not reduce KB records by id. Check that every record is a valid JSON object."
fi

# --- Glob → regex for --files (zero-or-more directories for **) ---
# Use Node when available (handles ** correctly: zero-or-more path segments).
# Node is a preflight requirement of setup-orchestration.sh, so most consumers
# will have it; falling back to no --files when Node is missing is acceptable
# and surfaces a clear notice (rather than the BSD-vs-GNU-sed brittleness the
# previous fallback hit).
FILES_REGEX=""
if [[ -n "$FILES" ]]; then
  if command -v node >/dev/null 2>&1; then
    FILES_REGEX=$(node -e '
      const g = process.argv[1];
      // Walk the glob, emit regex.
      //   "**/<rest>"  → zero-or-more "<seg>/" groups (matches both src/a.ts and src/x/a.ts when given src/**/*.ts)
      //   trailing "**" (no following /) → match any remaining path chars including / (so src/** matches src/a.ts, src/x/y/a.ts)
      //   "*"  → [^/]*  (single segment)
      //   "?"  → [^/]
      let out = "^";
      let i = 0;
      while (i < g.length) {
        const c = g[i];
        // "**" at end-of-string with NO trailing slash → match any path tail.
        if (c === "*" && g[i+1] === "*" && g[i+2] === undefined) {
          out += ".*";
          i += 2;
          continue;
        }
        // "**/" → zero-or-more "<seg>/" groups.
        if (c === "*" && g[i+1] === "*" && g[i+2] === "/") {
          out += "(?:[^/]+/)*";
          i += 3;
          continue;
        }
        if (c === "*") { out += "[^/]*"; i++; continue; }
        if (c === "?") { out += "[^/]"; i++; continue; }
        // Escape regex specials.
        if (/[.+(){}\[\]^$|\\]/.test(c)) { out += "\\" + c; i++; continue; }
        out += c;
        i++;
      }
      out += "$";
      process.stdout.write(out);
    ' "$FILES" 2>/dev/null || true)
  fi

  if [[ -z "$FILES_REGEX" ]]; then
    emit_fatal "GLOB_UNAVAILABLE" "--files requires Node for glob→regex conversion. Install Node (https://nodejs.org/) and re-run, or omit --files."
  fi
fi

# --- Keyword OR-regex for --keywords ---
# Each whitespace-separated word becomes an alternative; regex-escape each so a
# stray dot or paren doesn't blow up.
KW_REGEX=""
if [[ -n "$KEYWORDS" ]]; then
  if command -v node >/dev/null 2>&1; then
    KW_REGEX=$(node -e '
      const ws = process.argv[1].split(/\s+/).filter(Boolean);
      const esc = (s) => s.replace(/[.+*?(){}\[\]^$|\\\/]/g, "\\$&");
      process.stdout.write(ws.map(esc).join("|"));
    ' "$KEYWORDS")
  else
    KW_REGEX=$(printf '%s' "$KEYWORDS" \
      | tr ' ' '\n' \
      | sed -e 's/[][\.+*?(){}^$|\\\/]/\\&/g' \
      | paste -sd'|' -)
  fi
fi

# --- Apply filters via jq --arg (never string-interpolate user input) ---
# Capture stderr separately so a real jq runtime error (e.g. a malformed record
# that slipped past schema validation, or a regex compile failure) is reported
# fail-loud as KB_FILTER_FAILED instead of silently emptying the result set.
FILTER_STDERR=$(mktemp -t tl-telar-prime-filter.XXXXXX)
trap 'rm -f "$INVALID_LINES_FILE" "$RAW_FILE" "$FILTER_STDERR"' EXIT
FILTERED=$(printf '%s' "$REDUCED" | jq -c \
  --arg files_re "$FILES_REGEX" \
  --arg kw_re "$KW_REGEX" \
  --arg work_type "$WORK_TYPE" '
  .[]
  | (
      if $files_re != "" then
        select((.affectedFiles // []) | any(. as $p | $p | test($files_re)))
      else . end
    )
  | (
      if $kw_re != "" then
        select(
          (
            (.fact // "")
            + " " + (.recommendation // "")
            + " " + (((.tags.topic // []) | join(" ")))
            + " " + ((.tags.category // ""))
          ) | test($kw_re; "i")
        )
      else . end
    )
  | (
      if $work_type == "review" then
        select(.type | IN("pattern","anti_pattern","gotcha","security"))
      elif $work_type == "debugging" then
        select(.type | IN("gotcha","code_quirk","api_behavior"))
      else . end
    )
' 2>"$FILTER_STDERR") || FILTER_EXIT=$?
FILTER_EXIT=${FILTER_EXIT:-0}

if [[ "$FILTER_EXIT" -ne 0 ]]; then
  FILTER_ERR=$(head -c 400 "$FILTER_STDERR" | tr '\n' ' ')
  emit_fatal "KB_FILTER_FAILED" "jq filter exited $FILTER_EXIT during retrieval — a record's runtime shape is incompatible with the filter chain (e.g. affectedFiles or tags.topic non-array, or fact non-string). Stderr: $FILTER_ERR"
fi

# Robust count (no arithmetic-parse crashes on empty or multi-line results).
if [[ -z "${FILTERED//[[:space:]]/}" ]]; then
  COUNT=0
else
  COUNT=$(printf '%s\n' "$FILTERED" | grep -c '^{' || true)
  COUNT=${COUNT:-0}
  COUNT=$(printf '%s' "$COUNT" | tr -d '[:space:]')
  COUNT=${COUNT:-0}
fi

if [[ "$COUNT" -eq 0 ]]; then
  emit_empty "no facts matched filters (files=$FILES keywords=$KEYWORDS work-type=$WORK_TYPE)"
  exit 0
fi

# --- Bucket the filtered records into 5 categories ---
MUST_FOLLOW=$(printf '%s\n' "$FILTERED" | jq -c 'select(
  (.type | IN("security","performance"))
  or
  ((.fact // "") + " " + (.recommendation // "") | test("\\b(MUST|ALWAYS|NEVER)\\b"; "i"))
)' || true)

GOTCHAS=$(printf '%s\n' "$FILTERED" | jq -c 'select(.type | IN("gotcha","code_quirk"))' || true)
PATTERNS=$(printf '%s\n' "$FILTERED" | jq -c 'select(.type | IN("pattern","anti_pattern"))' || true)
DECISIONS=$(printf '%s\n' "$FILTERED" | jq -c 'select(.type | IN("decision","dependency"))' || true)
API_BEHAVIORS=$(printf '%s\n' "$FILTERED" | jq -c 'select(.type == "api_behavior")' || true)

slurp_or_empty() {
  if [[ -z "$1" ]]; then echo '[]'
  else printf '%s\n' "$1" | jq -s '.'
  fi
}

if [[ "$JSON_MODE" == "true" ]]; then
  jq -n \
    --argjson must "$(slurp_or_empty "$MUST_FOLLOW")" \
    --argjson gotchas "$(slurp_or_empty "$GOTCHAS")" \
    --argjson patterns "$(slurp_or_empty "$PATTERNS")" \
    --argjson decisions "$(slurp_or_empty "$DECISIONS")" \
    --argjson api "$(slurp_or_empty "$API_BEHAVIORS")" \
    --argjson count "$COUNT" \
    '{facts_loaded:$count,must_follow:$must,gotchas:$gotchas,patterns:$patterns,decisions:$decisions,api_behaviors:$api}'
  exit 0
fi

# --- Human-readable output (5 categories) ---
echo "# Relevant Knowledge Base Facts"
echo ""
echo "_${COUNT} facts loaded for this context_"
echo ""

print_bucket() {
  local title="$1" body="$2" fmt="$3"
  echo "## $title"
  if [[ -z "$body" ]]; then echo "(none)"
  else printf '%s\n' "$body" | jq -r "$fmt"
  fi
  echo ""
}

print_bucket "MUST FOLLOW (Critical Rules)" "$MUST_FOLLOW" \
  '"- [" + .type + "] " + (.fact // "") + (if .recommendation then " — " + .recommendation else "" end)'
print_bucket "GOTCHAS (Common Pitfalls)" "$GOTCHAS" \
  '"- [" + .type + "] " + (.fact // "")'
print_bucket "PATTERNS (Established Best Practices)" "$PATTERNS" \
  '"- [" + .type + "] " + (.fact // "")'
print_bucket "DECISIONS (Architectural Choices)" "$DECISIONS" \
  '"- [" + .type + "] " + (.fact // "")'
print_bucket "API BEHAVIORS (External API Quirks)" "$API_BEHAVIORS" \
  '"- " + (.fact // "")'

exit 0
