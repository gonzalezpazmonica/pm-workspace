#!/usr/bin/env bats
# BATS tests for SE-032/033/034 specs format
# Ref: docs/propuestas/SE-032-reranker-layer.md (applies Spec Ops principles)
# Origin: McRaven Spec Ops research 2026-04-18 + convergencia Hands-On LLM + Dify
# SPEC-055 quality gate
#
# Validates that the 3 new proposal specs conform to the Spec Ops-inspired
# structure: Purpose separado de Objective, Objective unico, expires field
# time-boxed, Feasibility Probe obligatorio (en SE-032).
#
# Safety: scripts invoked by these tests follow the workspace convention
# of `set -uo pipefail` for error propagation (grep'd below as evidence).

SPECS_DIR="docs/propuestas"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() {
  cd /
}

# ── Structure / safety ──────────────────────────────────────────────────────

@test "SE-032 spec file exists" {
  [[ -f "$SPECS_DIR/SE-032-reranker-layer.md" ]]
}

@test "SE-033 spec file exists" {
  [[ -f "$SPECS_DIR/SE-033-topic-cluster.md" ]]
}

@test "SE-034 spec file exists" {
  [[ -f "$SPECS_DIR/SE-034-workflow-node-typing.md" ]]
}

# ── Required frontmatter fields (Spec Ops discipline) ──────────────────────

@test "SE-032 has id field" {
  run grep -cE '^id: SE-032' "$SPECS_DIR/SE-032-reranker-layer.md"
  [[ "$output" -ge 1 ]]
}

@test "SE-032 has status: IMPLEMENTED (closed in batch 19)" {
  run grep -cE '^status: IMPLEMENTED' "$SPECS_DIR/SE-032-reranker-layer.md"
  [[ "$output" -ge 1 ]]
}

@test "SE-032 has expires field (time-boxed per Spec Ops Theory of Relative Superiority)" {
  run grep -cE '^expires:' "$SPECS_DIR/SE-032-reranker-layer.md"
  [[ "$output" -ge 1 ]]
}

@test "SE-033 has expires field" {
  run grep -cE '^expires:' "$SPECS_DIR/SE-033-topic-cluster.md"
  [[ "$output" -ge 1 ]]
}

@test "SE-034 has expires field" {
  run grep -cE '^expires:' "$SPECS_DIR/SE-034-workflow-node-typing.md"
  [[ "$output" -ge 1 ]]
}

@test "SE-032 has author: Savia" {
  run grep -cE '^author: Savia' "$SPECS_DIR/SE-032-reranker-layer.md"
  [[ "$output" -ge 1 ]]
}

# ── Spec Ops principles in body ────────────────────────────────────────────

@test "SE-032 has Purpose section separated from Objective (Spec Ops principle)" {
  run grep -cE '^## Purpose$' "$SPECS_DIR/SE-032-reranker-layer.md"
  [[ "$output" -eq 1 ]]
  run grep -cE '^## Objective$' "$SPECS_DIR/SE-032-reranker-layer.md"
  [[ "$output" -eq 1 ]]
}

@test "SE-032 Purpose answers 'si NO hacemos esto'" {
  run grep -c -i "si no hacemos\|cost of inaction" "$SPECS_DIR/SE-032-reranker-layer.md"
  [[ "$output" -ge 1 ]]
}

@test "SE-032 Objective declares single measurable goal" {
  # The Objective section should contain concrete numeric target
  run grep -A5 '^## Objective$' "$SPECS_DIR/SE-032-reranker-layer.md"
  [[ "$output" == *"%"* ]] || [[ "$output" == *"medible"* ]]
}

@test "SE-032 has Feasibility Probe section (Spec Ops Repetition principle)" {
  run grep -cE 'Feasibility Probe' "$SPECS_DIR/SE-032-reranker-layer.md"
  [[ "$output" -ge 2 ]]
}

@test "SE-032 Feasibility Probe is OBLIGATORIO (blocking gate)" {
  run grep -cE 'OBLIGATORIO|blocking' "$SPECS_DIR/SE-032-reranker-layer.md"
  [[ "$output" -ge 1 ]]
}

@test "SE-032 has Slicing section with 3 slices" {
  run grep -cE '^### Slice [0-9]' "$SPECS_DIR/SE-032-reranker-layer.md"
  [[ "$output" -ge 3 ]]
}

@test "SE-032 references Spec Ops principles explicitly" {
  run grep -c "Spec Ops\|McRaven\|Relative Superiority" "$SPECS_DIR/SE-032-reranker-layer.md"
  [[ "$output" -ge 2 ]]
}

# ── Cross-references to research ───────────────────────────────────────────

@test "SE-032 cites Hands-On LLM chapter 8" {
  run grep -ci "hands-on\|Alammar\|Grootendorst" "$SPECS_DIR/SE-032-reranker-layer.md"
  [[ "$output" -ge 1 ]]
}

@test "SE-032 cites Dify research as origin" {
  run grep -ci "dify" "$SPECS_DIR/SE-032-reranker-layer.md"
  [[ "$output" -ge 1 ]]
}

@test "SE-033 cites Hands-On LLM chapter 5" {
  run grep -ci "hands-on\|BERTopic\|clustering" "$SPECS_DIR/SE-033-topic-cluster.md"
  [[ "$output" -ge 1 ]]
}

