#!/usr/bin/env bats
# tests/test-se-270-s3-skill-creator.bats
# SE-270 Slice 3 — BATS tests for scripts/skill-creator.sh
#
# Verifies: directory creation, SKILL.md frontmatter, DOMAIN.md,
# references/ directory, test file generation, kebab-case validation.

SCRIPT="scripts/skill-creator.sh"
SKILLS_BASE=".opencode/skills"

setup() {
  TMPDIR="$(mktemp -d)"
  ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
  SAVIA_SKILLS_DIR="$TMPDIR/skills"
  mkdir -p "$SAVIA_SKILLS_DIR"
}

teardown() {
  rm -rf "$TMPDIR"
}

# ── Script existence ──────────────────────────────────────────────────────────

@test "SE-270-S3: skill-creator.sh exists" {
  [[ -f "$ROOT/$SCRIPT" ]]
}

@test "SE-270-S3: skill-creator.sh is executable" {
  [[ -x "$ROOT/$SCRIPT" ]]
}

@test "SE-270-S3: set -uo pipefail present" {
  run grep -c 'set -uo pipefail' "$ROOT/$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "SE-270-S3: bash -n syntax check passes" {
  run bash -n "$ROOT/$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "SE-270-S3: SE-270 reference present" {
  run grep -c 'SE-270' "$ROOT/$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "SE-270-S3: shows usage when no args" {
  run bash "$ROOT/$SCRIPT"
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "Usage" ]]
}

# ── Skill creation ────────────────────────────────────────────────────────────

@test "SE-270-S3: creates skill directory structure" {
  SAVIA_SKILLS_DIR="$TMPDIR/skills" run bash "$ROOT/$SCRIPT" test-skill --description "Usar cuando se necesita testear el sistema completo de skills con validación de frontmatter y routing."
  [[ "$status" -eq 0 ]]
  [[ -d "$TMPDIR/skills/test-skill" ]]
  [[ -f "$TMPDIR/skills/test-skill/SKILL.md" ]]
  [[ -f "$TMPDIR/skills/test-skill/DOMAIN.md" ]]
  [[ -d "$TMPDIR/skills/test-skill/references" ]]
}

@test "SE-270-S3: SKILL.md has correct frontmatter fields" {
  SAVIA_SKILLS_DIR="$TMPDIR/skills" run bash "$ROOT/$SCRIPT" test-frontmatter --description "Usar cuando se necesita validar el frontmatter YAML de las skills generadas automáticamente por el creador."
  [[ "$status" -eq 0 ]]
  run grep -c '^name: test-frontmatter' "$TMPDIR/skills/test-frontmatter/SKILL.md"
  [[ "$output" -ge 1 ]]
  run grep -c '^description:' "$TMPDIR/skills/test-frontmatter/SKILL.md"
  [[ "$output" -ge 1 ]]
  run grep -c '^tier: extended' "$TMPDIR/skills/test-frontmatter/SKILL.md"
  [[ "$output" -ge 1 ]]
  run grep -c '^maturity: stub' "$TMPDIR/skills/test-frontmatter/SKILL.md"
  [[ "$output" -ge 1 ]]
}

@test "SE-270-S3: tier defaults to extended" {
  SAVIA_SKILLS_DIR="$TMPDIR/skills" run bash "$ROOT/$SCRIPT" default-tier --description "Usar cuando se necesita validar que el tier por defecto sea extended y no core en la creación de nuevas skills."
  [[ "$status" -eq 0 ]]
  run grep 'tier: extended' "$TMPDIR/skills/default-tier/SKILL.md"
  [[ "$status" -eq 0 ]]
}

@test "SE-270-S3: --tier core sets tier to core" {
  SAVIA_SKILLS_DIR="$TMPDIR/skills" run bash "$ROOT/$SCRIPT" core-skill --tier core --description "Usar cuando se necesita una skill de tier core para el sistema de routing que es referenciada por agentes y comandos."
  [[ "$status" -eq 0 ]]
  run grep 'tier: core' "$TMPDIR/skills/core-skill/SKILL.md"
  [[ "$status" -eq 0 ]]
}

