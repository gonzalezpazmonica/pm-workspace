#!/usr/bin/env bash
set -eo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0

ok()   { PASS=$((PASS+1)); echo "  ✅ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }
check() { if [ -f "$1" ]; then ok "$2 exists"; else fail "$2 missing"; fi; }
has()  { grep -qi "$3" "$1" 2>/dev/null && ok "$2: has $3" || fail "$2: missing $3"; }

echo "═══════════════════════════════════════════════════════════"
echo "  TEST: v0.74.0 — Savia Flow Practice"
echo "═══════════════════════════════════════════════════════════"

echo ""
echo "1️⃣  Skill Files"
check "$REPO_ROOT/.claude/skills/savia-flow-practice/SKILL.md" "SKILL.md"
check "$REPO_ROOT/.claude/skills/savia-flow-practice/references/azure-devops-config.md" "azure-devops-config"
check "$REPO_ROOT/.claude/skills/savia-flow-practice/references/backlog-structure.md" "backlog-structure"
check "$REPO_ROOT/.claude/skills/savia-flow-practice/references/task-template-sdd.md" "task-template-sdd"
check "$REPO_ROOT/.claude/skills/savia-flow-practice/references/meetings-cadence.md" "meetings-cadence"
check "$REPO_ROOT/.claude/skills/savia-flow-practice/references/dual-track-coordination.md" "dual-track-coordination"
check "$REPO_ROOT/.claude/skills/savia-flow-practice/references/example-socialapp.md" "example-socialapp"

echo ""
echo "2️⃣  Command Files"
for cmd in flow-setup flow-board flow-intake flow-metrics flow-spec; do
  check "$REPO_ROOT/.claude/commands/${cmd}.md" "$cmd"
done

echo ""
echo "3️⃣  Frontmatter"
for cmd in flow-setup flow-board flow-intake flow-metrics flow-spec; do
  f="$REPO_ROOT/.claude/commands/${cmd}.md"
  grep -q "^name:" "$f" 2>/dev/null && ok "$cmd: has name" || fail "$cmd: missing name"
  grep -q "^description:" "$f" 2>/dev/null && ok "$cmd: has description" || fail "$cmd: missing description"
done

echo ""
echo "4️⃣  Line Count (≤ 150)"
for f in .claude/skills/savia-flow-practice/SKILL.md \
         .claude/skills/savia-flow-practice/references/*.md \
         .claude/commands/flow-setup.md .claude/commands/flow-board.md \
         .claude/commands/flow-intake.md .claude/commands/flow-metrics.md \
         .claude/commands/flow-spec.md; do
  lines=$(wc -l < "$REPO_ROOT/$f" | tr -d ' ')
  name=$(basename "$f")
  if [ "$lines" -le 150 ]; then ok "$name: $lines lines ≤ 150"; else fail "$name: $lines lines > 150"; fi
done

echo ""
echo "5️⃣  Key Concepts"
has "$REPO_ROOT/.claude/skills/savia-flow-practice/SKILL.md" "SKILL" "dual-track"
has "$REPO_ROOT/.claude/skills/savia-flow-practice/SKILL.md" "SKILL" "cycle time"
has "$REPO_ROOT/.claude/skills/savia-flow-practice/references/azure-devops-config.md" "azdevops" "exploration"
has "$REPO_ROOT/.claude/skills/savia-flow-practice/references/azure-devops-config.md" "azdevops" "production"
has "$REPO_ROOT/.claude/skills/savia-flow-practice/references/example-socialapp.md" "example" "ionic"
has "$REPO_ROOT/.claude/skills/savia-flow-practice/references/example-socialapp.md" "example" "rabbitmq"
has "$REPO_ROOT/.claude/skills/savia-flow-practice/references/task-template-sdd.md" "sdd" "outcome"
has "$REPO_ROOT/.claude/skills/savia-flow-practice/references/dual-track-coordination.md" "dual-track" "handoff"

echo ""
echo "6️⃣  Meta Files"
grep -qi "flow-setup" "$REPO_ROOT/.claude/profiles/context-map.md" 2>/dev/null && ok "flow in context-map" || fail "flow missing from context-map"
grep -qi "0.74.0" "$REPO_ROOT/CHANGELOG.md" 2>/dev/null && ok "CHANGELOG has v0.74.0" || fail "CHANGELOG missing v0.74.0"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Total: $((PASS+FAIL)) | ✅ Passed: $PASS | ❌ Failed: $FAIL"
echo "═══════════════════════════════════════════════════════════"
[ "$FAIL" -eq 0 ] && echo "  🎉 ALL TESTS PASSED" || { echo "  ⚠️  $FAIL TESTS FAILED"; exit 1; }
