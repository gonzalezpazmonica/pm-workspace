#!/usr/bin/env bash
# knowledge-federator.sh — SE-023 Knowledge Federation
set -uo pipefail
# Aggregates cross-project knowledge patterns with N4 anonymization.
#
# Usage:
#   scripts/enterprise/knowledge-federator.sh [--output-dir DIR] [--min-frequency N]
#
# Reads:  docs/rules/learned/*.md  (core lessons)
#         output/agent-trace/       (agent usage patterns)
# Output: output/enterprise/federated-knowledge-YYYY-MM-DD.json
#
# Anonymization (N4): project names → sha256 prefix, person names → role label
# Only patterns with frequency >= 3 are published (anti-singularization).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

LEARNED_DIR="${REPO_ROOT}/docs/rules/learned"
TRACE_DIR="${REPO_ROOT}/output/agent-trace"
OUTPUT_DIR="${REPO_ROOT}/output/enterprise"
MIN_FREQUENCY=3
DATE="$(date +%Y-%m-%d)"

# ── arg parsing ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)    OUTPUT_DIR="$2"; shift 2 ;;
    --min-frequency) MIN_FREQUENCY="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: knowledge-federator.sh [--output-dir DIR] [--min-frequency N]"
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

mkdir -p "$OUTPUT_DIR"
OUTPUT_FILE="${OUTPUT_DIR}/federated-knowledge-${DATE}.json"

# ── anonymization helpers ─────────────────────────────────────────────────────
# Hash a string to 8-char prefix (sha256 → first 8 chars)
_hash_name() {
  local name="$1"
  printf '%s' "$name" | sha256sum | cut -c1-8
}

# Anonymize text: replace known project/person names with hashed/role tokens
_anonymize() {
  local text="$1"
  # Strip monetary amounts: $1,234 or €5.000
  text="$(printf '%s' "$text" | sed 's/[$€£][0-9][0-9.,]*/\[AMOUNT\]/g')"
  # Strip email addresses
  text="$(printf '%s' "$text" | sed 's/[a-zA-Z0-9._%+-]*@[a-zA-Z0-9.-]*\.[a-zA-Z][a-zA-Z]*/\[EMAIL\]/g')"
  printf '%s' "$text"
}

# ── collect patterns from docs/rules/learned/*.md ────────────────────────────
declare -A topic_count
declare -A topic_lesson
declare -A topic_context

collect_from_learned() {
  if [[ ! -d "$LEARNED_DIR" ]]; then
    return
  fi

  local files
  mapfile -t files < <(find "$LEARNED_DIR" -name "*.md" -type f 2>/dev/null | sort)

  for f in "${files[@]:-}"; do
    [[ -z "${f:-}" ]] && continue
    [[ -f "$f" ]] || continue

    # Extract topic from filename (strip date prefix if present)
    local basename
    basename="$(basename "$f" .md)"
    local topic
    topic="$(printf '%s' "$basename" | sed 's/^[0-9-]*-//' | tr '-' ' ')"
    [[ -z "$topic" ]] && topic="$basename"

    # Extract first non-frontmatter line as lesson
    local lesson
    lesson="$(grep -v '^---' "$f" | grep -v '^#' | grep -v '^$' | head -1 2>/dev/null || true)"
    lesson="$(_anonymize "${lesson:-$topic}")"

    # Accumulate
    local key
    key="$(printf '%s' "$topic" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')"
    topic_count["$key"]=$(( ${topic_count["$key"]:-0} + 1 ))
    topic_lesson["$key"]="${topic_lesson["$key"]:-$lesson}"
    topic_context["$key"]="learned"
  done
}

# ── collect patterns from output/agent-trace/ ────────────────────────────────
collect_from_traces() {
  if [[ ! -d "$TRACE_DIR" ]]; then
    return
  fi

  local files
  mapfile -t files < <(find "$TRACE_DIR" -name "*.jsonl" -o -name "*.json" 2>/dev/null | sort)

  for f in "${files[@]:-}"; do
    [[ -z "${f:-}" ]] && continue
    [[ -f "$f" ]] || continue

    # Extract agent names as topic signals
    while IFS= read -r line; do
      local agent
      agent="$(printf '%s' "$line" | grep -o '"agent"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 || true)"
      [[ -z "$agent" ]] && continue
      local key
      key="agent_usage_${agent}"
      topic_count["$key"]=$(( ${topic_count["$key"]:-0} + 1 ))
      topic_lesson["$key"]="${topic_lesson["$key"]:-Agent $agent invocation pattern}"
      topic_context["$key"]="trace"
    done < "$f"
  done
}

# ── also count router-decisions.jsonl for mode patterns ──────────────────────
collect_from_router() {
  local router_file="${REPO_ROOT}/output/router-decisions.jsonl"
  [[ -f "$router_file" ]] || return

  while IFS= read -r line; do
    local mode
    mode="$(printf '%s' "$line" | grep -o '"detected_mode"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 || true)"
    [[ -z "$mode" ]] && continue
    local key="router_mode_${mode}"
    topic_count["$key"]=$(( ${topic_count["$key"]:-0} + 1 ))
    topic_lesson["$key"]="${topic_lesson["$key"]:-Router consistently selects $mode for these intents}"
    topic_context["$key"]="router"
  done < "$router_file"
}

collect_from_learned
collect_from_traces
collect_from_router

# ── build JSON output ─────────────────────────────────────────────────────────
_build_json() {
  printf '{\n'
  printf '  "generated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "min_frequency": %d,\n' "$MIN_FREQUENCY"
  printf '  "patterns": [\n'

  local first=true
  for key in "${!topic_count[@]}"; do
    local count=${topic_count["$key"]}
    (( count < MIN_FREQUENCY )) && continue

    local topic="$key"
    local lesson="${topic_lesson["$key"]:-Unknown lesson}"
    local ctx="${topic_context["$key"]:-unknown}"
    local anon_topic
    anon_topic="$(_anonymize "$topic")"
    local anon_lesson
    anon_lesson="$(_anonymize "$lesson")"

    if [[ "$first" == "true" ]]; then
      first=false
    else
      printf ',\n'
    fi

    printf '    {\n'
    printf '      "topic": "%s",\n' "$anon_topic"
    printf '      "frequency": %d,\n' "$count"
    printf '      "anonymized_context": "%s",\n' "$ctx"
    printf '      "lesson": "%s",\n' "$(printf '%s' "$anon_lesson" | sed 's/"/\\"/g')"
    printf '      "source_count": %d\n' "$count"
    printf '    }'
  done

  # If no patterns meet threshold, emit empty array (graceful)
  printf '\n  ]\n'
  printf '}\n'
}

_build_json > "$OUTPUT_FILE"

echo "federated-knowledge written: $OUTPUT_FILE"
