#!/usr/bin/env bash
# content-fingerprint.sh — SE-151 consolidation skill
#
# Provides deterministic short content fingerprint via sha256 truncation.
# Replaces 4 divergent implementations identified in audit:
#   - scripts/ado-bridge.sh:cache_key (cut -c1-16)
#   - scripts/failure-pattern-memory.sh (cut -c1-8)
#   - scripts/semantic-map.sh (cut -c1-8)
#   - scripts/test-auditor.sh (cut -c1-8)
#
# Inspiration (frontmatter-only, code is honest):
#   - DNA barcoding: Hebert 2003 doi:10.1098/rspb.2002.2218
#     "fragmento canonico discriminativo"
#   - Drosophila olfactory LSH: Dasgupta 2017 doi:10.1126/science.aam9868
#     (NOT applied here; future iteration condicional)
#
# Usage:
#   echo "content" | content-fingerprint.sh [LEN]
#   cat file.txt | content-fingerprint.sh 16
#   content-fingerprint.sh --self-test
#
# Exit codes:
#   0 success
#   2 invalid input (bad len, no stdin)

set -euo pipefail

VALID_LENS="8 16 32 64"

usage() {
  cat <<USAGE
content-fingerprint.sh — deterministic short content hash (sha256 truncated)

Usage:
  echo "content" | $0 [LEN]
  $0 --self-test

LEN: one of {8, 16, 32, 64}; default 16.
USAGE
}

self_test() {
  local errors=0

  # Determinism
  local a b
  a=$(echo "test" | _fingerprint 16)
  b=$(echo "test" | _fingerprint 16)
  if [[ "$a" != "$b" ]]; then
    echo "FAIL determinism: $a != $b" >&2
    errors=$((errors+1))
  fi

  # Avalanche
  a=$(echo "test1" | _fingerprint 16)
  b=$(echo "test2" | _fingerprint 16)
  if [[ "$a" == "$b" ]]; then
    echo "FAIL avalanche: collision on different inputs" >&2
    errors=$((errors+1))
  fi

  # Length validation
  local lens=(8 16 32 64)
  for L in "${lens[@]}"; do
    a=$(echo "x" | _fingerprint "$L")
    if [[ ${#a} -ne $L ]]; then
      echo "FAIL length $L: got ${#a}" >&2
      errors=$((errors+1))
    fi
  done

  if (( errors == 0 )); then
    echo "self-test OK"
    return 0
  fi
  echo "self-test FAILED: $errors errors" >&2
  return 1
}

# Internal: read stdin, output sha256 truncated to N chars
_fingerprint() {
  local len="${1:-16}"
  case " $VALID_LENS " in
    *" $len "*) ;;
    *)
      echo "ERROR: len must be one of: $VALID_LENS (got: $len)" >&2
      return 2
      ;;
  esac
  # sha256sum reads stdin, awk truncates first field
  sha256sum | awk -v n="$len" '{print substr($1, 1, n)}'
}

main() {
  case "${1:-}" in
    -h|--help) usage; return 0 ;;
    --self-test) self_test; return $? ;;
  esac

  # Stdin required
  if [[ -t 0 ]]; then
    echo "ERROR: input required via stdin" >&2
    usage >&2
    return 2
  fi

  _fingerprint "${1:-16}"
}

main "$@"
