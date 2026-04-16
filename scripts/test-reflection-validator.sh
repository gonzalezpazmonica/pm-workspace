#!/bin/bash
# Test suite for Reflection Validator — System 2 Meta-Cognition Agent
# Validates: skill, agent, memory, catalog integration, content correctness

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASSED=0
FAILED=0
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

assert() {
  if eval "$1"; then
    echo -e "  ${GREEN}✓${NC} $2"
    ((PASSED++))
  else
    echo -e "  ${RED}✗${NC} $2"
    ((FAILED++))
  fi
}

echo "═══════════════════════════════════════════════════════════════════"
echo "  Test Suite — Reflection Validator (System 2 Meta-Cognition)"
echo "═══════════════════════════════════════════════════════════════════"
echo

# ── 1. File existence ─────────────────────────────────────────────
echo "[Test 1] Files exist"
assert "[ -f '$PROJECT_DIR/.claude/skills/reflection-validation/SKILL.md' ]" \
  "SKILL.md exists"
assert "[ -f '$PROJECT_DIR/.claude/agents/reflection-validator.md' ]" \
  "Agent reflection-validator.md exists"
assert "[ -f '$PROJECT_DIR/.claude/agent-memory/reflection-validator/MEMORY.md' ]" \
  "Agent MEMORY.md exists"
echo

# ── 2. Line count ≤ 150 ──────────────────────────────────────────
echo "[Test 2] Line count ≤ 150"
for f in \
  ".claude/skills/reflection-validation/SKILL.md" \
  ".claude/agents/reflection-validator.md" \
  ".claude/agent-memory/reflection-validator/MEMORY.md"; do
  lines=$(wc -l < "$PROJECT_DIR/$f" 2>/dev/null || echo 999)
  assert "[ $lines -le 150 ]" "$f: $lines lines"
done
echo

# ── 3. Agent frontmatter ─────────────────────────────────────────
echo "[Test 3] Agent frontmatter fields"
AGENT="$PROJECT_DIR/.claude/agents/reflection-validator.md"
assert "grep -q '^name: reflection-validator' '$AGENT'" \
  "name: reflection-validator"
assert "grep -q 'model: claude-opus-4-7' '$AGENT'" \
  "model: claude-opus-4-7"
assert "grep -q 'color: purple' '$AGENT'" \
  "color: purple"
assert "grep -q 'memory: project' '$AGENT'" \
  "memory: project"
assert "grep -q 'permissionMode: plan' '$AGENT'" \
  "permissionMode: plan"
assert "grep -q 'reflection-validation' '$AGENT'" \
  "skill reference: reflection-validation"
assert "grep -q 'max_context_tokens: 8000' '$AGENT'" \
  "max_context_tokens: 8000"
assert "grep -q 'output_max_tokens: 800' '$AGENT'" \
  "output_max_tokens: 800"
echo

# ── 4. Skill frontmatter ─────────────────────────────────────────
echo "[Test 4] Skill frontmatter fields"
SKILL="$PROJECT_DIR/.claude/skills/reflection-validation/SKILL.md"
assert "grep -q '^name: reflection-validation' '$SKILL'" \
  "name: reflection-validation"
assert "grep -q 'context_cost: medium' '$SKILL'" \
  "context_cost: medium"
assert "grep -q 'user-invocable: false' '$SKILL'" \
  "user-invocable: false"
echo

# ── 5. Protocol: 5 Steps present ─────────────────────────────────
echo "[Test 5] Protocol — 5 Steps present in SKILL.md"
assert "grep -q 'Step 1.*Real Objective' '$SKILL'" \
  "Step 1: Extract Real Objective"
assert "grep -q 'Step 2.*Assumption Audit' '$SKILL'" \
  "Step 2: Assumption Audit"
assert "grep -q 'Step 3.*Mental Simulation' '$SKILL'" \
  "Step 3: Mental Simulation"
assert "grep -q 'Step 4.*Gap Detection' '$SKILL'" \
  "Step 4: Gap Detection"
assert "grep -q 'Step 5.*Transparent Correction' '$SKILL'" \
  "Step 5: Transparent Correction"
echo

# ── 6. Cognitive bias taxonomy ────────────────────────────────────
echo "[Test 6] Cognitive bias taxonomy present"
for bias in "Proxy optimization" "Anchoring" "Satisficing" \
  "Narrow framing" "Confirmation bias" "Sunk cost"; do
  assert "grep -q '$bias' '$SKILL'" \
    "Bias: $bias"
done
echo

# ── 7. Gap types documented ──────────────────────────────────────
echo "[Test 7] Gap types documented"
for gap in "Missing prerequisite" "Wrong optimization" \
  "Ignored constraint" "Anchoring bias" "Satisficing" "Narrow framing"; do
  assert "grep -q '$gap' '$SKILL'" \
    "Gap type: $gap"
done
echo

# ── 8. Embeddable pattern ────────────────────────────────────────
echo "[Test 8] Embeddable pattern for other agents"
assert "grep -q 'Embeddable Pattern' '$SKILL'" \
  "Section: Embeddable Pattern"
