#!/usr/bin/env bats
# tests/test-architectural-vocabulary.bats — SE-082 Architectural Vocabulary Discipline
# Ref: docs/propuestas/SE-082-architectural-vocabulary-discipline.md
# Ref: docs/rules/domain/architectural-vocabulary.md

ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
DOC="$ROOT/docs/rules/domain/architectural-vocabulary.md"
ANCHOR="$ROOT/docs/rules/domain/attention-anchor.md"
ARCHITECT="$ROOT/.opencode/agents/architect.md"
JUDGE="$ROOT/.opencode/agents/architecture-judge.md"
AUDIT="$ROOT/scripts/architectural-vocabulary-audit.sh"

# ── AC-01: Doc exists and is within 200-line budget ──────────────────────────

@test "AC-01a: architectural-vocabulary.md exists" {
  [ -f "$DOC" ]
}

@test "AC-01b: doc is within 200-line budget (≤200 LOC)" {
  local lines
  lines=$(wc -l < "$DOC")
  [ "$lines" -le 200 ]
}

# ── AC-02: MIT attribution to mattpocock ─────────────────────────────────────

@test "AC-02: doc cites mattpocock MIT attribution" {
  grep -q "mattpocock" "$DOC"
  grep -q "MIT" "$DOC"
}

# ── AC-01 details: 6 canonical terms defined with _Avoid_ ────────────────────

@test "AC-01c: Module defined with _Avoid_" {
  grep -q "### Module" "$DOC"
  grep -A 5 "### Module" "$DOC" | grep -q "_Avoid_"
}

@test "AC-01d: Interface defined with _Avoid_" {
  grep -q "### Interface" "$DOC"
  grep -A 5 "### Interface" "$DOC" | grep -q "_Avoid_"
}

@test "AC-01e: Seam defined with _Avoid_" {
  grep -q "### Seam" "$DOC"
  grep -A 5 "### Seam" "$DOC" | grep -q "_Avoid_"
}

@test "AC-01f: Adapter defined with _Avoid_" {
  grep -q "### Adapter" "$DOC"
  grep -A 5 "### Adapter" "$DOC" | grep -q "_Avoid_"
}

@test "AC-01g: Depth defined with _Avoid_" {
  grep -q "### Depth" "$DOC"
  grep -A 8 "### Depth" "$DOC" | grep -q "_Avoid_"
}

@test "AC-01h: Locality defined with _Avoid_" {
  grep -q "### Locality" "$DOC"
  grep -A 5 "### Locality" "$DOC" | grep -q "_Avoid_"
}

# ── AC-03: Cross-reference in attention-anchor.md ────────────────────────────

@test "AC-03: attention-anchor.md references architectural-vocabulary.md (SE-082)" {
  [ -f "$ANCHOR" ]
  grep -q "architectural-vocabulary.md" "$ANCHOR"
  grep -q "SE-082" "$ANCHOR"
}

# ── AC-04: architect agent references canonical doc ──────────────────────────

@test "AC-04: architect.md references architectural-vocabulary.md" {
  [ -f "$ARCHITECT" ]
  grep -q "architectural-vocabulary.md" "$ARCHITECT"
}

# ── AC-05: architecture-judge agent references canonical doc ─────────────────

@test "AC-05: architecture-judge.md references architectural-vocabulary.md" {
  [ -f "$JUDGE" ]
  grep -q "architectural-vocabulary.md" "$JUDGE"
}

# ── AC-06: audit script is executable and exits 0 (warning-only) ─────────────

@test "AC-06a: architectural-vocabulary-audit.sh is executable" {
  [ -x "$AUDIT" ]
}

@test "AC-06b: audit script --help exits 0" {
  run bash "$AUDIT" --help
  [ "$status" -eq 0 ]
}

@test "AC-06c: audit script exits 0 on empty scan (warning-only)" {
  run env AUDIT_GLOBS="no-match-*.md" bash "$AUDIT" --report
  [ "$status" -eq 0 ]
}

@test "AC-06d: audit script --json mode produces valid JSON structure" {
  run env AUDIT_GLOBS="no-match-*.md" bash "$AUDIT" --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"file_count"'
  echo "$output" | grep -q '"violations"'
}

# ── Additional structural checks ─────────────────────────────────────────────

@test "doc contains ratchet principles section" {
  grep -q "Principios ratchet\|ratchet" "$DOC"
}

@test "doc mentions deletion test" {
  grep -qi "deletion test\|Deletion test" "$DOC"
}

@test "agents cite SE-082 identifier" {
  grep -q "SE-082" "$ARCHITECT"
  grep -q "SE-082" "$JUDGE"
}
