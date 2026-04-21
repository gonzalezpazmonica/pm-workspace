#!/usr/bin/env bash
# memvid-probe.sh — SE-041 Slice 1 memvid portable memory viability probe.
#
# Memvid codifica memoria semántica como video MP4 portable — 1 millón de
# documentos en ~1GB, searchable sin DB/servidor. Fit para backup portable
# de memoria Savia.
#
# Este probe verifica deps + disk + estimaciones de viabilidad. NO instala.
#
# Usage:
#   memvid-probe.sh
#   memvid-probe.sh --corpus-dir PATH       # estimar tamaño si conocido corpus
#   memvid-probe.sh --json
#
# Exit codes:
#   0 — VIABLE / NEEDS_INSTALL
#   1 — BLOCKED
#   2 — usage error
#
# Ref: SE-041, ROADMAP §Tier 3 Champions
# Safety: read-only. set -uo pipefail.

set -uo pipefail

JSON=0
CORPUS_DIR=""

usage() {
  cat <<EOF
Usage:
  $0 [--corpus-dir PATH] [--json]

Options:
  --corpus-dir PATH    Corpus para estimar memvid file size
  --json               JSON output

Probe memvid (video-encoded portable memory) viability.
Ref: SE-041.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --corpus-dir) CORPUS_DIR="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

[[ -n "$CORPUS_DIR" && ! -d "$CORPUS_DIR" ]] && { echo "ERROR: corpus-dir not found" >&2; exit 2; }

PYTHON_VERSION=""
PYTHON_MAJOR=0
MEMVID_OK=0
FFMPEG_OK=0
OPENCV_OK=0
DISK_FREE_GB=0

if command -v python3 >/dev/null 2>&1; then
  PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" 2>/dev/null)
  PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
  python3 -c "import memvid" 2>/dev/null && MEMVID_OK=1
  python3 -c "import cv2" 2>/dev/null && OPENCV_OK=1
fi
command -v ffmpeg >/dev/null 2>&1 && FFMPEG_OK=1

if command -v df >/dev/null 2>&1; then
  DISK_FREE_GB=$(df -BG "$HOME" 2>/dev/null | awk 'NR==2 {gsub("G",""); print $4}' | head -1)
  DISK_FREE_GB="${DISK_FREE_GB:-0}"
fi

# Corpus estimation
CORPUS_DOCS=0
CORPUS_MB=0
if [[ -n "$CORPUS_DIR" ]]; then
  CORPUS_DOCS=$(find "$CORPUS_DIR" -name "*.md" -type f 2>/dev/null | wc -l)
  CORPUS_MB=$(du -sm "$CORPUS_DIR" 2>/dev/null | awk '{print $1}')
  CORPUS_MB="${CORPUS_MB:-0}"
fi

VERDICT="VIABLE"
EXIT_CODE=0
REASONS=()

if [[ "$PYTHON_MAJOR" -lt 3 ]]; then
  VERDICT="BLOCKED"
  EXIT_CODE=1
  REASONS+=("Python 3 not found")
fi

MISSING=()
[[ "$MEMVID_OK" -eq 0 ]] && MISSING+=("memvid")
[[ "$FFMPEG_OK" -eq 0 ]] && MISSING+=("ffmpeg (system)")
[[ "$OPENCV_OK" -eq 0 ]] && MISSING+=("opencv-python")

if [[ ${#MISSING[@]} -gt 0 ]]; then
  [[ "$VERDICT" == "VIABLE" ]] && VERDICT="NEEDS_INSTALL"
  REASONS+=("Missing deps: ${MISSING[*]}")
fi

if [[ "${DISK_FREE_GB:-0}" -lt 2 ]]; then
  REASONS+=("disk free < 2GB (memvid output + buffer)")
fi

if [[ "$JSON" -eq 1 ]]; then
  reasons_json=""
  for r in "${REASONS[@]}"; do
    r_esc=$(echo "$r" | sed 's/"/\\"/g')
    reasons_json+="\"$r_esc\","
  done
  reasons_json="[${reasons_json%,}]"
  missing_json=$(printf '"%s",' "${MISSING[@]}")
  missing_json="[${missing_json%,}]"
  cat <<JSON
{"verdict":"$VERDICT","python_version":"$PYTHON_VERSION","memvid":$MEMVID_OK,"ffmpeg":$FFMPEG_OK,"opencv":$OPENCV_OK,"disk_free_gb":$DISK_FREE_GB,"corpus_docs":$CORPUS_DOCS,"corpus_size_mb":$CORPUS_MB,"missing_deps":$missing_json,"reasons":$reasons_json}
JSON
else
  echo "=== SE-041 memvid Viability Probe ==="
  echo ""
  echo "Python:           ${PYTHON_VERSION:-not installed}"
  echo "memvid:           $([ $MEMVID_OK -eq 1 ] && echo '✅' || echo '❌')"
  echo "ffmpeg (system):  $([ $FFMPEG_OK -eq 1 ] && echo '✅' || echo '❌')"
  echo "opencv-python:    $([ $OPENCV_OK -eq 1 ] && echo '✅' || echo '❌')"
  echo "Disk free:        ${DISK_FREE_GB}GB"
  if [[ -n "$CORPUS_DIR" ]]; then
    echo ""
    echo "Corpus estimation:"
    echo "  docs:     $CORPUS_DOCS"
    echo "  size:     ${CORPUS_MB}MB"
    # Rough: memvid ~1MB per 1000 docs
    est_mb=$((CORPUS_DOCS / 1000))
    [[ "$est_mb" -lt 1 ]] && est_mb=1
    echo "  estimated memvid: ~${est_mb}MB MP4"
  fi
  echo ""
  echo "VERDICT: $VERDICT"
  for r in "${REASONS[@]}"; do
    echo "  • $r"
  done
  echo ""
  if [[ "$VERDICT" == "NEEDS_INSTALL" ]]; then
    echo "Install:"
    echo "  sudo apt install ffmpeg"
    echo "  pip install memvid opencv-python"
  fi
fi

exit $EXIT_CODE
