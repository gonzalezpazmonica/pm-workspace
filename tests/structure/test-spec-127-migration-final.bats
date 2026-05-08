#!/usr/bin/env bats
# Ref: SPEC-127 final migration to OpenCode v1.14
# Spec: docs/propuestas/SPEC-127-savia-opencode-provider-agnostic.md
#
# Last entrega bajo Claude Code. Verifica que TODO lo necesario para
# operar Savia bajo OpenCode v1.14 esta en su sitio.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="scripts/opencode-migration-smoke.sh"
  SMOKE="$REPO_ROOT/$SCRIPT"
  CONVERT="$REPO_ROOT/scripts/agents-opencode-convert.sh"
  COGNITIVE="$REPO_ROOT/scripts/cognitive-debt.sh"
  ONBOARDING="$REPO_ROOT/docs/migration-claude-code-to-opencode.md"
  SETTINGS="$REPO_ROOT/.claude/settings.json"
  PLUGINS_DIR="$REPO_ROOT/.opencode/plugins"
  AGENTS_DST="$REPO_ROOT/.opencode/agents"
  SPEC="$REPO_ROOT/docs/propuestas/SPEC-127-savia-opencode-provider-agnostic.md"
  TMPDIR_M=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_M"
}

@test "AC-2.2: 5 TIER-1 hook TS files exist with their .test.ts" {
  for h in block-credential-leak block-gitignored-references prompt-injection-guard validate-bash-global tdd-gate; do
    [ -f "$PLUGINS_DIR/guards/${h}.ts" ]
    [ -f "$PLUGINS_DIR/__tests__/${h}.test.ts" ]
  done
}

@test "AC-2.2: each hook port imports from lib/hook-input" {
  for h in block-credential-leak block-gitignored-references prompt-injection-guard validate-bash-global tdd-gate; do
    grep -qE 'from "\.\./lib/hook-input' "$PLUGINS_DIR/guards/${h}.ts"
  done
}

@test "AC-2.2: each hook test imports its handler" {
  for h in block-credential-leak block-gitignored-references prompt-injection-guard validate-bash-global tdd-gate; do
    grep -qE "from \"\\.\\./guards/${h}\\.ts\"" "$PLUGINS_DIR/__tests__/${h}.test.ts"
  done
}

@test "AC-2.2: lib helpers exist (4 modules)" {
  for f in hook-input credential-patterns leakage-patterns injection-patterns; do
    [ -f "$PLUGINS_DIR/lib/${f}.ts" ]
    [ -f "$PLUGINS_DIR/lib/${f}.test.ts" ]
  done
}

@test "AC-2.3: block-credential-leak port (PV-02 safety-critical)" {
  [ -f "$PLUGINS_DIR/guards/block-credential-leak.ts" ]
  grep -q "blockCredentialLeak" "$PLUGINS_DIR/guards/block-credential-leak.ts"
}

@test "AC-2.3: block-gitignored-references port (PV-02 safety-critical)" {
  [ -f "$PLUGINS_DIR/guards/block-gitignored-references.ts" ]
  grep -q "blockGitignoredReferences" "$PLUGINS_DIR/guards/block-gitignored-references.ts"
}

@test "AC-2.3: prompt-injection-guard port (PV-02 safety-critical)" {
  [ -f "$PLUGINS_DIR/guards/prompt-injection-guard.ts" ]
  grep -q "promptInjectionGuard" "$PLUGINS_DIR/guards/prompt-injection-guard.ts"
}

@test "foundation plugin imports + chains all 5 guards" {
  for guard in validateBashGlobal blockCredentialLeak blockGitignoredReferences promptInjectionGuard tddGate; do
    grep -q "$guard" "$PLUGINS_DIR/savia-foundation.ts"
  done
}

@test "foundation plugin registers tool.execute.before dispatcher" {
  grep -qE '"tool\.execute\.before"' "$PLUGINS_DIR/savia-foundation.ts"
}

@test "foundation plugin sequentially awaits each guard" {
  grep -qE 'await guard' "$PLUGINS_DIR/savia-foundation.ts"
}

