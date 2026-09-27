#!/usr/bin/env bats
# Ref: Fase A (ADR-002) — decimal formatting must not depend on the locale.
# With LC_NUMERIC=es_ES.UTF-8, awk/printf "%.4f" emit "5000,0000": JSON broke
# and threshold comparisons misclassified (delta-tier: 49000 -> amber).

setup() {
  set -o pipefail
  cd "$BATS_TEST_DIRNAME/.."
  FX="$(mktemp -d)"
  if locale -a 2>/dev/null | grep -qiE '^es_ES\.utf-?8$'; then
    ES_LOCALE="es_ES.UTF-8"
  else
    ES_LOCALE=""
  fi
}

teardown() {
  cd /
}

_need_es() { [[ -n "$ES_LOCALE" ]] || skip "es_ES.UTF-8 locale not installed"; }

@test "safety: delta-tier pins LC_NUMERIC=C" {
  grep -q "export LC_NUMERIC=C" scripts/enterprise/delta-tier.sh
}

@test "positive: delta-tier classifies 49000 as red under a comma-decimal locale" {
  _need_es
  run env LC_ALL="$ES_LOCALE" bash scripts/enterprise/delta-tier.sh 50000 1000
  [ "$status" -eq 0 ]
  [[ "$output" == *"delta=49000.0000 tier=red"* ]]
}

@test "positive: delta-tier --json is valid JSON under a comma-decimal locale" {
  _need_es
  run env LC_ALL="$ES_LOCALE" bash scripts/enterprise/delta-tier.sh --json 100 50 25 100
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['tier']=='amber' and d['delta']==50.0"
}

@test "boundary: delta exactly at the red threshold is red" {
  _need_es
  run env LC_ALL="$ES_LOCALE" bash scripts/enterprise/delta-tier.sh 6000 1000
  [[ "$output" == *"tier=red"* ]]
}

@test "reject: no script formats decimals without pinning the numeric locale" {
  run bash -c 'for f in $(grep -rlE "printf *\(? *\"[^\"]*%[0-9]*\.[0-9]+f" --include=*.sh scripts .claude/hooks); do grep -qE "LC_ALL=C|LC_NUMERIC=C" "$f" || echo "$f"; done'
  [ -z "$output" ]
}

@test "empty: missing arguments fail without emitting a partial result" {
  run bash scripts/enterprise/delta-tier.sh
  [ "$status" -ne 0 ]
  [[ "$output" != *"tier="* ]]
}

@test "nonexistent: non-numeric input is rejected" {
  run bash scripts/enterprise/delta-tier.sh abc 1000
  [ "$status" -ne 0 ]
}
