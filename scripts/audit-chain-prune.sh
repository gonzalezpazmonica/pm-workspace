#!/usr/bin/env bash
# audit-chain-prune.sh — SE-275 S1: rotación de cadenas antiguas.
#
# Mueve cadenas de output/audit con más de <dias> (default 90) a
# output/audit/archive/ (comprimidas si gzip está disponible).
#
# Uso: audit-chain-prune.sh [dias]
set -uo pipefail

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
AUDIT_DIR="$REPO_ROOT/output/audit"
DAYS="${1:-90}"
ARCHIVE="$AUDIT_DIR/archive"
mkdir -p "$ARCHIVE" 2>/dev/null || true

[[ -d "$AUDIT_DIR" ]] || { echo "SKIP: no existe $AUDIT_DIR"; exit 0; }

CUTOFF="$(date -u -d "-${DAYS} days" +%s 2>/dev/null || date -d "-${DAYS} days" +%s 2>/dev/null)"
[[ -z "$CUTOFF" ]] && { echo "WARN: no se pudo calcular cutoff"; exit 1; }

PRUNED=0
for f in "$AUDIT_DIR"/*.jsonl; do
  [[ -f "$f" ]] || continue
  MTIME="$(stat -c %Y "$f" 2>/dev/null || echo 0)"
  if [[ "$MTIME" -lt "$CUTOFF" ]]; then
    if command -v gzip >/dev/null 2>&1; then
      gzip -c "$f" > "$ARCHIVE/$(basename "$f").gz" 2>/dev/null && rm -f "$f"
    else
      mv "$f" "$ARCHIVE/"
    fi
    echo "archived: $(basename "$f") (>${DAYS}d)"
    PRUNED=$((PRUNED+1))
  fi
done

[[ "$PRUNED" -eq 0 ]] && echo "OK: nada que podar"
exit 0
