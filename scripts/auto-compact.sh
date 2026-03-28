#!/bin/bash
# auto-compact.sh — Disparado automáticamente cuando contexto > 85%
# Persiste estado crítico antes de que Claude compacte
set -euo pipefail

SNAPSHOT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/output/context-snapshots"
mkdir -p "$SNAPSHOT_DIR"

SNAPSHOT="$SNAPSHOT_DIR/$(date -u +%Y%m%d-%H%M%S)-auto.json"
echo "{
  \"ts\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
  \"trigger\": \"auto-compact\",
  \"pct\": \"${CLAUDE_CONTEXT_TOKENS_USED:-?}/${CLAUDE_CONTEXT_TOKENS_MAX:-?}\",
  \"branch\": \"$(git branch --show-current 2>/dev/null || echo unknown)\"
}" > "$SNAPSHOT"

echo "Snapshot guardado: $SNAPSHOT" >&2
