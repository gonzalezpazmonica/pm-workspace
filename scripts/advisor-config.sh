#!/usr/bin/env bash
# advisor-config.sh — Generate Anthropic Advisor Strategy configuration
# for the SDD agent pipeline.
#
# Usage: bash scripts/advisor-config.sh [options]
#
# Options:
#   --executor MODEL     Executor model. Default: claude-sonnet-4-6
#   --advisor MODEL      Advisor model. Default: claude-opus-4-7
#   --max-uses N         Max advisor calls per request. Default: 3
#   --enabled BOOL       Enable/disable advisor. Default: true
#   --output json|yaml   Output format. Default: json
#   --agent NAME         Agent name to look up advisor config from frontmatter
#   --agents-dir DIR     Directory containing agent .md files
#
# Environment variables (override defaults):
#   ADVISOR_ENABLED            true|false (default: true)
#   ADVISOR_MODEL              Full model ID (default: claude-opus-4-7)
#   ADVISOR_MAX_USES           Integer (default: 3)
#   ADVISOR_EXECUTOR_DEFAULT   Full model ID (default: claude-sonnet-4-6)
#
# Exit codes:
#   0  Success
#   1  Advisor disabled or agent has no advisor config
#   2  Invalid arguments
#
# Rules:
#   ADV-01: Advisor NEVER executes tools (API-level guarantee)
#   ADV-03: If advisor unsupported, caller handles the API error
#   ADV-04: If executor is already opus, skip advisor (no self-advise)
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

# Read stdin for hook compatibility
cat /dev/stdin > /dev/null 2>&1 || true

# ── Model name mapping ───────────────────────────────────────────────────────

resolve_model() {
  local short="$1"
  case "$short" in
    opus)   echo "claude-opus-4-7" ;;
    sonnet) echo "claude-sonnet-4-6" ;;
    haiku)  echo "claude-haiku-4-5-20251001" ;;
    claude-opus-4-7|claude-sonnet-4-6|claude-haiku-4-5-20251001)
      echo "$short" ;;
    *)
      echo "" ;;
  esac
}

is_opus() {
  local model="$1"
  [[ "$model" == "opus" || "$model" == "claude-opus-4-7" ]]
}

# ── Frontmatter parser ───────────────────────────────────────────────────────

# Extract a YAML field value from frontmatter between --- delimiters.
# Usage: frontmatter_field FILE FIELD
frontmatter_field() {
  local file="$1" field="$2"
  local in_fm=false value=""
  while IFS= read -r line; do
    if [[ "$line" == "---" ]]; then
      if $in_fm; then
        break
      else
        in_fm=true
        continue
      fi
    fi
    if $in_fm; then
      # Match "field: value" — handles optional quotes
      if [[ "$line" =~ ^${field}:[[:space:]]*(.*) ]]; then
        value="${BASH_REMATCH[1]}"
        # Strip surrounding quotes
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"
        echo "$value"
        return 0
      fi
    fi
  done < "$file"
  return 1
}

# ── Output formatters ────────────────────────────────────────────────────────

emit_json() {
  local model="$1" max_uses="$2"
  if command -v jq &>/dev/null; then
    jq -n \
      --arg type "advisor_20260301" \
      --arg name "advisor" \
      --arg model "$model" \
      --argjson max_uses "$max_uses" \
      '{type: $type, name: $name, model: $model, max_uses: $max_uses}'
  else
    printf '{"type":"advisor_20260301","name":"advisor","model":"%s","max_uses":%d}\n' \
      "$model" "$max_uses"
  fi
}

emit_yaml() {
  local model="$1" max_uses="$2"
  printf 'type: advisor_20260301\nname: advisor\nmodel: %s\nmax_uses: %d\n' \
    "$model" "$max_uses"
}

# ── Defaults from env ────────────────────────────────────────────────────────

ENABLED="${ADVISOR_ENABLED:-true}"
ADVISOR="${ADVISOR_MODEL:-claude-opus-4-7}"
MAX_USES="${ADVISOR_MAX_USES:-3}"
EXECUTOR="${ADVISOR_EXECUTOR_DEFAULT:-claude-sonnet-4-6}"
OUTPUT_FMT="json"
AGENT_NAME=""
AGENTS_DIR=".claude/agents"

