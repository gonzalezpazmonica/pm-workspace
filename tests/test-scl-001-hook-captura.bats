#!/usr/bin/env bats
# SCL-001 — Hook de captura (learning-capture-hook.sh): producción
# Ref: docs/specs/SCL-001-aprendizaje-continuo.spec.md (S1) + fix prod 2026-08-17

set -uo pipefail

setup_file() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  export REPO_ROOT
}

setup() {
  HOOK="$REPO_ROOT/.claude/hooks/learning-capture-hook.sh"
  TMPD="$(mktemp -d -t scl-hook-XXXXXX)"
  export SAVIA_LEARNING_CAPTURE=on
  export SCL_PROPOSALS_DIR="$TMPD/proposals"
  export SCL_GRAPH_INDEX="$TMPD/graph.jsonl"
  mkdir -p "$SCL_PROPOSALS_DIR"
}

teardown() {
  [ -n "${TMPD:-}" ] && rm -rf "$TMPD"
}

@test "hook: master switch off → no captura nada (exit 0)" {
  run bash -c "printf '%s' '{\"tool_name\":\"Task\",\"tool_response\":\"se reconoce el error X\"}' | SAVIA_LEARNING_CAPTURE=off SCL_PROPOSALS_DIR='$SCL_PROPOSALS_DIR' SCL_GRAPH_INDEX='$SCL_GRAPH_INDEX' bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ "$(ls "$SCL_PROPOSALS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')" = "0" ]
}

@test "hook: error reconocido genera UNA propuesta de aprendizaje" {
  run bash -c "printf '%s' '{\"tool_name\":\"Task\",\"tool_response\":\"se reconoce el error: la memoria captura sin diagnostico\",\"tool_input\":{\"agent\":\"code-reviewer\"}}' | SAVIA_LEARNING_CAPTURE=on SCL_PROPOSALS_DIR='$SCL_PROPOSALS_DIR' SCL_GRAPH_INDEX='$SCL_GRAPH_INDEX' bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ "$(ls "$SCL_PROPOSALS_DIR"/*.md | wc -l | tr -d ' ')" = "1" ]
  f=$(ls "$SCL_PROPOSALS_DIR"/*.md)
  grep -q "^trigger: recurrence" "$f"
  grep -q "^provenance: INFERRED" "$f"
  grep -q "^lifecycle: proposed" "$f"
}

@test "hook: no actua en outputs sin keyword de error (exit 0, 0 propuestas)" {
  run bash -c "printf '%s' '{\"tool_name\":\"Task\",\"tool_response\":\"tarea completada sin incidencias\",\"tool_input\":{\"agent\":\"x\"}}' | SAVIA_LEARNING_CAPTURE=on SCL_PROPOSALS_DIR='$SCL_PROPOSALS_DIR' SCL_GRAPH_INDEX='$SCL_GRAPH_INDEX' bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ "$(ls "$SCL_PROPOSALS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')" = "0" ]
}

@test "hook fix prod: evidencia por hash de respuesta — errores distintos generan propuestas distintas" {
  for msg in "volvimos a fallar: bug del campo diagnostico" "se reconoce el error: gate no discrimina"; do
    printf '{"tool_name":"Task","tool_response":"%s","tool_input":{"agent":"t"}}' "$msg" \
      | SAVIA_LEARNING_CAPTURE=on SCL_PROPOSALS_DIR="$SCL_PROPOSALS_DIR" SCL_GRAPH_INDEX="$SCL_GRAPH_INDEX" bash "$HOOK"
  done
  count=$(ls "$SCL_PROPOSALS_DIR"/*.md | wc -l | tr -d ' ')
  [ "$count" = "2" ]
  # hashes de evidencia distintos
  h1=$(grep -m1 '^evidence_hash:' "$SCL_PROPOSALS_DIR"/*.md | head -1 | cut -d' ' -f2)
  h2=$(ls "$SCL_PROPOSALS_DIR"/*.md | tail -1 | xargs grep -m1 '^evidence_hash:' | cut -d' ' -f2)
  [ -n "$h1" ] && [ -n "$h2" ]
}

@test "hook fix prod: idempotencia — misma respuesta repetida no duplica" {
  msg='{"tool_name":"Task","tool_response":"volvimos a fallar: mismo error de calibracion","tool_input":{"agent":"t"}}'
  for i in 1 2; do
    printf '%s' "$msg" | SAVIA_LEARNING_CAPTURE=on SCL_PROPOSALS_DIR="$SCL_PROPOSALS_DIR" SCL_GRAPH_INDEX="$SCL_GRAPH_INDEX" bash "$HOOK"
  done
  count=$(ls "$SCL_PROPOSALS_DIR"/*.md | wc -l | tr -d ' ')
  [ "$count" = "1" ]
}

@test "hook fix prod: keyword sin tilde matchea (leccion vs lección)" {
  printf '%s' '{"tool_name":"Task","tool_response":"leccion aprendida: verificar hashes antes de firmar","tool_input":{"agent":"r"}}' \
    | SAVIA_LEARNING_CAPTURE=on SCL_PROPOSALS_DIR="$SCL_PROPOSALS_DIR" SCL_GRAPH_INDEX="$SCL_GRAPH_INDEX" bash "$HOOK"
  count=$(ls "$SCL_PROPOSALS_DIR"/*.md | wc -l | tr -d ' ')
  [ "$count" = "1" ]
}

@test "hook: siempre exit 0 (no bloquea tool call)" {
  run bash -c "printf '%s' '{}' | SAVIA_LEARNING_CAPTURE=on SCL_PROPOSALS_DIR='$SCL_PROPOSALS_DIR' SCL_GRAPH_INDEX='$SCL_GRAPH_INDEX' bash '$HOOK'"
  [ "$status" -eq 0 ]
}
