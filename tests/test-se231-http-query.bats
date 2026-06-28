#!/usr/bin/env bats
# tests/test-se231-http-query.bats
# SE-231 — HTTP QUERY Method (RFC 10008) — 20 tests

NIDO="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
DOMAIN_RULE="${NIDO}/docs/rules/domain/http-query-method.md"
EXAMPLES="${NIDO}/scripts/examples/http-query"
LANG="${NIDO}/docs/rules/languages"

# ─── Grupo 1: docs/rules/domain/http-query-method.md ────────────────────────

@test "1. http-query-method.md existe" {
  [ -f "${DOMAIN_RULE}" ]
}

@test "2. http-query-method.md tiene <= 150 líneas" {
  lines=$(wc -l < "${DOMAIN_RULE}")
  [ "${lines}" -le 150 ]
}

@test "3. http-query-method.md menciona RFC 10008" {
  grep -q "RFC 10008" "${DOMAIN_RULE}"
}

@test "4. http-query-method.md menciona Safe YES o seguro" {
  grep -qiE "(Safe.*YES|seguro|Safe: YES)" "${DOMAIN_RULE}"
}

@test "5. http-query-method.md menciona Idempotente" {
  grep -qi "Idempoten" "${DOMAIN_RULE}"
}

@test "6. http-query-method.md menciona Content-Type" {
  grep -q "Content-Type" "${DOMAIN_RULE}"
}

# ─── Grupo 2: archivos de servidor ──────────────────────────────────────────

@test "7. server-express.ts existe y contiene QUERY" {
  [ -f "${EXAMPLES}/server-express.ts" ]
  grep -q "QUERY" "${EXAMPLES}/server-express.ts"
}

@test "8. server-fastapi.py existe y contiene QUERY" {
  [ -f "${EXAMPLES}/server-fastapi.py" ]
  grep -q "QUERY" "${EXAMPLES}/server-fastapi.py"
}

@test "9. server-aspnet.cs existe y contiene QUERY" {
  [ -f "${EXAMPLES}/server-aspnet.cs" ]
  grep -q "QUERY" "${EXAMPLES}/server-aspnet.cs"
}

@test "10. server-gin.go existe y contiene QUERY" {
  [ -f "${EXAMPLES}/server-gin.go" ]
  grep -q "QUERY" "${EXAMPLES}/server-gin.go"
}

# ─── Grupo 3: archivos de cliente ───────────────────────────────────────────

@test "11. client-curl.sh existe y es ejecutable" {
  [ -f "${EXAMPLES}/client-curl.sh" ]
  [ -x "${EXAMPLES}/client-curl.sh" ]
}

@test "12. client-curl.sh contiene -X QUERY" {
  grep -q "\-X QUERY" "${EXAMPLES}/client-curl.sh"
}

@test "13. client-fetch.ts existe y contiene method: 'QUERY'" {
  [ -f "${EXAMPLES}/client-fetch.ts" ]
  grep -q "method: 'QUERY'" "${EXAMPLES}/client-fetch.ts"
}

@test "14. client-python.py existe y contiene method='QUERY'" {
  [ -f "${EXAMPLES}/client-python.py" ]
  grep -q "method='QUERY'" "${EXAMPLES}/client-python.py"
}

@test "15. client-go.go contiene \"QUERY\"" {
  [ -f "${EXAMPLES}/client-go.go" ]
  grep -q '"QUERY"' "${EXAMPLES}/client-go.go"
}

@test "16. client-csharp.cs contiene HttpMethod(\"QUERY\")" {
  [ -f "${EXAMPLES}/client-csharp.cs" ]
  grep -q 'HttpMethod("QUERY")' "${EXAMPLES}/client-csharp.cs"
}

@test "17. client-rust.rs contiene QUERY" {
  [ -f "${EXAMPLES}/client-rust.rs" ]
  grep -q "QUERY" "${EXAMPLES}/client-rust.rs"
}

@test "18. client-java.java contiene valueOf(\"QUERY\")" {
  [ -f "${EXAMPLES}/client-java.java" ]
  grep -q 'valueOf("QUERY")' "${EXAMPLES}/client-java.java"
}

# ─── Grupo 4: language rules actualizadas ───────────────────────────────────

@test "19. TypeScript language rule menciona HTTP QUERY o referencia http-query-method" {
  grep -qiE "(HTTP QUERY|http-query-method)" "${LANG}/typescript-rules.md"
}

@test "20. Python language rule menciona HTTP QUERY o referencia http-query-method" {
  grep -qiE "(HTTP QUERY|http-query-method)" "${LANG}/python-rules.md"
}
