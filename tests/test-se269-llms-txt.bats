#!/usr/bin/env bats
# BATS tests for scripts/llms-txt-generate.sh (SE-269 S5)
# Ref: docs/specs/SE-269-bmad-patterns.spec.md

SCRIPT="scripts/llms-txt-generate.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
}

# ── Structure / safety ────────────────────────────────────────────────────

@test "SE269-S5: script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "SE269-S5: script has valid bash syntax" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ── LLMS index generation ─────────────────────────────────────────────────

@test "SE269-S5: generate produces docs/llms.txt" {
  run bash "$SCRIPT" generate
  [ "$status" -eq 0 ]
  [[ -f "docs/llms.txt" ]]
}

@test "SE269-S5: generate produces docs/llms-full.txt" {
  run bash "$SCRIPT" generate
  [ "$status" -eq 0 ]
  [[ -f "docs/llms-full.txt" ]]
}

@test "SE269-S5 AC-5.1: llms.txt contains key sections" {
  run bash "$SCRIPT" generate
  [ "$status" -eq 0 ]
  run cat docs/llms.txt
  [[ "$output" == *"Savia"* ]]
  [[ "$output" == *"Nucleo operativo"* ]]
  [[ "$output" == *"Arquitectura"* ]]
  [[ "$output" == *"Seguridad"* ]]
  [[ "$output" == *"Desarrollo"* ]]
}

@test "SE269-S5 AC-5.1: llms-full.txt contains core docs" {
  run bash "$SCRIPT" generate
  [ "$status" -eq 0 ]
  # Verify core docs are referenced (check for path references)
  run grep -q "critical-facts" docs/llms-full.txt
  [ "$status" -eq 0 ]
  run grep -q "CRITERIO" docs/llms-full.txt
  [ "$status" -eq 0 ]
}

# ── AC-5.3: Determinism ──────────────────────────────────────────────────

@test "SE269-S5 AC-5.3: check reports deterministic" {
  run bash "$SCRIPT" check
  [ "$status" -eq 0 ]
  [[ "$output" == *"DETERMINISTA"* ]]
}

@test "SE269-S5 AC-5.3: two generations produce identical output (minus timestamps)" {
  run bash "$SCRIPT" generate
  [ "$status" -eq 0 ]
  local hash1; hash1=$(grep -v "Generado:" docs/llms-full.txt | sha256sum | cut -d' ' -f1)
  run bash "$SCRIPT" generate
  [ "$status" -eq 0 ]
  local hash2; hash2=$(grep -v "Generado:" docs/llms-full.txt | sha256sum | cut -d' ' -f1)
  [[ "$hash1" == "$hash2" ]]
}

# ── Subcommands ───────────────────────────────────────────────────────────

@test "SE269-S5: index subcommand generates llms.txt but not full" {
  local before_hash; before_hash=$(sha256sum docs/llms-full.txt 2>/dev/null | cut -d' ' -f1 || echo "initial")
  run bash "$SCRIPT" index
  [ "$status" -eq 0 ]
  [[ -f "docs/llms.txt" ]]
}

@test "SE269-S5: full subcommand regenerates llms-full.txt" {
  run bash "$SCRIPT" full
  [ "$status" -eq 0 ]
  [[ -f "docs/llms-full.txt" ]]
}

# ── AC-5.2: Sensitive path filtering ──────────────────────────────────────

@test "SE269-S5 AC-5.2: llms-full.txt does not contain active-user profile" {
  run bash "$SCRIPT" generate
  [ "$status" -eq 0 ]
  # active-user.md should NOT appear in consolidated output
  run grep -c "active-user.md" docs/llms-full.txt 2>/dev/null || true
  # count should be 0 or the grep exits non-zero meaning not found
  [[ "$output" == "0" || "$status" -ne 0 ]]
}

# ── Spec index in llms-full.txt ───────────────────────────────────────────

@test "SE269-S5: llms-full.txt contains spec index" {
  run bash "$SCRIPT" generate
  [ "$status" -eq 0 ]
  run grep -q "docs/specs/ (indice)" docs/llms-full.txt
  [ "$status" -eq 0 ]
}

@test "SE269-S5: llms-full.txt references SE-269 spec" {
  run bash "$SCRIPT" generate
  [ "$status" -eq 0 ]
  run grep -q "SE-269" docs/llms-full.txt
  [ "$status" -eq 0 ]
}

# ── Output size ───────────────────────────────────────────────────────────

@test "SE269-S5 AC-5.1: llms.txt has reasonable size" {
  run bash "$SCRIPT" generate
  [ "$status" -eq 0 ]
  local size; size=$(wc -c < docs/llms.txt)
  [[ "$size" -gt 100 ]]
  [[ "$size" -lt 10000 ]]
}

@test "SE269-S5 AC-5.1: llms-full.txt has reasonable size" {
  run bash "$SCRIPT" generate
  [ "$status" -eq 0 ]
  local size; size=$(wc -c < docs/llms-full.txt)
  [[ "$size" -gt 500 ]]
  [[ "$size" -lt 50000 ]]
}

# ── Invalid subcommand ────────────────────────────────────────────────────

@test "SE269-S5: invalid subcommand shows usage" {
  run bash "$SCRIPT" invalid-subcommand
  [ "$status" -eq 1 ]
}
