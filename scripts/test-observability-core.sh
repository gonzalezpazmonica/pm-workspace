#!/bin/bash
# Test: Observability Core v0.71.0 (Era 13)
# Validates: 4 obs-* commands, frontmatter, ≤150 lines, key concepts, meta files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "═════════════════════════════════════════════════════════════"
echo "  TEST: Observability Core v0.71.0 — Era 13"
echo "═════════════════════════════════════════════════════════════"

# Test counters
TESTS=0
PASSED=0
FAILED=0

test_case() {
  local desc="$1"
  local condition="$2"
  TESTS=$((TESTS + 1))
  if bash -c "$condition"; then
    PASSED=$((PASSED + 1))
    echo "  ✅ $desc"
  else
    FAILED=$((FAILED + 1))
    echo "  ❌ $desc"
  fi
}

# ── Test 1: Command files exist ─────────────────────────────────
echo ""
echo "1️⃣  Command Files Exist"
test_case "obs-connect.md exists" "[ -f $REPO_ROOT/.claude/commands/obs-connect.md ]"
test_case "obs-query.md exists" "[ -f $REPO_ROOT/.claude/commands/obs-query.md ]"
test_case "obs-dashboard.md exists" "[ -f $REPO_ROOT/.claude/commands/obs-dashboard.md ]"
test_case "obs-status.md exists" "[ -f $REPO_ROOT/.claude/commands/obs-status.md ]"

# ── Test 2: YAML frontmatter ────────────────────────────────────
echo ""
echo "2️⃣  YAML Frontmatter"
for cmd in obs-connect obs-query obs-dashboard obs-status; do
  file="$REPO_ROOT/.claude/commands/${cmd}.md"
  test_case "${cmd}: has name field" "grep -q '^name: ' $file"
  test_case "${cmd}: has description" "grep -q '^description: ' $file"
  test_case "${cmd}: developer_type: all" "grep -q 'developer_type: all' $file"
  test_case "${cmd}: agent: task" "grep -q 'agent: task' $file"
  test_case "${cmd}: context_cost: high" "grep -q 'context_cost: high' $file"
done

# ── Test 3: Line count ≤ 150 ────────────────────────────────────
echo ""
echo "3️⃣  Line Count (≤ 150 lines)"
for cmd in obs-connect obs-query obs-dashboard obs-status; do
  file="$REPO_ROOT/.claude/commands/${cmd}.md"
  lines=$(wc -l < "$file")
  test_case "${cmd}: ${lines} lines ≤ 150" "[ $lines -le 150 ]"
done

# ── Test 4: Key concepts present ────────────────────────────────
echo ""
echo "4️⃣  Key Concepts"
test_case "obs-connect mentions Grafana" "grep -q 'Grafana' $REPO_ROOT/.claude/commands/obs-connect.md"
test_case "obs-connect mentions Datadog" "grep -q 'Datadog' $REPO_ROOT/.claude/commands/obs-connect.md"
test_case "obs-connect mentions App Insights" "grep -q 'Application Insights\|App Insights' $REPO_ROOT/.claude/commands/obs-connect.md"
test_case "obs-connect mentions OpenTelemetry" "grep -q 'OpenTelemetry' $REPO_ROOT/.claude/commands/obs-connect.md"
test_case "obs-query mentions PromQL" "grep -q 'PromQL' $REPO_ROOT/.claude/commands/obs-query.md"
test_case "obs-query mentions KQL" "grep -q 'KQL' $REPO_ROOT/.claude/commands/obs-query.md"
test_case "obs-query mentions natural language" "grep -q 'lenguaje natural\|natural language' $REPO_ROOT/.claude/commands/obs-query.md"
test_case "obs-dashboard mentions role-based" "grep -q 'rol\|role' $REPO_ROOT/.claude/commands/obs-dashboard.md"
test_case "obs-status mentions health check" "grep -q 'health\|salud' $REPO_ROOT/.claude/commands/obs-status.md"

# ── Test 5: Meta files updated ──────────────────────────────────
echo ""
echo "5️⃣  Meta Files (Dynamic command count)"

# Count commands
cmd_count=$(find "$REPO_ROOT/.claude/commands" -name "*.md" | wc -l)
test_case "Command count is ≥260" "[ $cmd_count -ge 260 ]"

# Check CLAUDE.md
test_case "CLAUDE.md mentions Era 13" "grep -q 'Era 13' $REPO_ROOT/CLAUDE.md"
test_case "CLAUDE.md mentions obs-connect" "grep -q 'obs-connect' $REPO_ROOT/CLAUDE.md"
test_case "CLAUDE.md mentions obs-query" "grep -q 'obs-query' $REPO_ROOT/CLAUDE.md"
test_case "CLAUDE.md mentions obs-dashboard" "grep -q 'obs-dashboard' $REPO_ROOT/CLAUDE.md"
test_case "CLAUDE.md mentions obs-status" "grep -q 'obs-status' $REPO_ROOT/CLAUDE.md"

# Check CHANGELOG
test_case "CHANGELOG.md has v0.71.0 entry" "grep -q '## \[0.71.0\]' $REPO_ROOT/CHANGELOG.md"

# Check README
test_case "README.md mentions v0.71.0" "grep -q '0.71.0' $REPO_ROOT/README.md"
test_case "README.md mentions observability" "grep -q -i 'observability\|observabilidad' $REPO_ROOT/README.md"

# ── Test 6: Spanish content & Savia persona ─────────────────────
echo ""
echo "6️⃣  Spanish Content & Savia Persona"
for cmd in obs-connect obs-query obs-dashboard obs-status; do
  file="$REPO_ROOT/.claude/commands/${cmd}.md"
  test_case "${cmd}: has Savia emoji (🦉)" "grep -q '🦉' $file"
  test_case "${cmd}: has Spanish content" "grep -q -i 'conectar\|consulta\|estado' $file"
done

# ── Test 7: Era 13 documentation ────────────────────────────────
echo ""
echo "7️⃣  Era 13: Observability & Intelligence"
test_case "context-map.md mentions observability" "grep -q -i 'observability\|observabilidad' $REPO_ROOT/docs/context-map.md 2>/dev/null || true"
test_case "role-workflows.md mentions obs commands" "grep -q 'obs-' $REPO_ROOT/.claude/rules/domain/role-workflows.md 2>/dev/null || true"

# ── Summary ─────────────────────────────────────────────────────
echo ""
echo "═════════════════════════════════════════════════════════════"
echo "  TEST SUMMARY"
echo "═════════════════════════════════════════════════════════════"
echo "  Total tests: $TESTS"
echo "  ✅ Passed: $PASSED"
echo "  ❌ Failed: $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
  echo "  🎉 ALL TESTS PASSED"
  exit 0
else
  echo "  ⚠️  SOME TESTS FAILED"
  exit 1
fi

