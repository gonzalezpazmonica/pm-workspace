#!/usr/bin/env bash
# code-twin-simulate.sh — SPEC-190 Slice 5
# Wrapper for the Application Code Twin symbolic simulation engine.
#
# Usage:
#   bash scripts/code-twin-simulate.sh <module_id> <method> <args_json> <seeds_dir>
#
# Exit codes (delegated from code-twin-simulate.py):
#   0 — simulation succeeded
#   1 — domain error (INVALID_CREDENTIALS, USER_DISABLED, …)
#   2 — engine error (bad args, CTF not found, seeds missing)
#
# IMPORTANT: Output is NEVER ground truth. Always check the confidence field.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec python3 "${SCRIPT_DIR}/code-twin-simulate.py" "$@"
