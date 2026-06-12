#!/usr/bin/env bash
set -uo pipefail
# sycophancy-strip.sh — SPEC-192 Layer 1: deterministic adulation hook.
#
# Inspects LLM output (PostToolUse Task envelope or piped text) and applies
# the configured action when adulation patterns match. Layer 1 is regex-only,
# fast (<50ms), no LLM judge involved. Layer 2 (sycophancy-judge) handles
# semantic detection.
#
# Modes (SAVIA_ANTIADULATION_LAYER1):
#   off     — hook disabled completely.
#   shadow  — telemetry only, no stderr, no exit code change. (DEFAULT)
#   warn    — telemetry + stderr advisory.
#   strip   — replace matched span with empty in stdout (for downstream).
#   block   — exit 2 if score >= 85 AND position < 50.
#
# Master switch: SAVIA_ANTIADULATION=off disables everything.
#
# Telemetry: output/anti-adulation-telemetry.jsonl (one JSON per invocation).
#
# Ref: SPEC-192 docs/propuestas/SPEC-192-anti-adulation-illusory-truth.md

if [[ -f "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh" ]]; then
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh" 2>/dev/null || true
fi
export CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-${SAVIA_WORKSPACE_DIR:-$(pwd)}}"

MASTER="${SAVIA_ANTIADULATION:-on}"
[[ "$MASTER" == "off" ]] && exit 0

MODE="${SAVIA_ANTIADULATION_LAYER1:-shadow}"
case "$MODE" in
  off|shadow|warn|strip|block) ;;
  *) MODE="shadow" ;;
esac
[[ "$MODE" == "off" ]] && exit 0

LOG_FILE="${CLAUDE_PROJECT_DIR}/output/anti-adulation-telemetry.jsonl"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

log_telemetry() {
  # Args: layer decision score category pattern position draft_len
  local layer="$1" decision="$2" score="$3" category="$4" pattern="$5" position="$6" draft_len="$7"
  if command -v jq >/dev/null 2>&1; then
    jq -nc \
      --arg ts "$(date -Iseconds 2>/dev/null || date)" \
      --arg mode "$MODE" \
      --arg layer "$layer" \
      --arg decision "$decision" \
      --arg score "$score" \
      --arg category "$category" \
      --arg pattern "$pattern" \
      --arg position "$position" \
      --arg draft_len "$draft_len" \
      '{ts:$ts, mode:$mode, layer:($layer|tonumber? // 1), decision:$decision, score:($score|tonumber? // 0), category:$category, pattern:$pattern, position:($position|tonumber? // -1), draft_len:($draft_len|tonumber? // 0)}' \
      >> "$LOG_FILE" 2>/dev/null || true
  fi
}

command -v jq >/dev/null 2>&1 || exit 0

# Read input. If stdin has a JSON envelope (hook context), extract draft.
# Otherwise, treat stdin as raw draft text.
INPUT=""
if [[ ! -t 0 ]]; then
  INPUT=$(cat 2>/dev/null || true)
fi
[[ -z "$INPUT" ]] && exit 0

DRAFT=""
# Try to parse as PostToolUse JSON envelope
if printf "%s" "$INPUT" | jq -e . >/dev/null 2>&1; then
  DRAFT=$(printf "%s" "$INPUT" | jq -r ".tool_response.output // .tool_input.text // empty" 2>/dev/null)
fi
# Fallback: treat raw input as draft
[[ -z "$DRAFT" ]] && DRAFT="$INPUT"
[[ -z "$DRAFT" ]] && exit 0

DRAFT_LEN=${#DRAFT}

# Locate detector
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECTOR="$HOOK_DIR/../../scripts/anti-adulation/lexical-strip.py"
PATTERNS="${SAVIA_ANTIADULATION_PATTERNS:-$HOOK_DIR/../../scripts/anti-adulation/regex-patterns.json}"

if [[ ! -f "$DETECTOR" || ! -f "$PATTERNS" ]]; then
  exit 0  # fail-open
fi

# Run detector
RESULT=$(python3 "$DETECTOR" --draft "$DRAFT" --patterns "$PATTERNS" --json 2>/dev/null)
if [[ -z "$RESULT" ]] || ! printf "%s" "$RESULT" | jq -e . >/dev/null 2>&1; then
  exit 0  # fail-open
fi

SCORE=$(printf "%s" "$RESULT" | jq -r ".score // 0")
CATEGORY=$(printf "%s" "$RESULT" | jq -r ".category // \"none\"")
PATTERN=$(printf "%s" "$RESULT" | jq -r ".pattern // \"\"")
POSITION=$(printf "%s" "$RESULT" | jq -r ".position // -1")

if [[ "$SCORE" -eq 0 ]]; then
  log_telemetry "1" "PASS" "0" "none" "" "-1" "$DRAFT_LEN"
  exit 0
fi

case "$MODE" in
  shadow)
    log_telemetry "1" "SHADOW_DETECTED" "$SCORE" "$CATEGORY" "$PATTERN" "$POSITION" "$DRAFT_LEN"
    exit 0
    ;;
  warn)
    log_telemetry "1" "WARN" "$SCORE" "$CATEGORY" "$PATTERN" "$POSITION" "$DRAFT_LEN"
    printf "[anti-adulation L1] WARN: pattern matched (score=%s pos=%s category=%s)\n" \
      "$SCORE" "$POSITION" "$CATEGORY" >&2
    exit 0
    ;;
  strip)
    log_telemetry "1" "STRIPPED" "$SCORE" "$CATEGORY" "$PATTERN" "$POSITION" "$DRAFT_LEN"
    printf "%s" "$RESULT" | jq -r ".stripped"
    exit 0
    ;;
  block)
    if [[ "$SCORE" -ge 85 && "$POSITION" -ge 0 && "$POSITION" -lt 50 ]]; then
      log_telemetry "1" "BLOCKED" "$SCORE" "$CATEGORY" "$PATTERN" "$POSITION" "$DRAFT_LEN"
      cat >&2 <<EOF

[anti-adulation SPEC-192 Layer 1]
Adulation pattern detected at position $POSITION (score=$SCORE):
  pattern : $PATTERN
  category: $CATEGORY

ACTION: regenerate the response without the opening adulation phrase.
The substance of the answer is fine; only the social validation needs to go.

Bypass for this turn: SAVIA_ANTIADULATION_LAYER1=warn (advisory only)
Disable globally  : SAVIA_ANTIADULATION=off
EOF
      exit 2
    fi
    log_telemetry "1" "BELOW_BLOCK_THRESHOLD" "$SCORE" "$CATEGORY" "$PATTERN" "$POSITION" "$DRAFT_LEN"
    exit 0
    ;;
esac
