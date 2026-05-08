#!/bin/bash
# Test: v0.73.0 — Vertical Banking
# Validates: 5 banking-* commands, skill, detection rule, meta files

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "═════════════════════════════════════════════════════════════"
echo "  TEST: v0.73.0 — Vertical Banking"
echo "═════════════════════════════════════════════════════════════"

TESTS=0
PASSED=0
FAILED=0

test_case() {
  local desc="$1"
  local condition="$2"
  TESTS=$((TESTS + 1))
  if eval "$condition"; then
    PASSED=$((PASSED + 1))
    echo "  ✅ $desc"
  else
    FAILED=$((FAILED + 1))
    echo "  ❌ $desc"
  fi
}

# ── 1. Command files exist ────────────────────────────────────
echo ""
echo "1️⃣  Command Files"
for cmd in banking-detect banking-bian banking-eda-validate banking-data-governance banking-mlops-audit; do
  test_case "$cmd.md exists" "[ -f $REPO_ROOT/.opencode/commands/$cmd.md ]"
done

# ── 2. YAML frontmatter ──────────────────────────────────────
echo ""
echo "2️⃣  Frontmatter"
for cmd in banking-detect banking-bian banking-eda-validate banking-data-governance banking-mlops-audit; do
  file="$REPO_ROOT/.opencode/commands/$cmd.md"
  test_case "$cmd: has name" "grep -q '^name: ' $file"
  test_case "$cmd: has description" "grep -q '^description: ' $file"
done

# ── 3. Line count ≤ 150 ──────────────────────────────────────
echo ""
echo "3️⃣  Line Count (≤ 150)"
for cmd in banking-detect banking-bian banking-eda-validate banking-data-governance banking-mlops-audit; do
  file="$REPO_ROOT/.opencode/commands/$cmd.md"
  lines=$(wc -l < "$file")
  test_case "$cmd: ${lines} lines ≤ 150" "[ $lines -le 150 ]"
done

# ── 4. Key concepts ──────────────────────────────────────────
echo ""
echo "4️⃣  Key Concepts"
test_case "banking-detect: mentions BIAN" "grep -qi 'BIAN' $REPO_ROOT/.opencode/commands/banking-detect.md"
test_case "banking-bian: mentions ArchiMate" "grep -qi 'ArchiMate' $REPO_ROOT/.opencode/commands/banking-bian.md"
test_case "banking-eda: mentions Kafka" "grep -qi 'Kafka' $REPO_ROOT/.opencode/commands/banking-eda-validate.md"
test_case "banking-data: mentions lineage" "grep -qi 'lineage' $REPO_ROOT/.opencode/commands/banking-data-governance.md"
test_case "banking-mlops: mentions drift" "grep -qi 'drift' $REPO_ROOT/.opencode/commands/banking-mlops-audit.md"

# ── 5. Skill files ───────────────────────────────────────────
echo ""
echo "5️⃣  Skill: banking-architecture"
test_case "SKILL.md exists" "[ -f $REPO_ROOT/.opencode/skills/banking-architecture/SKILL.md ]"
test_case "bian-framework.md exists" "[ -f $REPO_ROOT/.opencode/skills/banking-architecture/references/bian-framework.md ]"
test_case "eda-patterns.md exists" "[ -f $REPO_ROOT/.opencode/skills/banking-architecture/references/eda-patterns-banking.md ]"
test_case "data-governance.md exists" "[ -f $REPO_ROOT/.opencode/skills/banking-architecture/references/data-governance-banking.md ]"

# ── 6. Detection rule ────────────────────────────────────────
echo ""
echo "6️⃣  Detection Rule"
test_case "banking-detection.md exists" "[ -f $REPO_ROOT/docs/rules/domain/banking-detection.md ]"
test_case "detection: mentions Settlement" "grep -q 'Settlement' $REPO_ROOT/docs/rules/domain/banking-detection.md"
test_case "detection: 5 phases" "grep -q 'Fase 5' $REPO_ROOT/docs/rules/domain/banking-detection.md"

# ── 7. Meta files ────────────────────────────────────────────
echo ""
echo "7️⃣  Meta Files"
test_case "banking in context-map" "grep -q 'banking' $REPO_ROOT/.claude/profiles/context-map.md 2>/dev/null"
test_case "CHANGELOG has v0.73.0" "grep -q '0.73.0' $REPO_ROOT/CHANGELOG.md"

# ── Summary ──────────────────────────────────────────────────
echo ""
echo "═════════════════════════════════════════════════════════════"
echo "  Total: $TESTS | ✅ Passed: $PASSED | ❌ Failed: $FAILED"
echo "═════════════════════════════════════════════════════════════"

if [ $FAILED -eq 0 ]; then
  echo "  🎉 ALL TESTS PASSED"
  exit 0
else
  echo "  ⚠️  SOME TESTS FAILED"
  exit 1
fi
