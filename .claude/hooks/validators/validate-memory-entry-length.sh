#!/usr/bin/env bash
# validate-memory-entry-length.sh — SPEC-184
# MEMORY auto-memory entries must be <150 chars per entry.
# Triggers only on .claude/external-memory/auto/MEMORY.md and per-entry files.
# Always exits 0.
set -uo pipefail

FILE="${1:-}"
[[ -f "$FILE" ]] || exit 0

case "$FILE" in
  */external-memory/auto/MEMORY.md|*/external-memory/auto/*/*.md) ;;
  *) exit 0 ;;
esac

CAP=150
lineno=0
while IFS= read -r line; do
  lineno=$((lineno+1))
  # Only check entries (lines starting with - or *), skip headers/comments/blanks
  case "$line" in
    -\ *|\*\ *) ;;
    *) continue ;;
  esac
  len=${#line}
  if (( len > CAP )); then
    echo "[WARN][memory-entry-length][$FILE:$lineno] entry has $len chars (cap=$CAP) — shorten or split" >&2
  fi
done < "$FILE"

exit 0
