#!/usr/bin/env bash
# memory-canary-check.sh — SE-073 Output Filtering + Canary Tokens
# Defensa anti memory-poisoning (AgentPoison Chen 2024).
# Verifica invariantes de MEMORY.md: cap, dedup, formato, canary.
set -uo pipefail

MEMORY_DIR="${SAVIA_MEMORY_DIR:-${HOME}/.savia-memory}/auto"
INDEX="${MEMORY_DIR}/MEMORY.md"
CANARY_FILE="${MEMORY_DIR}/.canary"
SOFT_CAP="${MEMORY_INDEX_SOFT_CAP:-200}"
SIZE_CAP_BYTES=25600
JSON=0
ROTATE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=1; shift ;;
    --rotate) ROTATE=1; shift ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown arg" >&2; exit 2 ;;
  esac
done

if [[ "$ROTATE" -eq 1 ]]; then
  [[ ! -d "$MEMORY_DIR" ]] && mkdir -p "$MEMORY_DIR"
  RAND=$(openssl rand -hex 4 2>/dev/null || dd if=/dev/urandom bs=4 count=1 2>/dev/null | xxd -p | tr -d '\n')
  CANARY="MEMORY_INDEX_CANARY_$(date +%Y%m%d)_${RAND}"
  {
    echo "$CANARY"
    echo "issued_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "purpose: anti memory-poisoning verification (SE-073)"
    echo "verified_by: scripts/memory-canary-check.sh"
  } > "$CANARY_FILE"
  chmod 600 "$CANARY_FILE"
  echo "Canary rotated: $CANARY"
  exit 0
fi

ERRORS=()
LINES=0
SIZE=0
TOKEN=""

if [[ ! -f "$CANARY_FILE" ]]; then
  ERRORS+=("canary_missing")
else
  TOKEN=$(head -1 "$CANARY_FILE" 2>/dev/null || echo "")
  if [[ ! "$TOKEN" =~ ^MEMORY_INDEX_CANARY_[0-9]{8}_[a-f0-9]+$ ]]; then
    ERRORS+=("canary_token_malformed")
  fi
fi

if [[ ! -f "$INDEX" ]]; then
  ERRORS+=("index_missing")
else
  LINES=$(wc -l < "$INDEX" 2>/dev/null || echo 0)
  [[ "$LINES" -gt "$SOFT_CAP" ]] && ERRORS+=("lines_over_cap:$LINES/$SOFT_CAP")
  SIZE=$(stat -c%s "$INDEX" 2>/dev/null || stat -f%z "$INDEX" 2>/dev/null || echo 0)
  [[ "$SIZE" -gt "$SIZE_CAP_BYTES" ]] && ERRORS+=("size_over_cap:${SIZE}B")
  grep -q "ENTRIES_START" "$INDEX" || ERRORS+=("entries_start_missing")
  grep -q "ENTRIES_END" "$INDEX" || ERRORS+=("entries_end_missing")
  DUPS=$(grep -oE '\[[^]]+\]' "$INDEX" 2>/dev/null | sort | uniq -c | awk '$1 > 1 {sum += $1 - 1} END {print sum+0}')
  [[ "${DUPS:-0}" -gt 0 ]] && ERRORS+=("topic_key_duplicates:$DUPS")
  MALFORMED=$(awk '
    /ENTRIES_START/ {flag=1; next}
    /ENTRIES_END/ {flag=0}
    flag && /^- / {
      if ($0 !~ /^- [a-zA-Z_-]+: .+ \[[^][]+\][[:space:]]*$/) print
    }
  ' "$INDEX" | wc -l)
  [[ "${MALFORMED:-0}" -gt 0 ]] && ERRORS+=("malformed_entries:$MALFORMED")
fi

if [[ "${#ERRORS[@]}" -eq 0 ]]; then
  if [[ "$JSON" -eq 1 ]]; then
    printf '{"verdict":"PASS","lines":%d,"size":%d,"cap":%d}\n' "$LINES" "$SIZE" "$SOFT_CAP"
  else
    echo "memory-canary-check: PASS"
    echo "  index: $INDEX"
    echo "  lines: $LINES / $SOFT_CAP"
    echo "  size:  $SIZE / $SIZE_CAP_BYTES bytes"
    echo "  canary: $TOKEN"
  fi
  exit 0
else
  if [[ "$JSON" -eq 1 ]]; then
    err_json="["
    for i in "${!ERRORS[@]}"; do
      [[ $i -gt 0 ]] && err_json="${err_json},"
      err_json="${err_json}\"${ERRORS[$i]}\""
    done
    err_json="${err_json}]"
    printf '{"verdict":"FAIL","errors":%s}\n' "$err_json"
  else
    echo "memory-canary-check: FAIL" >&2
    for e in "${ERRORS[@]}"; do echo "  - $e" >&2; done
    echo "" >&2
    echo "Fix: bash scripts/memory-hygiene.sh" >&2
  fi
  exit 1
fi
