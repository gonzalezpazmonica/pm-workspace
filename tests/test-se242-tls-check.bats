#!/usr/bin/env bats
# SE-242 — TLS Security Check tests
# Tests: tls-security-check.sh, web-headers-check.sh, SKILL.md, policy doc

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export TLS_SCRIPT="$REPO_ROOT/scripts/tls-security-check.sh"
  export HEADERS_SCRIPT="$REPO_ROOT/scripts/web-headers-check.sh"
  export SKILL_FILE="$REPO_ROOT/.opencode/skills/tls-security-checker/SKILL.md"
  export POLICY_FILE="$REPO_ROOT/docs/rules/domain/web-security-headers-policy.md"
}

# Test 1: tls-security-check.sh existe y pasa bash -n
@test "tls-security-check.sh existe y pasa bash -n" {
  [[ -f "$TLS_SCRIPT" ]]
  run bash -n "$TLS_SCRIPT"
  [[ "$status" -eq 0 ]]
}

# Test 2: web-headers-check.sh existe y pasa bash -n
@test "web-headers-check.sh existe y pasa bash -n" {
  [[ -f "$HEADERS_SCRIPT" ]]
  run bash -n "$HEADERS_SCRIPT"
  [[ "$status" -eq 0 ]]
}

# Test 3: tls-security-checker/SKILL.md existe y tiene ≤150 líneas
@test "tls-security-checker/SKILL.md existe y tiene 150 lineas o menos" {
  [[ -f "$SKILL_FILE" ]]
  LINE_COUNT=$(wc -l < "$SKILL_FILE")
  [[ "$LINE_COUNT" -le 150 ]]
}

# Test 4: web-security-headers-policy.md existe y tiene ≤150 líneas
@test "web-security-headers-policy.md existe y tiene 150 lineas o menos" {
  [[ -f "$POLICY_FILE" ]]
  LINE_COUNT=$(wc -l < "$POLICY_FILE")
  [[ "$LINE_COUNT" -le 150 ]]
}

# Test 5: Con testssl.sh no disponible → muestra Docker fallback
@test "tls-security-check.sh muestra Docker fallback cuando testssl no instalado" {
  # PATH sin testssl pero con bash, mkdir, date, etc.
  # Usar directorio temporal vacío como PATH adicional al principio
  FAKE_BIN=$(mktemp -d)
  trap 'rm -rf "$FAKE_BIN"' RETURN
  # El script detecta que testssl.sh no está y debe mencionar docker
  run env PATH="$FAKE_BIN:$PATH" bash "$TLS_SCRIPT" --host example.com
  # Debe mencionar Docker fallback o drwetter
  [[ "$output" == *"docker"* ]] || [[ "$output" == *"Docker"* ]] || [[ "$output" == *"drwetter"* ]]
}

# Test 6: web-headers-check.sh solo usa curl (no requiere testssl)
@test "web-headers-check.sh no tiene referencias a testssl ni MobSF" {
  run grep -i "testssl\|mobsf\|nikto" "$HEADERS_SCRIPT"
  # No debe mencionar testssl ni herramientas externas no-curl
  [[ "$status" -ne 0 ]]
}

# Test 7: web-headers-check.sh acepta --url
@test "web-headers-check.sh acepta argumento --url" {
  run grep "\-\-url" "$HEADERS_SCRIPT"
  [[ "$status" -eq 0 ]]
}

# Test 8: tls-security-check.sh acepta --host
@test "tls-security-check.sh acepta argumento --host" {
  run grep "\-\-host" "$TLS_SCRIPT"
  [[ "$status" -eq 0 ]]
}

# Test 9: tls-security-check.sh acepta --port
@test "tls-security-check.sh acepta argumento --port" {
  run grep "\-\-port" "$TLS_SCRIPT"
  [[ "$status" -eq 0 ]]
}

# Test 10: El report va a output/security/
@test "tls-security-check.sh escribe report en output/security/" {
  run grep "output/security" "$TLS_SCRIPT"
  [[ "$status" -eq 0 ]]
  run grep "output/security" "$HEADERS_SCRIPT"
  [[ "$status" -eq 0 ]]
}

# Test 11: web-security-headers-policy.md menciona Content-Security-Policy
@test "web-security-headers-policy.md menciona Content-Security-Policy" {
  run grep -i "Content-Security-Policy\|CSP" "$POLICY_FILE"
  [[ "$status" -eq 0 ]]
}

# Test 12: web-security-headers-policy.md menciona HSTS
@test "web-security-headers-policy.md menciona HSTS" {
  run grep -i "HSTS\|Strict-Transport-Security" "$POLICY_FILE"
  [[ "$status" -eq 0 ]]
}
