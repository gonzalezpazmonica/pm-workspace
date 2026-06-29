#!/usr/bin/env bats
# tests/test-se232-structure.bats
# Tests de estructura para SE-232/SE-233: specs, guías, reglas y skills de labour
# 10 tests

ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
LABOUR_BASE="$ROOT/.opencode/skills/professional-domain/labour"

# ── Test 1: SE-233 spec existe ───────────────────────────────────────────────

@test "01 docs/propuestas/SE-233-professional-domain-skills.md existe" {
    [ -f "$ROOT/docs/propuestas/SE-233-professional-domain-skills.md" ] \
        || fail "Falta SE-233-professional-domain-skills.md en docs/propuestas/"
}

# ── Test 2: Guía de adopción existe ─────────────────────────────────────────

@test "02 docs/guides_es/domain-skills-adoption-guide.md existe" {
    [ -f "$ROOT/docs/guides_es/domain-skills-adoption-guide.md" ] \
        || fail "Falta domain-skills-adoption-guide.md en docs/guides_es/"
}

# ── Test 3: org-intelligence-protocol.md existe ─────────────────────────────

@test "03 docs/rules/domain/org-intelligence-protocol.md existe" {
    [ -f "$ROOT/docs/rules/domain/org-intelligence-protocol.md" ] \
        || fail "Falta org-intelligence-protocol.md en docs/rules/domain/"
}

# ── Test 4: professional-domain-disclaimer.md existe ────────────────────────

@test "04 docs/rules/domain/professional-domain-disclaimer.md existe" {
    [ -f "$ROOT/docs/rules/domain/professional-domain-disclaimer.md" ] \
        || fail "Falta professional-domain-disclaimer.md en docs/rules/domain/"
}

# ── Tests 5-8: Los 4 skills de labour existen (verificación de directorio) ──

@test "05 directorio labour-document-drafter existe en professional-domain/labour" {
    [ -d "$LABOUR_BASE/labour-document-drafter" ] \
        || fail "No existe el directorio labour-document-drafter"
}

@test "06 directorio labour-convention-analyzer existe en professional-domain/labour" {
    [ -d "$LABOUR_BASE/labour-convention-analyzer" ] \
        || fail "No existe el directorio labour-convention-analyzer"
}

@test "07 directorio labour-conflict-resolver existe en professional-domain/labour" {
    [ -d "$LABOUR_BASE/labour-conflict-resolver" ] \
        || fail "No existe el directorio labour-conflict-resolver"
}

@test "08 directorio labour-onboarding-offboarding existe en professional-domain/labour" {
    [ -d "$LABOUR_BASE/labour-onboarding-offboarding" ] \
        || fail "No existe el directorio labour-onboarding-offboarding"
}

# ── Test 9: skill-families-registry.md existe y menciona professional-domain ─

@test "09 skill-families-registry.md existe y menciona professional-domain" {
    local f="$ROOT/docs/rules/domain/skill-families-registry.md"
    [ -f "$f" ] || fail "Falta skill-families-registry.md en docs/rules/domain/"
    grep -qi "professional-domain" "$f" \
        || fail "skill-families-registry.md no menciona professional-domain"
}

# ── Test 10: guía de adopción menciona todos los perfiles clave ──────────────

@test "10 domain-skills-adoption-guide.md menciona RRHH o labour" {
    local f="$ROOT/docs/guides_es/domain-skills-adoption-guide.md"
    grep -qiE "RRHH|Recursos Humanos|labour|laboral" "$f" \
        || fail "La guía de adopción no cubre el perfil de RRHH/labour"
}
