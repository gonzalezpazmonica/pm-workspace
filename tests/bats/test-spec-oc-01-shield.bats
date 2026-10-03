#!/usr/bin/env bats
# test-spec-oc-01-shield.bats — SPEC-OC-01 Savia Shield OpenCode Adaptation
#
# Tests: savia-shield-check.sh and supporting components.
# Run: bats tests/bats/test-spec-oc-01-shield.bats

WORKSPACE="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$WORKSPACE/scripts/savia-shield-check.sh"
DOC="$WORKSPACE/docs/rules/domain/savia-shield-opencode.md"

# ── Test 1: Script exists and is executable ───────────────────────────────────
@test "savia-shield-check.sh exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

# ── Test 2: --json flag produces valid JSON ───────────────────────────────────
@test "savia-shield-check.sh --json produces valid JSON" {
  run bash "$SCRIPT" --json
  # exit 0 (active) or 1 (partial) are both acceptable — just not 2
  [ "$status" -ne 2 ]
  # Output must be parseable JSON
  echo "$output" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null
}

# ── Test 3: shield_status field is present in JSON output ────────────────────
@test "JSON output contains shield_status field" {
  run bash "$SCRIPT" --json
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert 'shield_status' in d, 'shield_status missing'
assert d['shield_status'] in ('active', 'partial', 'inactive'), f'bad value: {d[\"shield_status\"]}'
"
}

# ── Test 4: components and missing arrays are present ────────────────────────
@test "JSON output contains components and missing arrays" {
  run bash "$SCRIPT" --json
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert 'components' in d, 'components missing'
assert 'missing' in d, 'missing missing'
assert isinstance(d['components'], list), 'components must be list'
assert isinstance(d['missing'], list), 'missing must be list'
"
}

# ── Test 5: context-sanitize-input.sh is referenced in check ────────────────
@test "context-sanitize-input.sh component appears in output when present" {
  # The hook exists (checked in test setup), so it must appear in components
  [ -f "$WORKSPACE/.opencode/hooks/context-sanitize-input.sh" ]
  run bash "$SCRIPT" --json
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert 'context-sanitize-input' in d['components'], \
  'context-sanitize-input not in components: ' + str(d['components'])
"
}

# ── Test 6: data-sovereignty-gate guard is checked ───────────────────────────
@test "data-sovereignty-gate guard detected as component" {
  [ -f "$WORKSPACE/.opencode/plugins/guards/data-sovereignty-gate.ts" ]
  run bash "$SCRIPT" --json
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert 'data-sovereignty-gate' in d['components'], \
  'data-sovereignty-gate not in components: ' + str(d['components'])
"
}

# ── Test 7: savia-foundation-wired is checked (dataSovereigntyGate wired) ────
@test "savia-foundation-wired component detected" {
  run bash "$SCRIPT" --json
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert 'savia-foundation-wired' in d['components'], \
  'savia-foundation-wired not in components: ' + str(d['components'])
"
}

# ── Test 8: shield_status is active when all components present ───────────────
@test "shield_status is active when all components are present" {
  run bash "$SCRIPT" --json
  # With doc present, should be active
  [ -f "$DOC" ]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['shield_status'] == 'active', \
  'Expected active, got: ' + d['shield_status'] + ' | missing: ' + str(d['missing'])
"
}

# ── Test 9: savia-shield-opencode.md doc exists with required sections ────────
@test "savia-shield-opencode.md exists with required sections" {
  [ -f "$DOC" ]
  grep -q "shield_status" "$DOC"
  grep -q "Verificar que está activo" "$DOC"
  grep -q "Qué datos protege" "$DOC"
}

# ── Test 10: doc contains OpenCode vs Claude Code comparison table ────────────
@test "savia-shield-opencode.md contains activation and comparison info" {
  [ -f "$DOC" ]
  grep -q "Activar Savia Shield" "$DOC"
  grep -q "Claude Code" "$DOC"
  grep -q "OpenCode" "$DOC"
}