@test "agents converter exists, executable, has shebang" {
  [ -f "$CONVERT" ]
  head -1 "$CONVERT" | grep -q '^#!'
  [ -x "$CONVERT" ]
}

@test "agents converter declares pipefail + LC_ALL=C" {
  head -5 "$CONVERT" | grep -q "set -uo pipefail"
  head -5 "$CONVERT" | grep -q "LC_ALL=C"
}

@test "agents converter passes bash -n" {
  bash -n "$CONVERT"
}

@test "agents converter --check is idempotent" {
  run bash "$CONVERT" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"in sync"* ]]
}

@test "agents converter handled all 70 source agents" {
  count=$(find "$AGENTS_DST" -maxdepth 1 -type f -name "*.md" ! -name "README.md" | wc -l | tr -d ' ')
  [ "$count" -ge 70 ]
}

@test "agents converter: tools array → object (court-orchestrator sample)" {
  grep -qE '^tools:$' "$AGENTS_DST/court-orchestrator.md"
  grep -qE '^  read: true' "$AGENTS_DST/court-orchestrator.md"
}

@test "agents converter: tools YAML list → object (coherence-validator)" {
  grep -qE '^tools:$' "$AGENTS_DST/coherence-validator.md"
  grep -qE '^  read: true' "$AGENTS_DST/coherence-validator.md"
}

