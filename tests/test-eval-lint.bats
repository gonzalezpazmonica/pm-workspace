#!/usr/bin/env bats
# tests/test-eval-lint.bats — SE-316: linter de golden sets de tribunales.
# Ref: docs/propuestas/SE-316-eval-lint-golden-sets.md (AC-S1, AC-S2)

SCRIPT="scripts/eval-lint.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export EVAL_TMP="${BATS_TEST_TMPDIR}/evals"
  mkdir -p "$EVAL_TMP/code-review-court"
}

teardown() {
  rm -rf "$BATS_TEST_TMPDIR" 2>/dev/null || true
  cd /
}

# Genera un golden set válido con N casos bien formados.
make_golden() {
  local file="$1" n="$2"
  : > "$file"
  local i=1
  while [[ $i -le $n ]]; do
    cat >> "$file" <<EOF
{"id":"case-$i","input":"input $i","expected":"finding","should_trigger":["security-judge","correctness-judge","spec-judge","architecture-judge","cognitive-judge"],"should_not_trigger":[{"case":"a-$i","route_to":"agent:correctness-judge"},{"case":"b-$i","route_to":"agent:spec-judge"},{"case":"c-$i","route_to":"none"},{"case":"d-$i","route_to":"external:vendor"}],"capabilities":[{"name":"cap-$i","must_include":"$i"}]}
EOF
    i=$((i+1))
  done
}

# ── Estructura ────────────────────────────────────────────────────────────────

@test "script existe y es ejecutable" {
  [[ -f "$SCRIPT" ]]
  [[ -x "$SCRIPT" ]]
}

@test "usa set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "pasa bash -n" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "sin args devuelve usage (exit 2)" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage"* ]]
}

# ── AC-S1: Linter operativo ──────────────────────────────────────────────────

@test "AC-S1.1: golden set real de code-review-court pasa" {
  run bash "$SCRIPT" --check tests/evals/code-review-court
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}

@test "AC-S1.1: los 3 golden sets reales pasan (check global)" {
  run bash "$SCRIPT" --check tests/evals
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}

@test "AC-S1.2: route_to a skill inexistente produce FAIL" {
  make_golden "$EVAL_TMP/code-review-court/cases.jsonl" 5
  sed -i 's/"route_to":"agent:correctness-judge"/"route_to":"skill:inexistente-xyz"/' "$EVAL_TMP/code-review-court/cases.jsonl"
  run bash "$SCRIPT" --check "$EVAL_TMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"route_to"*"inexistente-xyz"* ]]
}

@test "AC-S1.3: caso sin should_not_trigger produce FAIL" {
  : > "$EVAL_TMP/code-review-court/cases.jsonl"
  cat > "$EVAL_TMP/code-review-court/cases.jsonl" <<'EOF'
{"id":"no-neg","input":"x","expected":"clean","should_trigger":["security-judge","correctness-judge","spec-judge","architecture-judge","cognitive-judge"]}
EOF
  run bash "$SCRIPT" --check "$EVAL_TMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"should_not_trigger vacío"* ]]
}

@test "golden set bien formado pasa" {
  make_golden "$EVAL_TMP/code-review-court/cases.jsonl" 5
  run bash "$SCRIPT" --check "$EVAL_TMP"
  [ "$status" -eq 0 ]
}

@test "JSONL mal formado produce FAIL" {
  echo '{"id":"broken","input":' > "$EVAL_TMP/code-review-court/cases.jsonl"
  run bash "$SCRIPT" --check "$EVAL_TMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"JSONL inválido"* ]]
}

@test "route_to valida agentes reales del catálogo" {
  make_golden "$EVAL_TMP/code-review-court/cases.jsonl" 5
  sed -i 's/"route_to":"none"/"route_to":"agent:code-reviewer"/' "$EVAL_TMP/code-review-court/cases.jsonl"
  run bash "$SCRIPT" --check "$EVAL_TMP"
  [ "$status" -eq 0 ]
}

@test "route_to valida skills reales de RESOLVER.md" {
  make_golden "$EVAL_TMP/code-review-court/cases.jsonl" 5
  sed -i 's/"route_to":"none"/"route_to":"skill:sprint-management"/' "$EVAL_TMP/code-review-court/cases.jsonl"
  run bash "$SCRIPT" --check "$EVAL_TMP"
  [ "$status" -eq 0 ]
}

@test "evals dir inexistente devuelve exit 2" {
  run bash "$SCRIPT" --check /nonexistent/evals
  [ "$status" -eq 2 ]
}

@test "directorio sin golden sets produce FAIL" {
  mkdir -p "$EVAL_TMP/empty"
  run bash "$SCRIPT" --check "$EVAL_TMP/empty"
  [ "$status" -eq 1 ]
}

# ── AC-S2: Schema ────────────────────────────────────────────────────────────

@test "AC-S2.1: config/eval-case.schema.json existe y es JSON válido" {
  run jq -e . config/eval-case.schema.json
  [ "$status" -eq 0 ]
}

@test "AC-S2.2: linter reporta caso y campo de cada violación" {
  make_golden "$EVAL_TMP/code-review-court/cases.jsonl" 5
  sed -i 's/"route_to":"agent:spec-judge"/"route_to":"agent:ghost-judge"/' "$EVAL_TMP/code-review-court/cases.jsonl"
  run bash "$SCRIPT" --check "$EVAL_TMP"
  [ "$status" -eq 1 ]
  [[ "$output" == *"case-1"* ]]
  [[ "$output" == *"route_to"* ]]
}

@test "--json emite objeto JSON con verdict FAIL en violación" {
  make_golden "$EVAL_TMP/code-review-court/cases.jsonl" 5
  sed -i 's/"route_to":"agent:spec-judge"/"route_to":"agent:ghost-judge"/' "$EVAL_TMP/code-review-court/cases.jsonl"
  run bash "$SCRIPT" --check "$EVAL_TMP" --json
  [ "$status" -eq 1 ]
  run jq -e '.verdict == "FAIL" and (.violations | length > 0)' <<< "$output"
  [ "$status" -eq 0 ]
}

# ── Cobertura ────────────────────────────────────────────────────────────────

@test "cobertura: eval-lint referencia SE-316" {
  run grep -c 'SE-316' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "cobertura: eval-lint referencia SE-274" {
  run grep -c 'SE-274' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "aislamiento: linter no modifica golden sets" {
  make_golden "$EVAL_TMP/code-review-court/cases.jsonl" 5
  local before after
  before=$(md5sum "$EVAL_TMP/code-review-court/cases.jsonl" | awk '{print $1}')
  bash "$SCRIPT" --check "$EVAL_TMP" >/dev/null 2>&1
  after=$(md5sum "$EVAL_TMP/code-review-court/cases.jsonl" | awk '{print $1}')
  [[ "$before" == "$after" ]]
}
