#!/usr/bin/env bash
# bertopic-probe.sh — SE-033 Slice 1 BERTopic viability probe.
#
# Evalúa preconditions para topic-cluster skill con BERTopic
# (UMAP + HDBSCAN + c-TF-IDF) sobre corpus de retros/backlog/lessons.
# No instala nada — solo reporta.
#
# Modelo embedding referencia: all-MiniLM-L6-v2 (pequeño, rápido).
#
# Usage:
#   bertopic-probe.sh
#   bertopic-probe.sh --json
#   bertopic-probe.sh --corpus-dir projects/X/retros/
#
# Exit codes:
#   0 — VIABLE (deps + corpus ≥ 50 docs)
#   1 — NEEDS_INSTALL o corpus insuficiente
#   2 — usage error
#
# Ref: SE-033, ROADMAP §Tier 3 Champions
# Safety: read-only. set -uo pipefail.

set -uo pipefail

JSON=0
CORPUS_DIR=""
MIN_DOCS=50

usage() {
  cat <<EOF
Usage:
  $0 [--corpus-dir DIR] [--json]

Options:
  --corpus-dir DIR    Directory with .md files to audit as corpus
  --json              JSON output

Probe BERTopic viability: python deps + corpus size.
Ref: SE-033.
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

[[ -n "$CORPUS_DIR" && ! -d "$CORPUS_DIR" ]] && { echo "ERROR: corpus-dir not found: $CORPUS_DIR" >&2; exit 2; }

# Python + deps
PYTHON_VERSION=""
PYTHON_MAJOR=0
BERTOPIC_OK=0
UMAP_OK=0
HDBSCAN_OK=0
SENTENCE_TRANS=0

if command -v python3 >/dev/null 2>&1; then
  PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" 2>/dev/null)
  PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
  python3 -c "import bertopic" 2>/dev/null && BERTOPIC_OK=1
  python3 -c "import umap" 2>/dev/null && UMAP_OK=1
  python3 -c "import hdbscan" 2>/dev/null && HDBSCAN_OK=1
  python3 -c "import sentence_transformers" 2>/dev/null && SENTENCE_TRANS=1
fi

# Corpus size
CORPUS_COUNT=0
if [[ -n "$CORPUS_DIR" ]]; then
  CORPUS_COUNT=$(find "$CORPUS_DIR" -name "*.md" -type f 2>/dev/null | wc -l)
fi

VERDICT="VIABLE"
EXIT_CODE=0
REASONS=()

if [[ "$PYTHON_MAJOR" -lt 3 ]]; then
  VERDICT="BLOCKED"
  EXIT_CODE=1
  REASONS+=("Python 3 required, not found")
fi

MISSING_DEPS=()
[[ "$BERTOPIC_OK" -eq 0 ]] && MISSING_DEPS+=("bertopic")
[[ "$UMAP_OK" -eq 0 ]] && MISSING_DEPS+=("umap-learn")
[[ "$HDBSCAN_OK" -eq 0 ]] && MISSING_DEPS+=("hdbscan")
[[ "$SENTENCE_TRANS" -eq 0 ]] && MISSING_DEPS+=("sentence-transformers")

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
  VERDICT="NEEDS_INSTALL"
  EXIT_CODE=1
  REASONS+=("Missing Python deps: ${MISSING_DEPS[*]}")
fi

if [[ -n "$CORPUS_DIR" && "$CORPUS_COUNT" -lt "$MIN_DOCS" ]]; then
  [[ "$VERDICT" == "VIABLE" ]] && VERDICT="CORPUS_TOO_SMALL"
  EXIT_CODE=1
  REASONS+=("Corpus has $CORPUS_COUNT docs < min $MIN_DOCS for meaningful clusters")
fi

if [[ "$JSON" -eq 1 ]]; then
  reasons_json=""
  for r in "${REASONS[@]}"; do
    r_esc=$(echo "$r" | sed 's/"/\\"/g')
    reasons_json+="\"$r_esc\","
  done
  reasons_json="[${reasons_json%,}]"
  missing_json=$(printf '"%s",' "${MISSING_DEPS[@]}")
  missing_json="[${missing_json%,}]"
  cat <<JSON
{"verdict":"$VERDICT","python_version":"$PYTHON_VERSION","bertopic":$BERTOPIC_OK,"umap":$UMAP_OK,"hdbscan":$HDBSCAN_OK,"sentence_transformers":$SENTENCE_TRANS,"corpus_dir":"$CORPUS_DIR","corpus_count":$CORPUS_COUNT,"min_docs":$MIN_DOCS,"missing_deps":$missing_json,"reasons":$reasons_json}
JSON
else
  echo "=== SE-033 BERTopic Viability Probe ==="
  echo ""
  echo "Python:             ${PYTHON_VERSION:-not installed}"
  echo ""
  echo "Dependencies:"
  echo "  bertopic:                $([ "$BERTOPIC_OK" -eq 1 ] && echo '✅' || echo '❌')"
  echo "  umap-learn:              $([ "$UMAP_OK" -eq 1 ] && echo '✅' || echo '❌')"
  echo "  hdbscan:                 $([ "$HDBSCAN_OK" -eq 1 ] && echo '✅' || echo '❌')"
  echo "  sentence-transformers:   $([ "$SENTENCE_TRANS" -eq 1 ] && echo '✅' || echo '❌')"
  echo ""
  if [[ -n "$CORPUS_DIR" ]]; then
    echo "Corpus:"
    echo "  dir:    $CORPUS_DIR"
    echo "  docs:   $CORPUS_COUNT (min $MIN_DOCS)"
    echo ""
  fi
  echo "VERDICT: $VERDICT"
  for r in "${REASONS[@]}"; do
    echo "  • $r"
  done
  echo ""
  if [[ "$VERDICT" == "VIABLE" ]]; then
    echo "Next steps (manual, SE-033 Slice 2):"
    echo "  1. Create scripts/topic-cluster.py wrapper"
    echo "  2. Define label generation pipeline"
    echo "  3. Output cluster-report.md for human review"
  elif [[ "$VERDICT" == "NEEDS_INSTALL" ]]; then
    echo "Install:"
    echo "  pip install bertopic umap-learn hdbscan sentence-transformers"
  fi
fi

exit $EXIT_CODE
