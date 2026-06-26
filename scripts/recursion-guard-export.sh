#!/usr/bin/env bash
# scripts/recursion-guard-export.sh — Sets SAVIA_LOOP_CONTEXT for recursion prevention
# Usage: source scripts/recursion-guard-export.sh overnight-sprint
# Ref: SPEC-RECURSION-GUARD
LOOP_NAME="${1:-unknown}"
CURRENT_DEPTH=$(printf '%s' "${SAVIA_LOOP_CONTEXT:-:0}" | cut -d: -f2)
NEW_DEPTH=$((CURRENT_DEPTH + 1))
export SAVIA_LOOP_CONTEXT="${LOOP_NAME}:${NEW_DEPTH}"
