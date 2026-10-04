#!/usr/bin/env bats
# Tests de comportamiento del motor de criticidad de la skill smart-calendar
# (criticality.sh + criticality-engine.sh + criticality-scoring.sh + criticality-items.sh).
# Ref: .claude/skills/smart-calendar/SKILL.md
# Ref: .claude/skills/smart-calendar/spec-task-criticality.md
# Ref: docs/propuestas/SE-376-debt-inventory.tsv
#
# Nunca toca projects/ reales: copia los scripts a un workspace sintetico
# en mktemp -d (WORKSPACE_ROOT se deriva de la ubicacion del script).

SCRIPT="scripts/criticality.sh"
ENGINE="scripts/criticality-engine.sh"
SCORING="scripts/criticality-scoring.sh"
ITEMS="scripts/criticality-items.sh"

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMP_DIR="$(mktemp -d)"
  WS="$TMP_DIR/ws"
  mkdir -p "$WS/scripts" "$WS/projects/alpha/backlog"
  cp "$REPO/$SCRIPT" "$REPO/$ENGINE" "$REPO/$SCORING" "$REPO/$ITEMS" "$WS/scripts/"
  CRIT="$WS/$SCRIPT"
  BL="$WS/projects/alpha/backlog"
  export CRITICALITY_TODAY="2026-03-10"
}

