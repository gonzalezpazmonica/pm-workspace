#!/usr/bin/env bats
# tests/test-pursuit-pipeline.bats
# Test strategy: Validate SE-015 Pipeline-as-Code artefacts — script safety/logic,
# JSON schema integrity, rule doc existence, and all 7 command docs.
# Covers: pursuit-validate.sh (8 failure modes), pipeline-as-code rule,
# pursuit-frontmatter schema, and commands pursuit-{init,qualify,bid,draft,handoff,close}
# plus pipeline-view.
# Ref: docs/propuestas/savia-enterprise/SE-015-project-prospect.md
# Ref: docs/rules/domain/pipeline-as-code.md
# Auditor target: score >= 80 (SPEC-055)

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
  TMPDIR="$(mktemp -d)"
  # Build a minimal pipeline fixture used by many tests
  PIPE="$TMPDIR/pipeline"
  mkdir -p "$PIPE/pursuits"
}

teardown() {
  rm -rf "$TMPDIR"
}

# ─── helper ───────────────────────────────────────────────────────────────────
_make_pursuit() {
  local opp="$1" stage="$2"
  local dir="$PIPE/pursuits/$opp"
  mkdir -p "$dir"
  cat > "$dir/pursuit.md" <<EOF
---
opp_id: "$opp"
stage: "$stage"
---
# $opp
EOF
}

_add_qualification() {
  local opp="$1"
  cat > "$PIPE/pursuits/$opp/qualification.yaml" <<'EOF'
  budget: high
  authority: cto
  need: critical
  timing: q3
  metrics: roi
  economic_buyer: cfo
  decision_criteria: price
  decision_process: committee
  identify_pain: yes
  champion: alice
EOF
}

_add_bid_decision() {
  local opp="$1"
  echo "decision: bid" > "$PIPE/pursuits/$opp/bid-decision.md"
}

_add_handoff() {
  local opp="$1"
  echo "delivery-owner: bob" > "$PIPE/pursuits/$opp/handoff.md"
}

# ═══════════════════════════════════════════════════════════════════════════════
# C2 — Safety-flag verification
# ═══════════════════════════════════════════════════════════════════════════════

