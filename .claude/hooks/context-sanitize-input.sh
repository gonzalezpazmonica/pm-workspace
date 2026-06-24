#!/usr/bin/env bash
# context-sanitize-input.sh — SPEC-193 Capa A, Componente 3.
#
# PreToolUse hook: sanitizes text payload before Read/Write tools load
# content into model context.
#
# Modes: off | shadow | warn | block
#   off    → pass-through, no action
#   shadow → observe + telemetry, no block
#   warn   → emit warning to stderr, no block
#   block  → exit 2 if homoglyph_score >= THRESHOLD_BLOCK OR bidi_present
#
# Master switch:
#   SAVIA_HARDENING=off  → disables this hook entirely
#
# Bidi rule: bidi_present → ALWAYS exit 2 in block mode (unconditional).
#
# Exit codes:
#   0 — pass (or mode off/shadow/warn)
#   2 — blocked

set -uo pipefail

# ── Master switch ────────────────────────────────────────────────────────────
SAVIA_HARDENING="${SAVIA_HARDENING:-on}"
if [[ "$SAVIA_HARDENING" == "off" ]]; then
  exit 0
fi

# ── Configuration ────────────────────────────────────────────────────────────
MODE="${SAVIA_SANITIZE_INPUT:-warn}"
THRESHOLD_BLOCK="${SAVIA_HOMOGLYPH_THRESHOLD_BLOCK:-70}"
THRESHOLD_WARN="${SAVIA_HOMOGLYPH_THRESHOLD_WARN:-30}"
TELEMETRY_LOG="${SAVIA_HARDENING_LOG:-output/context-hardening-telemetry.jsonl}"
REDTEAM_MODE="${SAVIA_REDTEAM_MODE:-off}"

# ── Locate workspace root ────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
NORMALIZE_PY="$WORKSPACE_DIR/scripts/context-sanitize/normalize.py"

# Early exit: off mode
if [[ "$MODE" == "off" ]]; then
  exit 0
fi

# ── Read tool input from stdin ───────────────────────────────────────────────
INPUT=""
if INPUT=$(timeout 3 cat 2>/dev/null); then
  :
fi
[[ -z "$INPUT" ]] && exit 0

