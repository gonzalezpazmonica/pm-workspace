#!/usr/bin/env bash
# memory-tier-rotate.sh — SE-073 Slice 1 — 2-tier rotation for auto-memory
#
# Reads all memory files in MEMORY_DIR, classifies into:
#   Tier A (high-freq, inline in MEMORY.md, hard-cap MEMORY_TIER_A_CAP entries)
#   Tier B (low-freq, filename-only in MEMORY-ARCHIVE.md)
#
# Algorithm:
#   1. Each memory file has frontmatter with access_count + last_access
#   2. Compute score = access_count + recency_bonus (last_access < 30d → +3)
#   3. Top N by score → Tier A (default cap 30)
#   4. Rest → Tier B
#
# Env:
#   MEMORY_DIR (default: ~/.claude/projects/-home-monica-claude/memory)
#   MEMORY_TIER_A_CAP (default: 30)
#   MEMORY_TIER_DRY_RUN (default: 0; set 1 to print without writing)
#
# Usage:
#   bash scripts/memory-tier-rotate.sh           # rotate
#   bash scripts/memory-tier-rotate.sh --dry-run # preview
#   bash scripts/memory-tier-rotate.sh --status  # show current tier distribution
#
# Reference: docs/propuestas/SE-073-memory-index-cap-tiered.md

set -uo pipefail

MEMORY_DIR="${MEMORY_DIR:-$HOME/.claude/projects/-home-monica-claude/memory}"
MEMORY_TIER_A_CAP="${MEMORY_TIER_A_CAP:-30}"
MEMORY_TIER_DRY_RUN="${MEMORY_TIER_DRY_RUN:-0}"

INDEX_FILE="${MEMORY_DIR}/MEMORY.md"
ARCHIVE_FILE="${MEMORY_DIR}/MEMORY-ARCHIVE.md"
TODAY=$(date -u +"%Y-%m-%d")

usage() {
  cat <<USG
Usage: memory-tier-rotate.sh [--dry-run|--status|--help]

  --dry-run   Preview rotation without writing files
  --status    Show current tier distribution
  --help      Show this help

Env:
  MEMORY_DIR              ${MEMORY_DIR}
  MEMORY_TIER_A_CAP       ${MEMORY_TIER_A_CAP}
USG
}

case "${1:-}" in
  --help|-h) usage; exit 0 ;;
  --dry-run) MEMORY_TIER_DRY_RUN=1 ;;
  --status) MEMORY_TIER_DRY_RUN=1; STATUS_ONLY=1 ;;
  "") ;;
  *) echo "Unknown arg: $1" >&2; usage >&2; exit 2 ;;
esac

if [[ ! -d "${MEMORY_DIR}" ]]; then
  echo "ERROR: MEMORY_DIR no existe: ${MEMORY_DIR}" >&2
  exit 1
fi

# Read frontmatter field from a memory file (returns empty if missing)
read_field() {
  local file="$1" field="$2"
  awk -v field="^${field}:" '/^---$/{c++; next} c==1 && $0~field {sub(field, ""); gsub(/^[[:space:]]*"?|"?[[:space:]]*$/, ""); print; exit} c==2{exit}' "${file}"
}