assert "grep -q 'Post-Response Reflection' '$SKILL'" \
  "Contains: Post-Response Reflection block"
assert "grep -q 'REAL objective' '$SKILL'" \
  "Contains: REAL objective question"
assert "grep -q 'broken link' '$SKILL'" \
  "Contains: broken link check"
echo

# ── 9. Output format ─────────────────────────────────────────────
echo "[Test 9] Output format contains verdict types"
assert "grep -q 'VALIDATED' '$SKILL'" \
  "Verdict: VALIDATED"
assert "grep -q 'CORRECTED' '$SKILL'" \
  "Verdict: CORRECTED"
assert "grep -q 'REQUIRES_RETHINKING' '$SKILL'" \
  "Verdict: REQUIRES_RETHINKING"
assert "grep -q 'System 2 Analysis' '$SKILL'" \
  "Banner: System 2 Analysis"
echo

# ── 10. Agent process covers protocol ────────────────────────────
echo "[Test 10] Agent references protocol steps"
assert "grep -q 'Real Objective' '$AGENT'" \
  "Agent mentions: Real Objective"
assert "grep -q 'Assumption Audit' '$AGENT'" \
  "Agent mentions: Assumption Audit"
assert "grep -q 'Mental Simulation' '$AGENT'" \
  "Agent mentions: Mental Simulation"
assert "grep -q 'Gap Detection' '$AGENT'" \
  "Agent mentions: Gap Detection"
assert "grep -q 'Transparent Correction' '$AGENT'" \
  "Agent mentions: Transparent Correction"
echo

# ── 11. Agent restrictions ───────────────────────────────────────
echo "[Test 11] Agent restrictions defined"
assert "grep -q 'NEVER.*change.*original.*response' '$AGENT'" \
  "Restriction: never change without reasoning"
assert "grep -q 'NEVER.*validate.*without.*5 steps' '$AGENT'" \
  "Restriction: never skip steps"
assert "grep -q 'minimum 3' '$AGENT'" \
  "Restriction: minimum 3 assumptions"
echo

# ── 12. Catalog integration ──────────────────────────────────────
echo "[Test 12] Catalog integration"
CATALOG="$PROJECT_DIR/.claude/rules/domain/agents-catalog.md"
assert "grep -q 'reflection-validator' '$CATALOG'" \
  "agents-catalog.md: reflection-validator listed"
assert "grep -q '26' '$CATALOG'" \
  "agents-catalog.md: count is 26"
echo

# ── 13. README integration ───────────────────────────────────────
echo "[Test 13] README integration"
assert "grep -q 'reflection-validator' '$PROJECT_DIR/docs/readme/12-comandos-agentes.md'" \
  "ES docs: reflection-validator in agent table"
assert "grep -q 'reflection-validator' '$PROJECT_DIR/docs/readme_en/12-commands-agents.md'" \
  "EN docs: reflection-validator in agent table"
assert "grep -q '26 agentes' '$PROJECT_DIR/README.md'" \
  "README.md: 26 agentes"
assert "grep -q '26 agents' '$PROJECT_DIR/README.en.md'" \
  "README.en.md: 26 agents"
echo

# ── 14. CLAUDE.md count updated ──────────────────────────────────
echo "[Test 14] CLAUDE.md count updated"
assert "grep -q 'agents/ (26)' '$PROJECT_DIR/CLAUDE.md'" \
  "CLAUDE.md: agents/ (26)"
assert "grep -q 'Catálogo (26)' '$PROJECT_DIR/CLAUDE.md'" \
  "CLAUDE.md: Catálogo (26)"
echo

# ── 15. Memory file structure ────────────────────────────────────
echo "[Test 15] Memory file structure"
MEMORY="$PROJECT_DIR/.claude/agent-memory/reflection-validator/MEMORY.md"
assert "grep -q 'Persistent Memory' '$MEMORY'" \
  "MEMORY.md: has header"
assert "grep -q 'Discovered Patterns' '$MEMORY'" \
  "MEMORY.md: has Discovered Patterns section"
assert "grep -q 'Date.*Pattern.*Context.*Source' '$MEMORY'" \
  "MEMORY.md: has table headers"
echo

# ── 16. Car wash example detectable ──────────────────────────────
echo "[Test 16] Canonical example (car wash) present"
assert "grep -qi 'car wash\|car.*wash\|coche.*lav' '$SKILL'" \
  "SKILL.md: car wash example referenced"
assert "grep -qi 'walk\|pie\|50' '$SKILL'" \
  "SKILL.md: walking/distance context"
echo

# ── 17. Kahneman reference ───────────────────────────────────────
echo "[Test 17] Theoretical foundation"
assert "grep -q 'Kahneman\|System 1\|System 2' '$SKILL'" \
  "SKILL.md: Kahneman/System 1/System 2"
assert "grep -q 'System 2' '$AGENT'" \
  "Agent: System 2 reference"
echo

# ── Summary ──────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════════"
echo -e "  Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}"
echo "═══════════════════════════════════════════════════════════════════"

exit $FAILED
