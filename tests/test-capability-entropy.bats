#!/usr/bin/env bats
# Ref: SE-380 — capability-entropy.py (ratchet v0, calibración v1)
# Spec: docs/specs/SE-380-capability-lifecycle-usage-budget.spec.md
# RN-03: el budget nunca sube. Cada test usa un --root temporal con su propio
# registry y baseline; nunca toca tests/baselines/ del repo.

SCRIPT="scripts/capability-entropy.py"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  R="$(mktemp -d)"
  mkdir -p "$R/.scm" "$R/tests/baselines" "$R/tests/bats"
}

teardown() {
  rm -rf "$R" 2>/dev/null || true
}

# registry with N active scripts (no overlaps, no deps)
registry() {
  python3 -c "
import json, sys
n = int(sys.argv[1])
caps = [{'id': f'script:scripts/s{i}', 'kind': 'script', 'source': f'scripts/s{i}.sh'} for i in range(n)]
caps.append({'id': 'agent:.opencode/agents/a', 'kind': 'agent', 'source': '.opencode/agents/a.md', 'risk_level': 'L3'})
json.dump({'capabilities': caps}, open(sys.argv[2], 'w'))
" "$1" "$R/.scm/registry.json"
}

baseline() {
  printf '{"entropy": %s, "components": {}, "entropy_version": 0}\n' "$1" > "$R/tests/baselines/capability-entropy.json"
}

@test "first run freezes a baseline when none exists" {
  registry 10
  run python3 "$SCRIPT" --root "$R"
  [ "$status" -eq 0 ]
  [[ "$output" == *"congelado"* ]]
  python3 -c "import json; assert json.load(open('$R/tests/baselines/capability-entropy.json'))['entropy'] == 11"
}

@test "--check passes at the boundary (entropy == baseline)" {
  registry 10; baseline 11
  run python3 "$SCRIPT" --root "$R" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}

@test "--check fails when entropy grows over baseline" {
  registry 12; baseline 11
  run python3 "$SCRIPT" --root "$R" --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL: entropía 13 > baseline 11"* ]]
}

@test "--v1 never raises the v0 baseline (RN-03)" {
  registry 20; baseline 11
  run python3 "$SCRIPT" --root "$R" --v1
  [ "$status" -eq 0 ]
  python3 -c "
import json
b = json.load(open('$R/tests/baselines/capability-entropy.json'))
assert b['entropy'] == 11, b
assert b['entropy_v1'] >= 21, b
"
  run python3 "$SCRIPT" --root "$R" --check
  [ "$status" -eq 1 ]
}

@test "--v1 counts untested high-risk agents in entropy_v1 only" {
  registry 5; baseline 6
  python3 "$SCRIPT" --root "$R" --v1 >/dev/null
  python3 -c "
import json
b = json.load(open('$R/tests/baselines/capability-entropy.json'))
assert b['components']['untested_high_risk'] == 1, b
assert b['components']['unowned_agents'] == 1, b
assert b['entropy_v1'] == 6 + 1 + 1, b
"
}

@test "plain run with a baseline reports and does not rewrite it" {
  registry 20; baseline 11
  before=$(md5sum < "$R/tests/baselines/capability-entropy.json")
  run python3 "$SCRIPT" --root "$R"
  [ "$status" -eq 0 ]
  [ "$(md5sum < "$R/tests/baselines/capability-entropy.json")" = "$before" ]
}

@test "missing registry fails with error (exit != 0)" {
  run python3 "$SCRIPT" --root "$R" --check
  [ "$status" -ne 0 ]
}

@test "--check without baseline fails (no silent pass)" {
  registry 3
  run python3 "$SCRIPT" --root "$R" --check
  [ "$status" -ne 0 ]
}

@test "invalid flag rejected (exit 2)" {
  run python3 "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "empty registry → zero capabilities, entropy is only sync surfaces" {
  python3 -c "import json; json.dump({'capabilities': []}, open('$R/.scm/registry.json', 'w'))"
  baseline 0
  run python3 "$SCRIPT" --root "$R" --check
  [ "$status" -eq 0 ]
}

@test "repo baseline file is untouched by the suite" {
  git diff --quiet -- tests/baselines/capability-entropy.json
}

@test "nonexistent --root fails instead of reporting zero entropy" {
  run python3 "$SCRIPT" --root "$R/no-existe" --check
  [ "$status" -ne 0 ]
  [[ "$output" != *"PASS"* ]]
}
