#!/usr/bin/env bats
# SE-232: Org Intelligence Skills — Tests de existencia y contenido
# Ref: docs/rules/domain/org-intelligence-protocol.md

setup() {
  SKILLS_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/.opencode/skills"
}

# ── Tests 1-3: Los 3 skills org-intelligence existen con sus 3 ficheros ──────

@test "01 org-stakeholder-mapper tiene SKILL.md, DOMAIN.md y prompt.md" {
  [[ -f "$SKILLS_DIR/org-stakeholder-mapper/SKILL.md" ]]
  [[ -f "$SKILLS_DIR/org-stakeholder-mapper/DOMAIN.md" ]]
  [[ -f "$SKILLS_DIR/org-stakeholder-mapper/prompt.md" ]]
}

@test "02 org-political-landscape tiene SKILL.md, DOMAIN.md y prompt.md" {
  [[ -f "$SKILLS_DIR/org-political-landscape/SKILL.md" ]]
  [[ -f "$SKILLS_DIR/org-political-landscape/DOMAIN.md" ]]
  [[ -f "$SKILLS_DIR/org-political-landscape/prompt.md" ]]
}

@test "03 org-meeting-capture tiene SKILL.md, DOMAIN.md y prompt.md" {
  [[ -f "$SKILLS_DIR/org-meeting-capture/SKILL.md" ]]
  [[ -f "$SKILLS_DIR/org-meeting-capture/DOMAIN.md" ]]
  [[ -f "$SKILLS_DIR/org-meeting-capture/prompt.md" ]]
}

# ── Tests 4-6: Cada SKILL.md tiene ≤150 líneas ───────────────────────────────

@test "04 org-stakeholder-mapper/SKILL.md tiene 150 líneas o menos" {
  count=$(wc -l < "$SKILLS_DIR/org-stakeholder-mapper/SKILL.md")
  [[ "$count" -le 150 ]]
}

@test "05 org-political-landscape/SKILL.md tiene 150 líneas o menos" {
  count=$(wc -l < "$SKILLS_DIR/org-political-landscape/SKILL.md")
  [[ "$count" -le 150 ]]
}

@test "06 org-meeting-capture/SKILL.md tiene 150 líneas o menos" {
  count=$(wc -l < "$SKILLS_DIR/org-meeting-capture/SKILL.md")
  [[ "$count" -le 150 ]]
}

# ── Tests 7-10: Contenido de prompts org-intelligence ────────────────────────

@test "07 org-stakeholder-mapper/prompt.md menciona EXTRACTED e INFERRED" {
  grep -q "EXTRACTED" "$SKILLS_DIR/org-stakeholder-mapper/prompt.md"
  grep -q "INFERRED" "$SKILLS_DIR/org-stakeholder-mapper/prompt.md"
}

@test "08 org-stakeholder-mapper/prompt.md menciona validación humana o aprobación humana" {
  grep -qi "aprobaci" "$SKILLS_DIR/org-stakeholder-mapper/prompt.md" || \
  grep -qi "validaci" "$SKILLS_DIR/org-stakeholder-mapper/prompt.md" || \
  grep -qi "humana" "$SKILLS_DIR/org-stakeholder-mapper/prompt.md"
}

@test "09 org-meeting-capture/prompt.md menciona que no escribe al grafo sin aprobación" {
  grep -qi "grafo" "$SKILLS_DIR/org-meeting-capture/prompt.md"
  grep -qi "aprobaci" "$SKILLS_DIR/org-meeting-capture/prompt.md"
}

@test "10 org-political-landscape/prompt.md menciona confidence levels" {
  grep -q "confidence" "$SKILLS_DIR/org-political-landscape/prompt.md"
  grep -q "INFERRED" "$SKILLS_DIR/org-political-landscape/prompt.md"
}

# ── Tests 11-14: Los 4 skills de sales existen con sus 3 ficheros ────────────

@test "11 sales-account-research tiene SKILL.md, DOMAIN.md y prompt.md" {
  SALES="$SKILLS_DIR/professional-domain/sales"
  [[ -f "$SALES/sales-account-research/SKILL.md" ]]
  [[ -f "$SALES/sales-account-research/DOMAIN.md" ]]
  [[ -f "$SALES/sales-account-research/prompt.md" ]]
}

@test "12 sales-proposal-writer tiene SKILL.md, DOMAIN.md y prompt.md" {
  SALES="$SKILLS_DIR/professional-domain/sales"
  [[ -f "$SALES/sales-proposal-writer/SKILL.md" ]]
  [[ -f "$SALES/sales-proposal-writer/DOMAIN.md" ]]
  [[ -f "$SALES/sales-proposal-writer/prompt.md" ]]
}

@test "13 sales-objection-analyzer tiene SKILL.md, DOMAIN.md y prompt.md" {
  SALES="$SKILLS_DIR/professional-domain/sales"
  [[ -f "$SALES/sales-objection-analyzer/SKILL.md" ]]
  [[ -f "$SALES/sales-objection-analyzer/DOMAIN.md" ]]
  [[ -f "$SALES/sales-objection-analyzer/prompt.md" ]]
}

@test "14 sales-pipeline-analyst tiene SKILL.md, DOMAIN.md y prompt.md" {
  SALES="$SKILLS_DIR/professional-domain/sales"
  [[ -f "$SALES/sales-pipeline-analyst/SKILL.md" ]]
  [[ -f "$SALES/sales-pipeline-analyst/DOMAIN.md" ]]
  [[ -f "$SALES/sales-pipeline-analyst/prompt.md" ]]
}

# ── Test 15: Contenido crítico sales-proposal-writer ─────────────────────────

@test "15 sales-proposal-writer/prompt.md menciona DATO PENDIENTE" {
  grep -q "DATO PENDIENTE" "$SKILLS_DIR/professional-domain/sales/sales-proposal-writer/prompt.md"
}
