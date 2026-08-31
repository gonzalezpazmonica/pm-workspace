#!/usr/bin/env bats
# test-se353-credential-egress.bats — BATS tests for SE-353 Sentinel Credential Substitution
# Ref: SE-353 — credenciales fuera del contexto del modelo, resolución solo en egress

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  EGRESS="$REPO_ROOT/scripts/credential-egress.sh"
  export EGRESS
  # Store aislado por test (tmpdir, se limpia en teardown)
  export SAVIA_CRED_STORE_DIR="$(mktemp -d)"
}

teardown() {
  if [[ -d "${SAVIA_CRED_STORE_DIR:-}" ]]; then
    rm -rf "$SAVIA_CRED_STORE_DIR"
  fi
}

# ── T1: store / resolve / status ──────────────────────────────────────────────

@test "store crea keys.json con permisos 0600" {
  run "$EGRESS" store "pat-test" "secreto-123"
  [[ "$status" -eq 0 ]]
  local perms
  perms=$(stat -c "%a" "$SAVIA_CRED_STORE_DIR/keys.json")
  [[ "$perms" == "600" ]]
}

@test "store guarda cifrado (no contiene el valor en plano)" {
  "$EGRESS" store "pat-test" "VALOR-PLANO-SUPERSECRETO-999" >/dev/null
  run grep -q "VALOR-PLANO-SUPERSECRETO-999" "$SAVIA_CRED_STORE_DIR/keys.json"
  [[ "$status" -ne 0 ]]
}

@test "resolve devuelve el valor real para destino autorizado" {
  "$EGRESS" store "pat-test" "valor-real-abc" >/dev/null
  run "$EGRESS" resolve "pat-test" --dest dev.azure.com
  [[ "$status" -eq 0 ]]
  [[ "$output" == "valor-real-abc" ]]
}

@test "resolve REFUSE destino no autorizado" {
  "$EGRESS" store "pat-test" "valor-real-abc" >/dev/null
  run "$EGRESS" resolve "pat-test" --dest evil.com
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"REFUSE"* ]]
}

@test "resolve REFUSE marcador no registrado" {
  "$EGRESS" store "pat-existente" "valor-abc" >/dev/null
  run "$EGRESS" resolve "no-existe-xyz" --dest dev.azure.com
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"REFUSE"* ]]
}

@test "resolve REFUSE store no existe" {
  run "$EGRESS" resolve "pat-test" --dest dev.azure.com
  [[ "$status" -ne 0 ]]
}

# ── T2: run (sustitución en subproceso) ───────────────────────────────────────

@test "run sustituye savia:cred:<key> en args y ejecuta" {
  "$EGRESS" store "pat-test" "valor-run-42" >/dev/null
  run "$EGRESS" run bash -c 'echo "recibido:$1"' _ savia:cred:pat-test
  [[ "$status" -eq 0 ]]
  [[ "$output" == "recibido:valor-run-42" ]]
}

@test "run con marcador no registrado → exit != 0" {
  run "$EGRESS" run bash -c 'echo x' _ savia:cred:no-existe
  [[ "$status" -ne 0 ]]
}

# ── T3: status (nunca valores) ────────────────────────────────────────────────

@test "status lista keys sin exponer valores" {
  "$EGRESS" store "pat-a" "secreto-a" >/dev/null
  "$EGRESS" store "pat-b" "secreto-b" >/dev/null
  run "$EGRESS" status
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"pat-a"* ]]
  [[ "$output" == *"pat-b"* ]]
  [[ "$output" != *"secreto-a"* ]]
  [[ "$output" != *"secreto-b"* ]]
}

# ── T4: audit ─────────────────────────────────────────────────────────────────

@test "audit produce output de diagnóstico" {
  run "$EGRESS" audit
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Audit"* ]]
}

@test "audit detecta PAT-shaped en tests de hooks" {
  run "$EGRESS" audit "$REPO_ROOT"
  # los tests de hooks contienen ghp_ de ejemplo — el audit debe encontrarlos
  [[ "$output" == *"ghp_"* ]]
}

# ── T5: integridad / fail-safe ────────────────────────────────────────────────

@test "store sin valor → error" {
  run "$EGRESS" store "solo-key"
  [[ "$status" -ne 0 ]]
}

@test "resolve sin key → error" {
  run "$EGRESS" resolve
  [[ "$status" -ne 0 ]]
}
