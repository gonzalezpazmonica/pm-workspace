#!/usr/bin/env bash
# Agent Architect wrapper (SPEC-AGENT-ARCHITECT §2.2).
# Bash is the envelope only; analysis lives in Python (Rule #26).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THRESHOLDS="${AGENT_ARCHITECT_THRESHOLDS:-$ROOT/.opencode/agent-architect-thresholds.yaml}"

PYBIN="${PYTHON:-python3}"
[[ -x "$ROOT/.venv/bin/python" ]] && PYBIN="$ROOT/.venv/bin/python"

PYTHONPATH="$ROOT/scripts/lib${PYTHONPATH:+:$PYTHONPATH}" \
  exec "$PYBIN" -m agent_architect.cli --thresholds "$THRESHOLDS" --root "$ROOT" "$@"
