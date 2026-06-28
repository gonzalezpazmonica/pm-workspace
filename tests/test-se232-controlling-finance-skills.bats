#!/usr/bin/env bats
# tests/test-se232-controlling-finance-skills.bats
# Tests para las skills de controlling y finance (SE-232)

CONTROLLING_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/.opencode/skills/professional-domain/controlling"
FINANCE_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/.opencode/skills/professional-domain/finance"

# ──────────────────────────────────────────────────────────────────────────────
# Tests 1-3: Los 3 skills controlling existen con sus 3 archivos
# ──────────────────────────────────────────────────────────────────────────────

@test "1: controlling-variance-analyzer tiene SKILL.md, DOMAIN.md y prompt.md" {
  [ -f "$CONTROLLING_DIR/controlling-variance-analyzer/SKILL.md" ]
  [ -f "$CONTROLLING_DIR/controlling-variance-analyzer/DOMAIN.md" ]
  [ -f "$CONTROLLING_DIR/controlling-variance-analyzer/prompt.md" ]
}

@test "2: controlling-management-report tiene SKILL.md, DOMAIN.md y prompt.md" {
  [ -f "$CONTROLLING_DIR/controlling-management-report/SKILL.md" ]
  [ -f "$CONTROLLING_DIR/controlling-management-report/DOMAIN.md" ]
  [ -f "$CONTROLLING_DIR/controlling-management-report/prompt.md" ]
}

@test "3: controlling-kpi-analyst tiene SKILL.md, DOMAIN.md y prompt.md" {
  [ -f "$CONTROLLING_DIR/controlling-kpi-analyst/SKILL.md" ]
  [ -f "$CONTROLLING_DIR/controlling-kpi-analyst/DOMAIN.md" ]
  [ -f "$CONTROLLING_DIR/controlling-kpi-analyst/prompt.md" ]
}

# ──────────────────────────────────────────────────────────────────────────────
# Tests 4-6: Los 3 skills finance existen con sus 3 archivos
# ──────────────────────────────────────────────────────────────────────────────

@test "4: finance-investment-analyst tiene SKILL.md, DOMAIN.md y prompt.md" {
  [ -f "$FINANCE_DIR/finance-investment-analyst/SKILL.md" ]
  [ -f "$FINANCE_DIR/finance-investment-analyst/DOMAIN.md" ]
  [ -f "$FINANCE_DIR/finance-investment-analyst/prompt.md" ]
}

@test "5: finance-cash-flow-analyst tiene SKILL.md, DOMAIN.md y prompt.md" {
  [ -f "$FINANCE_DIR/finance-cash-flow-analyst/SKILL.md" ]
  [ -f "$FINANCE_DIR/finance-cash-flow-analyst/DOMAIN.md" ]
  [ -f "$FINANCE_DIR/finance-cash-flow-analyst/prompt.md" ]
}

@test "6: finance-financial-report-writer tiene SKILL.md, DOMAIN.md y prompt.md" {
  [ -f "$FINANCE_DIR/finance-financial-report-writer/SKILL.md" ]
  [ -f "$FINANCE_DIR/finance-financial-report-writer/DOMAIN.md" ]
  [ -f "$FINANCE_DIR/finance-financial-report-writer/prompt.md" ]
}

# ──────────────────────────────────────────────────────────────────────────────
# Tests 7-12: Cada SKILL.md de controlling y finance ≤150 líneas
# ──────────────────────────────────────────────────────────────────────────────

@test "7: controlling-variance-analyzer/SKILL.md tiene 150 líneas o menos" {
  lines=$(wc -l < "$CONTROLLING_DIR/controlling-variance-analyzer/SKILL.md")
  [ "$lines" -le 150 ]
}

@test "8: controlling-management-report/SKILL.md tiene 150 líneas o menos" {
  lines=$(wc -l < "$CONTROLLING_DIR/controlling-management-report/SKILL.md")
  [ "$lines" -le 150 ]
}

@test "9: controlling-kpi-analyst/SKILL.md tiene 150 líneas o menos" {
  lines=$(wc -l < "$CONTROLLING_DIR/controlling-kpi-analyst/SKILL.md")
  [ "$lines" -le 150 ]
}

@test "10: finance-investment-analyst/SKILL.md tiene 150 líneas o menos" {
  lines=$(wc -l < "$FINANCE_DIR/finance-investment-analyst/SKILL.md")
  [ "$lines" -le 150 ]
}

@test "11: finance-cash-flow-analyst/SKILL.md tiene 150 líneas o menos" {
  lines=$(wc -l < "$FINANCE_DIR/finance-cash-flow-analyst/SKILL.md")
  [ "$lines" -le 150 ]
}

@test "12: finance-financial-report-writer/SKILL.md tiene 150 líneas o menos" {
  lines=$(wc -l < "$FINANCE_DIR/finance-financial-report-writer/SKILL.md")
  [ "$lines" -le 150 ]
}

# ──────────────────────────────────────────────────────────────────────────────
# Tests 13-15: Contenido específico de prompts
# ──────────────────────────────────────────────────────────────────────────────

@test "13: controlling-variance-analyzer/prompt.md menciona [DATO REAL PENDIENTE]" {
  grep -q "\[DATO REAL PENDIENTE\]" "$CONTROLLING_DIR/controlling-variance-analyzer/prompt.md"
}

@test "14: finance-investment-analyst/prompt.md menciona [SUPUESTO A VALIDAR]" {
  grep -q "\[SUPUESTO A VALIDAR" "$FINANCE_DIR/finance-investment-analyst/prompt.md"
}

@test "15: finance-investment-analyst/prompt.md menciona disclaimer" {
  grep -qi "disclaimer" "$FINANCE_DIR/finance-investment-analyst/prompt.md"
}