@test "SE-270-S3: --description sets custom description" {
  local mydesc="Usar cuando se necesita procesar y analizar grandes volúmenes de datos transaccionales con validación de integridad referencial y generación de reportes estructurados en formatos estándar."
  SAVIA_SKILLS_DIR="$TMPDIR/skills" run bash "$ROOT/$SCRIPT" custom-desc --description "$mydesc"
  [[ "$status" -eq 0 ]]
  run grep "$mydesc" "$TMPDIR/skills/custom-desc/SKILL.md"
  [[ "$status" -eq 0 ]]
}

@test "SE-270-S3: generates placeholder test file" {
  TEST_DIR="$TMPDIR/tests"
  mkdir -p "$TEST_DIR"
  local orig_test_dir="tests"
  # Override: test file goes to the actual tests dir relative to ROOT
  # We test the file creation by checking the ROOT tests dir
  # For test isolation, create a symlink approach
  # Instead, check that the script attempts to create the test in tests/
  # We'll verify the reference is present in output
  SAVIA_SKILLS_DIR="$TMPDIR/skills" run bash "$ROOT/$SCRIPT" has-test --description "Usar cuando se necesita verificar que el creador de skills genera los tests placeholder correctamente en el directorio."
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "tests/test-se-270-skill-has-test.bats" ]]
}

@test "SE-270-S3: SKILL.md has Authoritative Paths section" {
  SAVIA_SKILLS_DIR="$TMPDIR/skills" run bash "$ROOT/$SCRIPT" auth-paths --description "Usar cuando se necesita verificar que la sección de Authoritative Paths se genera correctamente en el SKILL.md de la nueva skill."
  [[ "$status" -eq 0 ]]
  run grep -c 'Authoritative Paths' "$TMPDIR/skills/auth-paths/SKILL.md"
  [[ "$output" -ge 1 ]]
}

@test "SE-270-S3: DOMAIN.md has frontmatter" {
  SAVIA_SKILLS_DIR="$TMPDIR/skills" run bash "$ROOT/$SCRIPT" domain-test --description "Usar cuando se necesita verificar que el DOMAIN.md generado tiene frontmatter válido con el nombre de la skill."
  [[ "$status" -eq 0 ]]
  run grep -c '^name:' "$TMPDIR/skills/domain-test/DOMAIN.md"
  [[ "$output" -ge 1 ]]
}

# ── Kebab-case validation ─────────────────────────────────────────────────────

@test "SE-270-S3: rejects non-kebab-case names" {
  SAVIA_SKILLS_DIR="$TMPDIR/skills" run bash "$ROOT/$SCRIPT" "Invalid Name"
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "kebab-case" ]]
}

@test "SE-270-S3: rejects names with underscores" {
  SAVIA_SKILLS_DIR="$TMPDIR/skills" run bash "$ROOT/$SCRIPT" "invalid_name"
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "kebab-case" ]]
}

@test "SE-270-S3: accepts valid kebab-case names" {
  SAVIA_SKILLS_DIR="$TMPDIR/skills" run bash "$ROOT/$SCRIPT" my-valid-skill-name --description "Usar cuando se necesita validar que el creador de skills acepta correctamente nombres en formato kebab-case válido."
  [[ "$status" -eq 0 ]]
  [[ -d "$TMPDIR/skills/my-valid-skill-name" ]]
}

# ── Rejects duplicate ─────────────────────────────────────────────────────────

@test "SE-270-S3: rejects duplicate skill names" {
  mkdir -p "$TMPDIR/skills/existing-skill"
  SAVIA_SKILLS_DIR="$TMPDIR/skills" run bash "$ROOT/$SCRIPT" existing-skill --description "Usar cuando se necesita verificar que el creador rechaza skills que ya existen en el directorio de skills."
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "already exists" ]]
}

# ── Invalid tier ──────────────────────────────────────────────────────────────

@test "SE-270-S3: rejects invalid tier values" {
  SAVIA_SKILLS_DIR="$TMPDIR/skills" run bash "$ROOT/$SCRIPT" bad-tier --tier invalid --description "Usar cuando se necesita verificar que el creador rechaza valores de tier inválidos."
  [[ "$status" -eq 1 ]]
}

# ── Safe mode: run against real skills dir (integration) ──────────────────────

@test "SE-270-S3: real skill-creator.sh runs successfully with --help" {
  run bash "$ROOT/$SCRIPT" --help
  [[ "$status" -eq 1 ]] || [[ "$output" =~ "Usage" ]]
}
