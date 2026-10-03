#!/usr/bin/env bats
# Ref: .claude/skills/ast-quality-gate/SKILL.md — SE-376
#
# Comportamiento de scripts/ast-quality-gate.sh con linters y semgrep falsos en el PATH:
# qué recibe cada herramienta, cómo se normalizan sus hallazgos, qué códigos de salida
# devuelve el gate y que una herramienta ausente o rota nunca se presente como PASS.

SCRIPT="scripts/ast-quality-gate.sh"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMPDIR="$(mktemp -d)"
  mkdir -p "$TMPDIR/bin" "$TMPDIR/out" "$TMPDIR/py proj"
  printf 'import os\n' > "$TMPDIR/py proj/app.py"
  touch "$TMPDIR/py proj/requirements.txt"
  export AST_QG_OUTPUT_DIR="$TMPDIR/out"
  export FAKE_LOG="$TMPDIR/calls.log"
  # PATH mínimo: solo las herramientas falsas y lo imprescindible (jq, coreutils, find).
  mkdir -p "$TMPDIR/sys"
  for t in bash jq find date mktemp wc tr cat rm mkdir head dirname basename grep sed sort cp mv ls env printf touch tail chmod; do
    p="$(command -v "$t")" && ln -sf "$p" "$TMPDIR/sys/$t"
  done
  ORIG_PATH="$PATH"
  PATH="$TMPDIR/bin:$TMPDIR/sys"
}

teardown() {
  PATH="$ORIG_PATH"; hash -r
  rm -rf "$TMPDIR"
}

# fake <tool> <rc> <stdout> — herramienta falsa que registra argv, cwd y LANG.
fake() {
  local tool="$1" rc="$2" out="$3"
  printf '%s' "$out" > "$TMPDIR/bin/$tool.out"
  cat > "$TMPDIR/bin/$tool" <<EOF
#!/bin/bash
echo "$tool cwd=\$PWD lang=\${LANG:-} args=\$*" >> "\$FAKE_LOG"
cat "$TMPDIR/bin/$tool.out"
exit $rc
EOF
  chmod +x "$TMPDIR/bin/$tool"
}

ruff_json() { # code message
  printf '[{"filename":"app.py","location":{"row":3,"column":1},"message":"%s","code":"%s","fix":null}]' "$2" "$1"
}

semgrep_json() { # gate severity
  printf '{"results":[{"check_id":"llm.rule","path":"app.py","start":{"line":2,"col":1},"extra":{"message":"m","severity":"%s","metadata":{"gate":"%s"},"lines":"x"}}],"errors":[]}' "$2" "$1"
}