@test "SPEC pursuit-validate.sh has set -uo pipefail safety flags" {
  grep -q 'set -uo pipefail' "$REPO_ROOT/scripts/pursuit-validate.sh"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Positive cases (C3) — happy-path scenarios
# ═══════════════════════════════════════════════════════════════════════════════

@test "pursuit-validate reports PASS for valid discovery-stage pursuit" {
  _make_pursuit "OPP-001" "discovery"
  run bash "$REPO_ROOT/scripts/pursuit-validate.sh" "$PIPE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}

@test "pursuit-validate reports PASS for pursuit stage with qualification" {
  _make_pursuit "OPP-002" "pursuit"
  _add_qualification "OPP-002"
  run bash "$REPO_ROOT/scripts/pursuit-validate.sh" "$PIPE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}

@test "pursuit-validate reports PASS for proposal stage with qualification and bid-decision" {
  _make_pursuit "OPP-003" "proposal"
  _add_qualification "OPP-003"
  _add_bid_decision "OPP-003"
  run bash "$REPO_ROOT/scripts/pursuit-validate.sh" "$PIPE"
  [ "$status" -eq 0 ]
}

@test "pursuit-validate reports PASS for won pursuit with handoff" {
  _make_pursuit "OPP-004" "won"
  _add_handoff "OPP-004"
  run bash "$REPO_ROOT/scripts/pursuit-validate.sh" "$PIPE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}

@test "pursuit-validate counts checked pursuits correctly" {
  _make_pursuit "OPP-005" "discovery"
  _make_pursuit "OPP-006" "discovery"
  run bash "$REPO_ROOT/scripts/pursuit-validate.sh" "$PIPE"
  [[ "$output" == *"Pursuits checked:  2"* ]]
}

@test "pursuit-validate summary banner contains SE-015 label" {
  _make_pursuit "OPP-007" "discovery"
  run bash "$REPO_ROOT/scripts/pursuit-validate.sh" "$PIPE"
  [[ "$output" == *"SE-015"* ]]
}

@test "pursuit-validate accepts --summary flag without crashing" {
  run bash "$REPO_ROOT/scripts/pursuit-validate.sh" --summary
  # exit 0 when no pipeline dirs found is acceptable
  [ "$status" -eq 0 ]
}

@test "pursuit-validate reports OK for lost pursuit without handoff" {
  _make_pursuit "OPP-008" "lost"
  run bash "$REPO_ROOT/scripts/pursuit-validate.sh" "$PIPE"
  [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════════════════════
# Negative cases (C4) — error / failure / missing / invalid inputs
# ═══════════════════════════════════════════════════════════════════════════════

@test "pursuit-validate errors on missing qualification before pursuit stage" {
  _make_pursuit "OPP-010" "pursuit"
  # no qualification.yaml
  run bash "$REPO_ROOT/scripts/pursuit-validate.sh" "$PIPE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ERROR"* ]] || [[ "$output" == *"FAIL"* ]]
}

@test "pursuit-validate errors on missing bid-decision before proposal stage" {
  _make_pursuit "OPP-011" "proposal"
  _add_qualification "OPP-011"
  # no bid-decision.md
  run bash "$REPO_ROOT/scripts/pursuit-validate.sh" "$PIPE"
  [ "$status" -ne 0 ]
}

@test "pursuit-validate errors on missing handoff for won pursuit" {
  _make_pursuit "OPP-012" "won"
  # no handoff.md
  run bash "$REPO_ROOT/scripts/pursuit-validate.sh" "$PIPE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"handoff"* ]]
}

@test "pursuit-validate errors on duplicate OPP-IDs in same pipeline" {
  _make_pursuit "OPP-DUPE" "discovery"
  local dir2="$PIPE/pursuits/OPP-DUPE-B"
  mkdir -p "$dir2"
  cat > "$dir2/pursuit.md" <<'EOF'
---
opp_id: "OPP-DUPE"
stage: "discovery"
---
EOF
  run bash "$REPO_ROOT/scripts/pursuit-validate.sh" "$PIPE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Duplicate"* ]] || [[ "$output" == *"FAIL"* ]]
}

@test "pursuit-validate fails with nonexistent pipeline directory argument" {
  run bash "$REPO_ROOT/scripts/pursuit-validate.sh" "/tmp/does-not-exist-$$"
  [ "$status" -ne 0 ]
}

@test "pursuit-validate errors on missing pursuit.md inside pursuit directory" {
  mkdir -p "$PIPE/pursuits/OPP-NOFILE"
  # directory exists but pursuit.md absent
  run bash "$REPO_ROOT/scripts/pursuit-validate.sh" "$PIPE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing pursuit.md"* ]] || [[ "$output" == *"ERROR"* ]]
}

# ═══════════════════════════════════════════════════════════════════════════════
# Edge cases (C5) — empty / boundary / nonexistent
# ═══════════════════════════════════════════════════════════════════════════════

@test "pursuit-validate handles empty pursuits directory without crashing" {
  # pursuits/ exists but contains no subdirs
  run bash "$REPO_ROOT/scripts/pursuit-validate.sh" "$PIPE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Pursuits checked:  0"* ]]
}

@test "pursuit-validate edge: negotiation stage requires qualification" {
  _make_pursuit "OPP-NEG" "negotiation"
  # no qualification.yaml -> gate triggers
  run bash "$REPO_ROOT/scripts/pursuit-validate.sh" "$PIPE"
  [ "$status" -ne 0 ]
}

@test "pursuit-validate edge: library reference to nonexistent asset triggers warning" {
  _make_pursuit "OPP-LIB" "discovery"
  mkdir -p "$PIPE/library"
  # pursuit.md references a library asset that does not exist
  cat >> "$PIPE/pursuits/OPP-LIB/pursuit.md" <<'EOF'

See [deck](library/missing-deck.pptx) for details.
EOF
  run bash "$REPO_ROOT/scripts/pursuit-validate.sh" "$PIPE"
  # should at minimum warn (WARN in stderr or PASS with warnings)
  [[ "$output" == *"PASS (with warnings)"* ]] || [ "$status" -ne 0 ]
}

