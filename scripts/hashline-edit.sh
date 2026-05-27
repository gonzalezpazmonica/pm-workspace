#!/usr/bin/env bash
# hashline-edit.sh — Safe edit wrapper with stale-file protection (SE-149)
#
# Usage: bash scripts/hashline-edit.sh <file_path> <old_string> <new_string>
#
# Exit codes:
#   0  — edit applied successfully
#   1  — file stale (hash mismatch — should not happen in normal flow, useful for testing)
#   2  — old_string not found in file
#   3  — internal error
#
# Log: /tmp/hashline-edits.log
# Ref: SE-149, docs/rules/domain/hashline-edit-protocol.md

set -uo pipefail

LOG_FILE="${HASHLINE_LOG:-/tmp/hashline-edits.log}"
GUARD_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/hashline-guard.sh"

_die() { echo "ERROR: $*" >&2; exit 3; }
_log() {
  local ts; ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  printf '%s\t%s\n' "$ts" "$*" >> "$LOG_FILE"
}

FILE="${1:-}"
OLD_STRING="${2:-}"
NEW_STRING="${3:-}"

[[ -z "$FILE" || -z "$OLD_STRING" ]] && _die "Usage: hashline-edit.sh <file> <old_string> <new_string>"
[[ -f "$FILE" ]] || _die "file not found: $FILE"

# ── 1. Verify old_string exists ───────────────────────────────────────────────

FIRST_LINE=$(printf '%s' "$OLD_STRING" | head -1)
MATCH_LINENO=$(grep -nF -- "$FIRST_LINE" "$FILE" | awk -F: '{print $1}' | head -1)

if [[ -z "$MATCH_LINENO" ]]; then
  _log "FAIL\tfile=$FILE\tstatus=old_string_not_found"
  exit 2
fi

# ── 2. Generate anchor hash ───────────────────────────────────────────────────

OLD_LINE_COUNT=$(printf '%s' "$OLD_STRING" | wc -l)
CENTER_OFFSET=$(( (OLD_LINE_COUNT - 1) / 2 ))
CENTER_LINENO=$(( MATCH_LINENO + CENTER_OFFSET ))

ANCHOR_OUT=$(bash "$GUARD_SCRIPT" anchor "$FILE" "$CENTER_LINENO")
OLD_HASH=$(printf '%s' "$ANCHOR_OUT" | head -1)

# ── 3. Re-verify hash (guard check) ───────────────────────────────────────────
# Extract anchor_text from file (3-line context)
TOTAL=$(wc -l < "$FILE")
START=$(( CENTER_LINENO - 1 )); [[ $START -lt 1 ]] && START=1
END=$(( CENTER_LINENO + 1 ));   [[ $END -gt $TOTAL ]] && END=$TOTAL
ANCHOR_TEXT=$(sed -n "${START},${END}p" "$FILE")

bash "$GUARD_SCRIPT" check "$FILE" "$ANCHOR_TEXT" "$OLD_HASH"
CHECK_EXIT=$?

if [[ $CHECK_EXIT -eq 1 ]]; then
  _log "FAIL\tfile=$FILE\told_hash=$OLD_HASH\tstatus=stale"
  exit 1
elif [[ $CHECK_EXIT -eq 2 ]]; then
  _log "FAIL\tfile=$FILE\tstatus=anchor_not_found"
  exit 2
fi

# ── 4. Apply edit (python for safe multiline replace) ────────────────────────

python3 - <<PYEOF
import sys, pathlib

file_path = """$FILE"""
old_str   = """$OLD_STRING"""
new_str   = """$NEW_STRING"""

content = pathlib.Path(file_path).read_text()
if old_str not in content:
    print(f"ERROR: old_string not in file after guard passed", file=sys.stderr)
    sys.exit(2)
new_content = content.replace(old_str, new_str, 1)
pathlib.Path(file_path).write_text(new_content)
PYEOF

EDIT_EXIT=$?

if [[ $EDIT_EXIT -ne 0 ]]; then
  _log "FAIL\tfile=$FILE\told_hash=$OLD_HASH\tstatus=apply_failed"
  exit 3
fi

# ── 5. Compute new hash & log ─────────────────────────────────────────────────

NEW_ANCHOR_OUT=$(bash "$GUARD_SCRIPT" anchor "$FILE" "$CENTER_LINENO" 2>/dev/null || true)
NEW_HASH=$(printf '%s' "$NEW_ANCHOR_OUT" | head -1)

_log "OK\tfile=$FILE\told_hash=$OLD_HASH\tnew_hash=${NEW_HASH:-unknown}\tstatus=applied"
echo "OK: edit applied to $FILE"
