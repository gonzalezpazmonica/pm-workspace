#!/usr/bin/env bash
# hashline-guard.sh — Stale-file protection for L3 agent edits (SE-149)
#
# Modes:
#   anchor <file_path> <line_number>
#     → outputs: <hash> <anchor_text_base64>
#     hash = sha256 of 3-line context (N-1, N, N+1)
#
#   check <file_path> <anchor_text> <anchor_hash>
#     exit 0: file intact, safe to edit
#     exit 1: file stale (anchor exists but hash changed)
#     exit 2: anchor_text not found (file too different)
#
# Usage: bash scripts/hashline-guard.sh <mode> [args...]
# Ref: SE-149, docs/rules/domain/hashline-edit-protocol.md

set -uo pipefail

MODE="${1:-}"
shift || true

# ── helpers ──────────────────────────────────────────────────────────────────

_die() { echo "ERROR: $*" >&2; exit 3; }

_hash_lines() {
  # Accepts lines via stdin, outputs sha256 hex
  local content
  content=$(cat)
  printf '%s' "$content" | sha256sum | awk '{print $1}'
}

_extract_context() {
  local file="$1"
  local lineno="$2"
  local total
  total=$(wc -l < "$file")
  local start=$(( lineno - 1 ))
  local end=$(( lineno + 1 ))
  [[ $start -lt 1 ]] && start=1
  [[ $end -gt $total ]] && end=$total
  sed -n "${start},${end}p" "$file"
}

# ── mode: anchor ─────────────────────────────────────────────────────────────

cmd_anchor() {
  local file="${1:-}"
  local lineno="${2:-}"
  [[ -z "$file" || -z "$lineno" ]] && _die "anchor requires <file_path> <line_number>"
  [[ -f "$file" ]] || _die "file not found: $file"
  [[ "$lineno" =~ ^[0-9]+$ ]] || _die "line_number must be integer"

  local context
  context=$(_extract_context "$file" "$lineno")
  local hash
  hash=$(printf '%s' "$context" | sha256sum | awk '{print $1}')
  # Output format: first line = hash, subsequent lines = context text
  # Parse with: head -1 (hash) and tail -n +2 (context)
  printf '%s\n%s\n' "$hash" "$context"
}

# ── mode: check ──────────────────────────────────────────────────────────────

cmd_check() {
  local file="${1:-}"
  local anchor_text="${2:-}"
  local anchor_hash="${3:-}"
  [[ -z "$file" || -z "$anchor_text" || -z "$anchor_hash" ]] && \
    _die "check requires <file_path> <anchor_text> <anchor_hash>"
  [[ -f "$file" ]] || _die "file not found: $file"

  # Search for anchor_text in file (exact multiline match via grep -F -c)
  local first_line
  first_line=$(printf '%s' "$anchor_text" | head -1)

  # Find all line numbers where the first line of anchor_text appears
  local match_lineno
  match_lineno=$(grep -nF -- "$first_line" "$file" | awk -F: '{print $1}' | head -1)

  if [[ -z "$match_lineno" ]]; then
    # anchor_text not found at all
    exit 2
  fi

  # Verify full multiline match around that line
  # Use awk NR to count actual lines (wc -l undercounts without trailing newline)
  local anchor_line_count
  anchor_line_count=$(printf '%s' "$anchor_text" | awk 'END{print NR}')

  # Extract the same number of lines from the file starting at match_lineno
  local file_section
  file_section=$(sed -n "${match_lineno},$((match_lineno + anchor_line_count - 1))p" "$file")

  if [[ "$file_section" != "$anchor_text" ]]; then
    # First line found but full text doesn't match → stale
    exit 1
  fi

  # Text found — now verify the hash of the 3-line context
  # Center line of anchor_text: floor(anchor_line_count / 2) offset from match
  local center_offset=$(( anchor_line_count / 2 ))
  local center_lineno=$(( match_lineno + center_offset ))

  local current_context
  current_context=$(_extract_context "$file" "$center_lineno")
  local current_hash
  current_hash=$(printf '%s' "$current_context" | sha256sum | awk '{print $1}')

  if [[ "$current_hash" != "$anchor_hash" ]]; then
    # Hash mismatch → stale
    exit 1
  fi

  # All good
  exit 0
}

# ── dispatch ─────────────────────────────────────────────────────────────────

case "$MODE" in
  anchor) cmd_anchor "$@" ;;
  check)  cmd_check  "$@" ;;
  *)
    echo "Usage: hashline-guard.sh <anchor|check> [args...]" >&2
    echo "  anchor <file> <lineno>                    — generate anchor hash" >&2
    echo "  check  <file> <anchor_text> <anchor_hash> — verify file not stale" >&2
    exit 3
    ;;
esac
