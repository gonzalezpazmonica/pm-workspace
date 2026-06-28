#!/usr/bin/env bats
# tests/test-se232-labour-skills.bats
# Tests para la familia professional-domain/labour (SE-232/SE-233)
# 15 tests: existencia de skills, tamaño SKILL.md y contenido de prompts

SKILLS_BASE="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/.opencode/skills/professional-domain/labour"

# ── Tests 1-4: Los 4 skills de labour existen con sus 3 archivos ────────────

@test "01 labour-document-drafter tiene SKILL.md, DOMAIN.md y prompt.md" {
    local dir="$SKILLS_BASE/labour-document-drafter"
    [ -f "$dir/SKILL.md" ]   || fail "Falta SKILL.md en labour-document-drafter"
    [ -f "$dir/DOMAIN.md" ]  || fail "Falta DOMAIN.md en labour-document-drafter"
    [ -f "$dir/prompt.md" ]  || fail "Falta prompt.md en labour-document-drafter"
}

@test "02 labour-convention-analyzer tiene SKILL.md, DOMAIN.md y prompt.md" {
    local dir="$SKILLS_BASE/labour-convention-analyzer"
    [ -f "$dir/SKILL.md" ]   || fail "Falta SKILL.md en labour-convention-analyzer"
    [ -f "$dir/DOMAIN.md" ]  || fail "Falta DOMAIN.md en labour-convention-analyzer"
    [ -f "$dir/prompt.md" ]  || fail "Falta prompt.md en labour-convention-analyzer"
}

@test "03 labour-conflict-resolver tiene SKILL.md, DOMAIN.md y prompt.md" {
    local dir="$SKILLS_BASE/labour-conflict-resolver"
    [ -f "$dir/SKILL.md" ]   || fail "Falta SKILL.md en labour-conflict-resolver"
    [ -f "$dir/DOMAIN.md" ]  || fail "Falta DOMAIN.md en labour-conflict-resolver"
    [ -f "$dir/prompt.md" ]  || fail "Falta prompt.md en labour-conflict-resolver"
}

@test "04 labour-onboarding-offboarding tiene SKILL.md, DOMAIN.md y prompt.md" {
    local dir="$SKILLS_BASE/labour-onboarding-offboarding"
    [ -f "$dir/SKILL.md" ]   || fail "Falta SKILL.md en labour-onboarding-offboarding"
    [ -f "$dir/DOMAIN.md" ]  || fail "Falta DOMAIN.md en labour-onboarding-offboarding"
    [ -f "$dir/prompt.md" ]  || fail "Falta prompt.md en labour-onboarding-offboarding"
}

# ── Tests 5-8: Cada SKILL.md de labour tiene ≤150 líneas ───────────────────

@test "05 labour-document-drafter/SKILL.md tiene 150 líneas o menos" {
    local lines
    lines=$(wc -l < "$SKILLS_BASE/labour-document-drafter/SKILL.md")
    [ "$lines" -le 150 ] || fail "SKILL.md tiene $lines líneas (máx. 150)"
}

@test "06 labour-convention-analyzer/SKILL.md tiene 150 líneas o menos" {
    local lines
    lines=$(wc -l < "$SKILLS_BASE/labour-convention-analyzer/SKILL.md")
    [ "$lines" -le 150 ] || fail "SKILL.md tiene $lines líneas (máx. 150)"
}

@test "07 labour-conflict-resolver/SKILL.md tiene 150 líneas o menos" {
    local lines
    lines=$(wc -l < "$SKILLS_BASE/labour-conflict-resolver/SKILL.md")
    [ "$lines" -le 150 ] || fail "SKILL.md tiene $lines líneas (máx. 150)"
}

@test "08 labour-onboarding-offboarding/SKILL.md tiene 150 líneas o menos" {
    local lines
    lines=$(wc -l < "$SKILLS_BASE/labour-onboarding-offboarding/SKILL.md")
    [ "$lines" -le 150 ] || fail "SKILL.md tiene $lines líneas (máx. 150)"
}

# ── Tests 9-11: Contenido de labour-document-drafter/prompt.md ─────────────

@test "09 labour-document-drafter/prompt.md menciona art. 54 ET o art. 55 ET" {
    local f="$SKILLS_BASE/labour-document-drafter/prompt.md"
    grep -qiE "art\.?\s*5[45]\s*ET|54[-.]|55[-.]" "$f" \
        || fail "prompt.md no menciona art. 54 ET ni art. 55 ET"
}

@test "10 labour-document-drafter/prompt.md usa marcador [DATO PENDIENTE]" {
    local f="$SKILLS_BASE/labour-document-drafter/prompt.md"
    grep -q "\[DATO PENDIENTE" "$f" \
        || fail "prompt.md no contiene marcadores [DATO PENDIENTE]"
}

@test "11 labour-document-drafter/prompt.md contiene disclaimer laboral" {
    local f="$SKILLS_BASE/labour-document-drafter/prompt.md"
    grep -qi "AVISO\|disclaimer\|graduado social\|abogado laboralista" "$f" \
        || fail "prompt.md no contiene disclaimer laboral"
}

# ── Test 12: labour-convention-analyzer/prompt.md menciona BOE o vigente ───

@test "12 labour-convention-analyzer/prompt.md menciona BOE o vigente" {
    local f="$SKILLS_BASE/labour-convention-analyzer/prompt.md"
    grep -qiE "BOE|boe\.es|vigente|vigencia" "$f" \
        || fail "prompt.md no menciona BOE ni vigencia del convenio"
}

# ── Test 13: labour-conflict-resolver/prompt.md menciona SMAC ──────────────

@test "13 labour-conflict-resolver/prompt.md menciona SMAC" {
    local f="$SKILLS_BASE/labour-conflict-resolver/prompt.md"
    grep -qi "SMAC" "$f" \
        || fail "prompt.md no menciona SMAC (conciliación previa obligatoria)"
}

# ── Test 14: labour-onboarding-offboarding/prompt.md menciona alta SS ──────

@test "14 labour-onboarding-offboarding/prompt.md menciona alta SS o Seguridad Social" {
    local f="$SKILLS_BASE/labour-onboarding-offboarding/prompt.md"
    grep -qiE "alta.{0,20}(SS|Seguridad Social)|Seguridad Social.{0,20}alta|TGSS" "$f" \
        || fail "prompt.md no menciona alta en Seguridad Social"
}

# ── Test 15: SE-232 spec existe ─────────────────────────────────────────────

@test "15 docs/propuestas/SE-232-org-intelligence-skills.md existe" {
    local root
    root="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    [ -f "$root/docs/propuestas/SE-232-org-intelligence-skills.md" ] \
        || fail "Falta SE-232-org-intelligence-skills.md en docs/propuestas/"
}