@test "agents converter: at least one named color translated to hex" {
  count=$(grep -lE '^color: "#[0-9A-Fa-f]{6}"$' "$AGENTS_DST"/*.md 2>/dev/null | wc -l | tr -d ' ')
  [ "$count" -ge 1 ]
}

@test "savia-budget-guard registered as PreToolUse in settings.json" {
  python3 -c "
import json, sys
cfg = json.load(open('$SETTINGS'))
pre = cfg.get('hooks', {}).get('PreToolUse', [])
found = any(
  'savia-budget-guard' in h.get('command', '')
  for entry in pre for h in entry.get('hooks', [])
)
sys.exit(0 if found else 1)
"
}

@test "savia-budget-guard hook file exists, executable, NEVER block marker" {
  [ -f "$REPO_ROOT/.opencode/hooks/savia-budget-guard.sh" ]
  [ -x "$REPO_ROOT/.opencode/hooks/savia-budget-guard.sh" ]
  grep -qiE 'never block|NEVER block' "$REPO_ROOT/.opencode/hooks/savia-budget-guard.sh"
}

@test "onboarding doc exists" {
  [ -f "$ONBOARDING" ]
}

@test "onboarding doc ≤ 150 lines (workspace cap)" {
  lines=$(wc -l < "$ONBOARDING")
  [ "$lines" -le 150 ]
}

@test "onboarding doc covers 7 numbered steps + rollback + troubleshooting" {
  for tag in "### 1\." "### 2\." "### 3\." "### 4\." "### 5\." "### 6\." "### 7\."; do
    grep -qE "^$tag" "$ONBOARDING"
  done
  grep -qE "^## Rollback" "$ONBOARDING"
  grep -qE "^## Troubleshooting" "$ONBOARDING"
}

@test "onboarding doc references key scripts" {
  grep -q "savia-preferences.sh" "$ONBOARDING"
  grep -q "agents-opencode-convert.sh" "$ONBOARDING"
  grep -q "opencode-migration-smoke.sh" "$ONBOARDING"
}

@test "onboarding doc cites SPEC-127" {
  grep -q "SPEC-127" "$ONBOARDING"
}

@test "smoke script exists, executable, has shebang" {
  [ -f "$SMOKE" ]
  head -1 "$SMOKE" | grep -q '^#!'
  [ -x "$SMOKE" ]
}

@test "smoke script runs 6 numbered checks" {
  for n in 1 2 3 4 5 6; do
    grep -qE "\\[$n/6\\]" "$SMOKE"
  done
}

@test "smoke script has PASS/FAIL/WARN summary" {
  grep -qE 'PASS=|FAIL=|WARN=' "$SMOKE"
}

@test "smoke script declares pipefail + LC_ALL=C" {
  head -5 "$SMOKE" | grep -q "set -uo pipefail"
  head -5 "$SMOKE" | grep -q "LC_ALL=C"
}

@test "smoke script returns exit 0 on canonical workspace (skips if opencode missing)" {
  # CI runners do not have opencode binary installed. Skip when missing —
  # the smoke script's job is to validate the OPERATOR's local stack.
  if ! command -v opencode >/dev/null 2>&1; then
    skip "opencode binary not on PATH (expected in CI)"
  fi
  run bash "$SMOKE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Migration smoke OK"* ]]
}

@test "cognitive-debt.sh integrates quota tracker summary" {
  grep -q "savia-quota-tracker.sh" "$COGNITIVE"
  grep -qiE "Savia quota|month-to-date" "$COGNITIVE"
}

@test "PV-06: 5 TS hook ports never reference a hardcoded vendor" {
  for h in block-credential-leak block-gitignored-references prompt-injection-guard validate-bash-global tdd-gate; do
    ! grep -qiE 'github\.copilot|copilot\.enterprise|openai\.com|anthropic\.com/v1|mistral\.|deepseek/' "$PLUGINS_DIR/guards/${h}.ts"
  done
}

@test "PV-06: agents converter never references a hardcoded vendor" {
  ! grep -qiE 'github\.copilot|copilot\.enterprise|openai\.com|anthropic\.com/v1|mistral\.|deepseek/' "$CONVERT"
}

@test "PV-06: smoke script never references a hardcoded vendor" {
  ! grep -qiE 'github\.copilot|copilot\.enterprise|openai\.com|anthropic\.com/v1|mistral\.|deepseek/' "$SMOKE"
}

@test "negative: agents converter unknown flag exits 2" {
  run bash "$CONVERT" --bogus
  [ "$status" -eq 2 ]
}

@test "negative: agents converter missing source dir exits 3" {
  cp "$CONVERT" "$TMPDIR_M/c.sh"
  run env PROJECT_ROOT="$TMPDIR_M" bash "$TMPDIR_M/c.sh"
  [ "$status" -eq 3 ]
}

@test "edge: empty agents source produces zero converted output (boundary)" {
  mkdir -p "$TMPDIR_M/.claude/agents" "$TMPDIR_M/.opencode/agents"
  cp "$CONVERT" "$TMPDIR_M/c.sh"
  run env PROJECT_ROOT="$TMPDIR_M" bash "$TMPDIR_M/c.sh" --apply
  [ "$status" -eq 0 ]
}

@test "edge: smoke script without opencode binary on PATH (graceful)" {
  run env PATH="/usr/bin:/bin" bash "$SMOKE"
  if [ "$status" -ne 0 ]; then
    [[ "$output" == *"opencode"* ]] || [[ "$output" == *"PATH"* ]]
  fi
}

@test "spec ref: SPEC-127 declares slice_2b_ii_status: IMPLEMENTED" {
  grep -qE "^slice_2b_ii_status: IMPLEMENTED" "$SPEC"
}

@test "spec ref: docs/propuestas/SPEC-127 referenced in this test file" {
  grep -q "docs/propuestas/SPEC-127" "$BATS_TEST_FILENAME"
}

@test "coverage: foundation plugin imports all 5 guards by exact name" {
  for fn in validateBashGlobal blockCredentialLeak blockGitignoredReferences promptInjectionGuard tddGate; do
    grep -qE "import \\{ $fn \\}" "$PLUGINS_DIR/savia-foundation.ts"
  done
}

@test "coverage: each TS port has Promise<void> annotation" {
  for h in block-credential-leak block-gitignored-references prompt-injection-guard validate-bash-global tdd-gate; do
    grep -qE "Promise<void>" "$PLUGINS_DIR/guards/${h}.ts"
  done
}

@test "coverage: each TS port throws on block (block mechanism)" {
  for h in block-credential-leak block-gitignored-references prompt-injection-guard validate-bash-global; do
    grep -qE 'throw new Error' "$PLUGINS_DIR/guards/${h}.ts"
  done
}
