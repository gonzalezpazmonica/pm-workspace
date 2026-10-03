#!/usr/bin/env bats
# test-ast-comprehension.bats — calibracion SE-376 de la skill ast-comprehension
# Ref: .claude/skills/ast-comprehension/SKILL.md (extraccion monolitica)
# Ref: docs/ast-strategy.md
# Ejercita scripts/ast-comprehend.sh con ficheros sinteticos de estructura
# conocida: clases, funciones e imports esperados se fijan de antemano.

SCRIPT="scripts/ast-comprehend.sh"
bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SH="$REPO_ROOT/$SCRIPT"
  TMPDIR_TEST="$(mktemp -d)"
}

teardown() {
  [ -n "${TMPDIR_TEST:-}" ] && rm -rf "$TMPDIR_TEST"
}

# jq_py <expr-python sobre d> — evalua una expresion sobre el JSON de stdin
jq_py() {
  python3 -c "import json,sys; d=json.load(sys.stdin); print(($1))"
}

mk_python() {
  cat > "$1" <<'EOF'
import os
from collections import OrderedDict
class Foo:
    def bar(self):
        return 1
    async def qux(self):
        return 2
def baz():
    pass
EOF
}

mk_go() {
  cat > "$1" <<'EOF'
package main
import "fmt"
type Server struct{}
type Handler interface{}
func Hello() { fmt.Println("x") }
func (s *Server) Run() {}
EOF
}

# ── Contrato basico ──────────────────────────────────────────────────────────

@test "script uses set -uo pipefail and passes bash -n" {
  run grep -c '^set -uo pipefail' "$SH"
  [ "$output" -ge 1 ]
  run bash -n "$SH"
  [ "$status" -eq 0 ]
}

@test "python: output includes structure with classes, methods, functions and imports" {
  mk_python "$TMPDIR_TEST/a.py"
  run bash "$SH" "$TMPDIR_TEST/a.py"
  [ "$status" -eq 0 ]
  echo "$output" | jq_py "d['meta']['tool']" | grep -qx 'python-ast'
  run jq_py "sorted(c['name'] for c in d['structure']['classes'])" <<< "$output"
  [ "$output" = "['Foo']" ]
  mk_python "$TMPDIR_TEST/a.py"
  out=$(bash "$SH" "$TMPDIR_TEST/a.py")
  run jq_py "sorted(m['name'] for m in d['structure']['classes'][0]['methods'])" <<< "$out"
  [ "$output" = "['bar', 'qux']" ]
  run jq_py "'baz' in [f['name'] for f in d['structure']['functions']]" <<< "$out"
  [ "$output" = "True" ]
  run jq_py "d['structure']['imports']" <<< "$out"
  [ "$output" = "['os', 'from collections']" ]
}

@test "python: summary counts match the structure lists" {
  mk_python "$TMPDIR_TEST/a.py"
  out=$(bash "$SH" "$TMPDIR_TEST/a.py")
  run jq_py "len(d['structure']['classes']), len(d['structure']['functions'])" <<< "$out"
  [ "$output" = "(1, 3)" ]
  [[ "$out" == *"1 clase(s), 3 función(es)"* ]]
}

@test "grep fallback: go structs, interfaces and funcs detected without gawk" {
  mk_go "$TMPDIR_TEST/b.go"
  run bash "$SH" "$TMPDIR_TEST/b.go" --surface-only
  [ "$status" -eq 0 ]
  [[ "$output" != *"gensub"* ]]
  run jq_py "sorted(c['name'] for c in d['structure']['classes'])" <<< "$(bash "$SH" "$TMPDIR_TEST/b.go" --surface-only 2>/dev/null)"
  [ "$output" = "['Handler', 'Server']" ]
  run jq_py "sorted(f['name'] for f in d['structure']['functions'])" <<< "$(bash "$SH" "$TMPDIR_TEST/b.go" --surface-only 2>/dev/null)"
  [ "$output" = "['Hello', 'Run']" ]
}

