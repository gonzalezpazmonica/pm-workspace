#!/usr/bin/env bash
# context-guard-recall.sh — Retrieve a stored context-guard summary.
# Usage: context-guard-recall.sh <run_id> [summary_id] [--caller-level N1|N2|N3|N4|N4b]
# Rule #26: Bash as thin wrapper only. Logic lives in scripts/lib/context_guard/cli.py.
# Spec §2.5: recall_summary(run_id, summary_id?) → SummaryV1.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

RUN_ID="${1:?Usage: context-guard-recall.sh <run_id> [summary_id] [--caller-level LEVEL]}"
shift

exec python3 -m scripts.lib.context_guard.cli \
    recall "${RUN_ID}" "$@"
