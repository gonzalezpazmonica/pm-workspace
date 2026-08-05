#!/usr/bin/env bats
# test-se-305-dynamic-bats.bats — Tests for SE-305: Dynamic BATS Test Selection

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
DEPS_SCRIPT="$REPO_ROOT/scripts/ci-bats-deps.sh"
SELECT_SCRIPT="$REPO_ROOT/scripts/ci-select-bats.sh"
DEPS_FILE="$REPO_ROOT/tests/bats/.deps.json"

setup() {
  cd "$REPO_ROOT"
}

@test "SE-305: deps generator creates valid JSON" {
  run bash "$DEPS_SCRIPT" --generate
  [ "$status" -eq 0 ]
  [ -f "$DEPS_FILE" ]
  python3 -c "import json; d=json.load(open('$DEPS_FILE')); assert 'mappings' in d; assert 'core_tests' in d; assert 'dir_rules' in d"
}

@test "SE-305: deps generator includes core_tests" {
  bash "$DEPS_SCRIPT" --generate
  core=$(python3 -c "import json; print(len(json.load(open('$DEPS_FILE'))['core_tests']))")
  [ "$core" -ge 10 ]
}

@test "SE-305: deps check detects missing file" {
  rm -f "$DEPS_FILE"
  run bash "$DEPS_SCRIPT" --check
  [ "$status" -ne 0 ]
}

@test "SE-305: deps check passes when fresh" {
  bash "$DEPS_SCRIPT" --generate
  run bash "$DEPS_SCRIPT" --check
  [ "$status" -eq 0 ]
}

@test "SE-305: selector produces output for current changes" {
  bash "$DEPS_SCRIPT" --generate
  run bash "$SELECT_SCRIPT" --base HEAD~1
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
  [ -n "${lines[0]}" ]
}

@test "SE-305: selector returns FULL when too many changes" {
  bash "$DEPS_SCRIPT" --generate
  SAVIA_BATS_FULL_THRESHOLD_PCT=1 run bash "$SELECT_SCRIPT" --base HEAD~5
  [ "$status" -eq 1 ]
  [[ "${lines[0]}" == "FULL" ]]
}

@test "SE-305: selector exit 2 when deps file missing" {
  rm -f "$DEPS_FILE"
  run bash "$SELECT_SCRIPT" --base HEAD~1
  [ "$status" -ne 0 ]
}

@test "SE-305: deps generator uses dir rules" {
  bash "$DEPS_SCRIPT" --generate
  rules=$(python3 -c "import json; d=json.load(open('$DEPS_FILE')); print(len(d.get('dir_rules', {})))")
  [ "$rules" -ge 1 ]
}

@test "SE-305: core tests include attention anchor" {
  bash "$DEPS_SCRIPT" --generate
  has_anchor=$(python3 -c "import json; d=json.load(open('$DEPS_FILE')); print('test-se-080-attention-anchor.bats' in d.get('core_tests', []))")
  [ "$has_anchor" = "True" ]
}

@test "SE-305: mappings reference real bats files" {
  bash "$DEPS_SCRIPT" --generate
  python3 -c "
import json, os
d = json.load(open('$DEPS_FILE'))
bats_dir = '$REPO_ROOT/tests/bats'
for tests in d.get('mappings', {}).values():
    for t in tests:
        assert os.path.exists(os.path.join(bats_dir, t)), f'missing: {t}'
print('all ok')
"
}
