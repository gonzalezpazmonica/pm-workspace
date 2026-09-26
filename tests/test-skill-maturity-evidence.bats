#!/usr/bin/env bats
# Ref: SE-376 / SE-167 — Calibrated exige test certificado por el auditor (>=80),
# no la mera existencia de tests/test-<skill>.bats (inflado en #1097).

SCRIPT="scripts/skill-maturity-audit.sh"

setup() {
  set -o pipefail
  cd "$BATS_TEST_DIRNAME/.."
  REPO="$PWD"
  FX="$(mktemp -d)"
  mkdir -p "$FX/.claude/skills" "$FX/tests/evals" "$FX/output"
}

teardown() {
  cd /
}

# mk_skill <name> <maturity|-> [domain=yes|no]
mk_skill() {
  local d="$FX/.claude/skills/$1"
  mkdir -p "$d"
  { printf -- '---\nname: %s\nmetadata:\n' "$1"
    [[ "$2" != "-" ]] && printf '  savia.maturity: %s\n' "$2"
    printf -- '---\n'; for i in $(seq 60); do echo "line $i"; done; } > "$d/SKILL.md"
  [[ "${3:-yes}" == "yes" ]] && printf '# Por qué existe\n' > "$d/DOMAIN.md"
  return 0
}

has_test_of() {
  awk -F'\t' -v s="$1" '$1==s{print $4}' "$FX/output/skill-maturity-audit-$(date +%Y%m%d).tsv"
}

state_of() {
  awk -F'\t' -v s="$1" '$1==s{print $2}' "$FX/output/skill-maturity-audit-$(date +%Y%m%d).tsv"
}

audit() {
  run env SKILL_AUDIT_ROOT="$FX" "$@" bash "$REPO/$SCRIPT" --tsv-only
  [ "$status" -eq 0 ]
}

@test "safety: audit runs under set -uo pipefail" {
  grep -q '^set -uo pipefail' "$SCRIPT"
}

@test "positive: classify_skill marks stable skill with a certified test as Calibrated" {
  mk_skill good stable
  cp tests/fixtures/se376/certified-skill-test.bats.fixture "$FX/tests/test-good.bats"
  audit
  [ "$(state_of good)" = "Calibrated" ]
  [ "$(has_test_of good)" = "true" ]
}

@test "positive: certified eval counts as qualifying evidence" {
  mk_skill evald stable
  cp tests/fixtures/se376/certified-skill-test.bats.fixture "$FX/tests/evals/eval-evald.bats"
  audit
  [ "$(state_of evald)" = "Calibrated" ]
}

@test "reject: stable skill with a presence-only test stays Incomplete (#1097 regression)" {
  mk_skill thin stable
  cp tests/fixtures/se376/thin-skill-test.bats.fixture "$FX/tests/test-thin.bats"
  audit
  [ "$(state_of thin)" = "Incomplete" ]
  [ "$(has_test_of thin)" = "false" ]
}

@test "missing: stable skill without any test is Incomplete" {
  mk_skill notest stable
  audit
  [ "$(state_of notest)" = "Incomplete" ]
}

@test "reject: certified test without stable maturity is Incomplete" {
  mk_skill betaskill beta
  cp tests/fixtures/se376/certified-skill-test.bats.fixture "$FX/tests/test-betaskill.bats"
  audit
  [ "$(state_of betaskill)" = "Incomplete" ]
}

@test "missing: skill without DOMAIN.md is a Stub" {
  mk_skill nodomain stable no
  audit
  [ "$(state_of nodomain)" = "Stub" ]
}

@test "boundary: threshold zero lets a presence-only test qualify" {
  mk_skill thin stable
  cp tests/fixtures/se376/thin-skill-test.bats.fixture "$FX/tests/test-thin.bats"
  audit SKILL_TEST_MIN_SCORE=0
  [ "$(state_of thin)" = "Calibrated" ]
}

@test "empty: all _template* scaffolds are excluded from the TSV" {
  mk_skill _template stable
  mk_skill _template_python stable
  mk_skill real stable
  audit
  [ -z "$(state_of _template)" ]
  [ -z "$(state_of _template_python)" ]
  [ "$(state_of real)" = "Incomplete" ]
}

@test "nonexistent: has_qualified_test tolerates a repo without tests/evals" {
  mk_skill lone stable
  mv "$FX/tests/evals" "$FX/evals.moved"
  audit
  [ "$(state_of lone)" = "Incomplete" ]
  [ "$(has_test_of lone)" = "false" ]
}
