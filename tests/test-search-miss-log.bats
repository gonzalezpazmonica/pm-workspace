#!/usr/bin/env bats
# Tests for scripts/search-miss-log.sh — registro de misses heurísticos T4/T5
# Ref: docs/rules/domain/heuristic-self-learning.md
# Ref: SE-115618 heuristic search tier-based

SCRIPT="${BATS_TEST_DIRNAME}/../scripts/search-miss-log.sh"

setup() {
  [[ -x "$SCRIPT" ]] || skip "search-miss-log.sh missing or not executable"
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR
  export HOME="$TMP_DIR/home"
  mkdir -p "$HOME/.savia"
  WORK="$TMP_DIR/work"
  mkdir -p "$WORK"
  cd "$WORK"
}

teardown() {
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

@test "script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "safety: script uses set -euo pipefail" {
  run grep -E "set -euo pipefail" "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "missing tier arg fails" {
  run bash "$SCRIPT"
  [[ "$status" -ne 0 ]]
}

@test "missing category arg fails" {
  run bash "$SCRIPT" T4
  [[ "$status" -ne 0 ]]
}

@test "missing query arg fails" {
  run bash "$SCRIPT" T4 CONCEPTO
  [[ "$status" -ne 0 ]]
}

@test "missing reason arg fails" {
  run bash "$SCRIPT" T4 CONCEPTO "foo"
  [[ "$status" -ne 0 ]]
}

@test "valid invocation exits 0" {
  run bash "$SCRIPT" T4 CONCEPTO "mass balance v3" "no en GLOSSARY"
  [[ "$status" -eq 0 ]]
}

@test "valid invocation prints success marker" {
  run bash "$SCRIPT" T4 CONCEPTO "mass balance v3" "no en GLOSSARY"
  [[ "$output" == *"search-miss registrada"* ]]
  [[ "$output" == *"T4/CONCEPTO"* ]]
}

@test "creates global log at \$HOME/.savia/search-misses.jsonl" {
  bash "$SCRIPT" T4 CONCEPTO "mass balance v3" "no en GLOSSARY"
  [[ -f "$HOME/.savia/search-misses.jsonl" ]]
}

@test "global log entry is valid JSON" {
  bash "$SCRIPT" T4 CONCEPTO "mass balance v3" "no en GLOSSARY"
  run python3 -c "import json,sys; json.loads(open('$HOME/.savia/search-misses.jsonl').readline())"
  [[ "$status" -eq 0 ]]
}

@test "global log entry contains all required fields" {
  bash "$SCRIPT" T4 CONCEPTO "mass balance v3" "no en GLOSSARY"
  line="$(cat "$HOME/.savia/search-misses.jsonl")"
  [[ "$line" == *'"ts":'* ]]
  [[ "$line" == *'"project":'* ]]
  [[ "$line" == *'"tier":"T4"'* ]]
  [[ "$line" == *'"category":"CONCEPTO"'* ]]
  [[ "$line" == *'"query":"mass balance v3"'* ]]
  [[ "$line" == *'"reason":"no en GLOSSARY"'* ]]
}

@test "ts field is ISO-8601 (date -Iseconds shape)" {
  bash "$SCRIPT" T5 PERSONA "Virginia" "no en members/"
  line="$(cat "$HOME/.savia/search-misses.jsonl")"
  run python3 -c "
import json,re,sys
e=json.loads(open('$HOME/.savia/search-misses.jsonl').readline())
assert re.match(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}', e['ts']), e['ts']
"
  [[ "$status" -eq 0 ]]
}

@test "appends (does not overwrite) on second invocation" {
  bash "$SCRIPT" T4 CONCEPTO "first" "r1"
  bash "$SCRIPT" T5 PERSONA "second" "r2"
  count="$(wc -l < "$HOME/.savia/search-misses.jsonl")"
  [[ "$count" -eq 2 ]]
}

@test "project field defaults to basename of pwd" {
  mkdir -p "$TMP_DIR/myproject"
  cd "$TMP_DIR/myproject"
  bash "$SCRIPT" T4 CONCEPTO "x" "y"
  line="$(cat "$HOME/.savia/search-misses.jsonl")"
  [[ "$line" == *'"project":"myproject"'* ]]
}

@test "SAVIA_PROJECT env overrides pwd basename" {
  SAVIA_PROJECT="alpha-project" bash "$SCRIPT" T4 CONCEPTO "x" "y"
  line="$(cat "$HOME/.savia/search-misses.jsonl")"
  [[ "$line" == *'"project":"alpha-project"'* ]]
}

@test "writes per-project log when projects/<slug>/output exists" {
  mkdir -p projects/alpha/output
  SAVIA_PROJECT="alpha" bash "$SCRIPT" T4 CONCEPTO "x" "y"
  [[ -f "projects/alpha/output/audits/search-misses.jsonl" ]]
}

@test "skips per-project log when projects/<slug>/output does not exist" {
  SAVIA_PROJECT="ghost" bash "$SCRIPT" T4 CONCEPTO "x" "y"
  [[ ! -f "projects/ghost/output/audits/search-misses.jsonl" ]]
  [[ -f "$HOME/.savia/search-misses.jsonl" ]]
}

@test "per-project log entry matches global log entry" {
  mkdir -p projects/alpha/output
  SAVIA_PROJECT="alpha" bash "$SCRIPT" T4 CONCEPTO "shared" "reason"
  global="$(cat "$HOME/.savia/search-misses.jsonl")"
  proj="$(cat projects/alpha/output/audits/search-misses.jsonl)"
  [[ "$global" == "$proj" ]]
}

@test "accepts T5 tier" {
  run bash "$SCRIPT" T5 EVENTO "blackout" "log"
  [[ "$status" -eq 0 ]]
}

@test "accepts all canonical categories" {
  for cat in PERSONA CONCEPTO REGLA CODIGO EVENTO; do
    run bash "$SCRIPT" T4 "$cat" "q-$cat" "r"
    [[ "$status" -eq 0 ]]
  done
}

@test "handles query with spaces correctly" {
  bash "$SCRIPT" T4 CONCEPTO "multi word query here" "reason"
  line="$(cat "$HOME/.savia/search-misses.jsonl")"
  [[ "$line" == *'"query":"multi word query here"'* ]]
}
