#!/usr/bin/env bats
# SCL-004 — Labs L1: divergencia grafo-modelo como instrumento del bucle
# Ref: docs/specs/SCL-004-labs-instrumentos.spec.md

set -uo pipefail

setup_file() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  export REPO_ROOT
}

setup() {
  DIV="$REPO_ROOT/scripts/learning-divergence.sh"
  TMPD="$(mktemp -d -t scl-s4-XXXXXX)"
  mkdir -p "$TMPD/proposals"
}

teardown() {
  [ -n "${TMPD:-}" ] && rm -rf "$TMPD"
}

@test "AC-1: claim alineado con el grafo → divergencia <= umbral, exit 0" {
  run bash "$DIV" --claim "el hook de captura debe generar diagnostico no vacio" \
    --graph-text "captura diagnostico hook memoria error causa raiz"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ALINEADO"* ]]
}

@test "AC-2: claim divergente → divergencia > umbral, exit 1" {
  run bash "$DIV" --claim "la receta de paella lleva arroz bomba y azafran" \
    --graph-text "captura diagnostico hook memoria error"
  [ "$status" -ne 0 ]
  [[ "$output" == *"DIVERGENCIA"* ]]
}

@test "AC-3: divergencia determinista — misma entrada → mismo valor" {
  a=$(bash "$DIV" --claim "el hook de captura diagnostico" --graph-text "captura diagnostico hook memoria error" --json)
  b=$(bash "$DIV" --claim "el hook de captura diagnostico" --graph-text "captura diagnostico hook memoria error" --json)
  [ "$a" = "$b" ]
  echo "$a" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['divergence'] == 0.4, d"
}

@test "AC-4: --propose genera propuesta con trigger divergence" {
  run bash "$DIV" --claim "vamos a hardcodear el PAT en el script de azure" \
    --graph-text "captura diagnostico hook memoria PAT" --threshold 0.5 \
    --propose --output-dir "$TMPD/proposals"
  [ "$status" -ne 0 ]
  f=$(ls "$TMPD/proposals/"*.md 2>/dev/null | head -1)
  [ -n "$f" ]
  grep -q "^trigger: divergence" "$f"
}

@test "AC-5: claim alineado con --propose NO genera propuesta" {
  run bash "$DIV" --claim "el hook de captura genera diagnostico de error" \
    --graph-text "captura diagnostico hook memoria error causa raiz" --propose --output-dir "$TMPD/proposals"
  [ "$status" -eq 0 ]
  count=$(find "$TMPD/proposals" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  [ "$count" = "0" ]
}

@test "AC-6: grafo vacio → divergencia maxima (exit 1)" {
  run bash "$DIV" --claim "algo" --graph-text ""
  [ "$status" -ne 0 ]
  [[ "$output" == *"1.0000"* ]]
}

@test "AC-7: --json emite JSON valido" {
  run bash "$DIV" --claim "el hook de captura diagnostico" --graph-text "captura diagnostico hook memoria" --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'divergence' in d, d"
}