# ═══════════════════════════════════════════════════════════════════════════════
# Schema validation (C7 coverage, C9 diverse assertions)
# ═══════════════════════════════════════════════════════════════════════════════

@test "SPEC pursuit-frontmatter schema file exists and is valid JSON" {
  local schema="$REPO_ROOT/schemas/pursuit-frontmatter.schema.json"
  [ -f "$schema" ]
  python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$schema"
}

@test "SPEC pursuit-frontmatter schema contains required opp_id and stage fields" {
  local schema="$REPO_ROOT/schemas/pursuit-frontmatter.schema.json"
  grep -q '"opp_id"' "$schema"
  grep -q '"stage"' "$schema"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Rule doc (C8 spec reference, C7 coverage)
# ═══════════════════════════════════════════════════════════════════════════════

@test "SPEC pipeline-as-code rule doc exists" {
  [ -f "$REPO_ROOT/docs/rules/domain/pipeline-as-code.md" ]
}

@test "SPEC pipeline-as-code rule doc references SE-015" {
  grep -qi "SE-015" "$REPO_ROOT/docs/rules/domain/pipeline-as-code.md"
}

@test "SPEC pipeline-as-code rule doc describes pursuit stages" {
  grep -qi "stage" "$REPO_ROOT/docs/rules/domain/pipeline-as-code.md"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Command docs existence (C7 coverage breadth)
# ═══════════════════════════════════════════════════════════════════════════════

@test "SPEC pursuit-init command doc exists" {
  [ -f "$REPO_ROOT/.claude/commands/pursuit-init.md" ]
}

@test "SPEC pursuit-qualify command doc exists" {
  [ -f "$REPO_ROOT/.claude/commands/pursuit-qualify.md" ]
}

@test "SPEC pursuit-bid command doc exists" {
  [ -f "$REPO_ROOT/.claude/commands/pursuit-bid.md" ]
}

@test "SPEC pursuit-draft command doc exists" {
  [ -f "$REPO_ROOT/.claude/commands/pursuit-draft.md" ]
}

@test "SPEC pursuit-handoff command doc exists" {
  [ -f "$REPO_ROOT/.claude/commands/pursuit-handoff.md" ]
}

@test "SPEC pursuit-close command doc exists" {
  [ -f "$REPO_ROOT/.claude/commands/pursuit-close.md" ]
}

@test "SPEC pipeline-view command doc exists" {
  [ -f "$REPO_ROOT/.claude/commands/pipeline-view.md" ]
}

@test "SPEC pursuit-init command doc has non-empty description" {
  local f="$REPO_ROOT/.claude/commands/pursuit-init.md"
  [ -s "$f" ]
  grep -qi "description" "$f" || grep -qi "pursuit" "$f"
}

@test "SPEC pipeline-view command doc references pipeline or stage" {
  grep -qi "pipeline\|stage" "$REPO_ROOT/.claude/commands/pipeline-view.md"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Script structural checks (C7 coverage)
# ═══════════════════════════════════════════════════════════════════════════════

@test "SPEC pursuit-validate.sh script file exists and is executable" {
  local s="$REPO_ROOT/scripts/pursuit-validate.sh"
  [ -f "$s" ]
  [ -x "$s" ]
}

@test "pursuit-validate.sh defines validate_pursuit function" {
  grep -q 'validate_pursuit()' "$REPO_ROOT/scripts/pursuit-validate.sh"
}

@test "pursuit-validate.sh defines check_duplicates function" {
  grep -q 'check_duplicates()' "$REPO_ROOT/scripts/pursuit-validate.sh"
}

@test "pursuit-validate.sh defines check_library_refs function" {
  grep -q 'check_library_refs()' "$REPO_ROOT/scripts/pursuit-validate.sh"
}
