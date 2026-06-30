#!/usr/bin/env bats
# SE-247 — Tests para pre-push security gate
# Ref: docs/propuestas/SE-247-pre-push-security-gate.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT_GATE="$REPO_ROOT/scripts/pre-push-security-gate.sh"
  SCRIPT_INSTALL="$REPO_ROOT/scripts/install-prepush-hook.sh"
  GATE_DOC="$REPO_ROOT/docs/rules/domain/pre-push-security-gate.md"
  GITLEAKS_CONFIG="$REPO_ROOT/.gitleaks.toml"
  TMPDIR_247="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPDIR_247"
}

# ── 1. pre-push-security-gate.sh existe y pasa bash -n ───────────────────────
@test "SE247-01: pre-push-security-gate.sh existe y pasa bash -n" {
  [[ -f "$SCRIPT_GATE" ]]
  bash -n "$SCRIPT_GATE"
}

# ── 2. install-prepush-hook.sh existe y pasa bash -n ─────────────────────────
@test "SE247-02: install-prepush-hook.sh existe y pasa bash -n" {
  [[ -f "$SCRIPT_INSTALL" ]]
  bash -n "$SCRIPT_INSTALL"
}

# ── 3. pre-push-security-gate.md existe y ≤150 líneas ────────────────────────
@test "SE247-03: pre-push-security-gate.md existe y tiene 150 líneas o menos" {
  [[ -f "$GATE_DOC" ]]
  local lines
  lines=$(wc -l < "$GATE_DOC")
  [[ "$lines" -le 150 ]]
}

# ── 4. Con SAVIA_PREPUSH_SECURITY=off → exit 0 sin ejecutar scan ──────────────
@test "SE247-04: SAVIA_PREPUSH_SECURITY=off produce exit 0 inmediato" {
  run env SAVIA_PREPUSH_SECURITY=off bash "$SCRIPT_GATE" <<< ""
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"SAVIA_PREPUSH_SECURITY=off"* ]] || [[ "$output" == *"skipped"* ]]
}

# ── 5. Si gitleaks no instalado → warning pero exit 0 ────────────────────────
@test "SE247-05: si gitleaks no instalado, warning pero continúa (exit 0)" {
  # Crear un wrapper que oculta gitleaks del PATH
  local fake_home="$TMPDIR_247/nohome"
  mkdir -p "$fake_home/bin"
  # Git sigue disponible, pero gitleaks no
  run env PATH="$fake_home/bin:$(dirname $(which git))" bash "$SCRIPT_GATE" \
    <<< "refs/heads/main abc123 refs/heads/main 0000000000000000000000000000000000000000"
  # exit 0 cuando gitleaks no existe (no bloquear)
  [[ "$status" -eq 0 ]]
}

# ── 6. El script verifica que output/security/ está en .gitignore ─────────────
@test "SE247-06: el script referencia output/security/ o .gitignore" {
  grep -qE '\.gitignore|output/' "$SCRIPT_GATE"
}

# ── 7. Con input vacío (no hay commits nuevos) → exit 0 ──────────────────────
@test "SE247-07: sin commits nuevos (stdin vacío), exit 0" {
  run bash "$SCRIPT_GATE" <<< ""
  [[ "$status" -eq 0 ]]
}

# ── 8. El hook genera output/security/pre-push-findings.jsonl cuando hay findings ──
@test "SE247-08: el script menciona pre-push-findings.jsonl como destino de findings" {
  grep -q "pre-push-findings.jsonl" "$SCRIPT_GATE"
}

# ── 9. pre-push-security-gate.md menciona "gitleaks" ─────────────────────────
@test "SE247-09: pre-push-security-gate.md menciona gitleaks" {
  grep -qi "gitleaks" "$GATE_DOC"
}

# ── 10. pre-push-security-gate.md menciona "SAVIA_PREPUSH_SECURITY" ──────────
@test "SE247-10: pre-push-security-gate.md menciona SAVIA_PREPUSH_SECURITY" {
  grep -q "SAVIA_PREPUSH_SECURITY" "$GATE_DOC"
}

# ── 11. install-prepush-hook.sh menciona ".git/hooks/pre-push" ───────────────
@test "SE247-11: install-prepush-hook.sh menciona .git/hooks/pre-push" {
  grep -q "pre-push" "$SCRIPT_INSTALL"
}

# ── 12. pre-push-security-gate.sh tiene set -uo pipefail ─────────────────────
@test "SE247-12: pre-push-security-gate.sh tiene set -uo pipefail o equivalente" {
  grep -qE "set -[a-z]*u[a-z]*(o pipefail)?|set -uo pipefail|set -euo pipefail" "$SCRIPT_GATE"
}

# ── 13. El script maneja el caso de repo sin commits (nuevo repo) ─────────────
@test "SE247-13: el script maneja SHA de cero (nuevo repo, rama nueva)" {
  local zero_sha="0000000000000000000000000000000000000000"
  run bash "$SCRIPT_GATE" <<< "refs/heads/main $zero_sha refs/heads/main $zero_sha"
  # Debe terminar con exit 0 (no hay commits que escanear)
  [[ "$status" -eq 0 ]]
}

# ── 14. La allowlist .gitleaks.toml existe en la raíz ────────────────────────
@test "SE247-14: .gitleaks.toml existe en la raíz del repo" {
  [[ -f "$GITLEAKS_CONFIG" ]]
}

# ── 15. El script menciona output/security/ como destino de reports ──────────
@test "SE247-15: el script menciona output/security/ como destino" {
  grep -q "output/security" "$SCRIPT_GATE"
}