@test "grep fallback: import with double quotes yields valid escaped JSON" {
  mk_go "$TMPDIR_TEST/b.go"
  run bash "$SH" "$TMPDIR_TEST/b.go" --surface-only
  [ "$status" -eq 0 ]
  run jq_py "d['structure']['imports']" <<< "$output"
  [ "$status" -eq 0 ]
  [ "$output" = "['import \"fmt\"']" ]
}

@test "grep fallback: rust import line with colons is not truncated" {
  printf 'use std::collections::HashMap;\nstruct Cache {}\nfn get() {}\n' > "$TMPDIR_TEST/c.rs"
  out=$(bash "$SH" "$TMPDIR_TEST/c.rs" --surface-only)
  run jq_py "d['structure']['imports']" <<< "$out"
  [ "$output" = "['use std::collections::HashMap;']" ]
  run jq_py "[c['name'] for c in d['structure']['classes']], [f['name'] for f in d['structure']['functions']]" <<< "$out"
  [ "$output" = "(['Cache'], ['get'])" ]
}

@test "tool field is truthful: never claims gopls or ts-morph when absent" {
  mk_go "$TMPDIR_TEST/b.go"
  printf 'export class Svc {}\nexport function run() {}\n' > "$TMPDIR_TEST/c.ts"
  gt=$(bash "$SH" "$TMPDIR_TEST/b.go" 2>/dev/null | jq_py "d['meta']['tool']")
  tt=$(bash "$SH" "$TMPDIR_TEST/c.ts" 2>/dev/null | jq_py "d['meta']['tool']")
  if ! command -v gopls >/dev/null 2>&1; then [ "$gt" = "grep-structural" ]; fi
  if ! node -e "require('ts-morph')" >/dev/null 2>&1; then [ "$tt" = "grep-structural" ]; fi
  run jq_py "sorted(c['name'] for c in d['structure']['classes'])" <<< "$(bash "$SH" "$TMPDIR_TEST/c.ts" 2>/dev/null)"
  [ "$output" = "['Svc']" ]
}

# ── Complejidad ──────────────────────────────────────────────────────────────

@test "boundary: zero decision points gives 0 with no stderr noise" {
  printf 'def a():\n    return 1\n' > "$TMPDIR_TEST/z.py"
  run --separate-stderr bash "$SH" "$TMPDIR_TEST/z.py"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  run jq_py "d['complexity']['total_decision_points'], d['complexity']['hotspots'][0]['warn']" <<< "$output"
  [ "$output" = "(0, False)" ]
}

@test "boundary: 15 decision points do not warn, 16 do" {
  for i in $(seq 1 15); do echo "if (x$i) {}"; done > "$TMPDIR_TEST/w15.js"
  for i in $(seq 1 16); do echo "if (x$i) {}"; done > "$TMPDIR_TEST/w16.js"
  run jq_py "d['complexity']['total_decision_points'], d['complexity']['hotspots'][0]['warn']" <<< "$(bash "$SH" "$TMPDIR_TEST/w15.js" 2>/dev/null)"
  [ "$output" = "(15, False)" ]
  run jq_py "d['complexity']['total_decision_points'], d['complexity']['hotspots'][0]['warn']" <<< "$(bash "$SH" "$TMPDIR_TEST/w16.js" 2>/dev/null)"
  [ "$output" = "(16, True)" ]
}

# ── Errores y argumentos ─────────────────────────────────────────────────────

@test "error: no target exits 1 with JSON error on stderr" {
  run --separate-stderr bash "$SH"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *'"error"'* ]]
}

@test "error: nonexistent target fails with non-zero exit and empty stdout" {
  run --separate-stderr bash "$SH" "$TMPDIR_TEST/nope"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  echo "$stderr" | jq_py "d['error']" | grep -q 'Target not found'
}

@test "invalid: unknown flag is rejected with exit 2" {
  mk_python "$TMPDIR_TEST/a.py"
  run --separate-stderr bash "$SH" "$TMPDIR_TEST/a.py" --bogus
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"--bogus"* ]]
}

@test "invalid: --output without value is rejected with exit 2" {
  mk_python "$TMPDIR_TEST/a.py"
  run bash "$SH" "$TMPDIR_TEST/a.py" --output
  [ "$status" -eq 2 ]
}

