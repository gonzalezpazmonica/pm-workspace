#!/usr/bin/env bats
# test-se101-102-103-batch.bats — Tests for SE-101, SE-102, SE-103
# Tests: 14

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
RETENTION_DOC="$REPO_ROOT/docs/rules/domain/output-retention.md"
CLEANUP_SCRIPT="$REPO_ROOT/scripts/output-cleanup.sh"
ERAS_DOC="$REPO_ROOT/docs/eras-timeline.md"
DORMANT_SCRIPT="$REPO_ROOT/scripts/dormant-rules-review.sh"
SE101_SPEC="$REPO_ROOT/docs/propuestas/SE-101-output-cleanup-policy.md"
SE102_SPEC="$REPO_ROOT/docs/propuestas/SE-102-eras-timeline.md"
SE103_SPEC="$REPO_ROOT/docs/propuestas/SE-103-dormant-rules-review.md"

# ── SE-101: output-retention.md ───────────────────────────────────────────────

@test "SE-101: output-retention.md existe" {
  [ -f "$RETENTION_DOC" ]
}

@test "SE-101: output-retention.md menciona retención de 90 días" {
  grep -q "90" "$RETENTION_DOC"
}

@test "SE-101: output-retention.md menciona agent-runs con rotación semanal" {
  grep -q "agent-runs" "$RETENTION_DOC"
  grep -q "7" "$RETENTION_DOC"
}

@test "SE-101: output-retention.md menciona baselines con retención indefinida" {
  grep -q "baselines" "$RETENTION_DOC"
  grep -qi "indefinida\|indefinite" "$RETENTION_DOC"
}

# ── SE-101: output-cleanup.sh ─────────────────────────────────────────────────

@test "SE-101: output-cleanup.sh es ejecutable" {
  [ -x "$CLEANUP_SCRIPT" ]
}

@test "SE-101: output-cleanup.sh --help funciona y menciona --apply" {
  run bash "$CLEANUP_SCRIPT" --help
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "\-\-apply"
}

@test "SE-101: output-cleanup.sh sin flags no borra (sale con código 0)" {
  run bash "$CLEANUP_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "SE-101: output-cleanup.sh --dry-run no borra nada (fichero de prueba sobrevive)" {
  local tmpfile
  tmpfile=$(mktemp "$REPO_ROOT/output/test-keep-probe-XXXXXX.md")
  echo "probe" > "$tmpfile"
  run bash "$CLEANUP_SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  # El fichero sigue existiendo (--dry-run no borra)
  [ -f "$tmpfile" ]
  rm -f "$tmpfile"
}

@test "SE-101: output-cleanup.sh --stats muestra tamaño de output/" {
  run bash "$CLEANUP_SCRIPT" --stats
  [ "$status" -eq 0 ]
  # Debe mostrar alguna info de tamaño (M o K)
  echo "$output" | grep -qE "[0-9]+[KMG]|Ficheros"
}

# ── SE-102: eras-timeline.md ─────────────────────────────────────────────────

@test "SE-102: eras-timeline.md existe" {
  [ -f "$ERAS_DOC" ]
}

@test "SE-102: eras-timeline.md tiene tabla con columna Era (formato |)" {
  grep -q "| Era" "$ERAS_DOC"
}

@test "SE-102: eras-timeline.md contiene al menos 5 eras documentadas" {
  local count
  count=$(grep -c "^| Era [0-9]" "$ERAS_DOC" || true)
  [ "$count" -ge 5 ]
}

# ── SE-103: dormant-rules-review.sh ─────────────────────────────────────────

@test "SE-103: dormant-rules-review.sh es ejecutable" {
  [ -x "$DORMANT_SCRIPT" ]
}

@test "SE-103: dormant-rules-review.sh --dry-run lista reglas y sale con 0" {
  run bash "$DORMANT_SCRIPT" --dry-run --days 30
  [ "$status" -eq 0 ]
  # Debe mostrar header con el umbral
  echo "$output" | grep -q "30d"
}

# ── Specs IMPLEMENTED ────────────────────────────────────────────────────────

@test "SE-101: spec marcada IMPLEMENTED" {
  grep -q "status: IMPLEMENTED" "$SE101_SPEC"
}

@test "SE-102: spec marcada IMPLEMENTED" {
  grep -q "status: IMPLEMENTED" "$SE102_SPEC"
}

@test "SE-103: spec marcada IMPLEMENTED" {
  grep -q "status: IMPLEMENTED" "$SE103_SPEC"
}
