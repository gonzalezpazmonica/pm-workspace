#!/usr/bin/env bash
# artifact-export.sh — URL efímera para un artifact. ≤15 líneas. Rule #26.
# Uso: ./scripts/artifact-export.sh [--artifacts-dir DIR] ARTIFACT_ID [--ttl SEG]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARTIFACTS_DIR="${SAVIA_ARTIFACTS_DIR:-output/artifacts}"
[[ "${1:-}" == "--artifacts-dir" ]] && { ARTIFACTS_DIR="$2"; shift 2; }
[[ $# -lt 1 ]] && { echo "Uso: $0 [--artifacts-dir DIR] ARTIFACT_ID [--ttl SEG]" >&2; exit 1; }
PYTHONPATH="${SCRIPT_DIR}/.." python3 -m scripts.lib.artifacts.cli \
  --artifacts-dir "$ARTIFACTS_DIR" export "$@"
