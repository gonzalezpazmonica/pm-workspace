#!/usr/bin/env bash
# test-wellbeing-guardian.sh — Structural tests for Wellbeing Guardian (Era 34 — v2.9.0)
set -uo pipefail

PASS=0; FAIL=0

pass() { ((PASS+=1)) || true; echo "  ✅ $1"; }
fail() { ((FAIL+=1)) || true; echo "  ❌ $1"; }
check() { if eval "$2" > /dev/null 2>&1; then pass "$1"; else fail "$1"; fi; }

echo "══════════════════════════════════════════"
echo "  Wellbeing Guardian Tests (Era 34 — v2.9.0)"
echo "══════════════════════════════════════════"

# ── Section 1: Command file ────────────────────────────────────────────────
echo ""
echo "── Section 1: Command file ──"
CMD=".claude/commands/wellbeing-guardian.md"
check "Command exists" "[ -f $CMD ]"
LINES=$(wc -l < "$CMD")
check "Command within line limit ($LINES/150 lines)" "[ $LINES -le 150 ]"
check "Has status subcommand" "grep -q 'wellbeing-guardian status' $CMD"
check "Has configure subcommand" "grep -q 'wellbeing-guardian configure' $CMD"
check "Has breaks subcommand" "grep -q 'wellbeing-guardian breaks' $CMD"
check "Has report subcommand" "grep -q 'wellbeing-guardian report' $CMD"
check "Has pause subcommand" "grep -q 'wellbeing-guardian pause' $CMD"
check "References skill" "grep -q 'wellbeing-guardian/SKILL.md' $CMD"
check "References config rule" "grep -q 'wellbeing-config' $CMD"
check "Has strategy table" "grep -q 'pomodoro' $CMD && grep -q '52-17' $CMD && grep -q '5-50' $CMD"

# ── Section 2: Domain rule ─────────────────────────────────────────────────
echo ""
echo "── Section 2: Domain rule ──"
RULE=".claude/rules/domain/wellbeing-config.md"
check "Config rule exists" "[ -f $RULE ]"
LINES=$(wc -l < "$RULE")
check "Config rule within limit ($LINES/150 lines)" "[ $LINES -le 150 ]"
check "Has HBR reference" "grep -q 'HBR' $RULE"
check "Has pomodoro strategy" "grep -q 'pomodoro' $RULE"
check "Has 52-17 strategy" "grep -q '52-17' $RULE"
check "Has 5-50 strategy" "grep -q '5-50' $RULE"
check "Has 20-20-20 eye rule" "grep -q '20-20-20' $RULE"
check "Has INSST reference" "grep -q 'INSST' $RULE"
check "Has break nudge template" "grep -q 'Break debido' $RULE"
check "Has after-hours nudge" "grep -q 'Fuera de horario' $RULE"
check "Has weekend nudge" "grep -q 'Fin de semana' $RULE"
check "Has hydration nudge" "grep -q 'Hidratación' $RULE"
check "Has post-break nudge" "grep -q 'Post-descanso' $RULE"
check "Has schema section" "grep -q 'Schema de horario' $RULE"
check "Has work_hours_start field" "grep -q 'work_hours_start' $RULE"
check "Has break_strategy field" "grep -q 'break_strategy' $RULE"
check "Has burnout-radar integration" "grep -q 'burnout-radar' $RULE"
check "Has sustainable-pace integration" "grep -q 'sustainable-pace' $RULE"
check "Has privacy section" "grep -q 'privacidad' $RULE || grep -q 'Privacidad' $RULE || grep -q 'Seguridad' $RULE"

# ── Section 3: Skill ──────────────────────────────────────────────────────
echo ""
echo "── Section 3: Skill ──"
SKILL=".claude/skills/wellbeing-guardian/SKILL.md"
check "Skill exists" "[ -f $SKILL ]"
LINES=$(wc -l < "$SKILL")
check "Skill within limit ($LINES/150 lines)" "[ $LINES -le 150 ]"
check "Has correct name" "grep -q 'wellbeing-guardian' $SKILL"
check "Has session start flow" "grep -q 'Inicio de sesión' $SKILL"
check "Has periodic check flow" "grep -q 'Check periódico' $SKILL"
check "Has configure flow" "grep -q 'Configure' $SKILL"
check "Has status flow" "grep -q 'Status' $SKILL"
check "Has pause flow" "grep -q 'Pause' $SKILL"
check "Has breaks flow" "grep -q 'Breaks' $SKILL"
check "Has report flow" "grep -q 'Report' $SKILL"
check "Has break_compliance_score" "grep -q 'break_compliance_score' $SKILL"
check "Has escalation rule" "grep -q 'ignora.*nudge' $SKILL || grep -q 'Escalado' $SKILL"
check "Has max 1 nudge rule" "grep -q '1 nudge' $SKILL"
check "References workflow.md" "grep -q 'workflow.md' $SKILL"
check "References preferences.md" "grep -q 'preferences.md' $SKILL"

# ── Section 4: Cross-references ────────────────────────────────────────────
echo ""
echo "── Section 4: Cross-references ──"
check "Skill references config rule" "grep -q 'wellbeing-config' $SKILL"
check "Command references skill" "grep -q 'wellbeing-guardian/SKILL.md' $CMD"
check "Command references config rule" "grep -q 'wellbeing-config' $CMD"
check "Rule references burnout-radar" "grep -q 'burnout-radar' $RULE"
check "Rule references sustainable-pace" "grep -q 'sustainable-pace' $RULE"
check "Skill references burnout-radar" "grep -q 'burnout-radar' $SKILL"

echo ""
echo "══════════════════════════════════════════"
echo "  Results: $PASS/$((PASS+FAIL)) passed, $FAIL failed"
echo "══════════════════════════════════════════"
[ "$FAIL" -eq 0 ] || exit 1