@test "error: python syntax error is surfaced in structure.error" {
  printf 'def broken(:\n' > "$TMPDIR_TEST/bad.py"
  run bash "$SH" "$TMPDIR_TEST/bad.py"
  [ "$status" -eq 0 ]
  run jq_py "'error' in d['structure']" <<< "$output"
  [ "$output" = "True" ]
}

# ── Rutas, directorios y salida ──────────────────────────────────────────────

@test "edge: filename with double quote and spaces yields valid JSON" {
  mkdir -p "$TMPDIR_TEST/my dir"
  mk_python "$TMPDIR_TEST/my dir/we\"ird 'x.py"
  run bash "$SH" "$TMPDIR_TEST/my dir"
  [ "$status" -eq 0 ]
  run jq_py "len(d), d[0]['meta']['file'].endswith('we\"ird \\'x.py')" <<< "$output"
  [ "$output" = "(1, True)" ]
}

@test "empty: empty directory gives empty JSON array" {
  mkdir -p "$TMPDIR_TEST/empty"
  run bash "$SH" "$TMPDIR_TEST/empty"
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}

@test "empty: zero-byte file reports 0 lines and empty structure" {
  : > "$TMPDIR_TEST/e.py"
  run bash "$SH" "$TMPDIR_TEST/e.py"
  [ "$status" -eq 0 ]
  run jq_py "d['meta']['lines'], d['structure']['classes'], d['structure']['functions']" <<< "$output"
  [ "$output" = "(0, [], [])" ]
}

@test "directory: walks sources and skips node_modules" {
  mkdir -p "$TMPDIR_TEST/p/src" "$TMPDIR_TEST/p/node_modules/x"
  mk_python "$TMPDIR_TEST/p/src/a.py"
  mk_go "$TMPDIR_TEST/p/src/b.go"
  echo 'function f(){}' > "$TMPDIR_TEST/p/node_modules/x/i.js"
  echo 'texto' > "$TMPDIR_TEST/p/src/README.md"
  run bash "$SH" "$TMPDIR_TEST/p"
  [ "$status" -eq 0 ]
  run jq_py "sorted(x['meta']['language'] for x in d)" <<< "$output"
  [ "$output" = "['go', 'python']" ]
}

@test "large: 600 functions are all reported, no silent truncation" {
  for i in $(seq 1 600); do echo "fn f$i() {}"; done > "$TMPDIR_TEST/big.rs"
  run bash "$SH" "$TMPDIR_TEST/big.rs"
  [ "$status" -eq 0 ]
  run jq_py "len(d['structure']['functions'])" <<< "$output"
  [ "$output" = "600" ]
}

@test "output: --output writes JSON to a path with spaces and keeps stdout empty" {
  mk_python "$TMPDIR_TEST/a.py"
  run --separate-stderr bash "$SH" "$TMPDIR_TEST/a.py" --output "$TMPDIR_TEST/out dir/r.json"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run jq_py "d['meta']['language']" < "$TMPDIR_TEST/out dir/r.json"
  [ "$output" = "python" ]
}

@test "concurrency: parallel --output to the same file leaves valid JSON" {
  mk_python "$TMPDIR_TEST/a.py"
  for i in 1 2 3 4; do
    bash "$SH" "$TMPDIR_TEST/a.py" --output "$TMPDIR_TEST/r.json" 2>/dev/null &
  done
  wait
  run jq_py "d['meta']['language']" < "$TMPDIR_TEST/r.json"
  [ "$status" -eq 0 ]
  [ "$output" = "python" ]
  run bash -c "ls '$TMPDIR_TEST' | grep -c 'r.json.'"
  [ "$output" = "0" ]
}

@test "locale es_ES: output is identical to C locale" {
  mk_go "$TMPDIR_TEST/b.go"
  a=$(LC_ALL=C bash "$SH" "$TMPDIR_TEST/b.go" 2>/dev/null)
  b=$(LC_ALL=es_ES.UTF-8 bash "$SH" "$TMPDIR_TEST/b.go" 2>/dev/null)
  [ -n "$a" ]
  [ "$a" = "$b" ]
}
