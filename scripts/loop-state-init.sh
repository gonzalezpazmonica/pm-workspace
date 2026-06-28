#!/usr/bin/env bash
set -uo pipefail
# loop-state-init.sh — Inicializa STATE.md canónico para un skill autónomo
# SPEC: SE-228 Slice 1 — Loop State Schema
#
# Usage:
#   bash scripts/loop-state-init.sh --skill <nombre>
#   bash scripts/loop-state-init.sh --skill <nombre> --force
#   bash scripts/loop-state-init.sh --skill <nombre> --dry-run
#
# Exit codes:
#   0 — OK (creado o ya existía sin --force)
#   1 — Error (argumento faltante, fallo de escritura)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SKILL_NAME=""
FORCE=false
DRY_RUN=false

# ── Parse args ──────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill)
      [[ -z "${2:-}" ]] && { echo "ERROR: --skill requires a value" >&2; exit 1; }
      SKILL_NAME="$2"
      shift 2
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help|-h)
      sed -n '2,10p' "$0" | sed 's/^# //'
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$SKILL_NAME" ]]; then
  echo "ERROR: --skill <nombre> is required" >&2
  exit 1
fi

STATE_DIR="${PROJECT_ROOT}/output/loop-state/${SKILL_NAME}"
STATE_FILE="${STATE_DIR}/STATE.md"
NOW_UTC="$(date -u '+%Y-%m-%d %H:%M UTC')"

# ── Check if already exists ─────────────────────────────────────────────────
if [[ -f "$STATE_FILE" ]] && [[ "$FORCE" == false ]]; then
  echo "INFO: STATE.md already exists: ${STATE_FILE} (use --force to overwrite)"
  exit 0
fi

# ── Dry-run ─────────────────────────────────────────────────────────────────
if [[ "$DRY_RUN" == true ]]; then
  echo "DRY-RUN: would create ${STATE_FILE}"
  echo "DRY-RUN: skill = ${SKILL_NAME}"
  echo "DRY-RUN: Last run = ${NOW_UTC}"
  [[ "$FORCE" == true ]] && echo "DRY-RUN: --force active — would overwrite if exists"
  exit 0
fi

# ── Create directory ─────────────────────────────────────────────────────────
mkdir -p "$STATE_DIR"

# ── Write STATE.md from template ─────────────────────────────────────────────
cat > "$STATE_FILE" <<STATE_TEMPLATE
# Loop State — ${SKILL_NAME}

Last run: ${NOW_UTC}

## High Priority (loop actuando o esperando humano)

## Watch List

## Recently Resolved

## Noise / Ignored
STATE_TEMPLATE

echo "OK: created ${STATE_FILE}"
