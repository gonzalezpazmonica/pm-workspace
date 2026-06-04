#!/usr/bin/env bash
# validate-banned-unicode.sh — SPEC-184
# Detects banned unicode chars (em-dash, curly quotes, NBSP, ellipsis)
# in markdown files. Reports codepoint + ASCII replacement to stderr.
# Always exits 0.
set -uo pipefail

FILE="${1:-}"
[[ -f "$FILE" ]] || exit 0

# (codepoint, char, ascii_replacement, name)
declare -a CHECKS=(
  $'\xe2\x80\x94|U+2014|--|EM DASH'
  $'\xe2\x80\x93|U+2013|-|EN DASH'
  $'\xe2\x80\x9c|U+201C|"|LEFT DOUBLE QUOTE'
  $'\xe2\x80\x9d|U+201D|"|RIGHT DOUBLE QUOTE'
  $'\xe2\x80\x98|U+2018|'\''|LEFT SINGLE QUOTE'
  $'\xe2\x80\x99|U+2019|'\''|RIGHT SINGLE QUOTE'
  $'\xc2\xa0|U+00A0|space|NO-BREAK SPACE'
  $'\xe2\x80\xa6|U+2026|...|HORIZONTAL ELLIPSIS'
)

for entry in "${CHECKS[@]}"; do
  IFS='|' read -r ch cp repl name <<< "$entry"
  if grep -nF "$ch" "$FILE" >/dev/null 2>&1; then
    while IFS=: read -r lineno _; do
      echo "[WARN][banned-unicode][$FILE:$lineno] $name ($cp) — replace with '$repl'" >&2
    done < <(grep -nF "$ch" "$FILE" | head -5)
  fi
done

exit 0