# Compute days since YYYY-MM-DD; returns 9999 if invalid
days_since() {
  local date_str="$1"
  if [[ ! "${date_str}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo 9999; return
  fi
  local then_epoch now_epoch
  then_epoch=$(date -d "${date_str}" +%s 2>/dev/null) || { echo 9999; return; }
  now_epoch=$(date +%s)
  echo $(( (now_epoch - then_epoch) / 86400 ))
}

# Score: access_count + recency_bonus + pin_bonus
#   pin: true               → +999 (always Tier A)
#   last_access < 30d       → +3
#   filename starts user_   → +500 (foundational identity, near-pin)
compute_score() {
  local access_count="$1" last_access="$2" pin="$3" basename="$4"
  local count=${access_count:-0}
  [[ "${count}" =~ ^[0-9]+$ ]] || count=0
  local days; days=$(days_since "${last_access}")
  local bonus=0
  if [[ "${days}" -lt 30 ]]; then bonus=3; fi
  local pin_bonus=0
  if [[ "${pin}" == "true" ]]; then pin_bonus=999; fi
  local identity_bonus=0
  if [[ "${basename}" == user_* ]]; then identity_bonus=500; fi
  echo $((count + bonus + pin_bonus + identity_bonus))
}

# Collect all memory files (excluding MEMORY.md, MEMORY-ARCHIVE.md, session-journal.md)
collect_files() {
  find "${MEMORY_DIR}" -maxdepth 1 -type f -name '*.md' \
    -not -name 'MEMORY.md' \
    -not -name 'MEMORY-ARCHIVE.md' \
    -not -name 'session-journal.md' \
    | sort
}

# Build sorted list: "<score>\t<filename>\t<description>"
build_index() {
  local files; files=$(collect_files)
  while IFS= read -r file; do
    [[ -z "${file}" ]] && continue
    local basename; basename=$(basename "${file}")
    local access_count last_access pin description mtime score
    access_count=$(read_field "${file}" "access_count")
    last_access=$(read_field "${file}" "last_access")
    pin=$(read_field "${file}" "pin")
    description=$(read_field "${file}" "description")
    mtime=$(stat -c %Y "${file}" 2>/dev/null || stat -f %m "${file}" 2>/dev/null || echo 0)
    score=$(compute_score "${access_count}" "${last_access}" "${pin}" "${basename}")
    # Truncate description to 150 chars
    if [[ ${#description} -gt 150 ]]; then
      description="${description:0:147}..."
    fi
    printf "%d\t%d\t%s\t%s\n" "${score}" "${mtime}" "${basename}" "${description}"
  done <<< "${files}" | sort -t$'\t' -k1,1nr -k2,2nr -k3,3
}

INDEX_DATA=$(build_index)
TOTAL_FILES=$(printf '%s' "${INDEX_DATA}" | grep -c . 2>/dev/null || true)
TOTAL_FILES=${TOTAL_FILES:-0}

if [[ "${TOTAL_FILES}" -eq 0 ]]; then
  echo "memory-tier-rotate: no hay memory files en ${MEMORY_DIR}"
  exit 0
fi

# Top N → Tier A; rest → Tier B
TIER_A=$(echo "${INDEX_DATA}" | head -n "${MEMORY_TIER_A_CAP}")
TIER_B=$(echo "${INDEX_DATA}" | tail -n +$((MEMORY_TIER_A_CAP + 1)))
TIER_A_COUNT=$(printf '%s' "${TIER_A}" | grep -c . 2>/dev/null || true)
TIER_A_COUNT=${TIER_A_COUNT:-0}
TIER_B_COUNT=$(printf '%s' "${TIER_B}" | grep -c . 2>/dev/null || true)
TIER_B_COUNT=${TIER_B_COUNT:-0}
[[ -z "${TIER_A}" ]] && TIER_A_COUNT=0
[[ -z "${TIER_B}" ]] && TIER_B_COUNT=0

if [[ "${MEMORY_TIER_DRY_RUN}" == "1" ]]; then
  echo "memory-tier-rotate: DRY-RUN (no se escribe)"
  echo "  total files     : ${TOTAL_FILES}"
  echo "  cap             : ${MEMORY_TIER_A_CAP}"
  echo "  Tier A (active) : ${TIER_A_COUNT}"
  echo "  Tier B (archive): ${TIER_B_COUNT}"
  if [[ "${STATUS_ONLY:-0}" == "1" ]]; then
    echo ""
    echo "=== Tier A (top ${MEMORY_TIER_A_CAP}) ==="
    echo "${TIER_A}" | awk -F'\t' '{printf "  %d\t%s\n", $1, $3}'
    if [[ "${TIER_B_COUNT}" -gt 0 ]]; then
      echo ""
      echo "=== Tier B (archive) ==="
      echo "${TIER_B}" | awk -F'\t' '{printf "  %d\t%s\n", $1, $3}'
    fi
  fi
  exit 0
fi

# Write MEMORY.md (Tier A inline, full description)
{
  while IFS=$'\t' read -r score mtime basename description; do
    [[ -z "${basename}" ]] && continue
    if [[ -n "${description}" ]]; then
      echo "- [${basename}](${basename}) — ${description}"
    else
      echo "- [${basename}](${basename})"
    fi
  done <<< "${TIER_A}"
} > "${INDEX_FILE}.tmp"
mv "${INDEX_FILE}.tmp" "${INDEX_FILE}"

# Write MEMORY-ARCHIVE.md (Tier B filename-only)
if [[ "${TIER_B_COUNT}" -gt 0 ]]; then
  {
    echo "# MEMORY-ARCHIVE — Tier B (low-freq, filename-only)"
    echo ""
    echo "> Last rotation: ${TODAY}. Carga on-demand via grep/Read del filename."
    echo ""
    while IFS=$'\t' read -r score mtime basename description; do
      [[ -z "${basename}" ]] && continue
      echo "- [${basename}](${basename})"
    done <<< "${TIER_B}"
  } > "${ARCHIVE_FILE}.tmp"
  mv "${ARCHIVE_FILE}.tmp" "${ARCHIVE_FILE}"
elif [[ -f "${ARCHIVE_FILE}" ]]; then
  : # leave existing archive alone if no demotions
fi

echo "memory-tier-rotate: rotation complete"
echo "  Tier A: ${TIER_A_COUNT} entries → ${INDEX_FILE}"
echo "  Tier B: ${TIER_B_COUNT} entries → ${ARCHIVE_FILE}"
