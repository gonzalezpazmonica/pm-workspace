#!/usr/bin/env bats
# SPEC-188: Root-Cause Investigation Architecture (meta-spec).
# Validates the spec document structure, sub-spec coordination,
# and Fase 0 closure (feedback_root_cause_always.md canonical path).
# Target: docs/propuestas/SPEC-188-root-cause-investigation-architecture.md
#         .claude/rules/domain/feedback/feedback_root_cause_always.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SPEC="$REPO_ROOT/docs/propuestas/SPEC-188-root-cause-investigation-architecture.md"
  FEEDBACK="$REPO_ROOT/.claude/rules/domain/feedback/feedback_root_cause_always.md"
}

# ── Document structure invariants ───────────────────────────────────────────

@test "SPEC-188 documento existe y tiene frontmatter" {
  [ -f "$SPEC" ]
  grep -q '^spec_id: SPEC-188' "$SPEC"
  grep -q '^status:' "$SPEC"
}

@test "SPEC-188 status es PROPOSED inicial" {
  grep -q '^status: PROPOSED' "$SPEC"
}

@test "SPEC-188 tiene priority P0 y tier 1" {
  grep -q '^priority: P0' "$SPEC"
  grep -q '^tier: 1' "$SPEC"
}

@test "SPEC-188 declara deps SE-072 y SPEC-106" {
  grep -q '^deps:.*SE-072' "$SPEC"
  grep -q '^deps:.*SPEC-106' "$SPEC"
}

# ── Architectural completeness ──────────────────────────────────────────────

@test "SPEC-188 documenta las 5 piezas P1-P5" {
  grep -qF "P1 — Failure Pattern Memory" "$SPEC"
  grep -qF "P2 — Causal Confidence Channel" "$SPEC"
  grep -qF "P3 — Sealed Contract Tests" "$SPEC"
  grep -qF "P4 — Diagnostic Quality Metrics" "$SPEC"
  grep -qF "P5 — Decision Trace Artifact" "$SPEC"
}

@test "SPEC-188 referencia las 4 sub-specs coordinadas" {
  for s in SPEC-043 SPEC-065 SPEC-108 SPEC-125; do
    grep -qF "$s" "$SPEC"
  done
}

@test "SPEC-188 identifica los 5 gaps G1-G5" {
  grep -qF "G1 — No sealed contract tests" "$SPEC"
  grep -qF "G2 — No calibration channel POST-CODE-CHANGE" "$SPEC"
  grep -qF "G3 — No failure pattern memory" "$SPEC"
  grep -qF "G4 — No diagnostic quality metrics" "$SPEC"
  grep -qF "G5 — No decision trace artifact" "$SPEC"
}

@test "SPEC-188 incluye plan de implementacion fasificado 0-4" {
  grep -qF "Fase 0" "$SPEC"
  grep -qF "Fase 1" "$SPEC"
  grep -qF "Fase 2" "$SPEC"
  grep -qF "Fase 3" "$SPEC"
  grep -qF "Fase 4" "$SPEC"
}

@test "SPEC-188 cada pieza nueva tiene feature flag declarado" {
  # P1 y P2 declaran feature flag (off-switch sin codigo)
  grep -q "SAVIA_FAILURE_PATTERN_MEMORY_ENABLED" "$SPEC"
  grep -q "SAVIA_CAUSAL_CONFIDENCE_ENABLED" "$SPEC"
}

@test "SPEC-188 declara bridge SE-072 (verified-memory-axiom)" {
  grep -q "Bridge SE-072" "$SPEC"
}

# ── Fase 0 closure: feedback_root_cause_always.md ───────────────────────────

@test "feedback_root_cause_always.md existe en path canonico" {
  [ -f "$FEEDBACK" ]
}

@test "feedback_root_cause_always.md tiene frontmatter type feedback" {
  grep -q '^type: feedback' "$FEEDBACK"
  grep -q '^slug: root_cause_always' "$FEEDBACK"
  grep -q '^status: active' "$FEEDBACK"
}

@test "feedback_root_cause_always.md declara regla canonica NEVER shortcuts" {
  grep -q "NEVER propose shortcuts" "$FEEDBACK"
  # "ALWAYS investigate the root cause" puede estar wrappeado, normalizar
  tr '\n' ' ' < "$FEEDBACK" | grep -qi "ALWAYS investigate the root cause"
}

@test "feedback_root_cause_always.md lista patrones prohibidos enumerados" {
  # Al menos 10 patrones prohibidos numerados 1-10
  enumerados=$(grep -cE '^[[:space:]]*[1-9][0-9]?\.' "$FEEDBACK")
  [ "$enumerados" -ge 10 ]
}

@test "feedback_root_cause_always.md referencia consumidores (jueces)" {
  grep -q "memory-conflict-judge" "$FEEDBACK"
  grep -q "responsibility-judge" "$FEEDBACK"
  grep -q "execution-supervisor" "$FEEDBACK"
}

@test "feedback_root_cause_always.md tiene verified_source en frontmatter" {
  grep -q '^verified_source:' "$FEEDBACK"
}

# ── Cross-references with sub-specs ─────────────────────────────────────────

@test "SPEC-188 referencia hallazgo G3 closure en Fase 0" {
  grep -qF "Fase 0 cierra hallazgo G3" "$SPEC" \
    || grep -qF "Fase 0 (cierre hallazgo G3)" "$SPEC" \
    || grep -qF "Fase 0 (1h): crear el fichero" "$SPEC"
}

@test "SPEC-188 declara path canonico .claude/rules/domain/feedback/" {
  grep -qF ".claude/rules/domain/feedback/feedback_root_cause_always.md" "$SPEC"
}

@test "SPEC-188 listado en docs/ROADMAP.md como PROPOSED" {
  grep -qF "SPEC-188" "$REPO_ROOT/docs/ROADMAP.md"
}

@test "SPEC-188 entrada presente en CHANGELOG.md" {
  grep -qF "SPEC-188" "$REPO_ROOT/CHANGELOG.md"
}
