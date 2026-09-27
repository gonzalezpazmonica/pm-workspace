#!/usr/bin/env bash
set -uo pipefail
# edit-ledger-record.sh — async PostToolUse hook (SE-402).
#
# Registra cada escritura exitosa de Edit/Write/NotebookEdit en el ledger local
# de ediciones atribuidas (~/.savia/edits/<session>.jsonl): ruta y hash, nunca
# contenido. Nunca bloquea: exit 0 siempre.
# Ref: docs/specs/SE-402-attributed-edit-ledger.spec.md

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
bash "$ROOT/scripts/edit-ledger.sh" record 2>/dev/null || true
exit 0
