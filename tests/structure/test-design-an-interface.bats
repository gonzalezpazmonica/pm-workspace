#!/usr/bin/env bats
# SE-087: Design-an-interface skill — static acceptance tests
# ACs from docs/propuestas/SE-087-design-an-interface-parallel.md
# AC-01..AC-08

setup() {
  set -uo pipefail
  cd "$BATS_TEST_DIRNAME/../.."
  SKILL_MD=".opencode/skills/design-an-interface/SKILL.md"
  DOMAIN_MD=".opencode/skills/design-an-interface/DOMAIN.md"
}

teardown() {
  cd /
}

# ── AC-01: ≤120 LOC + SE-084 compliant ───────────────────────────────────────

@test "AC-01: SKILL.md exists" {
  [[ -f "$SKILL_MD" ]]
}

@test "AC-01: SKILL.md is ≤120 lines (SE-084 compliant)" {
  local lines
  lines=$(wc -l < "$SKILL_MD")
  [ "$lines" -le 120 ]
}

@test "AC-01: SKILL.md has valid YAML frontmatter (name + maturity)" {
  head -1 "$SKILL_MD" | grep -q "^---"
  grep -q "^name:" "$SKILL_MD"
  grep -q "^maturity:" "$SKILL_MD"
}

@test "AC-01: description field is present and non-empty" {
  grep -qE "^description:.{10,}" "$SKILL_MD"
}

# ── AC-02: MIT attribution to Pocock ─────────────────────────────────────────

@test "AC-02: SKILL.md cites Pocock MIT attribution" {
  grep -qi "mattpocock\|MIT" "$SKILL_MD"
}

@test "AC-02: SKILL.md mentions mattpocock/skills/design-an-interface" {
  grep -qi "mattpocock.*design-an-interface\|design-an-interface.*mattpocock" "$SKILL_MD"
}

# ── AC-03: Cross-reference to architectural-vocabulary.md ────────────────────

@test "AC-03: SKILL.md references architectural-vocabulary.md (SE-082)" {
  grep -q "architectural-vocabulary" "$SKILL_MD"
}

@test "AC-03: SKILL.md uses Module/Interface/Seam/Depth vocabulary terms" {
  grep -qE "Module|Interface|Seam|Depth" "$SKILL_MD"
}

# ── AC-04: Cross-reference to SE-074 ─────────────────────────────────────────

@test "AC-04: SKILL.md references SE-074 (parallel-specs-orchestrator)" {
  grep -qE "SE-074|parallel.*orchestr|parallel-specs" "$SKILL_MD"
}

# ── AC-05: N=3 alternatives with criteria described ──────────────────────────

@test "AC-05: SKILL.md describes 3 explicit design alternatives" {
  local count
  count=$(grep -cE "\*\*[ABC] —|\*\*Sub-agente [ABC]|Diseno [ABC]|\b[ABC] —.*[Mm]axim|\b[ABC] —.*[Pp]ragm" "$SKILL_MD" || true)
  [ "$count" -ge 3 ]
}

@test "AC-05: alternatives have distinct design criteria (simplicidad / flexibilidad)" {
  grep -qi "simplicidad\|simplicity\|minimal" "$SKILL_MD"
  grep -qi "flexib" "$SKILL_MD"
}

# ── AC-06: No auto-merge — decision stays with user ──────────────────────────

@test "AC-06: SKILL.md does NOT auto-merge (decision left to user)" {
  # Must contain recommendation pattern + NOT contain auto-merge/auto-approve
  run grep -iE "auto.merge|auto.approve|auto.implement|automerge" "$SKILL_MD"
  [ "$status" -ne 0 ]
}

@test "AC-06: SKILL.md has a recommendation step that references user decision" {
  grep -qiE "recomend|recommend|justif|decision" "$SKILL_MD"
}

# ── Spec ref ─────────────────────────────────────────────────────────────────

@test "spec ref: docs/propuestas/SE-087 exists" {
  [[ -f "docs/propuestas/SE-087-design-an-interface-parallel.md" ]]
}

@test "spec ref: SKILL.md references SE-082 architectural vocabulary" {
  # duplicated intentionally with different query to ensure cross-ref robustness
  grep -q "SE-082\|architectural-vocabulary" "$SKILL_MD"
}
