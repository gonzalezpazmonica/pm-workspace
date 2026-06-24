#!/usr/bin/env bash
# memory-write-sanitize.sh — SPEC-193 Capa A, Componente 4.
#
# PreToolUse hook: sanitizes content before memory-store save operations.
# Blocks entries with homoglyph_score > 70 or bidi_present in warn/block mode.
#
# Modes (SAVIA_MEMORY_WRITE_SANITIZE):
#   off   → pass-through
#   warn  → warn to stderr, do not block
#   block → exit 2 if score > 70 OR bidi_present
#
# Master switch: SAVIA_HARDENING=off → disables entirely.
#
# Exit codes:
#   0 — pass
#   2 — blocked

set -uo pipefail

# ── Master switch ────────────────────────────────────────────────────────────
SAVIA_HARDENING="${SAVIA_HARDENING:-on}"
if [[ "$SAVIA_HARDENING" == "off" ]]; then
  exit 0
fi

# ── Configuration ────────────────────────────────────────────────────────────
MODE="${SAVIA_MEMORY_WRITE_SANITIZE:-warn}"
TELEMETRY_LOG="${SAVIA_HARDENING_LOG:-output/context-hardening-telemetry.jsonl}"
REDTEAM_MODE="${SAVIA_REDTEAM_MODE:-off}"
BLOCK_THRESHOLD=70  # fixed per spec

# ── Locate workspace root ────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
NORMALIZE_PY="$WORKSPACE_DIR/scripts/context-sanitize/normalize.py"

if [[ "$MODE" == "off" ]]; then
  exit 0
fi

# ── Read stdin ───────────────────────────────────────────────────────────────
INPUT=""
if INPUT=$(timeout 3 cat 2>/dev/null); then
  :
fi
[[ -z "$INPUT" ]] && exit 0

# ── Extract text content from memory-store call ───────────────────────────────
# memory-store.sh is called as: bash scripts/memory-store.sh save "key" "content"
# Hook receives the Bash tool call envelope.
TEXT=""
if command -v jq &>/dev/null; then
  TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
  CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

  # Only act on memory-store save operations
  if [[ "$TOOL_NAME" != "Bash" ]]; then
    exit 0
  fi
  if [[ "$CMD" != *"memory-store"* && "$CMD" != *"memory_store"* ]]; then
    exit 0
  fi
  if [[ "$CMD" != *"save"* ]]; then
    exit 0
  fi

  # Extract the content argument (third positional after save)
  TEXT=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
else
  # No jq: try to get raw command text
  TEXT=$(python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
cmd = d.get('tool_input', {}).get('command', '')
if 'memory-store' in cmd or 'memory_store' in cmd:
    print(cmd)
" <<< "$INPUT" 2>/dev/null || echo "")
fi

[[ -z "$TEXT" ]] && exit 0

# ── Run normalizer ───────────────────────────────────────────────────────────
RESULT=""
if [[ -f "$NORMALIZE_PY" ]] && command -v python3 &>/dev/null; then
  RESULT=$(python3 "$NORMALIZE_PY" --text "$TEXT" --json 2>/dev/null) || RESULT=""
fi

[[ -z "$RESULT" ]] && exit 0

# ── Extract fields ────────────────────────────────────────────────────────────
SCORE=0
BIDI="false"
if command -v jq &>/dev/null; then
  SCORE=$(printf '%s' "$RESULT" | jq -r '.homoglyph_score // 0' 2>/dev/null)
  BIDI=$(printf '%s' "$RESULT"  | jq -r '.bidi_present // false' 2>/dev/null)
fi

# ── Telemetry ─────────────────────────────────────────────────────────────────
_write_telemetry() {
  local decision="$1" reason="${2:-}"
  local ts
  ts=$(date -Iseconds 2>/dev/null || date)
  mkdir -p "$(dirname "$WORKSPACE_DIR/$TELEMETRY_LOG")" 2>/dev/null || true
  python3 -c "
import json
entry = {
  'ts': '$ts',
  'layer': 'A',
  'hook': 'memory-write-sanitize',
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

# ── Decision ──────────────────────────────────────────────────────────────────
_should_block() {
  [[ "$BIDI" == "true" ]] && return 0
  [[ "$SCORE" -gt "$BLOCK_THRESHOLD" ]] && return 0
  return 1
}

case "$MODE" in
  warn)
    if _should_block; then
      echo "[SPEC-193 WARN] memory-write-sanitize: risk detected (score=$SCORE bidi=$BIDI)" >&2
      _write_telemetry "MEMORY_WRITE_WARN" "score=$SCORE bidi=$BIDI"
    else
      _write_telemetry "PASS" "score=$SCORE"
    fi
    exit 0
    ;;

  block)
    if _should_block; then
      if [[ "$REDTEAM_MODE" == "on" ]]; then
        echo "[SPEC-193 REDTEAM_BYPASS] memory-write blocked but redteam mode active" >&2
        _write_telemetry "REDTEAM_BYPASS" "score=$SCORE bidi=$BIDI"
        exit 0
      fi
      if [[ "$BIDI" == "true" ]]; then
        echo "[SPEC-193 BLOCK] memory-write rejected: bidi_present=true (exit 2)" >&2
        _write_telemetry "MEMORY_WRITE_BLOCK" "bidi_present=true score=$SCORE"
      else
        echo "[SPEC-193 BLOCK] memory-write rejected: homoglyph score=$SCORE > $BLOCK_THRESHOLD (exit 2)" >&2
        _write_telemetry "MEMORY_WRITE_BLOCK" "score=$SCORE threshold=$BLOCK_THRESHOLD"
      fi
      exit 2
    fi
    _write_telemetry "PASS" "score=$SCORE"
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
