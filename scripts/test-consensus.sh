#!/bin/bash
# Test suite for Multi-Judge Consensus — Quality Validation Framework
# Validates: protocol, skill, command, scoring, verdicts, integration

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASSED=0
FAILED=0
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

assert() {
  if eval "$1"; then
    echo -e "  ${GREEN}✓${NC} $2"
    PASSED=$((PASSED+1))
  else
    echo -e "  ${RED}✗${NC} $2"
    FAILED=$((FAILED+1))
  fi
}

echo "═══════════════════════════════════════════════════════════════════"
echo "  Test Suite — Multi-Judge Consensus Protocol"
echo "═══════════════════════════════════════════════════════════════════"
echo

# ── 1. File existence ─────────────────────────────────────────────
echo "[Test 1] Files exist"
assert "[ -f '$PROJECT_DIR/docs/rules/domain/consensus-protocol.md' ]" \
  "consensus-protocol.md exists"
assert "[ -f '$PROJECT_DIR/.opencode/skills/consensus-validation/SKILL.md' ]" \
  "consensus-validation SKILL.md exists"
assert "[ -f '$PROJECT_DIR/.opencode/commands/validate-consensus.md' ]" \
  "validate-consensus.md command exists"
echo

# ── 2. Line count ≤ 150 ──────────────────────────────────────────
echo "[Test 2] Line count ≤ 150"
for f in \
  "docs/rules/domain/consensus-protocol.md" \
  ".opencode/skills/consensus-validation/SKILL.md" \
  ".opencode/commands/validate-consensus.md"; do
  LINES=$(wc -l < "$PROJECT_DIR/$f")
  assert "[ $LINES -le 150 ]" "$f ($LINES lines)"
done
echo

# ── 3. Protocol: 3 judges defined ────────────────────────────────
echo "[Test 3] Protocol defines 3 judges"
PROTO="$PROJECT_DIR/docs/rules/domain/consensus-protocol.md"
assert "grep -q 'reflection-validator' '$PROTO'" "Judge: reflection-validator"
assert "grep -q 'code-reviewer' '$PROTO'" "Judge: code-reviewer"
assert "grep -q 'business-analyst' '$PROTO'" "Judge: business-analyst"
echo

# ── 4. Scoring weights ───────────────────────────────────────────
echo "[Test 4] Scoring weights defined"
assert "grep -q '0\.4' '$PROTO'" "Weight 0.4 (reflection)"
assert "grep -q '0\.3' '$PROTO'" "Weight 0.3 (code/business)"
echo

# ── 5. Verdict thresholds ────────────────────────────────────────
echo "[Test 5] Verdict thresholds"
assert "grep -q 'APPROVED' '$PROTO'" "APPROVED verdict defined"
assert "grep -q 'CONDITIONAL' '$PROTO'" "CONDITIONAL verdict defined"
assert "grep -q 'REJECTED' '$PROTO'" "REJECTED verdict defined"
assert "grep -qi '0\.75\|0,75' '$PROTO'" "Threshold ≥0.75 for APPROVED"
assert "grep -qi '0\.5\|0,5' '$PROTO'" "Threshold 0.5 for CONDITIONAL"
echo

# ── 6. Veto rule ──────────────────────────────────────────────────
echo "[Test 6] Veto rule"
assert "grep -qi 'veto' '$PROTO'" "Veto mechanism documented"
assert "grep -qi 'security\|seguridad' '$PROTO'" "Security veto trigger"
assert "grep -qi 'GDPR\|gdpr' '$PROTO'" "GDPR veto trigger"
echo

# ── 7. Skill: orchestration protocol ─────────────────────────────
echo "[Test 7] Skill orchestration"
SKILL="$PROJECT_DIR/.opencode/skills/consensus-validation/SKILL.md"
assert "grep -qi 'protocol\|protocolo' '$SKILL'" "Protocol section exists"
assert "grep -q '1\.0\|1,0' '$SKILL'" "Score 1.0 mapping exists"
assert "grep -q '0\.5\|0,5' '$SKILL'" "Score 0.5 mapping exists"
assert "grep -q '0\.0\|0,0' '$SKILL'" "Score 0.0 mapping exists"
echo

# ── 8. Skill: verdict normalization table ─────────────────────────
echo "[Test 8] Verdict normalization"
assert "grep -q 'VALIDATED' '$SKILL'" "VALIDATED mapped"
assert "grep -q 'APROBADO' '$SKILL'" "APROBADO mapped"
assert "grep -q 'RECHAZADO' '$SKILL'" "RECHAZADO mapped"
echo

# ── 9. Command: usage and flags ───────────────────────────────────
echo "[Test 9] Command structure"
CMD="$PROJECT_DIR/.opencode/commands/validate-consensus.md"
assert "grep -q 'validate-consensus' '$CMD'" "Command name present"
assert "grep -qi 'spec\|pr\|decision' '$CMD'" "Input types documented"
assert "grep -q '\-\-force' '$CMD'" "--force flag"
assert "grep -q '\-\-explain' '$CMD'" "--explain flag"
echo

# ── 10. Timeout defined ──────────────────────────────────────────
echo "[Test 10] Timeout"
assert "grep -q '120' '$PROTO'" "120s timeout in protocol"
echo

# ── 11. Anti-patterns section ─────────────────────────────────────
echo "[Test 11] Anti-patterns"
assert "grep -qi 'anti-pattern\|restricci\|nunca' '$PROTO'" "Anti-patterns documented"
echo

# ── 12. Dissent handling ──────────────────────────────────────────
echo "[Test 12] Dissent handling"
assert "grep -qi 'dissent\|disidencia' '$PROTO' || grep -qi 'dissent\|disidencia' '$SKILL'" \
  "Dissent mechanism documented"
echo

# ── Results ───────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════════"
echo -e "  Results: ${GREEN}${PASSED} passed${NC}, ${RED}${FAILED} failed${NC}"
echo "═══════════════════════════════════════════════════════════════════"
exit $FAILED
