#!/usr/bin/env bats
# SE-232: Sales Skills — Tests adicionales de contenido y estructura
# Ref: docs/rules/domain/org-intelligence-protocol.md

setup() {
  SKILLS_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/.opencode/skills"
  SALES="$SKILLS_DIR/professional-domain/sales"
}

# ── Test 1: sales-account-research/prompt.md separa datos de hipótesis ───────

@test "01 sales-account-research/prompt.md menciona datos verificados o hipótesis" {
  grep -qi "verificad" "$SALES/sales-account-research/prompt.md" || \
  grep -qi "hipótesis" "$SALES/sales-account-research/prompt.md" || \
  grep -qi "hipotesis" "$SALES/sales-account-research/prompt.md"
}

# ── Test 2: SKILL.md de account research cumple límite de líneas ─────────────

@test "02 sales-account-research/SKILL.md tiene 150 líneas o menos" {
  count=$(wc -l < "$SALES/sales-account-research/SKILL.md")
  [[ "$count" -le 150 ]]
}

# ── Test 3: sales-objection-analyzer menciona taxonomía ─────────────────────

@test "03 sales-objection-analyzer/prompt.md menciona taxonomía de objeciones" {
  grep -qi "PRECIO" "$SALES/sales-objection-analyzer/prompt.md"
  grep -qi "TIMING" "$SALES/sales-objection-analyzer/prompt.md"
  grep -qi "COMPETENCIA" "$SALES/sales-objection-analyzer/prompt.md"
}

# ── Test 4: sales-pipeline-analyst menciona MEDDIC ──────────────────────────

@test "04 sales-pipeline-analyst/prompt.md menciona MEDDIC" {
  grep -q "MEDDIC" "$SALES/sales-pipeline-analyst/prompt.md"
}

# ── Tests 5-8: Los 4 skills tienen SKILL.md con ≤150 líneas ─────────────────

@test "05 sales-proposal-writer/SKILL.md tiene 150 líneas o menos" {
  count=$(wc -l < "$SALES/sales-proposal-writer/SKILL.md")
  [[ "$count" -le 150 ]]
}

@test "06 sales-objection-analyzer/SKILL.md tiene 150 líneas o menos" {
  count=$(wc -l < "$SALES/sales-objection-analyzer/SKILL.md")
  [[ "$count" -le 150 ]]
}

@test "07 sales-pipeline-analyst/SKILL.md tiene 150 líneas o menos" {
  count=$(wc -l < "$SALES/sales-pipeline-analyst/SKILL.md")
  [[ "$count" -le 150 ]]
}

# ── Tests 8-10: Verificar que todos los skills tienen los 3 ficheros ─────────

@test "08 sales-account-research tiene los 3 ficheros obligatorios" {
  [[ -f "$SALES/sales-account-research/SKILL.md" ]]
  [[ -f "$SALES/sales-account-research/DOMAIN.md" ]]
  [[ -f "$SALES/sales-account-research/prompt.md" ]]
}

@test "09 sales-pipeline-analyst/prompt.md menciona supuestos o porcentajes documentados" {
  grep -qi "supuest" "$SALES/sales-pipeline-analyst/prompt.md" || \
  grep -qi "documentad" "$SALES/sales-pipeline-analyst/prompt.md"
}

@test "10 sales-proposal-writer/prompt.md menciona prueba de especificidad" {
  grep -qi "especificidad" "$SALES/sales-proposal-writer/prompt.md"
}
