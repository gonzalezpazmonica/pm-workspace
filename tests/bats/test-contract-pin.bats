#!/usr/bin/env bats
# test-contract-pin.bats — BATS tests para SE-369 Contract Digest Pins
# Ref: docs/specs/SE-369-contract-digest-pins.spec.md — AC-0..AC-6

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  PIN="$REPO_ROOT/scripts/contract-pin.sh"
  export PIN REPO_ROOT
  # Catálogo aislado por test (CRIT-001: todo local)
  TMPDIR_SE369="$(mktemp -d)"
  export CONTRACT_DIGESTS_FILE="$TMPDIR_SE369/contract-digests.json"
  export FIXTURES="$TMPDIR_SE369"
  printf '{"schema_version": 1, "hooks": {"pre_tool": "gate.sh"}}\n' > "$FIXTURES/contract-v1.json"
}

teardown() {
  if [[ -d "${TMPDIR_SE369:-}" ]]; then
    rm -rf "$TMPDIR_SE369"
  fi
}

# ── AC-0: pin registra digest canónico y check pasa ───────────────────────────

@test "AC-0: pin registra digest sha256 y check pasa" {
  run "$PIN" pin pilot-contract --path "$FIXTURES/contract-v1.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PINNED"* ]]
  local expected
  expected="sha256:$(sha256sum "$FIXTURES/contract-v1.json" | cut -d' ' -f1)"
  run jq -r '.["pilot-contract"].current.digest' "$CONTRACT_DIGESTS_FILE"
  [ "$output" = "$expected" ]
  run "$PIN" check pilot-contract
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "AC-0: pin sin --path falla; pin con fichero inexistente falla" {
  run "$PIN" pin solo-nombre
  [ "$status" -ne 0 ]
  run "$PIN" pin fantasma --path "$FIXTURES/no-existe.json"
  [ "$status" -ne 0 ]
}

# ── AC-1: check falla si el fichero cambió sin bump ───────────────────────────

@test "AC-1: check falla tras modificar el fichero sin bump" {
  "$PIN" pin pilot-contract --path "$FIXTURES/contract-v1.json" > /dev/null
  printf '{"schema_version": 1, "hooks": {"pre_tool": "gate-v2.sh"}}\n' > "$FIXTURES/contract-v1.json"
  run "$PIN" check pilot-contract
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL"* ]]
  [[ "$output" == *"bump"* ]]
}

@test "AC-1: tras el bump, check vuelve a pasar" {
  "$PIN" pin pilot-contract --path "$FIXTURES/contract-v1.json" > /dev/null
  printf '{"schema_version": 2, "hooks": {"pre_tool": "gate-v2.sh"}}\n' > "$FIXTURES/contract-v1.json"
  run "$PIN" check pilot-contract
  [ "$status" -ne 0 ]
  run "$PIN" pin pilot-contract --path "$FIXTURES/contract-v1.json"
  [ "$status" -eq 0 ]
  run "$PIN" check pilot-contract
  [ "$status" -eq 0 ]
  run jq -r '.["pilot-contract"].current.version' "$CONTRACT_DIGESTS_FILE"
  [ "$output" = "2" ]
}

# ── AC-2: consumidor con schema antiguo rechaza nombrando el upgrade ──────────

@test "AC-2: accept con schema antiguo rechaza y nombra 'requiere upgrade a'" {
  "$PIN" pin pilot-contract --path "$FIXTURES/contract-v1.json" > /dev/null
  printf '{"schema_version": 2, "hooks": {"pre_tool": "gate-v2.sh"}}\n' > "$FIXTURES/contract-v1.json"
  "$PIN" pin pilot-contract --path "$FIXTURES/contract-v1.json" > /dev/null
  run "$PIN" accept pilot-contract --schema 1
  [ "$status" -ne 0 ]
  [[ "$output" == *"requiere upgrade a 2"* ]]
  run "$PIN" accept pilot-contract --schema 2
  [ "$status" -eq 0 ]
}

