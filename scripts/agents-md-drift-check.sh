#!/usr/bin/env bash
# agents-md-drift-check.sh — SE-078
#
# Thin wrapper around `agents-md-generate.sh --check`. Exists for
# discoverability + symmetry with `claude-md-drift-check.sh`. Used by
# pr-plan G14.
#
# Reference: SE-078 (docs/propuestas/SE-078-agents-md-cross-frontend.md)
# Reference: docs/rules/domain/agents-md-source-of-truth.md

set -uo pipefail

# Resolve sibling generator script via own location — works regardless of
# the calling shell's PWD or any PROJECT_ROOT override.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/agents-md-generate.sh" --check "$@"