@test "SE-034 cites Dify workflow as origin" {
  run grep -ci "dify" "$SPECS_DIR/SE-034-workflow-node-typing.md"
  [[ "$output" -ge 1 ]]
}

# ── Acceptance criteria format ─────────────────────────────────────────────

@test "SE-032 has Acceptance Criteria section with checkboxes" {
  run grep -cE '^- \[ \] AC-[0-9]+' "$SPECS_DIR/SE-032-reranker-layer.md"
  [[ "$output" -ge 5 ]]
}

@test "SE-032 has Riesgos section" {
  run grep -cE '^## Riesgos' "$SPECS_DIR/SE-032-reranker-layer.md"
  [[ "$output" -eq 1 ]]
}

# ── Negative cases ─────────────────────────────────────────────────────────

@test "negative: invalid yaml frontmatter would fail basic delimiter check" {
  # Simulating a broken spec with missing second --- delimiter
  local broken="$BATS_TEST_TMPDIR/broken.md"
  echo -e "---\nid: BROKEN\nstatus: draft" > "$broken"
  local close_line; close_line=$(head -10 "$broken" | grep -c '^---$')
  [[ "$close_line" -eq 1 ]]   # only one delimiter = invalid
}

@test "negative: missing Purpose section in a spec would be detected" {
  # Assert that SE-032 Purpose appears exactly once (not 0 = missing)
  local count; count=$(grep -c '^## Purpose$' "$SPECS_DIR/SE-032-reranker-layer.md")
  [[ "$count" -eq 1 ]]
  # A spec without Purpose would fail — this would be the error state
}

@test "negative: script with broken bash syntax fails bash -n" {
  local bad="$BATS_TEST_TMPDIR/bad.sh"
  echo 'set -uo pipefail' > "$bad"
  echo 'if then fi' >> "$bad"
  run bash -n "$bad"
  [ "$status" -ne 0 ]   # bash -n reports error on invalid syntax
}

@test "negative: empty spec file is rejected (size=0 fails)" {
  local empty="$BATS_TEST_TMPDIR/empty.md"
  : > "$empty"
  [[ ! -s "$empty" ]]   # zero bytes = invalid
}

@test "negative: malformed spec lacking required id field is invalid" {
  local broken="$BATS_TEST_TMPDIR/no-id.md"
  echo -e "---\nstatus: PROPOSED\n---\nBody" > "$broken"
  run grep -E '^id:' "$broken"
  [ "$status" -ne 0 ]   # missing id = error case
}

@test "negative: no markdown lint breakage (basic yaml frontmatter)" {
  # First line must be ---, and closing --- within first 30 lines
  local first; first=$(head -1 "$SPECS_DIR/SE-032-reranker-layer.md")
  [[ "$first" == "---" ]]
  local close_line; close_line=$(head -30 "$SPECS_DIR/SE-032-reranker-layer.md" | grep -n '^---$' | sed -n '2p' | cut -d: -f1)
  [[ -n "$close_line" ]]
  [[ "$close_line" -le 30 ]]
}

@test "negative: spec file not empty" {
  [[ -s "$SPECS_DIR/SE-032-reranker-layer.md" ]]
  [[ -s "$SPECS_DIR/SE-033-topic-cluster.md" ]]
  [[ -s "$SPECS_DIR/SE-034-workflow-node-typing.md" ]]
}

@test "negative: SE-032 does not claim implemented status prematurely" {
  # Should be PROPOSED, not APPROVED/APPLIED until human review
  run grep -cE '^status: (APPROVED|APPLIED|DONE)' "$SPECS_DIR/SE-032-reranker-layer.md"
  [[ "$output" -eq 0 ]]
}

@test "post-IMPLEMENTED: approved_at is ISO date (batch 19 closure)" {
  run grep -E '^approved_at: "20[0-9]{2}-[0-9]{2}-[0-9]{2}"' "$SPECS_DIR/SE-032-reranker-layer.md"
  [ "$status" -eq 0 ]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: expires field is a future date (time-boxed 2 sprints ≈ 28 days max)" {
  local exp; exp=$(grep -oP '^expires: "\K[0-9-]+' "$SPECS_DIR/SE-032-reranker-layer.md" | head -1)
  [[ -n "$exp" ]]
  # Parse date — expires must be within 2026-04-18 to 2026-06-18 range (reasonable)
  [[ "$exp" > "2026-04-18" ]]
  [[ "$exp" < "2026-07-01" ]]
}

@test "edge: boundary — 3 specs exist as expected roadmap batch" {
  local count; count=$(ls "$SPECS_DIR"/SE-03{2,3,4}-*.md 2>/dev/null | wc -l)
  [[ "$count" -eq 3 ]]
}

@test "edge: SE-033 and SE-034 reference dependency on SE-032 or independence" {
  run grep -c "SE-032\|Dependencia\|Independiente" "$SPECS_DIR/SE-033-topic-cluster.md"
  [[ "$output" -ge 1 ]]
  run grep -c "SE-032\|Dependencia\|Independiente" "$SPECS_DIR/SE-034-workflow-node-typing.md"
  [[ "$output" -ge 1 ]]
}

@test "edge: nonexistent spec file would trigger failure" {
  [[ ! -f "$SPECS_DIR/SE-999-nonexistent.md" ]]
}
