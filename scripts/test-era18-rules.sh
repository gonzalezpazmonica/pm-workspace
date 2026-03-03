#!/usr/bin/env bash
# ── test-era18-rules.sh — Era 18 rule/config validation ──
set -euo pipefail
PASS=0; FAIL=0
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RULES_DIR="$REPO_ROOT/.claude/rules/domain"

ok()   { PASS=$((PASS+1)); echo "  ✅ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }
has()  { grep -qi "$3" "$1" 2>/dev/null && ok "$2: has '$3'" || fail "$2: missing '$3'"; }

echo "═══════════════════════════════════════════════════════════"
echo "  TEST: Era 18 — Rules & Config Validation"
echo "═══════════════════════════════════════════════════════════"

# ── ai-competency-framework.md ──────────────────────────────
echo ""
echo "1️⃣  AI Competency Framework"

ACF="$RULES_DIR/ai-competency-framework.md"

# 6 competencies present
has "$ACF" "competency" "Problem Formulation"
has "$ACF" "competency" "Output Evaluation"
has "$ACF" "competency" "Context Engineering"
has "$ACF" "competency" "AI Orchestration"
has "$ACF" "competency" "Critical Thinking"
has "$ACF" "competency" "Ethical Awareness"

# 4 levels each
for level in "Básico" "Intermedio" "Avanzado" "Experto"; do
  COUNT=$(grep -c "$level" "$ACF" 2>/dev/null || echo 0)
  [ "$COUNT" -ge 6 ] && ok "Level '$level' appears ≥6 times" || fail "Level '$level' only $COUNT times"
done

# Score formula
has "$ACF" "scoring" "promedio.*25"

# ── aepd-framework.md ───────────────────────────────────────
echo ""
echo "2️⃣  AEPD Framework"

AEPD="$RULES_DIR/aepd-framework.md"

# 4 phases
has "$AEPD" "AEPD" "Fase 1"
has "$AEPD" "AEPD" "Fase 2"
has "$AEPD" "AEPD" "Fase 3"
has "$AEPD" "AEPD" "Fase 4"

# References AEPD
has "$AEPD" "AEPD" "AEPD"
has "$AEPD" "AEPD" "governance"

# ── intelligent-hooks.md ────────────────────────────────────
echo ""
echo "3️⃣  Intelligent Hooks (Hook Taxonomy)"

IH="$RULES_DIR/intelligent-hooks.md"

# 3 types
has "$IH" "hooks" "Command"
has "$IH" "hooks" "Prompt"
has "$IH" "hooks" "Agent"

# Timing thresholds
has "$IH" "hooks" "1-3s"
has "$IH" "hooks" "2-5s"
has "$IH" "hooks" "30-120s"

# Calibration protocol
has "$IH" "hooks" "warning"
has "$IH" "hooks" "soft-block"
has "$IH" "hooks" "hard-block"

# ── source-tracking.md ──────────────────────────────────────
echo ""
echo "4️⃣  Source Tracking"

ST="$RULES_DIR/source-tracking.md"

# 6 citation formats
has "$ST" "source-tracking" "rule:"
has "$ST" "source-tracking" "skill:"
has "$ST" "source-tracking" "doc:"
has "$ST" "source-tracking" "agent:"
has "$ST" "source-tracking" "cmd:"
has "$ST" "source-tracking" "ext:"

# ── skillssh-publishing.md ──────────────────────────────────
echo ""
echo "5️⃣  skills.sh Publishing"

SP="$RULES_DIR/skillssh-publishing.md"

# 5 core skills mapped
has "$SP" "skillssh" "pm-sprint"
has "$SP" "skillssh" "pm-capacity"
has "$SP" "skillssh" "pm-pbi-decompose"
has "$SP" "skillssh" "pm-sdd"
has "$SP" "skillssh" "pm-diagrams"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Total: $((PASS+FAIL)) | ✅ Passed: $PASS | ❌ Failed: $FAIL"
echo "═══════════════════════════════════════════════════════════"
[ "$FAIL" -eq 0 ] && echo "  🎉 ALL TESTS PASSED" || { echo "  ⚠️  $FAIL TESTS FAILED"; exit 1; }
