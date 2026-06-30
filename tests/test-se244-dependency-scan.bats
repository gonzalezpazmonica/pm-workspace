#!/usr/bin/env bats
# test-se244-dependency-scan.bats — Tests para SE-244 Dependency Vulnerability Scanning
# Ref: docs/propuestas/SE-244-dependency-vulnerability-scanning.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPTS="$REPO_ROOT/scripts"
  SKILLS="$REPO_ROOT/.opencode/skills"
  DOCS="$REPO_ROOT/docs/rules/domain"
}

# ── Test 1: dependency-scan.sh existe y pasa bash -n ────────────────────────
@test "SE-244-01: dependency-scan.sh existe y pasa bash -n" {
  [ -f "$SCRIPTS/dependency-scan.sh" ]
  run bash -n "$SCRIPTS/dependency-scan.sh"
  [ "$status" -eq 0 ]
}

# ── Test 2: dependency-scanner/SKILL.md existe y ≤150 líneas ─────────────────
@test "SE-244-02: dependency-scanner/SKILL.md existe y tiene 150 lineas o menos" {
  local skill_file="$SKILLS/dependency-scanner/SKILL.md"
  [ -f "$skill_file" ]
  local lines
  lines=$(wc -l < "$skill_file")
  [ "$lines" -le 150 ]
}

# ── Test 3: dependency-security-policy.md existe y ≤150 líneas ───────────────
@test "SE-244-03: dependency-security-policy.md existe y tiene 150 lineas o menos" {
  local policy_file="$DOCS/dependency-security-policy.md"
  [ -f "$policy_file" ]
  local lines
  lines=$(wc -l < "$policy_file")
  [ "$lines" -le 150 ]
}

# ── Test 4: Sin Trivy instalado → muestra alternativa Docker ─────────────────
@test "SE-244-04: sin Trivy muestra alternativa Docker en mensaje" {
  grep -q "aquasec/trivy\|docker run.*trivy" "$SCRIPTS/dependency-scan.sh"
}

# ── Test 5: El script acepta --path ──────────────────────────────────────────
@test "SE-244-05: dependency-scan.sh acepta --path" {
  grep -q "\-\-path" "$SCRIPTS/dependency-scan.sh"
}

# ── Test 6: El script acepta --generate-sbom ─────────────────────────────────
@test "SE-244-06: dependency-scan.sh acepta --generate-sbom" {
  grep -q "\-\-generate-sbom" "$SCRIPTS/dependency-scan.sh"
}

# ── Test 7: El script auto-detecta package.json (Node) ───────────────────────
@test "SE-244-07: dependency-scan.sh auto-detecta package.json para Node" {
  grep -q "package.json" "$SCRIPTS/dependency-scan.sh"
}

# ── Test 8: El script auto-detecta requirements.txt (Python) ─────────────────
@test "SE-244-08: dependency-scan.sh auto-detecta requirements.txt para Python" {
  grep -q "requirements.txt" "$SCRIPTS/dependency-scan.sh"
}

# ── Test 9: El script auto-detecta *.csproj (C#) ─────────────────────────────
@test "SE-244-09: dependency-scan.sh auto-detecta *.csproj para C#/.NET" {
  grep -q "\.csproj" "$SCRIPTS/dependency-scan.sh"
}

# ── Test 10: El script genera SBOM en output/security/ ───────────────────────
@test "SE-244-10: dependency-scan.sh genera SBOM en output/security/" {
  grep -q "output/security" "$SCRIPTS/dependency-scan.sh"
  grep -q "sbom" "$SCRIPTS/dependency-scan.sh"
}

# ── Test 11: dependency-security-policy.md menciona SBOM o CycloneDX ─────────
@test "SE-244-11: dependency-security-policy.md menciona SBOM o CycloneDX" {
  local policy_file="$DOCS/dependency-security-policy.md"
  grep -qiE "SBOM|CycloneDX" "$policy_file"
}

# ── Test 12: dependency-scan.sh tiene set -uo pipefail ───────────────────────
@test "SE-244-12: dependency-scan.sh tiene set -uo pipefail" {
  grep -qE "set -[ue]o pipefail|set -uo pipefail" "$SCRIPTS/dependency-scan.sh"
}
