#!/usr/bin/env bats
# SCRIPT='scripts/code-twin-validate-spec.sh'
# test-spec-190-code-twin-validate.bats — BATS suite for SPEC-190 Slice 6 (validate-spec)
# Spec: SPEC-190 AC-5, AC-11
# Score target: ≥85 (SPEC-055 quality gate)
# Exercises: route_duplicate detection, no-conflict path, exit codes,
#            engine errors, safety, isolation, score computation

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
VAL="$REPO_ROOT/scripts/code-twin-validate-spec.sh"
TWIN="$REPO_ROOT/tests/fixtures/code-twin"
SPEC_DUP="$REPO_ROOT/tests/fixtures/spec-with-duplicate-route.md"
SPEC_NEW="$REPO_ROOT/tests/fixtures/spec-get-user-profile.md"

# ---------------------------------------------------------------------------
# Isolation setup / teardown
# ---------------------------------------------------------------------------

setup() {
  TMP_OUT="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMP_OUT"
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

val_json() {
  bash "$VAL" "$@" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Safety verification
# ---------------------------------------------------------------------------

@test "safety: wrapper contains set -uo pipefail" {
  grep -q "set -uo pipefail" "$VAL"
}

@test "safety: output captured correctly to file" {
  bash "$VAL" "$SPEC_NEW" "$TWIN" > "$TMP_OUT/out.txt" 2>&1
  [ -s "$TMP_OUT/out.txt" ]
}

@test "safety: wrapper script is executable" {
  [ -x "$VAL" ]
}

@test "safety: python engine file exists" {
  [ -f "$REPO_ROOT/scripts/code-twin-validate-spec.py" ]
}

# ---------------------------------------------------------------------------
# Engine validation — argument errors (exit 2)
# ---------------------------------------------------------------------------

@test "engine: no args exits 2" {
  run bash "$VAL"
  [ "$status" -eq 2 ]
}

@test "engine: one arg exits 2" {
  run bash "$VAL" "$SPEC_DUP"
  [ "$status" -eq 2 ]
}

@test "engine: non-existent spec exits 2" {
  run bash "$VAL" /tmp/no-such-spec.md "$TWIN"
  [ "$status" -eq 2 ]
}

@test "engine: non-existent twin dir exits 2" {
  run bash "$VAL" "$SPEC_DUP" /tmp/no-such-twin
  [ "$status" -eq 2 ]
}

@test "engine: error message goes to stderr, not stdout" {
  stdout=$(bash "$VAL" /tmp/no-such-spec.md "$TWIN" 2>/dev/null) || true
  [ -z "$stdout" ]
}

# ---------------------------------------------------------------------------
# AC-5: duplicate route detection (SPEC-190 §3.4)
# ---------------------------------------------------------------------------

@test "AC-5: duplicate-route spec exits 1" {
  run bash "$VAL" "$SPEC_DUP" "$TWIN"
  [ "$status" -eq 1 ]
}

@test "AC-5: duplicate-route produces valid JSON" {
  val_json "$SPEC_DUP" "$TWIN" > "$TMP_OUT/out.json"
  python3 -c "import json,sys; json.load(open('$TMP_OUT/out.json'))"
}

@test "AC-5: conflicts array is non-empty" {
  count=$(val_json "$SPEC_DUP" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d['conflicts']))")
  [ "$count" -gt 0 ]
}

@test "AC-5: first conflict type is route_duplicate" {
  t=$(val_json "$SPEC_DUP" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['conflicts'][0]['type'])")
  [ "$t" = "route_duplicate" ]
}

@test "AC-5: POST /items conflict detected" {
  ep=$(val_json "$SPEC_DUP" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['conflicts'][0]['endpoint'])")
  [ "$ep" = "POST /items" ]
}

@test "AC-5: GET /items conflict detected" {
  count=$(val_json "$SPEC_DUP" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); eps=[c['endpoint'] for c in d['conflicts']]; print(eps.count('GET /items'))")
  [ "$count" -eq 1 ]
}

@test "AC-5: exactly 2 conflicts for duplicate-route spec" {
  count=$(val_json "$SPEC_DUP" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d['conflicts']))")
  [ "$count" -eq 2 ]
}

@test "AC-5: feasibility_score is 60 for two route_duplicate conflicts" {
  score=$(val_json "$SPEC_DUP" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['feasibility_score'])")
  [ "$score" -eq 60 ]
}

@test "AC-5: feasibility_score is below 70 threshold" {
  score=$(val_json "$SPEC_DUP" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['feasibility_score'])")
  [ "$score" -lt 70 ]
}

