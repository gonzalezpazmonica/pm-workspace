#!/usr/bin/env bats
# Tests for Era 100.1 — Lazy Loading of Rules Domain
# Validates rule-usage-analyzer and rule-manifest.json

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  ROOT="$PWD"
}

# ── Analyzer script ──

@test "rule-usage-analyzer.sh exists and is executable" {
  [ -x "$ROOT/scripts/rule-usage-analyzer.sh" ]
}

@test "analyzer summary mode outputs rule counts" {
  run bash -c "echo '' | $ROOT/scripts/rule-usage-analyzer.sh --summary"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Rules:.*total"
  echo "$output" | grep -q "tier1"
  echo "$output" | grep -q "dormant"
}

@test "analyzer full mode outputs valid JSON" {
  run bash -c "echo '' | $ROOT/scripts/rule-usage-analyzer.sh"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)"
}

@test "analyzer detects at least 10 tier1 rules" {
  run bash -c "echo '' | $ROOT/scripts/rule-usage-analyzer.sh"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['tier1_count'])")
  [ "$count" -ge 10 ]
}

# ── Manifest file ──

@test "rule-manifest.json exists" {
  [ -f "$ROOT/.claude/rules/domain/rule-manifest.json" ]
}

@test "rule-manifest.json is valid JSON with required fields" {
  run python3 -c "
import json
d = json.load(open('$ROOT/.claude/rules/domain/rule-manifest.json'))
assert 'total' in d, 'missing total'
assert 'tier1_count' in d, 'missing tier1_count'
assert 'rules' in d, 'missing rules'
assert d['total'] > 0, 'no rules found'
print('OK')
"
  [ "$status" -eq 0 ]
  [ "$output" = "OK" ]
}

@test "manifest tier counts add up to total" {
  run python3 -c "
import json
d = json.load(open('$ROOT/.claude/rules/domain/rule-manifest.json'))
total = d['tier1_count'] + d['tier2_count'] + d['dormant_count']
assert total == d['total'], f'{total} != {d[\"total\"]}'
print('OK')
"
  [ "$status" -eq 0 ]
  [ "$output" = "OK" ]
}

@test "manifest dormant rules have no consumers" {
  run python3 -c "
import json
d = json.load(open('$ROOT/.claude/rules/domain/rule-manifest.json'))
for name, info in d['rules'].items():
    if info['tier'] == 'dormant' and info['consumers']:
        print(f'FAIL: {name} is dormant but has consumers: {info[\"consumers\"]}')
        exit(1)
print('OK')
"
  [ "$status" -eq 0 ]
  [ "$output" = "OK" ]
}
