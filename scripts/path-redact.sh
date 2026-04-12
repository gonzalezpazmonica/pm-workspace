#!/usr/bin/env bash
set -uo pipefail
# path-redact.sh — Redact absolute paths containing $HOME from text
#
# Prevents PII leakage via filesystem paths in agent output, logs, and
# persisted artifacts. Replaces /home/username/... with ~/ and strips
# other identifying path prefixes.
#
# Learned from multica-ai/multica: they redact $HOME/username before
# persisting agent results.
#
# Usage:
#   echo "text" | bash scripts/path-redact.sh         # stdin mode
#   bash scripts/path-redact.sh file.txt               # file mode (in-place)
#   bash scripts/path-redact.sh --check file.txt       # check only, exit 1 if found

die() { echo "ERROR: $*" >&2; exit 2; }

# Build redaction patterns from environment
HOME_DIR="${HOME:-/home/unknown}"
USERNAME=$(basename "$HOME_DIR")
# Patterns to redact (most specific first)
PATTERNS=(
  "$HOME_DIR"                          # /home/monica → ~
  "/home/$USERNAME"                    # explicit /home/user
  "/Users/$USERNAME"                   # macOS
  "C:\\\\Users\\\\$USERNAME"           # Windows (escaped backslash)
  "C:/Users/$USERNAME"                 # Windows (forward slash)
)

redact_text() {
  local text="$1"
  for pat in "${PATTERNS[@]}"; do
    text="${text//$pat/\~}"
  done
  echo "$text"
}

cmd_check() {
  local file="$1"
  [[ -f "$file" ]] || die "File not found: $file"
  local found=0
  for pat in "${PATTERNS[@]}"; do
    if grep -qF "$pat" "$file" 2>/dev/null; then
      echo "FOUND: $pat in $file"
      found=1
    fi
  done
  return "$found"
}

cmd_redact_file() {
  local file="$1"
  [[ -f "$file" ]] || die "File not found: $file"
  local tmp; tmp=$(mktemp)
  local content; content=$(cat "$file")
  redact_text "$content" > "$tmp"
  if ! diff -q "$file" "$tmp" >/dev/null 2>&1; then
    mv "$tmp" "$file"
    echo "REDACTED: $file"
  else
    rm "$tmp"
    echo "CLEAN: $file"
  fi
}

cmd_stdin() {
  local text; text=$(cat)
  redact_text "$text"
}

case "${1:-}" in
  --check)
    shift
    [[ -z "${1:-}" ]] && die "Usage: path-redact.sh --check FILE"
    cmd_check "$1"
    ;;
  "")
    cmd_stdin
    ;;
  *)
    if [[ -f "$1" ]]; then
      cmd_redact_file "$1"
    else
      die "Unknown argument: $1. Usage: path-redact.sh [--check] [FILE]"
    fi
    ;;
esac
