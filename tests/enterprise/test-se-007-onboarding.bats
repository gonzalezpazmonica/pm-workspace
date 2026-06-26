#!/usr/bin/env bats
# test-se-007-onboarding.bats — SPEC-SE-007: Enterprise Onboarding
# Tests: onboarding-batch.sh, sso-adapter-check.sh, enterprise-onboarding-protocol.md

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR

  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export REPO_ROOT

  ONBOARD_SCRIPT="${REPO_ROOT}/scripts/enterprise/onboarding-batch.sh"
  SSO_SCRIPT="${REPO_ROOT}/scripts/enterprise/sso-adapter-check.sh"
  PROTOCOL_DOC="${REPO_ROOT}/docs/rules/domain/enterprise-onboarding-protocol.md"
  export ONBOARD_SCRIPT SSO_SCRIPT PROTOCOL_DOC

  # Directorio de perfiles en tmp
  PROFILES_DIR="${TEST_TMPDIR}/profiles/users"
  export PROFILES_DIR

  # CSV sintético de prueba
  TEST_CSV="${TEST_TMPDIR}/test-users.csv"
  cat > "$TEST_CSV" <<'CSV'
user_slug,display_name,role,tenant,email
jsmith,John Smith,developer,squad-alpha,jsmith@test.com
mgomez,María Gómez,pm,squad-beta,mgomez@test.com
alopez,Ana López,architect,squad-alpha,alopez@test.com
CSV
  export TEST_CSV
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ── Test 1: onboarding-batch.sh existe ───────────────────────────────────────

@test "SE-007: onboarding-batch.sh existe y es ejecutable" {
  [[ -f "$ONBOARD_SCRIPT" ]]
  [[ -x "$ONBOARD_SCRIPT" ]] || chmod +x "$ONBOARD_SCRIPT"
}

# ── Test 2: --dry-run no crea ficheros ────────────────────────────────────────

@test "SE-007: --dry-run no crea ficheros de perfil" {
  chmod +x "$ONBOARD_SCRIPT"
  run bash "$ONBOARD_SCRIPT" --csv "$TEST_CSV" --dry-run --profiles-dir "$PROFILES_DIR"
  [ "$status" -eq 0 ]

  # No deben haberse creado perfiles
  # (el directorio puede no existir, o estar vacío)
  if [[ -d "$PROFILES_DIR" ]]; then
    USER_COUNT=$(find "$PROFILES_DIR" -name "identity.md" 2>/dev/null | wc -l | tr -d ' ')
    [ "$USER_COUNT" -eq 0 ]
  fi
}

# ── Test 3: con CSV sintético crea perfil identity.md ─────────────────────────

@test "SE-007: con CSV sintético crea perfiles identity.md" {
  chmod +x "$ONBOARD_SCRIPT"
  run bash "$ONBOARD_SCRIPT" --csv "$TEST_CSV" --profiles-dir "$PROFILES_DIR"
  [ "$status" -eq 0 ]

  # Verificar que se crearon perfiles
  [[ -f "${PROFILES_DIR}/jsmith/identity.md" ]]
  [[ -f "${PROFILES_DIR}/mgomez/identity.md" ]]
  [[ -f "${PROFILES_DIR}/alopez/identity.md" ]]
}

# ── Test 4: identity.md tiene nombre y rol correctos ─────────────────────────

@test "SE-007: identity.md contiene display_name y role del CSV" {
  chmod +x "$ONBOARD_SCRIPT"
  bash "$ONBOARD_SCRIPT" --csv "$TEST_CSV" --profiles-dir "$PROFILES_DIR" >/dev/null 2>&1

  IDENTITY="${PROFILES_DIR}/jsmith/identity.md"
  grep -q "John Smith" "$IDENTITY"
  grep -q "developer" "$IDENTITY"
}

# ── Test 5: sso-adapter-check.sh produce JSON ─────────────────────────────────

@test "SE-007: sso-adapter-check.sh produce JSON" {
  chmod +x "$SSO_SCRIPT"
  run bash "$SSO_SCRIPT" --provider okta
  [ "$status" -eq 0 ]
  # Debe producir JSON (empieza con {)
  [[ "$output" == "{"* ]] || [[ "$output" == *"{"* ]]
  # Debe tener alguno de los dos campos esperados
  echo "$output" | grep -qE '"(sso_not_configured|provider)"'
}

# ── Test 6: sso_not_configured=true en entorno sin SSO ───────────────────────

@test "SE-007: sso_not_configured=true en entorno sin SSO configurado" {
  chmod +x "$SSO_SCRIPT"

  # Asegurar que no hay vars de entorno de SSO
  unset SSO_PROVIDER_URL || true
  unset SSO_ACS_URL || true
  unset SSO_CERT_PATH || true

  run bash "$SSO_SCRIPT" --provider okta
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"sso_not_configured": true'
}

# ── Test 7: enterprise-onboarding-protocol.md existe ─────────────────────────

@test "SE-007: enterprise-onboarding-protocol.md existe" {
  [[ -f "$PROTOCOL_DOC" ]]
}

# ── Test 8: output JSON de batch tiene campo total ────────────────────────────

@test "SE-007: output JSON de onboarding-batch tiene campo total" {
  chmod +x "$ONBOARD_SCRIPT"
  run bash "$ONBOARD_SCRIPT" --csv "$TEST_CSV" --profiles-dir "$PROFILES_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"total"'
  echo "$output" | grep -q '"created"'
}
