#!/usr/bin/env bats
# tests/test-se231-syntax-check.bats
# SE-231 — HTTP QUERY Method — syntax validation (5 tests)

EXAMPLES="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/scripts/examples/http-query"

@test "1. server-fastapi.py pasa python3 -m py_compile" {
  python3 -m py_compile "${EXAMPLES}/server-fastapi.py"
}

@test "2. client-python.py pasa python3 -m py_compile" {
  python3 -m py_compile "${EXAMPLES}/client-python.py"
}

@test "3. client-curl.sh pasa bash -n (syntax check)" {
  bash -n "${EXAMPLES}/client-curl.sh"
}

@test "4. client-go.go contiene package main (estructura básica válida)" {
  grep -q "^package main" "${EXAMPLES}/client-go.go"
}

@test "5. client-csharp.cs contiene using statement (estructura básica)" {
  grep -qE "^using " "${EXAMPLES}/client-csharp.cs"
}