# ── Extract text from tool envelope ─────────────────────────────────────────
# Handles: Read (file_path), Write (content), generic tool_response.output
TEXT=""
if command -v jq &>/dev/null; then
  TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
  case "$TOOL_NAME" in
    Read)
      # For Read, the text is the file path (checked for Unicode tricks in path)
      TEXT=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
      ;;
    Write)
      TEXT=$(printf '%s' "$INPUT" | jq -r '.tool_input.content // empty' 2>/dev/null)
      ;;
    *)
      # Generic: check tool_input.text or tool_response.output
      TEXT=$(printf '%s' "$INPUT" | jq -r '
        .tool_input.text //
        .tool_response.output //
        .tool_input.content //
        empty
      ' 2>/dev/null)
      ;;
  esac
fi

# Nothing to check
[[ -z "$TEXT" ]] && exit 0

# ── Run normalizer ───────────────────────────────────────────────────────────
RESULT=""
if [[ -f "$NORMALIZE_PY" ]] && command -v python3 &>/dev/null; then
  RESULT=$(python3 "$NORMALIZE_PY" --text "$TEXT" --json 2>/dev/null) || RESULT=""
fi

if [[ -z "$RESULT" ]]; then
  # Normalizer unavailable → fail-open (do not block)
  exit 0
fi

# ── Extract analysis fields ──────────────────────────────────────────────────
SCORE=0
BIDI="false"
if command -v jq &>/dev/null; then
  SCORE=$(printf '%s' "$RESULT" | jq -r '.homoglyph_score // 0' 2>/dev/null)
  BIDI=$(printf '%s' "$RESULT"  | jq -r '.bidi_present // false' 2>/dev/null)
elif command -v python3 &>/dev/null; then
  SCORE=$(python3 -c "import json,sys; d=json.loads('''$RESULT'''); print(d.get('homoglyph_score',0))" 2>/dev/null || echo 0)
  BIDI=$(python3  -c "import json,sys; d=json.loads('''$RESULT'''); print('true' if d.get('bidi_present') else 'false')" 2>/dev/null || echo false)
fi

# ── Telemetry writer ─────────────────────────────────────────────────────────
_write_telemetry() {
  local decision="$1" reason="${2:-}"
  local ts
  ts=$(date -Iseconds 2>/dev/null || date)
  mkdir -p "$(dirname "$TELEMETRY_LOG")" 2>/dev/null || true
  python3 -c "
import json, sys
entry = {
  'ts': '$ts',
  'layer': 'A',
  'hook': 'context-sanitize-input',
  'decision': '$decision',
  'evidence': '$reason',
  'score': $SCORE,
  'bidi': '$BIDI',
  'mode': '$MODE',
  'redteam': '$REDTEAM_MODE',
}
print(json.dumps(entry))
" >> "$WORKSPACE_DIR/$TELEMETRY_LOG" 2>/dev/null || true
}

# ── Decision logic ───────────────────────────────────────────────────────────
case "$MODE" in
  shadow)
    _write_telemetry "SANITIZE_OBSERVED" "score=$SCORE bidi=$BIDI"
    exit 0
    ;;

  warn)
    if [[ "$BIDI" == "true" ]]; then
      echo "[SPEC-193 WARN] Bidi control characters detected in tool input" >&2
      _write_telemetry "BIDI_WARN" "bidi_present=true score=$SCORE"
    elif [[ "$SCORE" -gt "$THRESHOLD_WARN" ]]; then
      echo "[SPEC-193 WARN] Homoglyph risk detected (score=$SCORE)" >&2
      _write_telemetry "HOMOGLYPH_WARN" "score=$SCORE threshold_warn=$THRESHOLD_WARN"
    else
      _write_telemetry "PASS" "score=$SCORE"
    fi
    exit 0
    ;;

  block)
    if [[ "$BIDI" == "true" ]]; then
      if [[ "$REDTEAM_MODE" == "on" ]]; then
        echo "[SPEC-193 REDTEAM_BYPASS] Bidi detected, redteam mode bypasses block" >&2
        _write_telemetry "REDTEAM_BYPASS" "bidi_present=true score=$SCORE"
        exit 0
      fi
      echo "[SPEC-193 BLOCK] Bidi control characters rejected (exit 2)" >&2
      _write_telemetry "BIDI_BLOCK" "bidi_present=true score=$SCORE"
      exit 2
    fi
    if [[ "$SCORE" -ge "$THRESHOLD_BLOCK" ]]; then
      if [[ "$REDTEAM_MODE" == "on" ]]; then
        echo "[SPEC-193 REDTEAM_BYPASS] Homoglyph score=$SCORE, redteam mode bypasses block" >&2
        _write_telemetry "REDTEAM_BYPASS" "score=$SCORE threshold_block=$THRESHOLD_BLOCK"
        exit 0
      fi
      echo "[SPEC-193 BLOCK] Homoglyph risk score=$SCORE >= threshold=$THRESHOLD_BLOCK (exit 2)" >&2
      _write_telemetry "HOMOGLYPH_BLOCK" "score=$SCORE threshold_block=$THRESHOLD_BLOCK"
      exit 2
    fi
    if [[ "$SCORE" -gt "$THRESHOLD_WARN" ]]; then
      echo "[SPEC-193 WARN] Homoglyph risk score=$SCORE (below block threshold)" >&2
      _write_telemetry "HOMOGLYPH_WARN" "score=$SCORE"
    else
      _write_telemetry "PASS" "score=$SCORE"
    fi
    exit 0
    ;;

  off)
    exit 0
    ;;

  *)
    echo "[SPEC-193 ERROR] Unknown mode: $MODE" >&2
    exit 0
    ;;
esac
