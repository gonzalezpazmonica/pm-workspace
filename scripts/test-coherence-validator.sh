#!/bin/bash
# Test suite for Output Coherence Validator — Quality Validation Framework
# Validates: agent, skill, command, memory, catalog integration

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASSED=0
FAILED=0
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

assert() {
  if bash -c "$1"; then
    echo -e "  ${GREEN}✓${NC} $2"
    PASSED=$((PASSED+1))
  else
    echo -e "  ${RED}✗${NC} $2"
    FAILED=$((FAILED+1))
  fi
}

echo "═══════════════════════════════════════════════════════════════════"
echo "  Test Suite — Output Coherence Validator"
echo "═══════════════════════════════════════════════════════════════════"
echo

# ── 1. File existence ─────────────────────────────────────────────
echo "[Test 1] Files exist"
assert "[ -f '$PROJECT_DIR/.claude/agents/coherence-validator.md' ]" \
  "Agent coherence-validator.md exists"
assert "[ -f '$PROJECT_DIR/.claude/skills/coherence-check/SKILL.md' ]" \
  "Skill coherence-check SKILL.md exists"
assert "[ -f '$PROJECT_DIR/.claude/commands/check-coherence.md' ]" \
  "Command check-coherence.md exists"
assert "[ -f '$PROJECT_DIR/.claude/agent-memory/coherence-validator/MEMORY.md' ]" \
  "Agent MEMORY.md exists"
echo

# ── 2. Line count ≤ 150 ──────────────────────────────────────────
echo "[Test 2] Line count ≤ 150"
for f in \
  ".claude/agents/coherence-validator.md" \
  ".claude/skills/coherence-check/SKILL.md" \
  ".claude/commands/check-coherence.md"; do
  LINES=$(wc -l < "$PROJECT_DIR/$f")
  assert "[ $LINES -le 150 ]" "$f ($LINES lines)"
done
echo

# ── 3. Agent: frontmatter ────────────────────────────────────────
echo "[Test 3] Agent frontmatter"
AGENT="$PROJECT_DIR/.claude/agents/coherence-validator.md"
assert "grep -q 'name: coherence-validator' '$AGENT'" "name field"
assert "grep -q 'claude-sonnet-4-6' '$AGENT'" "Model: Sonnet 4.6"
assert "grep -q 'coherence-check' '$AGENT'" "Skill: coherence-check"
assert "grep -q 'memory: project' '$AGENT'" "Memory scope: project"
assert "grep -q 'permissionMode: plan' '$AGENT'" "Permission mode: plan"
assert "grep -q 'context_cost:' '$AGENT'" "context_cost defined"
echo

# ── 4. Agent: 3 coherence checks ─────────────────────────────────
echo "[Test 4] Coherence checks"
assert "grep -qi 'coverage\|cobertura\|objective' '$AGENT'" "Objective Coverage check"
assert "grep -qi 'consisten' '$AGENT'" "Internal Consistency check"
assert "grep -qi 'complet' '$AGENT'" "Completeness check"
echo

# ── 5. Agent: severity levels ────────────────────────────────────
echo "[Test 5] Severity levels"
assert "grep -q 'ok' '$AGENT'" "Severity: ok"
assert "grep -q 'warning' '$AGENT'" "Severity: warning"
assert "grep -q 'critical' '$AGENT'" "Severity: critical"
echo

# ── 6. Skill: protocol steps ─────────────────────────────────────
echo "[Test 6] Skill protocol"
SKILL="$PROJECT_DIR/.claude/skills/coherence-check/SKILL.md"
assert "grep -qi 'protocol\|protocolo' '$SKILL'" "Protocol section"
assert "grep -qi 'spec\|report\|code' '$SKILL'" "Output types covered"
assert "grep -qi 'non-block\|no bloq' '$SKILL'" "Non-blocking behavior"
echo

# ── 7. Skill: coverage thresholds ────────────────────────────────
echo "[Test 7] Coverage thresholds"
assert "grep -q '90' '$SKILL'" "90% threshold for ok"
assert "grep -q '70' '$SKILL'" "70% threshold for warning"
echo

# ── 8. Command: usage and flags ───────────────────────────────────
echo "[Test 8] Command structure"
CMD="$PROJECT_DIR/.claude/commands/check-coherence.md"
assert "grep -q 'check-coherence' '$CMD'" "Command name"
assert "grep -q '\-\-strict' '$CMD'" "--strict flag"
assert "grep -q '\-\-file' '$CMD'" "--file flag"
assert "grep -qi 'spec\|report\|code' '$CMD'" "Input types"
echo

# ── 9. Agent: tools ───────────────────────────────────────────────
echo "[Test 9] Agent tools"
assert "grep -q 'Read' '$AGENT'" "Tool: Read"
assert "grep -q 'Glob' '$AGENT'" "Tool: Glob"
assert "grep -q 'Grep' '$AGENT'" "Tool: Grep"
echo

# ── 10. Memory: initial structure ─────────────────────────────────
echo "[Test 10] Memory structure"
MEM="$PROJECT_DIR/.claude/agent-memory/coherence-validator/MEMORY.md"
assert "grep -q 'coherence-validator' '$MEM'" "Agent name in memory"
assert "grep -qi 'pattern\|patr' '$MEM'" "Patterns section exists"
echo

# ── 11. Agent: output format ─────────────────────────────────────
echo "[Test 11] Output format"
assert "grep -qi 'coherent\|gaps\|severity' '$AGENT'" "Output fields documented"
echo

# ── 12. Integration references ────────────────────────────────────
echo "[Test 12] Integration"
assert "grep -qi 'SDD\|spec-driven\|verify-coherence' '$SKILL' || grep -qi 'SDD\|spec-driven\|verify-coherence' '$CMD'" \
  "SDD integration referenced"
echo

# ── Results ───────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════════"
echo -e "  Results: ${GREEN}${PASSED} passed${NC}, ${RED}${FAILED} failed${NC}"
echo "═══════════════════════════════════════════════════════════════════"
exit $FAILED
