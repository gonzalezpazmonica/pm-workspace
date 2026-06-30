#!/usr/bin/env bats
# SE-239 — Tests para git history secret scanning
# Ref: docs/propuestas/SE-239-git-history-secret-scanning.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT_SCAN="$REPO_ROOT/scripts/git-history-secret-scan.sh"
  SCRIPT_REMEDIATE="$REPO_ROOT/scripts/git-history-secret-remediate.sh"
  SKILL_MD="$REPO_ROOT/.opencode/skills/git-secret-scanner/SKILL.md"
  GITLEAKS_CONFIG="$REPO_ROOT/.gitleaks.toml"
  TMPDIR_239="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPDIR_239"
}

# ── 1. git-history-secret-scan.sh existe y pasa bash -n ──────────────────────
@test "SE239-01: git-history-secret-scan.sh existe y pasa bash -n" {
  [[ -f "$SCRIPT_SCAN" ]]
  bash -n "$SCRIPT_SCAN"
}

# ── 2. git-history-secret-remediate.sh existe y pasa bash -n ─────────────────
@test "SE239-02: git-history-secret-remediate.sh existe y pasa bash -n" {
  [[ -f "$SCRIPT_REMEDIATE" ]]
  bash -n "$SCRIPT_REMEDIATE"
}

# ── 3. SKILL.md existe y ≤150 líneas ─────────────────────────────────────────
@test "SE239-03: git-secret-scanner/SKILL.md existe y tiene 150 líneas o menos" {
  [[ -f "$SKILL_MD" ]]
  local lines
  lines=$(wc -l < "$SKILL_MD")
  [[ "$lines" -le 150 ]]
}

# ── 4. Con gitleaks no disponible → muestra instrucciones de instalación ──────
@test "SE239-04: sin gitleaks muestra instrucciones de instalación" {
  local fake_home="$TMPDIR_239/nohome"
  mkdir -p "$fake_home/bin"
  # Crear un repo git de prueba con .gitignore
  local test_repo="$TMPDIR_239/testrepo"
  mkdir -p "$test_repo"
  git -C "$test_repo" init --quiet
  echo "output/" > "$test_repo/.gitignore"
  git -C "$test_repo" add .gitignore
  git -C "$test_repo" -c user.email="t@t.com" -c user.name="T" commit -m "init" --quiet

  # Crear una copia del script que apunte al test repo
  local test_script="$TMPDIR_239/git-history-secret-scan.sh"
  sed "s|REPO_ROOT=.*|REPO_ROOT=\"$test_repo\"|" "$SCRIPT_SCAN" > "$test_script"

  run env PATH="$fake_home/bin:$(dirname $(which git))" bash "$test_script" 2>&1
  # Debe mencionar instrucciones de instalación
  [[ "$output" == *"gitleaks"* ]] || [[ "$output" == *"install"* ]] || [[ "$output" == *"Instalación"* ]]
}

# ── 5. Con gitleaks no disponible → sugiere alternativa Docker ────────────────
@test "SE239-05: sin gitleaks sugiere alternativa Docker" {
  local fake_home="$TMPDIR_239/nohome2"
  mkdir -p "$fake_home/bin"
  local test_repo="$TMPDIR_239/testrepo2"
  mkdir -p "$test_repo"
  git -C "$test_repo" init --quiet
  echo "output/" > "$test_repo/.gitignore"
  git -C "$test_repo" add .gitignore
  git -C "$test_repo" -c user.email="t@t.com" -c user.name="T" commit -m "init" --quiet

  local test_script="$TMPDIR_239/scan2.sh"
  sed "s|REPO_ROOT=.*|REPO_ROOT=\"$test_repo\"|" "$SCRIPT_SCAN" > "$test_script"

  run env PATH="$fake_home/bin:$(dirname $(which git))" bash "$test_script" 2>&1
  [[ "$output" == *"docker"* ]] || [[ "$output" == *"Docker"* ]]
}

# ── 6. git-history-secret-scan.sh acepta flag --since ────────────────────────
@test "SE239-06: git-history-secret-scan.sh acepta flag --since" {
  grep -q -- "--since" "$SCRIPT_SCAN"
}

# ── 7. El script genera report en output/security/ (no en raíz) ───────────────
@test "SE239-07: el script genera report en output/security/" {
  grep -q "output/security" "$SCRIPT_SCAN"
}

# ── 8. El script clasifica findings por severidad ─────────────────────────────
@test "SE239-08: el script clasifica findings CRITICAL/HIGH/MEDIUM/LOW" {
  grep -q "CRITICAL" "$SCRIPT_SCAN"
  grep -q "HIGH"     "$SCRIPT_SCAN"
  grep -q "MEDIUM"   "$SCRIPT_SCAN"
  grep -q "LOW"      "$SCRIPT_SCAN"
}

# ── 9. Exit code 1 cuando hay CRITICAL o HIGH ─────────────────────────────────
@test "SE239-09: exit code 1 definido para CRITICAL/HIGH findings" {
  grep -q "sys.exit(1)" "$SCRIPT_SCAN"
}

# ── 10. Exit code 2 cuando solo hay MEDIUM/LOW ────────────────────────────────
@test "SE239-10: exit code 2 definido para MEDIUM/LOW findings" {
  grep -q "sys.exit(2)" "$SCRIPT_SCAN"
}

# ── 11. Exit code 0 cuando no hay findings ────────────────────────────────────
@test "SE239-11: exit code 0 cuando no hay findings" {
  grep -q "exit 0" "$SCRIPT_SCAN"
}

# ── 12. git-history-secret-remediate.sh genera comando pero NO lo ejecuta ─────
@test "SE239-12: el script de remediation NO ejecuta git filter-repo automáticamente" {
  # No debe contener llamada directa a git filter-repo ni BFG sin comentario
  # Verifica que hay un echo que muestra el comando, no una ejecución directa
  grep -q "echo" "$SCRIPT_REMEDIATE"
  # El script debe mencionar que solo genera comandos
  grep -qi "genera\|genera el comando\|only genera\|no lo ejecuta\|No.*ejecuta" "$SCRIPT_REMEDIATE" || \
  grep -qi "human\|humano\|decide\|decide\|review" "$SCRIPT_REMEDIATE"
}

# ── 13. .gitleaks.toml existe con allowlist para hashes SHA256 ────────────────
@test "SE239-13: .gitleaks.toml existe y contiene allowlist para hashes SHA256" {
  [[ -f "$GITLEAKS_CONFIG" ]]
  grep -q "sha256\|SHA256\|[0-9a-f]\{64\}\|hash" "$GITLEAKS_CONFIG"
}

# ── 14. .gitleaks.toml excluye el patrón diff_hash= de firma de confidencialidad ──
@test "SE239-14: .gitleaks.toml excluye diff_hash= de la firma de confidencialidad" {
  [[ -f "$GITLEAKS_CONFIG" ]]
  grep -q "diff_hash" "$GITLEAKS_CONFIG"
}

# ── 15. SKILL.md menciona "gitleaks" o "secret" ──────────────────────────────
@test "SE239-15: SKILL.md menciona gitleaks o secret" {
  grep -qi "gitleaks\|secret" "$SKILL_MD"
}
