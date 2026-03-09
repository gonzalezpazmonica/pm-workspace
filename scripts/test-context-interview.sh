#!/usr/bin/env bash
# test-context-interview.sh — Structural tests for Context Interview (Era 33 — v2.8.0)
set -uo pipefail

PASS=0; FAIL=0

pass() { ((PASS+=1)) || true; echo "  ✅ $1"; }
fail() { ((FAIL+=1)) || true; echo "  ❌ $1"; }
check() { if eval "$2" > /dev/null 2>&1; then pass "$1"; else fail "$1"; fi; }

echo "══════════════════════════════════════════"
echo "  Context Interview Tests (Era 33 — v2.8.0)"
echo "══════════════════════════════════════════"

# ── Section 1: Command file ────────────────────────────────────────────────
echo ""
echo "── Section 1: Command file ──"
CMD=".claude/commands/context-interview.md"
check "Command exists" "[ -f $CMD ]"
LINES=$(wc -l < "$CMD")
check "Command within line limit ($LINES/150 lines)" "[ $LINES -le 150 ]"
check "Has start subcommand" "grep -q 'context-interview start' $CMD"
check "Has resume subcommand" "grep -q 'context-interview resume' $CMD"
check "Has summary subcommand" "grep -q 'context-interview summary' $CMD"
check "Has gaps subcommand" "grep -q 'context-interview gaps' $CMD"
check "References config rule" "grep -q 'context-interview-config' $CMD"
check "References savia-hub" "grep -q 'savia-hub' $CMD"
check "References client profiles" "grep -q 'client-profile' $CMD"
check "Has 8 phases" "grep -q '8' $CMD && grep -q 'Fases' $CMD"
check "Has sector adaptation" "grep -q 'sector' $CMD"

# ── Section 2: Domain rule ─────────────────────────────────────────────────
echo ""
echo "── Section 2: Domain rule ──"
RULE=".claude/rules/domain/context-interview-config.md"
check "Config rule exists" "[ -f $RULE ]"
LINES=$(wc -l < "$RULE")
check "Config rule within limit ($LINES/150 lines)" "[ $LINES -le 150 ]"
check "Has phase 1 (Dominio)" "grep -q 'Fase 1.*Dominio' $RULE"
check "Has phase 2 (Stakeholders)" "grep -q 'Fase 2.*Stakeholders' $RULE"
check "Has phase 3 (Stack)" "grep -q 'Fase 3.*Stack' $RULE"
check "Has phase 4 (Restricciones)" "grep -q 'Fase 4.*Restricciones' $RULE"
check "Has phase 5 (Reglas)" "grep -q 'Fase 5.*Reglas' $RULE"
check "Has phase 6 (Compliance)" "grep -q 'Fase 6.*Compliance' $RULE"
check "Has phase 7 (Timeline)" "grep -q 'Fase 7.*Timeline' $RULE"
check "Has phase 8 (Resumen)" "grep -q 'Fase 8.*Resumen' $RULE"
check "Has fintech adaptation" "grep -q 'fintech' $RULE"
check "Has healthcare adaptation" "grep -q 'healthcare' $RULE"
check "Has gap detection schema" "grep -q 'Detección de gaps' $RULE"
check "Has session format" "grep -q 'in-progress.*completed.*paused' $RULE"
check "Has one-question rule" "grep -q 'UNA.*vez' $RULE"
check "Has security section" "grep -q 'Seguridad' $RULE"

# ── Section 3: Skill ──────────────────────────────────────────────────────
echo ""
echo "── Section 3: Skill ──"
SKILL=".claude/skills/context-interview-conductor/SKILL.md"
check "Skill exists" "[ -f $SKILL ]"
LINES=$(wc -l < "$SKILL")
check "Skill within limit ($LINES/150 lines)" "[ $LINES -le 150 ]"
check "Has correct name" "grep -q 'context-interview-conductor' $SKILL"
check "Has start flow" "grep -q 'Iniciar entrevista' $SKILL"
check "Has conduct phase flow" "grep -q 'Conducir fase' $SKILL"
check "Has phase 8 flow" "grep -q 'Fase 8' $SKILL"
check "Has resume flow" "grep -q 'Resume' $SKILL"
check "Has summary flow" "grep -q 'Summary' $SKILL"
check "Has gaps flow" "grep -q 'Gaps' $SKILL"
check "Has adaptive questions" "grep -q 'adaptativas' $SKILL"
check "Has fintech questions" "grep -q 'PCI-DSS' $SKILL"
check "Has healthcare questions" "grep -q 'HIPAA' $SKILL"
check "References savia-hub-sync" "grep -q 'savia-hub-sync' $SKILL"
check "References client-profile" "grep -q 'client-profile' $SKILL"
check "Has one-question rule" "grep -q 'Una pregunta a la vez' $SKILL"

# ── Section 4: Cross-references ────────────────────────────────────────────
echo ""
echo "── Section 4: Cross-references ──"
check "Skill references config rule" "grep -q 'context-interview-config' $SKILL"
check "Skill references hub config" "grep -q 'savia-hub-config' $SKILL"
check "Command mentions interviews dir" "grep -q 'interviews' $CMD"
check "Rule mentions profile.md" "grep -q 'profile.md' $RULE"
check "Rule mentions contacts.md" "grep -q 'contacts.md' $RULE"
check "Rule mentions rules.md" "grep -q 'rules.md' $RULE"
check "Rule mentions metadata.md" "grep -q 'metadata.md' $RULE"

echo ""
echo "══════════════════════════════════════════"
echo "  Results: $PASS/$((PASS+FAIL)) passed, $FAIL failed"
echo "══════════════════════════════════════════"
[ "$FAIL" -eq 0 ] || exit 1
