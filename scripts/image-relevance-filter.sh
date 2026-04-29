#!/usr/bin/env bash
# image-relevance-filter.sh — SPEC-103 Slice 1: deterministic-first image triage primitive.
#
# Pre-Vision filter that decides if an embedded image (extracted from a docx /
# pptx / xlsx by python-docx, python-pptx, openpyxl) is worth invoking Claude
# Vision on, or whether it should be skipped as boilerplate (logos, header
# banners, icons). Heuristic-first; cache learns over use.
#
# Subcommands:
#   check <image_path>   → exit 0 (skip, irrelevant) | exit 1 (invoke Vision)
#                          + stdout JSON with reason
#   skip <image_path>    → mark this image's sha256 as known-irrelevant in cache
#   log <image_path> <decision>
#                        → append decision to cache log (decision = skip|invoke)
#                          When ≥3 'skip' decisions for same sha → auto-add to skip-list
#
# Cache layout (off-repo, per-user):
#   ~/.savia/digest-cache/images/
#   ├── skip-list.txt    one sha256 per line, known-irrelevant images
#   └── last-seen.jsonl  one decision per line, JSONL audit trail
#
# Heuristic rules (in order, first match wins):
#   1. Cache hit on skip-list                → SKIP (cache)
#   2. File size < 10 KB                     → SKIP (probable icon)
#   3. Pixel dimensions < 50x50              → SKIP (probable icon, uses identify)
#   4. Aspect ratio ≥ 8:1 OR ≤ 1:8           → SKIP (probable banner/divider)
#   5. Otherwise                             → INVOKE (Vision warranted)
#
# Exit codes:
#   0  skip (irrelevant)            check / skip / log subcommands
#   1  invoke (relevant)            check only
#   2  usage / args invalid
#   3  image file missing
#   4  cache write failed
#
# Reference: SPEC-103 (`docs/propuestas/SPEC-103-deterministic-first-digests.md`)
# Pattern source: opendataloader-pdf hybrid local-first / AI-fallback pipeline (clean-room re-implementation).

set -uo pipefail

CACHE_DIR="${SAVIA_DIGEST_CACHE_DIR:-$HOME/.savia/digest-cache/images}"
SKIP_LIST="$CACHE_DIR/skip-list.txt"
LOG_FILE="$CACHE_DIR/last-seen.jsonl"
SIZE_THRESHOLD=10240        # 10 KB
DIM_THRESHOLD=50            # 50 px on either axis
ASPECT_RATIO_LIMIT=8        # 8:1 or 1:8 considered banner/divider

usage() {
  sed -n '2,33p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
  exit 2
}

ensure_cache() {
  mkdir -p "$CACHE_DIR" 2>/dev/null || {
    echo "ERROR: cannot create cache dir $CACHE_DIR" >&2
    exit 4
  }
  touch "$SKIP_LIST" "$LOG_FILE" 2>/dev/null || {
    echo "ERROR: cannot write to cache files" >&2
    exit 4
  }
}

sha_of() {
  local f="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" | awk '{print $1}'
  else
    echo "ERROR: neither sha256sum nor shasum available" >&2
    exit 4
  fi
}

filesize_bytes() {
  local f="$1"
  if stat --format=%s "$f" >/dev/null 2>&1; then
    stat --format=%s "$f"
  else
    stat -f%z "$f"
  fi
}

pixel_dimensions() {
  # Return "WIDTHxHEIGHT" or "" if unable
  local f="$1"
  if command -v identify >/dev/null 2>&1; then
    identify -format '%wx%h' "$f" 2>/dev/null || true
  fi
}

emit_json() {
  local action="$1" reason="$2" sha="$3" size="$4" dims="$5"
  printf '{"action":"%s","reason":"%s","sha":"%s","size":%s,"dims":"%s"}\n' \
    "$action" "$reason" "$sha" "$size" "$dims"
}

# ── Subcommand: check ───────────────────────────────────────────────────────