# ── Parse CLI args ───────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --executor)
      [[ $# -lt 2 ]] && { echo "ERROR: --executor requires a value" >&2; exit 2; }
      EXECUTOR="$2"; shift 2 ;;
    --advisor)
      [[ $# -lt 2 ]] && { echo "ERROR: --advisor requires a value" >&2; exit 2; }
      ADVISOR="$2"; shift 2 ;;
    --max-uses)
      [[ $# -lt 2 ]] && { echo "ERROR: --max-uses requires a value" >&2; exit 2; }
      MAX_USES="$2"; shift 2 ;;
    --enabled)
      [[ $# -lt 2 ]] && { echo "ERROR: --enabled requires a value" >&2; exit 2; }
      ENABLED="$2"; shift 2 ;;
    --output)
      [[ $# -lt 2 ]] && { echo "ERROR: --output requires a value" >&2; exit 2; }
      OUTPUT_FMT="$2"; shift 2 ;;
    --agent)
      [[ $# -lt 2 ]] && { echo "ERROR: --agent requires a value" >&2; exit 2; }
      AGENT_NAME="$2"; shift 2 ;;
    --agents-dir)
      [[ $# -lt 2 ]] && { echo "ERROR: --agents-dir requires a value" >&2; exit 2; }
      AGENTS_DIR="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,/^# ──/{ /^#/s/^# \?//p }' "$0"
      exit 0 ;;
    *)
      echo "ERROR: Unknown option '$1'" >&2; exit 2 ;;
  esac
done

# ── Validate output format ───────────────────────────────────────────────────

if [[ "$OUTPUT_FMT" != "json" && "$OUTPUT_FMT" != "yaml" ]]; then
  echo "ERROR: --output must be 'json' or 'yaml', got '$OUTPUT_FMT'" >&2
  exit 2
fi

# ── Check enabled ────────────────────────────────────────────────────────────

if [[ "$ENABLED" != "true" ]]; then
  echo "ADVISOR_DISABLED: advisor is not enabled" >&2
  exit 1
fi

# ── Agent lookup mode ────────────────────────────────────────────────────────

if [[ -n "$AGENT_NAME" ]]; then
  AGENT_FILE="${AGENTS_DIR}/${AGENT_NAME}.md"
  if [[ ! -f "$AGENT_FILE" ]]; then
    echo "ERROR: Agent file not found: $AGENT_FILE" >&2
    exit 2
  fi

  # Read advisor field from frontmatter
  AGENT_ADVISOR="$(frontmatter_field "$AGENT_FILE" "advisor" 2>/dev/null)" || true
  if [[ -z "$AGENT_ADVISOR" ]]; then
    echo "NO_ADVISOR: agent '$AGENT_NAME' has no advisor field" >&2
    exit 1
  fi

  # Read executor model from frontmatter
  AGENT_MODEL="$(frontmatter_field "$AGENT_FILE" "model" 2>/dev/null)" || true

  # ADV-04: If executor is already opus, skip advisor
  if is_opus "${AGENT_MODEL:-}"; then
    echo "ADV-04: agent '$AGENT_NAME' executor is opus; advisor skipped" >&2
    exit 1
  fi

  # Resolve advisor model name
  ADVISOR="$(resolve_model "$AGENT_ADVISOR")"
  if [[ -z "$ADVISOR" ]]; then
    echo "ERROR: Unknown advisor model '$AGENT_ADVISOR'" >&2
    exit 2
  fi

  # Read optional max_uses override from frontmatter
  AGENT_MAX_USES="$(frontmatter_field "$AGENT_FILE" "advisor_max_uses" 2>/dev/null)" || true
  if [[ -n "$AGENT_MAX_USES" ]]; then
    MAX_USES="$AGENT_MAX_USES"
  fi

  # Set executor from agent model
  if [[ -n "$AGENT_MODEL" ]]; then
    EXECUTOR="$(resolve_model "$AGENT_MODEL")"
    [[ -z "$EXECUTOR" ]] && EXECUTOR="${AGENT_MODEL}"
  fi
fi

# ── Validate max_uses ────────────────────────────────────────────────────────

if ! [[ "$MAX_USES" =~ ^[0-9]+$ ]] || [[ "$MAX_USES" -le 0 ]]; then
  echo "ERROR: --max-uses must be a positive integer, got '$MAX_USES'" >&2
  exit 2
fi

# ── Resolve advisor model (if short name given via CLI) ──────────────────────

RESOLVED="$(resolve_model "$ADVISOR")"
if [[ -n "$RESOLVED" ]]; then
  ADVISOR="$RESOLVED"
fi

# ── ADV-04: If executor is already opus (CLI mode), skip ─────────────────────

if [[ -z "$AGENT_NAME" ]] && is_opus "$EXECUTOR"; then
  echo "ADV-04: executor is opus; advisor skipped" >&2
  exit 1
fi

# ── Emit output ──────────────────────────────────────────────────────────────

case "$OUTPUT_FMT" in
  json) emit_json "$ADVISOR" "$MAX_USES" ;;
  yaml) emit_yaml "$ADVISOR" "$MAX_USES" ;;
esac

exit 0
