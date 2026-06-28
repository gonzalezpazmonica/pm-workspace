#!/usr/bin/env bats
# test-se241-iac-scan.bats — Tests para SE-241 IaC Security Scanning
# Ref: docs/propuestas/SE-241-iac-security-scanning.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPTS="$REPO_ROOT/scripts"
  SKILLS="$REPO_ROOT/.opencode/skills"
  DOCS="$REPO_ROOT/docs/rules/domain"
}

# ── Test 1: iac-security-scan.sh existe y pasa bash -n ──────────────────────
@test "SE-241-01: iac-security-scan.sh existe y pasa bash -n" {
  [ -f "$SCRIPTS/iac-security-scan.sh" ]
  run bash -n "$SCRIPTS/iac-security-scan.sh"
  [ "$status" -eq 0 ]
}

# ── Test 2: iac-security-baseline.sh existe y pasa bash -n ──────────────────
@test "SE-241-02: iac-security-baseline.sh existe y pasa bash -n" {
  [ -f "$SCRIPTS/iac-security-baseline.sh" ]
  run bash -n "$SCRIPTS/iac-security-baseline.sh"
  [ "$status" -eq 0 ]
}

# ── Test 3: iac-security-scanner/SKILL.md existe y ≤150 líneas ───────────────
@test "SE-241-03: iac-security-scanner/SKILL.md existe y tiene 150 lineas o menos" {
  local skill_file="$SKILLS/iac-security-scanner/SKILL.md"
  [ -f "$skill_file" ]
  local lines
  lines=$(wc -l < "$skill_file")
  [ "$lines" -le 150 ]
}

# ── Test 4: iac-security-policy.md existe y ≤150 líneas ─────────────────────
@test "SE-241-04: iac-security-policy.md existe y tiene 150 lineas o menos" {
  local policy_file="$DOCS/iac-security-policy.md"
  [ -f "$policy_file" ]
  local lines
  lines=$(wc -l < "$policy_file")
  [ "$lines" -le 150 ]
}

# ── Test 5: Sin Trivy instalado → muestra alternativa Docker ─────────────────
@test "SE-241-05: sin Trivy muestra alternativa Docker en mensaje" {
  grep -q "aquasec/trivy\|docker run.*trivy" "$SCRIPTS/iac-security-scan.sh"
}

# ── Test 6: El script acepta --path como argumento ───────────────────────────
@test "SE-241-06: iac-security-scan.sh acepta --path como argumento" {
  grep -q "\-\-path" "$SCRIPTS/iac-security-scan.sh"
}

# ── Test 7: El script acepta --severity como argumento ───────────────────────
@test "SE-241-07: iac-security-scan.sh acepta --severity como argumento" {
  grep -q "\-\-severity" "$SCRIPTS/iac-security-scan.sh"
}

# ── Test 8: El script acepta --format como argumento ─────────────────────────
@test "SE-241-08: iac-security-scan.sh acepta --format como argumento" {
  grep -q "\-\-format" "$SCRIPTS/iac-security-scan.sh"
}

# ── Test 9: Report va a output/security/ no a la raíz ────────────────────────
@test "SE-241-09: report se escribe en output/security/ no en la raiz" {
  # Verificar que OUTPUT_DIR apunta a output/security
  grep -q "output/security" "$SCRIPTS/iac-security-scan.sh"
  # La declaración de OUTPUT_DIR debe contener "security"
  grep -qE 'OUTPUT_DIR=.*security' "$SCRIPTS/iac-security-scan.sh"
}

# ── Test 10: iac-security-policy.md menciona CRITICAL y HIGH como bloqueantes
@test "SE-241-10: iac-security-policy.md menciona CRITICAL y HIGH como bloqueantes" {
  local policy_file="$DOCS/iac-security-policy.md"
  grep -q "CRITICAL" "$policy_file"
  grep -q "HIGH" "$policy_file"
  # Debe mencionar que bloquean (exit 1 o "Bloquea")
  grep -qiE "bloqu|exit.1|block" "$policy_file"
}

# ── Test 11: iac-security-scan.sh auto-detecta Terraform ─────────────────────
@test "SE-241-11: iac-security-scan.sh auto-detecta Terraform (menciona .tf o terraform)" {
  grep -qiE '\.tf|terraform' "$SCRIPTS/iac-security-scan.sh"
}

# ── Test 12: iac-security-scan.sh auto-detecta Dockerfile ────────────────────
@test "SE-241-12: iac-security-scan.sh auto-detecta Dockerfile" {
  grep -q "Dockerfile" "$SCRIPTS/iac-security-scan.sh"
}