cmd_check() {
  local img="$1"
  if [[ ! -f "$img" ]]; then
    echo "ERROR: image not found: $img" >&2
    exit 3
  fi

  ensure_cache

  local sha size dims w h ratio
  sha=$(sha_of "$img")
  size=$(filesize_bytes "$img")
  dims=$(pixel_dimensions "$img")

  # Rule 1: cache hit
  if grep -qFx "$sha" "$SKIP_LIST" 2>/dev/null; then
    emit_json "skip" "cache-hit" "$sha" "$size" "$dims"
    exit 0
  fi

  # Rule 2: tiny file size
  if [[ "$size" -lt "$SIZE_THRESHOLD" ]]; then
    emit_json "skip" "size-below-threshold" "$sha" "$size" "$dims"
    exit 0
  fi

  # Rule 3: tiny dimensions (only checked if identify is available)
  if [[ -n "$dims" ]]; then
    w="${dims%x*}"
    h="${dims#*x}"
    if [[ -n "$w" && -n "$h" && "$w" -lt "$DIM_THRESHOLD" && "$h" -lt "$DIM_THRESHOLD" ]]; then
      emit_json "skip" "dimensions-below-threshold" "$sha" "$size" "$dims"
      exit 0
    fi
    # Rule 4: extreme aspect ratio
    if [[ -n "$w" && -n "$h" && "$w" -gt 0 && "$h" -gt 0 ]]; then
      # Use awk for float math: max(w/h, h/w)
      ratio=$(awk -v w="$w" -v h="$h" 'BEGIN { r=w/h; if (r<1) r=1/r; printf "%.2f", r }')
      if awk -v r="$ratio" -v lim="$ASPECT_RATIO_LIMIT" 'BEGIN { exit !(r >= lim) }'; then
        emit_json "skip" "aspect-ratio-extreme" "$sha" "$size" "$dims"
        exit 0
      fi
    fi
  fi

  # Default: invoke Vision
  emit_json "invoke" "default-pass" "$sha" "$size" "$dims"
  exit 1
}

# ── Subcommand: skip ────────────────────────────────────────────────────────

cmd_skip() {
  local img="$1"
  if [[ ! -f "$img" ]]; then
    echo "ERROR: image not found: $img" >&2
    exit 3
  fi
  ensure_cache
  local sha
  sha=$(sha_of "$img")
  if ! grep -qFx "$sha" "$SKIP_LIST" 2>/dev/null; then
    printf '%s\n' "$sha" >> "$SKIP_LIST"
  fi
  emit_json "skip" "manual-add" "$sha" "0" ""
  exit 0
}

# ── Subcommand: log ─────────────────────────────────────────────────────────

cmd_log() {
  local img="$1" decision="${2:-}"
  if [[ ! -f "$img" ]]; then
    echo "ERROR: image not found: $img" >&2
    exit 3
  fi
  case "$decision" in
    skip|invoke) ;;
    *) echo "ERROR: decision must be 'skip' or 'invoke' (got: $decision)" >&2; exit 2 ;;
  esac
  ensure_cache
  local sha ts
  sha=$(sha_of "$img")
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  printf '{"sha":"%s","decision":"%s","timestamp":"%s","path":"%s"}\n' \
    "$sha" "$decision" "$ts" "$img" >> "$LOG_FILE"

  # Auto-add to skip list if ≥3 'skip' decisions for this sha
  if [[ "$decision" == "skip" ]]; then
    local count
    count=$(grep -F "\"sha\":\"$sha\"" "$LOG_FILE" 2>/dev/null \
            | grep -F '"decision":"skip"' | wc -l | awk '{print $1}')
    if [[ "$count" -ge 3 ]] && ! grep -qFx "$sha" "$SKIP_LIST" 2>/dev/null; then
      printf '%s\n' "$sha" >> "$SKIP_LIST"
      emit_json "skip" "auto-promoted-after-3-marks" "$sha" "0" ""
      exit 0
    fi
  fi

  emit_json "$decision" "logged" "$sha" "0" ""
  exit 0
}

# ── Dispatch ────────────────────────────────────────────────────────────────

[[ $# -lt 1 ]] && usage

case "${1:-}" in
  -h|--help) usage ;;
  check)
    [[ $# -ne 2 ]] && { echo "ERROR: check requires <image_path>" >&2; exit 2; }
    cmd_check "$2"
    ;;
  skip)
    [[ $# -ne 2 ]] && { echo "ERROR: skip requires <image_path>" >&2; exit 2; }
    cmd_skip "$2"
    ;;
  log)
    [[ $# -ne 3 ]] && { echo "ERROR: log requires <image_path> <skip|invoke>" >&2; exit 2; }
    cmd_log "$2" "$3"
    ;;
  *)
    echo "ERROR: unknown subcommand: $1" >&2
    usage
    ;;
esac
