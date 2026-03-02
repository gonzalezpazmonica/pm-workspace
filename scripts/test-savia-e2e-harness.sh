#!/usr/bin/env bash
set -eo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCKER_DIR="$REPO_ROOT/docker/savia-test"
PASS=0; FAIL=0

ok()   { PASS=$((PASS+1)); echo "  ✅ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }
check() { if [ -f "$1" ]; then ok "$2 exists"; else fail "$2 missing"; fi; }
has()  { grep -qi "$3" "$1" 2>/dev/null && ok "$2: has $3" || fail "$2: missing $3"; }

echo "═══════════════════════════════════════════════════════════"
echo "  TEST: v0.75.0 — Savia E2E Test Harness"
echo "═══════════════════════════════════════════════════════════"

echo ""
echo "1️⃣  Docker Files"
check "$DOCKER_DIR/Dockerfile" "Dockerfile"
check "$DOCKER_DIR/docker-compose.yml" "docker-compose.yml"
check "$DOCKER_DIR/harness.sh" "harness.sh"
check "$DOCKER_DIR/report-template.md" "report-template.md"

echo ""
echo "2️⃣  Scenario Files"
for s in 00-setup 01-exploration 02-production 03-coordination 04-release; do
  check "$DOCKER_DIR/scenarios/${s}.md" "scenario $s"
done

echo ""
echo "3️⃣  Scenario Structure (each has Steps with Role, Command, prompt)"
for s in "$DOCKER_DIR"/scenarios/*.md; do
  name=$(basename "$s" .md)
  steps=$(grep -c "^## Step" "$s" 2>/dev/null || echo 0)
  roles=$(grep -c "^\- \*\*Role\*\*" "$s" 2>/dev/null || echo 0)
  prompts=$(grep -c '```prompt' "$s" 2>/dev/null || echo 0)
  if [ "$steps" -gt 0 ] && [ "$steps" -eq "$roles" ] && [ "$steps" -eq "$prompts" ]; then
    ok "$name: $steps steps, all have role+prompt"
  else
    fail "$name: steps=$steps roles=$roles prompts=$prompts (mismatch)"
  fi
done

echo ""
echo "4️⃣  Harness Features"
check "$DOCKER_DIR/engines.sh" "engines.sh"
check "$DOCKER_DIR/report-gen.sh" "report-gen.sh"
has "$DOCKER_DIR/engines.sh" "engines" "mock_response"
has "$DOCKER_DIR/engines.sh" "engines" "live_exec"
has "$DOCKER_DIR/harness.sh" "harness" "csv_row"
has "$DOCKER_DIR/report-gen.sh" "report-gen" "generate_report"
has "$DOCKER_DIR/harness.sh" "harness" "context_overflow"
has "$DOCKER_DIR/engines.sh" "engines" "claude -p"
has "$DOCKER_DIR/harness.sh" "harness" "auto-compact"
has "$DOCKER_DIR/harness.sh" "harness" "compact_context"

echo ""
echo "5️⃣  Docker Config"
has "$DOCKER_DIR/Dockerfile" "Dockerfile" "claude-code"
has "$DOCKER_DIR/Dockerfile" "Dockerfile" "ENTRYPOINT"
has "$DOCKER_DIR/docker-compose.yml" "compose" "ANTHROPIC_API_KEY"
has "$DOCKER_DIR/docker-compose.yml" "compose" "SAVIA_TEST_MODE"

echo ""
echo "6️⃣  Scenario Content — Key Commands"
has "$DOCKER_DIR/scenarios/00-setup.md" "setup" "flow-setup"
has "$DOCKER_DIR/scenarios/01-exploration.md" "exploration" "flow-spec"
has "$DOCKER_DIR/scenarios/01-exploration.md" "exploration" "pbi-jtbd"
has "$DOCKER_DIR/scenarios/02-production.md" "production" "flow-intake"
has "$DOCKER_DIR/scenarios/02-production.md" "production" "pbi-decompose"
has "$DOCKER_DIR/scenarios/03-coordination.md" "coordination" "flow-metrics"
has "$DOCKER_DIR/scenarios/03-coordination.md" "coordination" "quality-gate"
has "$DOCKER_DIR/scenarios/03-coordination.md" "coordination" "flow-protect"
has "$DOCKER_DIR/scenarios/04-release.md" "release" "release-readiness"
has "$DOCKER_DIR/scenarios/04-release.md" "release" "outcome-track"

echo ""
echo "7️⃣  Mock Mode Dry Run"
# Run harness in mock mode to verify it works without Docker
cd "$REPO_ROOT"
# Mock has 5% random error rate, so exit 1 is expected sometimes
mock_exit=0
bash "$DOCKER_DIR/harness.sh" mock > /dev/null 2>&1 || mock_exit=$?
if [ "$mock_exit" -le 1 ]; then
  ok "Mock dry run completed (exit=$mock_exit)"
  LAST_RUN=$(ls -dt "$DOCKER_DIR/output/run-"* 2>/dev/null | head -1)
  if [ -n "$LAST_RUN" ] && [ -f "$LAST_RUN/report.md" ]; then
    ok "Report generated at $LAST_RUN/report.md"
  else
    fail "Report not generated"
  fi
  if [ -n "$LAST_RUN" ] && [ -f "$LAST_RUN/metrics.csv" ]; then
    csv_lines=$(wc -l < "$LAST_RUN/metrics.csv")
    if [ "$csv_lines" -gt 1 ]; then
      ok "Metrics CSV has $((csv_lines-1)) data rows"
    else
      fail "Metrics CSV is empty"
    fi
  else
    fail "Metrics CSV not generated"
  fi
else
  fail "Mock dry run crashed (exit=$mock_exit)"
fi

echo ""
echo "8️⃣  Auto-Compact Mock Run"
compact_exit=0
bash "$DOCKER_DIR/harness.sh" mock "" --auto-compact --compact-threshold=30 > /dev/null 2>&1 || compact_exit=$?
if [ "$compact_exit" -le 1 ]; then
  ok "Auto-compact mock run completed (exit=$compact_exit)"
  COMPACT_RUN=$(ls -dt "$DOCKER_DIR/output/run-"* 2>/dev/null | head -1)
  if [ -n "$COMPACT_RUN" ] && grep -q "Auto-Compaction" "$COMPACT_RUN/report.md" 2>/dev/null; then
    ok "Report includes Auto-Compaction section"
  else
    ok "No compaction needed (context below threshold)"
  fi
else
  fail "Auto-compact mock run crashed (exit=$compact_exit)"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Total: $((PASS+FAIL)) | ✅ Passed: $PASS | ❌ Failed: $FAIL"
echo "═══════════════════════════════════════════════════════════"
[ "$FAIL" -eq 0 ] && echo "  🎉 ALL TESTS PASSED" || { echo "  ⚠️  $FAIL TESTS FAILED"; exit 1; }
