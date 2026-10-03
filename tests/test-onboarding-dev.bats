#!/usr/bin/env bats
# SE-376 — onboarding-dev: calibración de su parte ejecutable. La skill es prosa (la ejecuta
# el agente); lo único ejecutable de su cadena es scripts/setup-memory.sh, que /project-new
# (prerrequisito de /onboarding-dev) usa para crear la memoria del proyecto en
# ~/.savia/projects/<proyecto>/memory/. Nunca toca el HOME real: HOME apunta a un temporal.
# Ref: .claude/skills/onboarding-dev/SKILL.md, .claude/commands/project-new.md,
#      docs/propuestas/SPEC-INSTALLER-OPENCODE-MIGRATION.md (AC-4)
set -uo pipefail

bats_require_minimum_version 1.5.0
SCRIPT="scripts/setup-memory.sh"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TARGET="$REPO_ROOT/$SCRIPT"
  TMP="$(mktemp -d -p "$BATS_TEST_TMPDIR")"
  export HOME="$TMP/home"
  mkdir -p "$HOME"
  unset SAVIA_MEMORY_DIR
  BASE="$HOME/.savia/projects"
  TODAY="$(date +%Y-%m-%d)"
}

teardown() { rm -rf "$TMP"; }

# Lista los ficheros que existen bajo $TMP (para detectar escrituras fuera de sitio).
all_files() { (cd "$TMP" && find . -type f | sort); }

@test "script: existe, es bash válido y usa modo estricto set -euo pipefail" {
  [ -f "$TARGET" ]
  run bash -n "$TARGET"
  [ "$status" -eq 0 ]
  run grep -cE '^set -[a-z]*u[a-z]*o pipefail' "$TARGET"
  [ "$output" -ge 1 ]
}

@test "positivo: crea MEMORY.md y los 5 topic files con el nombre y la fecha de hoy" {
  run bash "$TARGET" mi-api
  [ "$status" -eq 0 ]
  d="$BASE/mi-api/memory"
  [ "$(head -1 "$d/MEMORY.md")" = "# Memory — mi-api" ]
  grep -qF "> Última sync: $TODAY" "$d/MEMORY.md"
  for t in sprint-history architecture debugging team-patterns devops-notes; do
    [ -f "$d/$t.md" ]
    grep -qF "— mi-api" "$d/$t.md"
    grep -qF "> Actualizado: $TODAY" "$d/$t.md"
  done
  [ "$(head -1 "$d/team-patterns.md")" = "# Team Patterns — mi-api" ]
  [ "$(find "$d" -type f | wc -l)" -eq 6 ]
}

@test "idempotente: la segunda ejecución no sobrescribe notas ya existentes" {
  run bash "$TARGET" mi-api
  [ "$status" -eq 0 ]
  echo "nota de la operadora" >> "$BASE/mi-api/memory/debugging.md"
  run bash "$TARGET" mi-api
  [ "$status" -eq 0 ]
  [[ "$output" == *"MEMORY.md ya existe"* ]]
  grep -qF "nota de la operadora" "$BASE/mi-api/memory/debugging.md"
}

@test "nombre con & : el nombre se escribe literal, sin metacaracteres de sed" {
  run bash "$TARGET" 'R&D'
  [ "$status" -eq 0 ]
  [ "$(head -1 "$BASE/R&D/memory/MEMORY.md")" = "# Memory — R&D" ]
  grep -qF "— R&D" "$BASE/R&D/memory/architecture.md"
}

@test "nombre que contiene FECHA o PROJECT_NAME no se corrompe al rellenar la plantilla" {
  run bash "$TARGET" FECHA-app
  [ "$status" -eq 0 ]
  [ "$(head -1 "$BASE/FECHA-app/memory/MEMORY.md")" = "# Memory — FECHA-app" ]
  run bash "$TARGET" PROJECT_NAME_x
  [ "$status" -eq 0 ]
  [ "$(head -1 "$BASE/PROJECT_NAME_x/memory/MEMORY.md")" = "# Memory — PROJECT_NAME_x" ]
}

@test "ruta con espacios: nombre con espacios funciona y cuenta como un proyecto" {
  run bash "$TARGET" "Mi Proyecto Grande"
  [ "$status" -eq 0 ]
  [ "$(head -1 "$BASE/Mi Proyecto Grande/memory/MEMORY.md")" = "# Memory — Mi Proyecto Grande" ]
  [ "$(ls "$BASE" | wc -l)" -eq 1 ]
}

@test "invalid: nombre con / se rechaza con exit 2 y sin crear nada" {
  run bash "$TARGET" 'a/b'
  [ "$status" -eq 2 ]
  [[ "$output" == *"nombre de proyecto inválido"* ]]
  [ -z "$(all_files)" ]
}

@test "reject: path traversal ../ no escribe fuera de ~/.savia/projects" {
  run bash "$TARGET" '../../escape'
  [ "$status" -eq 2 ]
  [ -z "$(all_files)" ]
  [ ! -e "$HOME/escape" ]
  run bash "$TARGET" '..'
  [ "$status" -eq 2 ]
  run bash "$TARGET" '.'
  [ "$status" -eq 2 ]
  [ -z "$(all_files)" ]
}