@test "AC-2: accept con schema desconocido (mayor que current) también rechaza" {
  "$PIN" pin pilot-contract --path "$FIXTURES/contract-v1.json" > /dev/null
  run "$PIN" accept pilot-contract --schema 99
  [ "$status" -ne 0 ]
  [[ "$output" == *"RECHAZADO"* ]]
}

# ── AC-3: campo aditivo aceptado solo si los conocidos son byte-idénticos ─────

@test "AC-3: campo añadido con conocidos intactos → ADITIVO (exit 0)" {
  printf '{"schema_version": 1, "hooks": {"pre_tool": "gate.sh"}}\n' > "$FIXTURES/base.json"
  printf '{"schema_version": 1, "hooks": {"pre_tool": "gate.sh"}, "nuevo_campo": true}\n' > "$FIXTURES/new.json"
  run "$PIN" additive-check --base "$FIXTURES/base.json" --new "$FIXTURES/new.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ADITIVO"* ]]
}

@test "AC-3: campo conocido modificado → BREAKING (exit 1)" {
  printf '{"schema_version": 1, "hooks": {"pre_tool": "gate.sh"}}\n' > "$FIXTURES/base.json"
  printf '{"schema_version": 2, "hooks": {"pre_tool": "gate.sh"}, "nuevo_campo": true}\n' > "$FIXTURES/new.json"
  run "$PIN" additive-check --base "$FIXTURES/base.json" --new "$FIXTURES/new.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"BREAKING"* ]]
  [[ "$output" == *"schema_version"* ]]
}

@test "AC-3: campo conocido ausente → BREAKING (exit 1)" {
  printf '{"schema_version": 1, "hooks": {"pre_tool": "gate.sh"}}\n' > "$FIXTURES/base.json"
  printf '{"schema_version": 1}\n' > "$FIXTURES/new.json"
  run "$PIN" additive-check --base "$FIXTURES/base.json" --new "$FIXTURES/new.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"BREAKING"* ]]
  [[ "$output" == *"ausentes"* ]]
}

# ── AC-4: versión previa en compat pero NUNCA recupera autoridad ──────────────

@test "AC-4: tras el bump la v1 queda compat=true authoritative=false" {
  "$PIN" pin pilot-contract --path "$FIXTURES/contract-v1.json" > /dev/null
  printf '{"schema_version": 2, "hooks": {"pre_tool": "gate-v2.sh"}}\n' > "$FIXTURES/contract-v1.json"
  "$PIN" pin pilot-contract --path "$FIXTURES/contract-v1.json" > /dev/null
  run jq -r '.["pilot-contract"].previous[0] | "\(.version) \(.compat) \(.authoritative)"' "$CONTRACT_DIGESTS_FILE"
  [ "$status" -eq 0 ]
  [ "$output" = "1 true false" ]
}

@test "AC-4: compat --version 1 reporta modo compat" {
  "$PIN" pin pilot-contract --path "$FIXTURES/contract-v1.json" > /dev/null
  printf '{"schema_version": 2, "hooks": {"pre_tool": "gate-v2.sh"}}\n' > "$FIXTURES/contract-v1.json"
  "$PIN" pin pilot-contract --path "$FIXTURES/contract-v1.json" > /dev/null
  run "$PIN" compat pilot-contract --version 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"COMPAT"* ]]
  run "$PIN" compat pilot-contract
  [ "$status" -eq 0 ]
  [[ "$output" == *"v1"* ]]
}

@test "AC-4: re-pinear el contenido de una versión previa es rechazado" {
  "$PIN" pin pilot-contract --path "$FIXTURES/contract-v1.json" > /dev/null
  cp "$FIXTURES/contract-v1.json" "$FIXTURES/v1-copy.json"
  printf '{"schema_version": 2, "hooks": {"pre_tool": "gate-v2.sh"}}\n' > "$FIXTURES/contract-v1.json"
  "$PIN" pin pilot-contract --path "$FIXTURES/contract-v1.json" > /dev/null
  # intento de restaurar el contenido v1 como current
  run "$PIN" pin pilot-contract --path "$FIXTURES/v1-copy.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"nunca recupera autoridad"* ]]
  # la current sigue siendo v2
  run jq -r '.["pilot-contract"].current.version' "$CONTRACT_DIGESTS_FILE"
  [ "$output" = "2" ]
}

