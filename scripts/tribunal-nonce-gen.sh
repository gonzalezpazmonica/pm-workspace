#!/usr/bin/env bash
# tribunal-nonce-gen.sh — SE-227 Slice 1 — E3 entropy nonce generator
#
# Generates a cryptographically-derived nonce for the E3 anti-pre-cooking
# mechanism. The orchestrator generates a nonce per invocation; each judge
# must include it in the first line of their output. Verification post-judgement
# detects if the judge "pre-cooked" a response before receiving the input.
#
# Usage:
#   tribunal-nonce-gen.sh                              # generate nonce
#   tribunal-nonce-gen.sh --verify <nonce> <output>    # verify nonce present
#   tribunal-nonce-gen.sh --self-test                  # run internal tests
#
# Algorithm: sha256(timestamp_millis + ":" + 32 random bytes hex)
# Requires: openssl OR python3 (stdlib only, no pip)
#
# Exit codes:
#   0  OK / nonce present / self-test passed
#   1  Nonce absent / self-test failed
#   2  Usage error
#
# SE-227 — docs/propuestas/SE-227-mech-gov-hard-gates-tribunales.md

set -uo pipefail

# ── Nonce generation ──────────────────────────────────────────────────────────

_gen_nonce() {
  local ts_ms
  ts_ms="$(date +%s%3N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1000))')"

  if command -v openssl &>/dev/null; then
    local rand_hex
    rand_hex="$(openssl rand -hex 16 2>/dev/null)"
    local input="${ts_ms}:${rand_hex}"
    printf '%s' "$input" | openssl dgst -sha256 -binary 2>/dev/null \
      | od -An -tx1 | tr -d ' \n'
    echo ""
  else
    # python3 stdlib fallback — zero external deps
    python3 - "$ts_ms" <<'PYEOF'
import sys, hashlib, os, binascii
ts_ms = sys.argv[1]
rand_bytes = os.urandom(16)
rand_hex = binascii.hexlify(rand_bytes).decode()
payload = f"{ts_ms}:{rand_hex}"
nonce = hashlib.sha256(payload.encode()).hexdigest()
print(nonce)
PYEOF
  fi
}

# ── Nonce verification ────────────────────────────────────────────────────────

_verify_nonce() {
  local nonce="$1"
  local output_file="$2"

  if [[ -z "$nonce" ]]; then
    echo "Error: nonce is empty" >&2
    exit 2
  fi
  if [[ ! -r "$output_file" ]]; then
    echo "Error: output file not readable: $output_file" >&2
    exit 2
  fi

  if grep -qF "$nonce" "$output_file" 2>/dev/null; then
    exit 0
  else
    exit 1
  fi
}

# ── Self-test ─────────────────────────────────────────────────────────────────

_self_test() {
  local PASS=0 FAIL=0
  local TMP_DIR
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT

  _assert() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
      echo "  PASS: $desc"
      ((PASS++)) || true
    else
      echo "  FAIL: $desc (expected='$expected' got='$actual')"
      ((FAIL++)) || true
    fi
  }

  # Test 1: nonce has correct sha256 hex format (64 hex chars)
  local nonce
  nonce="$(_gen_nonce)"
  nonce="${nonce%$'\n'}"
  local len="${#nonce}"
  if [[ "$len" -eq 64 ]] && [[ "$nonce" =~ ^[0-9a-f]{64}$ ]]; then
    echo "  PASS: nonce format is 64-char lowercase hex"
    ((PASS++)) || true
  else
    echo "  FAIL: nonce format (len=$len value='$nonce')"
    ((FAIL++)) || true
  fi

  # Test 2: two nonces are different (entropy)
  local n1 n2
  n1="$(_gen_nonce)"
  n2="$(_gen_nonce)"
  if [[ "$n1" != "$n2" ]]; then
    echo "  PASS: consecutive nonces are unique"
    ((PASS++)) || true
  else
    echo "  FAIL: consecutive nonces are identical (no entropy)"
    ((FAIL++)) || true
  fi

  # Test 3: verify passes when nonce is present
  local test_nonce
  test_nonce="$(_gen_nonce)"
  local present_file="$TMP_DIR/present.txt"
  printf 'Judge output. Nonce: %s. End.\n' "$test_nonce" > "$present_file"
  if bash "$0" --verify "$test_nonce" "$present_file"; then
    echo "  PASS: --verify returns 0 when nonce present"
    ((PASS++)) || true
  else
    echo "  FAIL: --verify returned non-zero when nonce present"
    ((FAIL++)) || true
  fi

  # Test 4: verify fails when nonce is absent
  local absent_file="$TMP_DIR/absent.txt"
  echo "Judge output without any nonce here." > "$absent_file"
  if ! bash "$0" --verify "$test_nonce" "$absent_file"; then
    echo "  PASS: --verify returns 1 when nonce absent"
    ((PASS++)) || true
  else
    echo "  FAIL: --verify returned 0 when nonce absent (false positive)"
    ((FAIL++)) || true
  fi

  # Test 5: empty nonce returns non-zero
  if ! bash "$0" --verify "" "$absent_file" 2>/dev/null; then
    echo "  PASS: empty nonce returns non-zero"
    ((PASS++)) || true
  else
    echo "  FAIL: empty nonce did not error"
    ((FAIL++)) || true
  fi

  echo ""
  echo "Self-test: $PASS passed, $FAIL failed"
  [[ $FAIL -eq 0 ]] && exit 0 || exit 1
}

# ── Entrypoint ────────────────────────────────────────────────────────────────

case "${1:-}" in
  --self-test)
    _self_test
    ;;
  --verify)
    if [[ $# -lt 3 ]]; then
      echo "Usage: $(basename "$0") --verify <nonce> <output_file>" >&2
      exit 2
    fi
    _verify_nonce "$2" "$3"
    ;;
  *)
    # Default: generate a nonce
    _gen_nonce
    ;;
esac