@test "reject: nombre con salto de línea o que empieza por guion se rechaza" {
  run bash "$TARGET" $'linea1\nlinea2'
  [ "$status" -eq 2 ]
  run bash "$TARGET" '-rf'
  [ "$status" -eq 2 ]
  [ -z "$(all_files)" ]
}

@test "empty: argumento vacío usa el basename de la raíz git" {
  repo="$TMP/repo con espacio"
  mkdir -p "$repo"
  git -C "$repo" init -q
  run bash -c 'cd "$1" && bash "$2" ""' _ "$repo" "$TARGET"
  [ "$status" -eq 0 ]
  [ -f "$BASE/repo con espacio/memory/MEMORY.md" ]
}

@test "SAVIA_MEMORY_DIR redirige el destino y no toca ~/.savia" {
  export SAVIA_MEMORY_DIR="$TMP/otra ruta/mem"
  run bash "$TARGET" mi-api
  [ "$status" -eq 0 ]
  [ -f "$TMP/otra ruta/mem/MEMORY.md" ]
  [ ! -e "$HOME/.savia" ]
}

@test "error: sin HOME ni SAVIA_MEMORY_DIR falla con exit 2 y mensaje claro" {
  run env -u HOME -u SAVIA_MEMORY_DIR bash "$TARGET" mi-api
  [ "$status" -eq 2 ]
  [[ "$output" == *"HOME"* ]]
  [[ "$output" != *"unbound"* && "$output" != *"sin asignar"* ]]
}

@test "error: destino no escribible falla con exit distinto de 0 y no deja MEMORY.md a medias" {
  mkdir -p "$BASE"
  chmod 0555 "$BASE"
  run bash "$TARGET" mi-api
  chmod 0755 "$BASE"
  [ "$status" -ne 0 ]
  [ ! -e "$BASE/mi-api/memory/MEMORY.md" ]
}

@test "concurrencia: 20 rondas de 8 ejecuciones simultáneas dejan 6 ficheros completos y ningún temporal" {
  # La versión con cat > + sed -i fallaba ~1 de cada 20 rondas (medido: 2/40).
  for round in $(seq 1 20); do
    d="$BASE/p$round/memory"
    pids=()
    for i in 1 2 3 4 5 6 7 8; do
      bash "$TARGET" "p$round" >"$TMP/out.$round.$i" 2>&1 &
      pids+=("$!")
    done
    rc=0
    for p in "${pids[@]}"; do wait "$p" || rc=1; done
    [ "$rc" -eq 0 ]
    [ "$(find "$d" -type f | wc -l)" -eq 6 ]
    [ "$(head -1 "$d/MEMORY.md")" = "# Memory — p$round" ]
    grep -qF "(pendiente de primera sync)" "$d/MEMORY.md"
    [ "$(grep -c '^# Memory' "$d/MEMORY.md")" -eq 1 ]
    [ "$(grep -c '^# ' "$d/debugging.md")" -eq 1 ]
  done
}

@test "locale es_ES: la fecha sigue en formato ISO y nada depende de la coma decimal" {
  run env LC_ALL=es_ES.UTF-8 LANG=es_ES.UTF-8 bash "$TARGET" mi-api
  [ "$status" -eq 0 ]
  grep -qE '^> Última sync: [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$BASE/mi-api/memory/MEMORY.md"
}

@test "boundary: nombre largo (200 chars) funciona; 300 chars se rechaza sin crear nada" {
  long="$(printf 'a%.0s' $(seq 1 200))"
  run bash "$TARGET" "$long"
  [ "$status" -eq 0 ]
  [ -f "$BASE/$long/memory/MEMORY.md" ]
  huge="$(printf 'b%.0s' $(seq 1 300))"
  run bash "$TARGET" "$huge"
  [ "$status" -eq 2 ]
  [ ! -e "$BASE/$huge" ]
}

@test "contrato skill: los /comandos que anuncian la skill y su comando existen (sin /onboarding-ask fantasma)" {
  missing=""
  for f in "$REPO_ROOT/.claude/skills/onboarding-dev/SKILL.md" "$REPO_ROOT/.claude/commands/onboarding-dev.md"; do
    while read -r cmd; do
      [ -z "$cmd" ] && continue
      case "$cmd" in compact) continue ;; esac   # built-in del frontend
      [ -f "$REPO_ROOT/.claude/commands/$cmd.md" ] || missing+=" $cmd"
    done < <(grep -oE '(^|[[:space:]`(])/[a-z][a-z0-9-]+([[:space:]`)]|$)' "$f" | tr -d ' `()/' | sort -u)
  done
  [ -z "$missing" ] || { echo "comandos inexistentes:$missing"; false; }
}

@test "contrato skill: projects/*/onboarding/ está git-ignorado (RN-ONB-01)" {
  run git -C "$REPO_ROOT" check-ignore -q "projects/mi-api/onboarding/01-arquitectura-alto-nivel.md"
  [ "$status" -eq 0 ]
  run git -C "$REPO_ROOT" check-ignore -q "projects/mi-api/onboarding/ana-plan-30-60-90.md"
  [ "$status" -eq 0 ]
}
