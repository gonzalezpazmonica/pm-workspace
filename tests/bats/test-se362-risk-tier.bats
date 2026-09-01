#!/usr/bin/env bats
# test-se362-risk-tier.bats — BATS tests for SE-362 risk-tiering
# Ref: SE-362 — gradación de riesgo para auto-merge

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  TIER="$REPO_ROOT/scripts/risk-tier.py"
  export REPO_ROOT TIER
}

@test "docs-only → tier 1, no requiere humano" {
  run python3 "$TIER" --diff "README.md docs/guide.md" --json
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['tier'] == 1, f'tier={d[\"tier\"]}'
assert d['requires_human'] is False
"
}

@test "scripts con push/merge → tier 3, requiere humano" {
  run python3 "$TIER" --diff "scripts/push-pr.sh" --json
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['tier'] == 3, f'tier={d[\"tier\"]}'
assert d['requires_human'] is True
"
}

@test "infra → tier 4" {
  run python3 "$TIER" --diff "infra/main.tf" --json
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['tier'] == 4, f'tier={d[\"tier\"]}'
"
}

@test "código normal → tier 2" {
  run python3 "$TIER" --diff "src/service.py tests/test_service.py" --json
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['tier'] == 2, f'tier={d[\"tier\"]}'
"
}

@test "path desconocido → fail-closed tier 3" {
  run python3 "$TIER" --diff "weird/file.bin" --json
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['tier'] == 3, f'fail-closed: tier={d[\"tier\"]}'
"
}
