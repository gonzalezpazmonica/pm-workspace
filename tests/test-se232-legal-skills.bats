#!/usr/bin/env bats
# tests/test-se232-legal-skills.bats
# Tests para las skills de dominio profesional/legal (SE-232)

SKILLS_DIR="/home/monica/.savia/nidos/se232-domain-skills/.opencode/skills/professional-domain/legal"
DOCS_DIR="/home/monica/.savia/nidos/se232-domain-skills/docs/rules/domain"

# ──────────────────────────────────────────────────────────────────────────────
# Tests 1-3: Los 3 skills legales existen con sus 3 archivos
# ──────────────────────────────────────────────────────────────────────────────

@test "1: legal-contract-reviewer tiene SKILL.md, DOMAIN.md y prompt.md" {
  [ -f "$SKILLS_DIR/legal-contract-reviewer/SKILL.md" ]
  [ -f "$SKILLS_DIR/legal-contract-reviewer/DOMAIN.md" ]
  [ -f "$SKILLS_DIR/legal-contract-reviewer/prompt.md" ]
}

@test "2: legal-compliance-checker tiene SKILL.md, DOMAIN.md y prompt.md" {
  [ -f "$SKILLS_DIR/legal-compliance-checker/SKILL.md" ]
  [ -f "$SKILLS_DIR/legal-compliance-checker/DOMAIN.md" ]
  [ -f "$SKILLS_DIR/legal-compliance-checker/prompt.md" ]
}

@test "3: legal-document-drafter tiene SKILL.md, DOMAIN.md y prompt.md" {
  [ -f "$SKILLS_DIR/legal-document-drafter/SKILL.md" ]
  [ -f "$SKILLS_DIR/legal-document-drafter/DOMAIN.md" ]
  [ -f "$SKILLS_DIR/legal-document-drafter/prompt.md" ]
}

# ──────────────────────────────────────────────────────────────────────────────
# Tests 4-6: Cada SKILL.md de legal ≤150 líneas
# ──────────────────────────────────────────────────────────────────────────────

@test "4: legal-contract-reviewer/SKILL.md tiene 150 líneas o menos" {
  lines=$(wc -l < "$SKILLS_DIR/legal-contract-reviewer/SKILL.md")
  [ "$lines" -le 150 ]
}

@test "5: legal-compliance-checker/SKILL.md tiene 150 líneas o menos" {
  lines=$(wc -l < "$SKILLS_DIR/legal-compliance-checker/SKILL.md")
  [ "$lines" -le 150 ]
}

@test "6: legal-document-drafter/SKILL.md tiene 150 líneas o menos" {
  lines=$(wc -l < "$SKILLS_DIR/legal-document-drafter/SKILL.md")
  [ "$lines" -le 150 ]
}

# ──────────────────────────────────────────────────────────────────────────────
# Tests 7-11: Contenido específico de los archivos
# ──────────────────────────────────────────────────────────────────────────────

@test "7: legal-contract-reviewer/prompt.md menciona disclaimer" {
  grep -qi "disclaimer" "$SKILLS_DIR/legal-contract-reviewer/prompt.md"
}

@test "8: legal-document-drafter/prompt.md menciona [DATO PENDIENTE]" {
  grep -q "\[DATO PENDIENTE" "$SKILLS_DIR/legal-document-drafter/prompt.md"
}

@test "9: legal-compliance-checker/prompt.md menciona RGPD" {
  grep -qi "RGPD" "$SKILLS_DIR/legal-compliance-checker/prompt.md"
}

@test "10: legal-contract-reviewer/DOMAIN.md menciona 'red flag'" {
  grep -qi "red flag" "$SKILLS_DIR/legal-contract-reviewer/DOMAIN.md"
}

@test "11: legal-document-drafter/prompt.md menciona artículo ET (art. 54 o art. 55)" {
  grep -qE "art\. 5[45]|artículo 5[45]" "$SKILLS_DIR/legal-document-drafter/prompt.md"
}

# ──────────────────────────────────────────────────────────────────────────────
# Test 12: El fichero de disclaimers existe y tiene disclaimer legal
# ──────────────────────────────────────────────────────────────────────────────

@test "12: professional-domain-disclaimer.md existe y contiene disclaimer legal" {
  [ -f "$DOCS_DIR/professional-domain-disclaimer.md" ]
  grep -qi "aviso legal" "$DOCS_DIR/professional-domain-disclaimer.md"
}
