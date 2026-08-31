#!/usr/bin/env bats
# test-se359-review-policy.bats — BATS tests for SE-359 REVIEW.md policy
# Ref: SE-359 — política canónica de review con vocab cerrado y cap de nits

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  PARSE="$REPO_ROOT/scripts/review-policy-parse.py"
  REVIEW="$REPO_ROOT/REVIEW.md"
  export REPO_ROOT PARSE REVIEW
}

@test "REVIEW.md existe en la raíz" {
  [[ -f "$REVIEW" ]]
}

@test "parser extrae los 3 passes canónicos" {
  run python3 "$PARSE" --file "$REVIEW" --json
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert 'Bugs' in d['passes'], f'faltan Bugs: {d}'
assert 'Security' in d['passes']
assert 'Compliance' in d['passes']
"
}

@test "parser extrae nit_cap = 5" {
  run python3 "$PARSE" --file "$REVIEW" --json
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['nit_cap'] == 5, f'nit_cap={d[\"nit_cap\"]}'
"
}

@test "parser extrae exclusiones" {
  run python3 "$PARSE" --file "$REVIEW" --json
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert len(d['exclusions']) > 0
assert any('gen' in e for e in d['exclusions'])
"
}

@test "parser fail-soft con REVIEW.md ausente" {
  run python3 "$PARSE" --file "/no/existe/REVIEW.md" --json
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['exists'] is False
assert d['nit_cap'] == 5
"
}

@test "REVIEW.md usa vocabulario cerrado (Important|Nit)" {
  # todas las menciones de severidad son Important o Nit
  run grep -iE "important|nit" "$REVIEW"
  [[ "$status" -eq 0 ]]
  # no hay severidades inventadas
  run grep -iE "\b(critical|high|medium|low)\b" "$REVIEW"
  [[ "$status" -ne 0 ]]
}

@test "REVIEW.md menciona cap de nits" {
  grep -qi "at most" "$REVIEW"
  grep -qi "5" "$REVIEW"
}