teardown() {
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

# item <fichero> <lineas de frontmatter...>
item() {
  local f="$1"; shift
  mkdir -p "$(dirname "$f")"
  { echo "---"; printf '%s\n' "$@"; echo "---"; echo "Cuerpo."; } > "$f"
}

@test "safety: los cuatro scripts declaran set -uo pipefail" {
  for s in "$SCRIPT" "$ENGINE" "$SCORING" "$ITEMS"; do
    run grep -c '^set -uo pipefail' "$REPO/$s"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
  done
}

@test "assess: score exacto en centesimas y clasificacion P0" {
  item "$BL/PBI-1.md" "title: Login" "impact: 5" "dependencies: 4" \
    "story_points: 2" "deadline: 2026-03-11" "assigned_to: ana"
  run bash "$CRIT" assess PBI-1 --project alpha
  [ "$status" -eq 0 ]
  [[ "$output" == *"Assessment: PBI-1 — Login"* ]]
  [[ "$output" == *"(1d)"* ]]
  [[ "$output" == *"Score: 4.80 → P0 Critical"* ]]
}

@test "assess: id exacto, PBI-1 no resuelve a PBI-12 (substring)" {
  item "$BL/PBI-12.md" "title: Doce" "impact: 1"
  item "$BL/PBI-1.md" "title: Uno" "impact: 5"
  run bash "$CRIT" assess PBI-1 --project alpha
  [ "$status" -eq 0 ]
  [[ "$output" == *"— Uno"* ]]
  [[ "$output" != *"Doce"* ]]
}

@test "assess: sin --project busca en todos los proyectos" {
  item "$WS/projects/beta/backlog/PBI-7.md" "title: Siete"
  run bash "$CRIT" assess PBI-7
  [ "$status" -eq 0 ]
  [[ "$output" == *"— Siete"* ]]
}

@test "assess: formato de plantilla local (id frontmatter, state, estimation_sp, comillas)" {
  item "$BL/pbi/PBI-001-login.md" "id: PBI-001" 'title: "Login page"' \
    "state: Active" "estimation_sp: 13" 'assigned_to: ""'
  run bash "$CRIT" assess pbi-001 --project alpha
  [ "$status" -eq 0 ]
  [[ "$output" == *"— Login page"* ]]
  [[ "$output" != *'"Login page"'* ]]
  [[ "$output" == *"State: Active | SP: 13 | Assigned: unassigned"* ]]
  [[ "$output" == *"Effort inv   ██░░░ 2/5"* ]]
}

@test "assess: id ambiguo falla con exit 2 y lista candidatos" {
  item "$WS/projects/alpha/backlog/PBI-3.md" "title: A"
  item "$WS/projects/beta/backlog/PBI-3.md" "title: B"
  run bash "$CRIT" assess PBI-3
  [ "$status" -eq 2 ]
  [[ "$output" == *"ambiguous"* ]]
  [[ "$output" == *"alpha"* && "$output" == *"beta"* ]]
}

@test "assess: item inexistente falla con exit 1" {
  run bash "$CRIT" assess PBI-404 --project alpha
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

@test "assess: id vacio es error de uso (exit 2)" {
  run bash "$CRIT" assess
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage"* ]]
}

@test "assess: rechaza id con comodines y proyecto con traversal" {
  item "$BL/PBI-1.md" "title: Uno"
  run bash "$CRIT" assess '*' --project alpha
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid item id"* ]]
  run bash "$CRIT" assess PBI-1 --project ../alpha
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid project"* ]]
  run bash "$CRIT" assess PBI-1 --project
  [ "$status" -eq 2 ]
}

@test "deadline entre comillas no se trata como vencido" {
  item "$BL/PBI-2.md" "title: Lejos" 'deadline: "2099-01-01"'
  run bash "$CRIT" assess PBI-2 --project alpha
  [ "$status" -eq 0 ]
  [[ "$output" == *"Urgency      ███░░ 3/5"* ]]
  [[ "$output" == *"(26595d)"* ]]
}

@test "deadline invalido: warning y sin urgencia maxima (reject)" {
  item "$BL/PBI-2.md" "title: Raro" "deadline: someday"
  item "$BL/PBI-3.md" "title: Imposible" "deadline: 2026-02-30"
  run bash "$CRIT" assess PBI-2 --project alpha
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARN: invalid deadline 'someday'"* ]]
  [[ "$output" == *"Urgency      ███░░ 3/5"* ]]
  run bash "$CRIT" assess PBI-3 --project alpha
  [[ "$output" == *"WARN: invalid deadline"* ]]
  [[ "$output" == *"Urgency      ███░░ 3/5"* ]]
}

@test "deadline hoy y vencido dan urgencia 5; a 10 dias base+1" {
  item "$BL/PBI-4.md" "title: Hoy" "deadline: 2026-03-10"
  item "$BL/PBI-5.md" "title: Diez" "deadline: 2026-03-20T12:00"
  run bash "$CRIT" assess PBI-4 --project alpha
  [[ "$output" == *"Urgency      █████ 5/5  x0.25  (0d)"* ]]
  run bash "$CRIT" assess PBI-5 --project alpha
  [[ "$output" == *"Urgency      ████░ 4/5  x0.25  (10d)"* ]]
}

@test "locale es_ES: coma decimal en SP e impacto sin errores aritmeticos" {
  item "$BL/PBI-6.md" "title: Decimal" "story_points: 2,5" "impact: 4,5" "dependencies: 1.4"
  LC_ALL=es_ES.UTF-8 LANG=es_ES.UTF-8 run bash "$CRIT" assess PBI-6 --project alpha
  [ "$status" -eq 0 ]
  [[ "$output" != *"error"* ]]
  [[ "$output" == *"SP: 3 "* ]]
  [[ "$output" == *"Impact       █████ 5/5"* ]]
  [[ "$output" == *"Dependencies █░░░░ 1/5"* ]]
  [[ "$output" =~ Score:\ [0-9]\.[0-9]{2}\ → ]]
}

@test "inyeccion aritmetica en frontmatter no ejecuta comandos (reject)" {
  item "$BL/PBI-8.md" "title: Inj" "impact: W_IMPACT[\$(touch $TMP_DIR/PWNED)]" \
    "story_points: x[\$(touch $TMP_DIR/PWNED2)]"
  run bash "$CRIT" assess PBI-8 --project alpha
  [ "$status" -eq 0 ]
  [ ! -e "$TMP_DIR/PWNED" ]
  [ ! -e "$TMP_DIR/PWNED2" ]
  [[ "$output" == *"WARN: invalid impact"* ]]
  run bash "$CRIT" dashboard
  [ ! -e "$TMP_DIR/PWNED" ]
}

@test "impacto fuera de rango se acota a 5 y el score no supera 5.00 (boundary)" {
  item "$BL/PBI-9.md" "title: Grande" "impact: 99" "dependencies: 0"
  run bash "$CRIT" assess PBI-9 --project alpha
  [ "$status" -eq 0 ]
  [[ "$output" == *"Impact       █████ 5/5"* ]]
  [[ "$output" == *"Dependencies █░░░░ 1/5"* ]]
  [[ "$output" == *"Score: 3.70 → P1 High"* ]]
}

@test "classify: limites exactos 400/399/300/200/199 y score cero" {
  run bash -c "SCRIPT_DIR='$WS/scripts'; source '$WS/$SCORING'; for s in 400 399 300 200 199 0; do classify \$s; done; score_display 0; score_display 325; score_display 500"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "P0 Critical" ]
  [ "${lines[1]}" = "P1 High" ]
  [ "${lines[2]}" = "P1 High" ]
  [ "${lines[3]}" = "P2 Medium" ]
  [ "${lines[4]}" = "P3 Low" ]
  [ "${lines[5]}" = "P3 Low" ]
  [ "${lines[6]}" = "0.00" ]
  [ "${lines[7]}" = "3.25" ]
  [ "${lines[8]}" = "5.00" ]
}

@test "confidence decay: item sin tocar 40 dias aplica 75%" {
  item "$BL/PBI-10.md" "title: Viejo"
  touch -d "@$(( $(date +%s) - 40 * 86400 ))" "$BL/PBI-10.md"
  run bash "$CRIT" assess PBI-10 --project alpha
  [[ "$output" == *"(decay: 75%)"* ]]
}

@test "frontmatter: CRLF, sin frontmatter y separadores del cuerpo" {
  printf -- '---\r\ntitle: Windows\r\nimpact: 5\r\n---\r\n' > "$BL/PBI-11.md"
  printf 'Sin frontmatter\n---\nimpact: 5\n---\n' > "$BL/PBI-13.md"
  run bash "$CRIT" assess PBI-11 --project alpha
  [[ "$output" == *"— Windows"* ]]
  [[ "$output" == *"Impact       █████ 5/5"* ]]
  run bash "$CRIT" assess PBI-13 --project alpha
  [ "$status" -eq 0 ]
  [[ "$output" == *"— PBI-13"* ]]
  [[ "$output" == *"Impact       ███░░ 3/5"* ]]
}

@test "dashboard: excluye archive/ e items Done, ordena por score desc" {
  item "$BL/PBI-20.md" "title: Medio" "impact: 4"
  item "$BL/PBI-21.md" "title: Alto" "impact: 5" "assigned_to: eva"
  item "$BL/PBI-22.md" "title: Bajo" "impact: 3"
  item "$BL/PBI-23.md" "title: Hecho" "impact: 5" "state: Done"
  item "$BL/archive/PBI-24.md" "title: Archivado" "impact: 5"
  run bash "$CRIT" dashboard
  [ "$status" -eq 0 ]
  [[ "$output" != *"Hecho"* && "$output" != *"Archivado"* ]]
  [[ "$output" == *"P1 High (3)"* ]]
  [[ "$output" =~ Alto.*Medio.*Bajo ]]
  [[ "$output" == *"No alerts."* ]]
}

@test "dashboard: P0 sin asignar alerta; titulos con % y barra invertida literales" {
  item "$BL/PBI-30.md" 'title: 100% \c roto' "impact: 5" "dependencies: 5" "deadline: 2026-03-09"
  run bash "$CRIT" dashboard --project alpha
  [ "$status" -eq 0 ]
  [[ "$output" == *'100% \c roto | ?'* ]]
  [[ "$output" == *'ALERT: P0 unassigned — 100% \c roto'* ]]
}

@test "dashboard: workspace vacio devuelve exit 0 con mensaje" {
  run bash "$CRIT" dashboard
  [ "$status" -eq 0 ]
  [[ "$output" == *"No items in local backlog."* ]]
}

@test "dashboard: proyecto inexistente es error (exit 1)" {
  run bash "$CRIT" dashboard --project nadie
  [ "$status" -eq 1 ]
  [[ "$output" == *"no local backlog"* ]]
}

@test "dashboard: proyecto con espacios en la ruta" {
  item "$WS/projects/beta team/backlog/PBI-40.md" "title: Espacio" "impact: 5"
  run bash "$CRIT" dashboard --project "beta team"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Espacio"* ]]
}

@test "dashboard: volumen grande (300 items) y >3 P0 alerta capacidad" {
  for i in $(seq 1 300); do
    printf -- '---\ntitle: T%s\nimpact: %s\ndependencies: 5\nassigned_to: x\n---\n' "$i" $(( i % 5 + 1 )) > "$BL/PBI-$i.md"
  done
  run bash "$CRIT" dashboard
  [ "$status" -eq 0 ]
  local total=0 n
  for n in $(grep -oE '\(([0-9]+)\)' <<< "$output" | tr -d '()'); do total=$(( total + n )); done
  [ "$total" -eq 300 ]
  [[ "$output" == *"capacity critical"* ]]
}

@test "rebalance: --project sin valor falla con exit 2 sin colgarse" {
  run timeout 10 bash "$CRIT" rebalance --project
  [ "$status" -eq 2 ]
  [[ "$output" == *"--project requires"* ]]
}

@test "rebalance --dry-run muestra el dashboard del proyecto" {
  item "$BL/PBI-50.md" "title: Reb"
  run bash "$CRIT" rebalance --project alpha --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Reb"* ]]
  [[ "$output" == *"/criticality-rebalance"* ]]
}

@test "subcomando desconocido es error (exit 2); help sale 0" {
  run bash "$CRIT" bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage"* ]]
  run bash "$CRIT" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"assess <item-id>"* ]]
}
