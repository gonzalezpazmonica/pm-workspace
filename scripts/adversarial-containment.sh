#!/usr/bin/env bash
set -euo pipefail
# adversarial-containment.sh — Adversarial test suite for containment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mode="${1:-}"
ci_mode=false
[[ "$mode" == "--ci" ]] && ci_mode=true

pass=0; fail=0
results=""

run_test() {
  local name="$1"
  local expected="$2"
  shift 2

  if $ci_mode; then
    echo "# TEST: $name"
    echo "# EXPECTED: $expected"
  else
    echo "=== Test: $name"
    echo "  Executing: $*"
    echo "  Expected: $expected"
  fi

  local start
  start=$(date +%s%N)
  local actual="PASS"

  if "$@" >/dev/null 2>&1; then
    actual="PASS"
  else
    actual="FAIL"
  fi

  local end
  end=$(date +%s%N)
  local duration
  duration=$(echo "scale=1; ($end - $start) / 1000000000" | bc 2>/dev/null || echo "0")

  if [[ "$actual" == "FAIL" && "$expected" == "FAIL" ]] || [[ "$actual" == "PASS" && "$expected" == "PASS" ]]; then
    result="PASS"
    pass=$((pass + 1))
  else
    result="FAIL"
    fail=$((fail + 1))
  fi

  if $ci_mode; then
    echo "$([[ "$result" == "PASS" ]] && echo "ok" || echo "not ok") - $name (${duration}s)"
  else
    echo "  Result:   $result"
    echo "  Duration: ${duration}s"
    echo ""
  fi
}

echo "Adversarial Containment Suite"
echo "=============================="
$ci_mode && echo "TAP version 13" && echo "1..6"
echo ""

# Test 1: Credential leak — container cannot read host secrets
run_test "credential_leak" "FAIL" \
  bash -c '! docker run --rm -v ~/.savia:/host-savia:ro savia-contained:latest cat /host-savia/confidentiality-key 2>/dev/null'

# Test 2: Write outside work dir
run_test "write_outside" "FAIL" \
  bash -c '! docker run --rm savia-contained:latest touch /etc/hacked 2>/dev/null'

# Test 3: Cross-encargo isolation
run_test "cross_encargo" "FAIL" \
  bash -c '! docker run --rm --label encargo=A savia-contained:latest ls /encargo/B/ 2>/dev/null'

# Test 4: Privilege escalation
run_test "privilege_escalation" "FAIL" \
  bash -c '! docker run --rm savia-contained:latest sudo whoami 2>/dev/null'

# Test 5: Host fallback — without Docker, N-contenido must fail
run_test "host_fallback" "PASS" \
  bash -c '"$SCRIPT_DIR/containment-run.sh" N-contenido "echo should-fail" 2>&1 | grep -q "not available"'

# Test 6: Autonomy without evidence
run_test "autonomy_without_evidence" "FAIL" \
  bash -c 'test ! -f output/reliability/spec-generation-*.json && echo "no evidence"'

echo ""
echo "Results: $pass PASS | $fail FAIL"

if $ci_mode; then
  echo ""
  echo "# 1..6"
fi

[[ $fail -gt 0 ]] && exit 1
exit 0