@test "AC-4: --validate detecta catálogo manipulado con authoritative=true" {
  "$PIN" pin pilot-contract --path "$FIXTURES/contract-v1.json" > /dev/null
  printf '{"schema_version": 2, "hooks": {"pre_tool": "gate-v2.sh"}}\n' > "$FIXTURES/contract-v1.json"
  "$PIN" pin pilot-contract --path "$FIXTURES/contract-v1.json" > /dev/null
  local tmp
  tmp="$(mktemp)"
  jq '.["pilot-contract"].previous[0].authoritative = true' "$CONTRACT_DIGESTS_FILE" > "$tmp"
  mv "$tmp" "$CONTRACT_DIGESTS_FILE"
  run "$PIN" --validate
  [ "$status" -ne 0 ]
  [[ "$output" == *"authoritative=false"* ]]
}

# ── AC-5: catálogo --validate consistente ─────────────────────────────────────

@test "AC-5: --validate pasa con catálogo válido tras varios pins" {
  "$PIN" pin c1 --path "$FIXTURES/contract-v1.json" > /dev/null
  printf '{"schema_version": 2, "hooks": {"pre_tool": "gate-v2.sh"}}\n' > "$FIXTURES/contract-v1.json"
  "$PIN" pin c1 --path "$FIXTURES/contract-v1.json" > /dev/null
  printf '{"schema_version": 9, "hooks": {}}\n' > "$FIXTURES/contract-v1.json"
  "$PIN" pin c1 --path "$FIXTURES/contract-v1.json" > /dev/null
  "$PIN" pin c2 --path "$FIXTURES/base.json" > /dev/null 2>&1 || true
  run "$PIN" --validate
  [ "$status" -eq 0 ]
  [[ "$output" == *"VALID"* ]]
}

@test "AC-5: --validate falla con previous sin compat" {
  printf '{"c1": {"current": {"version": 2, "digest": "sha256:%s", "path": "x.json"}, "previous": [{"version": 1, "digest": "sha256:%s", "compat": false, "authoritative": false}]}}\n' \
    "$(printf 'a%.0s' {1..64})" "$(printf 'b%.0s' {1..64})" > "$CONTRACT_DIGESTS_FILE"
  run "$PIN" --validate
  [ "$status" -ne 0 ]
  [[ "$output" == *"compat=true"* ]]
}

@test "AC-5: --validate falla con digest malformado" {
  printf '{"c1": {"current": {"version": 1, "digest": "md5:abc", "path": "x.json"}, "previous": []}}\n' > "$CONTRACT_DIGESTS_FILE"
  run "$PIN" --validate
  [ "$status" -ne 0 ]
  [[ "$output" == *"digest malformado"* ]]
}

@test "AC-5: --validate falla con current ausente" {
  printf '{"c1": {"previous": []}}\n' > "$CONTRACT_DIGESTS_FILE"
  run "$PIN" --validate
  [ "$status" -ne 0 ]
  [[ "$output" == *"current"* ]]
}

# ── AC-6: piloto settings-hooks pineado, sin regresión ────────────────────────

@test "AC-6: piloto settings-hooks está pineado y check pasa contra .claude/settings.json" {
  local real_catalog="$REPO_ROOT/config/contract-digests.json"
  [ -f "$real_catalog" ]
  run jq -r 'has("settings-hooks")' "$real_catalog"
  [ "$output" = "true" ]
  run env CONTRACT_DIGESTS_FILE="$real_catalog" "$PIN" check settings-hooks
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
  run env CONTRACT_DIGESTS_FILE="$real_catalog" "$PIN" --validate
  [ "$status" -eq 0 ]
}

# ── extras: robustez CLI ──────────────────────────────────────────────────────

@test "check de contrato no pineado falla; comando desconocido falla" {
  run "$PIN" check inexistente
  [ "$status" -ne 0 ]
  run "$PIN" comando-inventado
  [ "$status" -ne 0 ]
}

@test "list muestra contratos pineados" {
  "$PIN" pin c1 --path "$FIXTURES/contract-v1.json" > /dev/null
  run "$PIN" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"c1"* ]]
}