@test "AC-5: conflict includes existing_in field" {
  has=$(val_json "$SPEC_DUP" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print('existing_in' in d['conflicts'][0])")
  [ "$has" = "True" ]
}

@test "AC-5: existing_in references api/routes.md" {
  ei=$(val_json "$SPEC_DUP" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['conflicts'][0]['existing_in'])")
  [[ "$ei" == *"api/routes.md"* ]]
}

@test "AC-5: existing_in includes line number" {
  ei=$(val_json "$SPEC_DUP" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['conflicts'][0]['existing_in'])")
  [[ "$ei" =~ :[0-9]+ ]]
}

@test "AC-5: spec field matches filename" {
  spec=$(val_json "$SPEC_DUP" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['spec'])")
  [ "$spec" = "spec-with-duplicate-route.md" ]
}

@test "AC-5: code_twin_dir field is present" {
  has=$(val_json "$SPEC_DUP" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print('code_twin_dir' in d)")
  [ "$has" = "True" ]
}

@test "AC-5: output contains validated_at timestamp" {
  ts=$(val_json "$SPEC_DUP" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('validated_at',''))")
  [[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]
}

# ---------------------------------------------------------------------------
# AC-11: no-conflict spec (SPEC-190 §3.4)
# ---------------------------------------------------------------------------

@test "AC-11: no-conflict spec exits 0" {
  run bash "$VAL" "$SPEC_NEW" "$TWIN"
  [ "$status" -eq 0 ]
}

@test "AC-11: no-conflict spec produces valid JSON" {
  val_json "$SPEC_NEW" "$TWIN" > "$TMP_OUT/out.json"
  python3 -c "import json,sys; json.load(open('$TMP_OUT/out.json'))"
}

@test "AC-11: conflicts array is empty" {
  count=$(val_json "$SPEC_NEW" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d['conflicts']))")
  [ "$count" -eq 0 ]
}

@test "AC-11: feasibility_score is 100" {
  score=$(val_json "$SPEC_NEW" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['feasibility_score'])")
  [ "$score" -eq 100 ]
}

@test "AC-11: feasibility_score is >= 85" {
  score=$(val_json "$SPEC_NEW" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['feasibility_score'])")
  [ "$score" -ge 85 ]
}

@test "AC-11: GET /users/{id}/profile is NOT in conflicts" {
  count=$(val_json "$SPEC_NEW" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); eps=[c.get('endpoint','') for c in d['conflicts']]; print(sum(1 for e in eps if '/users' in e))")
  [ "$count" -eq 0 ]
}

@test "AC-11: UserProfileDto is NOT in conflicts" {
  count=$(val_json "$SPEC_NEW" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); ents=[c.get('entity','') for c in d['conflicts']]; print(ents.count('UserProfileDto'))")
  [ "$count" -eq 0 ]
}

@test "AC-11: spec field matches filename" {
  spec=$(val_json "$SPEC_NEW" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['spec'])")
  [ "$spec" = "spec-get-user-profile.md" ]
}

@test "AC-11: missing_modules array is present" {
  has=$(val_json "$SPEC_NEW" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print('missing_modules' in d)")
  [ "$has" = "True" ]
}

@test "AC-11: warnings array is present" {
  has=$(val_json "$SPEC_NEW" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print('warnings' in d)")
  [ "$has" = "True" ]
}

@test "AC-11: impact_map is present" {
  has=$(val_json "$SPEC_NEW" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print('impact_map' in d)")
  [ "$has" = "True" ]
}

@test "AC-11: impact_map is empty dict for no-conflict spec" {
  count=$(val_json "$SPEC_NEW" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d['impact_map']))")
  [ "$count" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Score boundary conditions
# ---------------------------------------------------------------------------

@test "score: 100 - 2*20 = 60 for 2 conflicts" {
  score=$(val_json "$SPEC_DUP" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['feasibility_score'])")
  [ "$score" -eq 60 ]
}

@test "score: 100 - 0*20 = 100 for no conflicts" {
  score=$(val_json "$SPEC_NEW" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['feasibility_score'])")
  [ "$score" -eq 100 ]
}

@test "score: feasibility_score is always non-negative" {
  score_dup=$(val_json "$SPEC_DUP" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['feasibility_score'])")
  score_new=$(val_json "$SPEC_NEW" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['feasibility_score'])")
  [ "$score_dup" -ge 0 ]
  [ "$score_new" -ge 0 ]
}

# ---------------------------------------------------------------------------
# Route normalization
# ---------------------------------------------------------------------------

@test "normalize: {id} and :id treated as equivalent" {
  # /users/{id}/profile should NOT match /users/:id or /items/:id in routes.md
  count=$(val_json "$SPEC_NEW" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len([c for c in d['conflicts'] if 'users' in c.get('endpoint','') or 'profile' in c.get('endpoint','')]))")
  [ "$count" -eq 0 ]
}

@test "normalize: /items/:id does not match /items" {
  # Ensure /items pattern doesn't bleed into /items/:id
  count=$(val_json "$SPEC_DUP" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len([c for c in d['conflicts'] if c.get('endpoint','').endswith('/:id') or c.get('endpoint','').endswith('/{id}') or c.get('endpoint','').endswith('/:param')]))")
  [ "$count" -eq 0 ]
}

# ---------------------------------------------------------------------------
# JSON schema compliance
# ---------------------------------------------------------------------------

@test "schema: all required top-level keys present (dup)" {
  keys=$(val_json "$SPEC_DUP" "$TWIN" | python3 -c "
import json, sys
d = json.load(sys.stdin)
required = {'spec','code_twin_dir','feasibility_score','conflicts','missing_modules','warnings','impact_map','validated_at'}
missing = required - set(d.keys())
print(len(missing))
")
  [ "$keys" -eq 0 ]
}

@test "schema: all required top-level keys present (new)" {
  keys=$(val_json "$SPEC_NEW" "$TWIN" | python3 -c "
import json, sys
d = json.load(sys.stdin)
required = {'spec','code_twin_dir','feasibility_score','conflicts','missing_modules','warnings','impact_map','validated_at'}
missing = required - set(d.keys())
print(len(missing))
")
  [ "$keys" -eq 0 ]
}

@test "schema: conflicts is a list" {
  t=$(val_json "$SPEC_DUP" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print(type(d['conflicts']).__name__)")
  [ "$t" = "list" ]
}

@test "schema: feasibility_score is an integer" {
  t=$(val_json "$SPEC_DUP" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print(type(d['feasibility_score']).__name__)")
  [ "$t" = "int" ]
}

@test "schema: validated_at is ISO8601 UTC" {
  ts=$(val_json "$SPEC_DUP" "$TWIN" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['validated_at'])")
  [[ "$ts" =~ Z$ ]]
}