gate() { run bash "$REPO_ROOT/$SCRIPT" "$@"; }
report() { cat "$TMPDIR"/out/*.json; }

# ── Uso y entorno ─────────────────────────────────────────────────────────────

@test "script exists, is valid bash and uses set -uo pipefail" {
  [ -f "$REPO_ROOT/$SCRIPT" ]
  bash -n "$REPO_ROOT/$SCRIPT"
  grep -q 'set -uo pipefail' "$REPO_ROOT/$SCRIPT"
}

@test "usage: nonexistent target exits 2 and writes no report" {
  gate "$TMPDIR/no-such-dir"
  [ "$status" -eq 2 ]
  [[ "$output" == *"no existe"* ]]
  [ -z "$(ls "$TMPDIR/out")" ]
}

@test "usage: unknown flag exits 2" {
  gate "$TMPDIR/py proj" --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"--bogus"* ]]
}

@test "usage: --semgrep-only with --native-only is contradictory, exits 2" {
  gate "$TMPDIR/py proj" --semgrep-only --native-only
  [ "$status" -eq 2 ]
}

@test "env: without jq exits 2 instead of producing garbage" {
  rm -f "$TMPDIR/sys/jq"
  gate "$TMPDIR/py proj"
  [ "$status" -eq 2 ]
  [[ "$output" == *"jq"* ]]
}

# ── Fail-closed: herramienta ausente o rota nunca es PASS ────────────────────

@test "fail-closed: no linter and no semgrep is UNVERIFIED (exit 3), not PASS 100" {
  gate "$TMPDIR/py proj"
  [ "$status" -eq 3 ]
  [[ "$output" == *"UNVERIFIED"* ]]
  [[ "$output" != *"PASS"* ]]
  run jq -r '.score.verdict, .score.total, .meta.coverage' "$TMPDIR"/out/*.json
  [ "${lines[0]}" = "UNVERIFIED" ]
  [ "${lines[1]}" = "null" ]
  [ "${lines[2]}" = "none" ]
}

@test "fail-closed: missing tools are named in meta.tool_chain with status missing" {
  gate "$TMPDIR/py proj"
  run jq -r '.meta.tool_chain[] | "\(.layer):\(.tool):\(.status)"' "$TMPDIR"/out/*.json
  [[ "$output" == *"native:ruff:missing"* ]]
  [[ "$output" == *"semgrep:semgrep:missing"* ]]
}

@test "fail-closed: --advisory keeps exit 0 but the report still says UNVERIFIED" {
  gate "$TMPDIR/py proj" --advisory
  [ "$status" -eq 0 ]
  [ "$(report | jq -r .score.verdict)" = "UNVERIFIED" ]
}

@test "fail-closed: linter crashing with non-JSON output is status failed, not clean" {
  fake ruff 2 'error: Failed to parse pyproject.toml'
  gate "$TMPDIR/py proj" --native-only
  [ "$status" -eq 3 ]
  [ "$(report | jq -r '.meta.tool_chain[0].status')" = "failed" ]
}

@test "fail-closed: semgrep rules file missing is failed, not an empty pass" {
  fake semgrep 0 '{"results":[],"errors":[]}'
  AST_QG_SEMGREP_RULES="$TMPDIR/none.yaml" gate "$TMPDIR/py proj" --semgrep-only
  [ "$status" -eq 3 ]
  [ "$(report | jq -r '.meta.tool_chain[0].status')" = "failed" ]
}

@test "fail-closed: one layer ok and the other missing is coverage partial with a warning" {
  fake ruff 0 '[]'
  gate "$TMPDIR/py proj"
  [ "$status" -eq 0 ]
  [[ "$output" == *"parcial"* ]]
  [ "$(report | jq -r .meta.coverage)" = "partial" ]
  [ "$(report | jq -r .score.verdict)" = "PASS" ]
}

# ── Hallazgos: el exit 1 del linter no borra sus resultados ──────────────────

@test "findings: ruff exit 1 with findings keeps the findings (pipefail bug)" {
  fake ruff 1 "$(ruff_json F401 'os imported but unused')"
  gate "$TMPDIR/py proj" --native-only
  [ "$(report | jq '.issues | length')" -eq 1 ]
  [ "$(report | jq -r '.meta.tool_chain[0].status')" = "ok" ]
  [ "$(report | jq -r '.issues[0].gate')" = "QG-11" ]
  [ "$(report | jq -r .score.total)" -eq 97 ]
}

@test "findings: eslint exit 1 with errors is scored and errors block (score 70 REVIEW, QG-01 blocking)" {
  mkdir -p "$TMPDIR/ts"; echo '{}' > "$TMPDIR/ts/tsconfig.json"
  local m='{"line":4,"column":2,"message":"Promise not handled","ruleId":"@typescript-eslint/no-floating-promises","severity":2,"fix":null}'
  fake eslint 1 "[{\"filePath\":\"a.ts\",\"messages\":[$m,$m,$m]}]"
  gate "$TMPDIR/ts" --native-only
  [ "$status" -eq 1 ]
  [ "$(report | jq -r .score.total)" -eq 70 ]
  [ "$(report | jq -r .score.grade)" = "C" ]
  [ "$(report | jq -r .score.verdict)" = "BLOCK" ]
  [ "$(report | jq -r '.score.blocking_gates[0]')" = "QG-01" ]
}

@test "thresholds: score bands match the documented table (90 A PASS, 75 B, 60 C, 40 D, <40 F)" {
  for n in 0 3 4 8 13 15 21; do
    local items=""
    for ((i = 0; i < n; i++)); do items+="${items:+,}{\"filename\":\"a.py\",\"location\":{\"row\":1,\"column\":1},\"message\":\"m\",\"code\":\"E501\",\"fix\":null}"; done
    fake ruff 1 "[$items]"
    rm -f "$TMPDIR"/out/*.json
    gate "$TMPDIR/py proj" --native-only --advisory
    echo "$n -> $(report | jq -c .score)"
    case $n in
      0)  [ "$(report | jq -r '.score | "\(.total) \(.grade) \(.verdict)"')" = "100 A PASS" ] ;;
      3)  [ "$(report | jq -r '.score | "\(.total) \(.grade) \(.verdict)"')" = "91 A PASS" ] ;;
      4)  [ "$(report | jq -r '.score | "\(.total) \(.grade) \(.verdict)"')" = "88 B PASS_WITH_WARNINGS" ] ;;
      8)  [ "$(report | jq -r '.score | "\(.total) \(.grade) \(.verdict)"')" = "76 B PASS_WITH_WARNINGS" ] ;;
      13) [ "$(report | jq -r '.score | "\(.total) \(.grade) \(.verdict)"')" = "61 C REVIEW" ] ;;
      15) [ "$(report | jq -r '.score | "\(.total) \(.grade) \(.verdict)"')" = "55 D FAIL" ] ;;
      21) [ "$(report | jq -r '.score | "\(.total) \(.grade) \(.verdict)"')" = "37 F BLOCK" ] ;;
    esac
  done
}

@test "exit codes: REVIEW exits 0, FAIL exits 1, --advisory turns FAIL into 0" {
  local items=""
  for ((i = 0; i < 13; i++)); do items+="${items:+,}{\"filename\":\"a.py\",\"location\":{\"row\":1,\"column\":1},\"message\":\"m\",\"code\":\"E501\",\"fix\":null}"; done
  fake ruff 1 "[$items]"
  gate "$TMPDIR/py proj" --native-only
  [ "$status" -eq 0 ]
  items+=$(printf ',%.0s{"filename":"a.py","location":{"row":1,"column":1},"message":"m","code":"E501","fix":null}' 1 2 3 4 5 6)
  fake ruff 1 "[$items]"
  gate "$TMPDIR/py proj" --native-only
  [ "$status" -eq 1 ]
  gate "$TMPDIR/py proj" --native-only --advisory
  [ "$status" -eq 0 ]
}

@test "blocking: a single semgrep error in QG-09 blocks even with score 90" {
  fake semgrep 0 "$(semgrep_json QG-09 ERROR)"
  gate "$TMPDIR/py proj" --semgrep-only
  [ "$status" -eq 1 ]
  [ "$(report | jq -r .score.total)" -eq 90 ]
  [ "$(report | jq -r .score.verdict)" = "BLOCK" ]
}

@test "blocking: a warning in an advisory gate (QG-04) does not block" {
  fake semgrep 0 "$(semgrep_json QG-04 WARNING)"
  gate "$TMPDIR/py proj" --semgrep-only
  [ "$status" -eq 0 ]
  [ "$(report | jq -r .score.verdict)" = "PASS" ]
}

@test "semgrep: receives the canonical rules file and the target; gate comes from metadata" {
  fake semgrep 0 "$(semgrep_json QG-02 WARNING)"
  gate "$TMPDIR/py proj" --semgrep-only
  grep -q -- "--config $REPO_ROOT/.claude/skills/ast-quality-gate/references/semgrep-rules.yaml" "$FAKE_LOG"
  grep -q -- "$TMPDIR/py proj" "$FAKE_LOG"
  [ "$(report | jq -r '.issues[0].gate')" = "QG-02" ]
}

@test "semgrep: exit code >= 2 with no JSON is failed" {
  fake semgrep 2 'Fatal error: invalid config'
  gate "$TMPDIR/py proj" --semgrep-only
  [ "$status" -eq 3 ]
  [ "$(report | jq -r '.meta.tool_chain[0].status')" = "failed" ]
}

# ── Rutas, entorno y cwd ─────────────────────────────────────────────────────

@test "paths: target with spaces reaches the linter intact and the report is valid JSON" {
  fake ruff 0 '[]'
  gate "$TMPDIR/py proj" --native-only
  [ "$status" -eq 0 ]
  grep -q "args=check --output-format json $TMPDIR/py proj" "$FAKE_LOG"
  report | jq -e '.meta.target and (.issues | type == "array")'
}

@test "env: the detected language does not clobber the LANG locale passed to tools" {
  fake ruff 0 '[]'
  LANG=C.UTF-8 gate "$TMPDIR/py proj" --native-only
  grep -q "lang=C.UTF-8" "$FAKE_LOG"
  ! grep -q "lang=python" "$FAKE_LOG"
}

@test "cwd: cargo clippy runs inside the target project, not the caller's cwd" {
  mkdir -p "$TMPDIR/rs proj"; touch "$TMPDIR/rs proj/Cargo.toml"
  fake cargo 0 '{"reason":"compiler-message","message":{"level":"warning","message":"unused","code":{"code":"unused_variables"},"spans":[{"file_name":"src/main.rs","line_start":2}]}}'
  gate "$TMPDIR/rs proj" --native-only
  grep -q "cargo cwd=$TMPDIR/rs proj" "$FAKE_LOG"
  [ "$(report | jq -r '.issues[0].rule_id')" = "unused_variables" ]
}

@test "cwd: dotnet build runs in the target and parses only error/warning diagnostics" {
  mkdir -p "$TMPDIR/cs"; touch "$TMPDIR/cs/App.csproj"
  fake dotnet 1 "$(printf '%s\n' '/x/Program.cs(10,5): error CS0103: The name foo does not exist' '/x/Program.cs(3,1): warning CS0168: variable declared but never used, no error handling' 'Build FAILED.')"
  gate "$TMPDIR/cs" --native-only --advisory
  grep -q "dotnet cwd=$TMPDIR/cs" "$FAKE_LOG"
  [ "$(report | jq -r '[.issues[].severity] | join(",")')" = "error,warning" ]
  [ "$(report | jq -r '.issues[0].line')" = "10" ]
}

@test "dotnet: build failing with no parseable diagnostics is failed, not clean" {
  mkdir -p "$TMPDIR/cs"; touch "$TMPDIR/cs/App.csproj"
  fake dotnet 1 'MSBUILD : error MSB1003: Specify a project or solution file.'
  gate "$TMPDIR/cs" --native-only
  [ "$status" -eq 3 ]
}

# ── Lenguajes anunciados ─────────────────────────────────────────────────────

@test "languages: plain JavaScript project (package.json, no tsconfig) is detected and linted" {
  mkdir -p "$TMPDIR/js"; echo '{}' > "$TMPDIR/js/package.json"
  fake eslint 0 '[]'
  gate "$TMPDIR/js" --native-only
  [ "$status" -eq 0 ]
  [ "$(report | jq -r .meta.language)" = "javascript" ]
}

@test "languages: Java has no native linter wired and says so (unsupported), not PASS" {
  mkdir -p "$TMPDIR/java"; touch "$TMPDIR/java/pom.xml"
  gate "$TMPDIR/java" --native-only
  [ "$status" -eq 3 ]
  [ "$(report | jq -r '.meta.tool_chain[0].status')" = "unsupported" ]
}

@test "languages: unknown language with semgrep still analyses via semgrep" {
  mkdir -p "$TMPDIR/misc"; echo hi > "$TMPDIR/misc/notes.txt"
  fake semgrep 0 '{"results":[],"errors":[]}'
  gate "$TMPDIR/misc"
  [ "$status" -eq 0 ]
  [ "$(report | jq -r .meta.language)" = "unknown" ]
  [ "$(report | jq -r .meta.coverage)" = "partial" ]
}

@test "languages: single-file targets map by extension (.go, .rb, .tf, .kt)" {
  for f in m.go m.rb m.tf m.kt; do echo x > "$TMPDIR/$f"; done
  rm -f "$TMPDIR"/out/*.json
  gate "$TMPDIR/m.go" --advisory;  [ "$(report | jq -r .meta.language)" = "go" ];        rm -f "$TMPDIR"/out/*.json
  gate "$TMPDIR/m.rb" --advisory;  [ "$(report | jq -r .meta.language)" = "ruby" ];      rm -f "$TMPDIR"/out/*.json
  gate "$TMPDIR/m.tf" --advisory;  [ "$(report | jq -r .meta.language)" = "terraform" ]; rm -f "$TMPDIR"/out/*.json
  gate "$TMPDIR/m.kt" --advisory;  [ "$(report | jq -r .meta.language)" = "kotlin" ]
}

@test "reports: two runs in the same second do not overwrite each other" {
  fake ruff 0 '[]'
  gate "$TMPDIR/py proj" --native-only
  gate "$TMPDIR/py proj" --native-only
  [ "$(ls "$TMPDIR/out" | wc -l)" -eq 2 ]
}

@test "languages: semgrep has no rules for Swift, so it is unsupported there, not an empty ok" {
  mkdir -p "$TMPDIR/sw"; touch "$TMPDIR/sw/Package.swift"
  fake semgrep 0 '{"results":[],"errors":[]}'
  gate "$TMPDIR/sw"
  [ "$status" -eq 3 ]
  [ "$(report | jq -r '.meta.tool_chain[] | select(.layer == "semgrep") | .status')" = "unsupported" ]
  ! grep -q '^semgrep' "$FAKE_LOG" 2>/dev/null
}

@test "languages: Angular maps to the typescript semgrep rules and runs semgrep" {
  mkdir -p "$TMPDIR/ng"; echo '{}' > "$TMPDIR/ng/angular.json"
  fake semgrep 0 '{"results":[],"errors":[]}'
  gate "$TMPDIR/ng" --semgrep-only
  [ "$status" -eq 0 ]
  grep -q '^semgrep' "$FAKE_LOG"
}
