#!/bin/bash
# Test suite for Confidence Calibration — Quality Validation Framework
# Validates: calibrate script, protocol, NL resolution integration, decay logic

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
echo "  Test Suite — Confidence Calibration System"
echo "═══════════════════════════════════════════════════════════════════"
echo

# ── 1. File existence ─────────────────────────────────────────────
echo "[Test 1] Files exist"
assert "[ -f '$PROJECT_DIR/scripts/confidence-calibrate.sh' ]" \
  "confidence-calibrate.sh exists"
assert "[ -f '$PROJECT_DIR/.claude/rules/domain/confidence-protocol.md' ]" \
  "confidence-protocol.md exists"
assert "[ -x '$PROJECT_DIR/scripts/confidence-calibrate.sh' ]" \
  "confidence-calibrate.sh is executable"
echo

# ── 2. Line count ≤ 150 ──────────────────────────────────────────
echo "[Test 2] Line count ≤ 150"
for f in \
  "scripts/confidence-calibrate.sh" \
  ".claude/rules/domain/confidence-protocol.md" \
  ".claude/rules/domain/nl-command-resolution.md"; do
  LINES=$(wc -l < "$PROJECT_DIR/$f")
  assert "[ $LINES -le 150 ]" "$f ($LINES lines)"
done
echo

# ── 3. Script: subcommands ────────────────────────────────────────
echo "[Test 3] Script subcommands"
SCRIPT="$PROJECT_DIR/scripts/confidence-calibrate.sh"
assert "grep -q 'report' '$SCRIPT'" "report subcommand"
assert "grep -q 'summary' '$SCRIPT'" "summary subcommand"
assert "grep -q 'reset' '$SCRIPT'" "reset subcommand"
echo

# ── 4. Script: Brier score computation ────────────────────────────
echo "[Test 4] Brier score"
assert "grep -qi 'brier' '$SCRIPT'" "Brier score in script"
assert "grep -qi 'brier' '$PROJECT_DIR/.claude/rules/domain/confidence-protocol.md'" \
  "Brier score in protocol"
echo

# ── 5. Script: band segmentation ──────────────────────────────────
echo "[Test 5] Band segmentation"
assert "grep -q '60' '$SCRIPT'" "Band boundary 60%"
assert "grep -q '80' '$SCRIPT'" "Band boundary 80%"
echo

# ── 6. Protocol: decay mechanism ──────────────────────────────────
echo "[Test 6] Decay mechanism"
PROTO="$PROJECT_DIR/.claude/rules/domain/confidence-protocol.md"
assert "grep -qi 'decay' '$PROTO'" "Decay documented"
assert "grep -q '5%\|-5' '$PROTO'" "5% decay for pattern failures"
assert "grep -q '10%\|-10' '$PROTO'" "10% decay for command failures"
assert "grep -q '30' '$PROTO'" "Floor at 30%"
echo

# ── 7. Protocol: recovery mechanism ──────────────────────────────
echo "[Test 7] Recovery mechanism"
assert "grep -qi 'recup\|recovery' '$PROTO'" "Recovery documented"
assert "grep -q '3%\|+3' '$PROTO'" "3% recovery per success"
echo

# ── 8. Protocol: logging format ───────────────────────────────────
echo "[Test 8] Logging format"
assert "grep -q 'confidence-log.jsonl' '$PROTO'" "JSONL log file referenced"
assert "grep -q 'command' '$PROTO'" "command field in log"
assert "grep -q 'confidence' '$PROTO'" "confidence field in log"
assert "grep -q 'success' '$PROTO'" "success field in log"
echo

# ── 9. NL resolution: recalibration section ───────────────────────
echo "[Test 9] NL resolution integration"
NL="$PROJECT_DIR/.claude/rules/domain/nl-command-resolution.md"
assert "grep -qi 'recalib' '$NL'" "Recalibración section exists"
assert "grep -q 'confidence-protocol' '$NL'" "References confidence-protocol.md"
assert "grep -q 'confidence-log' '$NL'" "References confidence-log.jsonl"
echo

# ── 10. Script: functional test with mock data ────────────────────
echo "[Test 10] Functional test"
TD=$(mktemp -d)
mkdir -p "$TD/data"
# Create mock confidence log
cat > "$TD/data/confidence-log.jsonl" <<'MOCK'
{"command":"sprint-status","confidence":90,"success":true,"timestamp":"2026-03-01T10:00:00Z","pattern":"como va el sprint","band":"high"}
{"command":"sprint-status","confidence":85,"success":true,"timestamp":"2026-03-01T11:00:00Z","pattern":"estado sprint","band":"high"}
{"command":"my-focus","confidence":75,"success":false,"timestamp":"2026-03-01T12:00:00Z","pattern":"mis tareas","band":"mid"}
{"command":"flow-timesheet","confidence":55,"success":false,"timestamp":"2026-03-01T13:00:00Z","pattern":"registrar horas","band":"low"}
{"command":"sprint-status","confidence":92,"success":true,"timestamp":"2026-03-02T10:00:00Z","pattern":"sprint","band":"high"}
MOCK
OUTPUT=$(cd "$TD" && bash "$SCRIPT" report 2>&1) || true
assert "echo '$OUTPUT' | grep -qi 'band\|banda'" "Report shows bands"
assert "echo '$OUTPUT' | grep -qi 'brier\|score\|accuracy\|precis'" "Report shows scoring"
# summary subcommand
SUMM=$(cd "$TD" && bash "$SCRIPT" summary 2>&1) || true
assert "[ -n '$SUMM' ]" "Summary produces output"
rm -rf "$TD"
echo

# ── 11. Anti-patterns ─────────────────────────────────────────────
echo "[Test 11] Anti-patterns"
assert "grep -qi 'nunca\|never\|anti-pattern' '$PROTO'" "Anti-patterns documented"
echo

# ── Results ───────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════════"
echo -e "  Results: ${GREEN}${PASSED} passed${NC}, ${RED}${FAILED} failed${NC}"
echo "═══════════════════════════════════════════════════════════════════"
exit $FAILED
