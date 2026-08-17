#!/usr/bin/env bats
# SCL-003 — Recall operativo: recuperar lecciones de la cúpula cuando se trabaja
# Ref: docs/specs/SCL-003-recall-operativo.spec.md

set -uo pipefail

setup_file() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  export REPO_ROOT
}

setup() {
  RECALL="$REPO_ROOT/scripts/learning-recall.sh"
  HOOK="$REPO_ROOT/.claude/hooks/learning-recall-hook.sh"
  PROP="$REPO_ROOT/scripts/learning-proposal.sh"
  PERSIST="$REPO_ROOT/scripts/learning-persist.sh"
  TMPD="$(mktemp -d -t scl-s3-XXXXXX)"
  mkdir -p "$TMPD/vault/learning" "$TMPD/proposals"
  export SCL_VAULT_DIR="$TMPD/vault"
  export SCL_PROPOSALS_DIR="$TMPD/proposals"
  export SCL_RECALL_LOG="$TMPD/recall.jsonl"
  # Crear una lección persistida en la cúpula de prueba
  echo "ev-s3" > "$TMPD/ev.txt"
  bash "$PROP" --origin "leccion: el hook de captura pierde diagnostico" \
    --evidence "$TMPD/ev.txt" --diagnosis "la captura generaba ruido sin causa raiz" \
    --change "exigir diagnostico no vacio" --target criterio --trigger ledger \
    --output-dir "$TMPD/proposals" --graph-index "$TMPD/g.jsonl" >/dev/null
  f=$(ls "$TMPD/proposals/"*.md)
  bash "$PERSIST" --file "$f" >/dev/null 2>&1
}

teardown() {
  [ -n "${TMPD:-}" ] && rm -rf "$TMPD"
}

@test "AC-1: learning-recall devuelve lecciones relevantes por contexto" {
  run bash "$RECALL" --query "hook de captura diagnostico" --top 3
  [ "$status" -eq 0 ]
  [[ "$output" == *"Lecciones aprendidas relevantes"* ]]
  [[ "$output" == *"LP-"* ]]
}

@test "AC-2: recall sin contexto relacionado no produce ruido (exit 0, 0 hits)" {
  run bash "$RECALL" --query "receta de paella valenciana" --top 3
  [ "$status" -eq 0 ]
  [[ "$output" != *"LP-"* ]]
}

@test "AC-3: recall --json emite JSON valido con hits" {
  run bash "$RECALL" --query "hook captura diagnostico" --top 3 --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'hits' in d, d; print('hits:', len(d['hits']))"
}

@test "AC-4: recall registra en el log de utilidad (recall.jsonl)" {
  bash "$RECALL" --query "hook captura diagnostico" --top 3 >/dev/null 2>&1
  [ -f "$TMPD/recall.jsonl" ]
  hits=$(tail -1 "$TMPD/recall.jsonl" | python3 -c "import json,sys; print(json.load(sys.stdin)['hits'])")
  [ "$hits" -ge 1 ]
}

@test "AC-5: hook inyecta lecciones relevantes en prompt relacionado" {
  run bash -c "printf '%s' '{\"content\":\"voy a mejorar el hook de captura de memoria que pierde diagnostico\"}' | SAVIA_LEARNING_RECALL=on SCL_VAULT_DIR='$TMPD/vault' SCL_RECALL_LOG='$TMPD/recall.jsonl' bash '$HOOK'"
  [[ "$output" == *"Lecciones aprendidas relevantes"* ]]
  [[ "$output" == *"NO reintroduzcas"* ]]
}

@test "AC-6: hook NO inyecta en prompt no relacionado (umbral de score)" {
  run bash -c "printf '%s' '{\"content\":\"hazme un resumen del tiempo en Madrid\"}' | SAVIA_LEARNING_RECALL=on SCL_VAULT_DIR='$TMPD/vault' SCL_RECALL_LOG='$TMPD/recall.jsonl' bash '$HOOK'"
  [[ "$output" != *"Lecciones aprendidas relevantes"* ]]
}

@test "AC-7: hook nunca bloquea (exit 0 siempre)" {
  run bash -c "printf '%s' '{}' | SAVIA_LEARNING_RECALL=on SCL_VAULT_DIR='$TMPD/vault' SCL_RECALL_LOG='$TMPD/recall.jsonl' bash '$HOOK'"
  [ "$status" -eq 0 ]
}
