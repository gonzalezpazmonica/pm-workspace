#!/bin/bash
set -uo pipefail
# savia-goal.sh — Goal lifecycle management for Savia
# Usage:
#   savia-goal.sh status [--json]          Show current goal status
#   savia-goal.sh set "objective"          Create a new goal
#   savia-goal.sh pause                    Pause active goal
#   savia-goal.sh resume                   Resume paused goal
#   savia-goal.sh clear                    Clear current goal (interactive confirm)
#   savia-goal.sh history [--json] [N]     Show goal history
#   savia-goal.sh advance                  Increment turns_spent (called after each turn)
#   savia-goal.sh verify                   Increment verification_rounds
#   savia-goal.sh auto-inject              Print goal context for prompt injection

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEMORY_DIR="${SAVIA_WORKSPACE_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}/.savia-memory/goals"
CURRENT="${MEMORY_DIR}/current.json"
HISTORY="${MEMORY_DIR}/history.jsonl"
MKDIR=$(mkdir -p "$MEMORY_DIR" 2>/dev/null || true)

# ── Help ──────────────────────────────────────────────────────────────────────

usage() {
  cat <<'EOF'
Usage: savia-goal.sh <subcommand> [args]

Subcommands:
  status [--json]            Show current goal
  set "objective"            Create new goal
  pause                      Pause active goal
  resume                     Resume paused goal
  clear                      Clear goal (with confirm)
  history [--json] [N]       Show last N goals (default 10)
  advance                    +1 turns_spent, check budget
  verify                     +1 verification_rounds
  auto-inject                Print goal injection text for prompt

States: pursuing | paused | achieved | blocked | budget_exceeded
Files:  .savia-memory/goals/current.json
        .savia-memory/goals/history.jsonl
EOF
}

# ── Helpers ───────────────────────────────────────────────────────────────────

now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
gen_id() { echo "goal-$(date +%Y%m%d)-$(printf "%03d" "$(($(date +%s) % 1000))")"; }

read_current() {
  if [[ -f "$CURRENT" ]]; then
    cat "$CURRENT"
  fi
}

write_current() {
  echo "$1" > "$CURRENT"
}

append_history() {
  local event="$1" state="${2:-}" obj="${3:-}"
  echo "{\"timestamp\":\"$(now)\",\"event\":\"${event}\",\"state\":\"${state}\",\"objective\":\"${obj}\"}" >> "$HISTORY"
}

# ── Get field from current.json ───────────────────────────────────────────────

get_field() {
  local field="$1"
  read_current | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('${field}',''))" 2>/dev/null
}

# ── Status ────────────────────────────────────────────────────────────────────

cmd_status() {
  local fmt="${1:-}"
  local cur
  cur=$(read_current)
  if [[ -z "$cur" ]]; then
    if [[ "$fmt" == "--json" ]]; then
      echo '{"active":false}'
    else
      echo "No hay goal activo. Usa savia-goal.sh set \"objetivo\" para crear uno."
    fi
    return 0
  fi

  if [[ "$fmt" == "--json" ]]; then
    echo "$cur"
    return 0
  fi

  local state objective turns budget verifications sprint pbi created updated
  state=$(echo "$cur" | python3 -c "import sys,json; print(json.load(sys.stdin)['state'])")
  objective=$(echo "$cur" | python3 -c "import sys,json; print(json.load(sys.stdin)['objective'])")
  turns=$(echo "$cur" | python3 -c "import sys,json; print(json.load(sys.stdin)['turns_spent'])")
  budget=$(echo "$cur" | python3 -c "import sys,json; print(json.load(sys.stdin)['budget_limit_turns'])")
  verifications=$(echo "$cur" | python3 -c "import sys,json; print(json.load(sys.stdin)['verification_rounds'])")
  sprint=$(echo "$cur" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sprint_ref','-'))")
  pbi=$(echo "$cur" | python3 -c "import sys,json; print(json.load(sys.stdin).get('pbi_ref','-'))")
  created=$(echo "$cur" | python3 -c "import sys,json; print(json.load(sys.stdin)['created_at'])")
  updated=$(echo "$cur" | python3 -c "import sys,json; print(json.load(sys.stdin)['updated_at'])")

  local emoji label
  case "$state" in
    pursuing)      emoji="🟢"; label="Activo" ;;
    paused)        emoji="🟡"; label="Pausado" ;;
    achieved)      emoji="✅"; label="Completado" ;;
    blocked)       emoji="🔴"; label="Bloqueado" ;;
    budget_exceeded) emoji="⚠️"; label="Presupuesto excedido" ;;
    *)             emoji="❓"; label="$state" ;;
  esac

  echo ""
  echo "${emoji} Savia Goal — ${label} desde ${created}"
  echo ""
  echo "Objetivo: \"${objective}\""
  echo "Estado: ${state}"
  echo "Turns: ${turns}/${budget} · Verificaciones: ${verifications}/1"
  echo "Sprint: ${sprint} · PBI: ${pbi}"
  echo "Creado: ${created} · Actualizado: ${updated}"
  echo ""
  echo "Acciones: /savia-goal pause | /savia-goal clear | /savia-goal resume"
}

# ── Set ───────────────────────────────────────────────────────────────────────

cmd_set() {
  local objective="$*"
  if [[ -z "$objective" ]]; then
    echo "ERROR: Especifica un objetivo: savia-goal.sh set \"texto del objetivo\""
    return 1
  fi

  local cur
  cur=$(read_current)
  if [[ -n "$cur" ]]; then
    local state
    state=$(echo "$cur" | python3 -c "import sys,json; print(json.load(sys.stdin)['state'])")
    if [[ "$state" == "pursuing" || "$state" == "paused" ]]; then
      echo "Ya hay un goal activo: \"$(echo "$cur" | python3 -c "import sys,json; print(json.load(sys.stdin)['objective'])")\" (${state})."
      echo "Usa savia-goal.sh clear antes de establecer uno nuevo."
      return 1
    fi
  fi

  # Estimate turns
  local estimated=15
  if echo "$objective" | grep -qiE "simple|corregir|fix|bug|arreglar|cambiar una línea"; then
    estimated=5
  elif echo "$objective" | grep -qiE "implementar|feature|crear|añadir|agregar|build"; then
    estimated=15
  elif echo "$objective" | grep -qiE "refactorizar|migrar|arquitectura|rediseñar|migración"; then
    estimated=30
  fi

  local budget=$((estimated * 5 / 2))  # 2.5x multiplier
  local id
  id=$(gen_id)
  local ts
  ts=$(now)

  # Detect sprint and PBI references
  local sprint_ref="null"
  local pbi_ref="null"
  if echo "$objective" | grep -qoP 'Sprint \d{4}-\d{2}'; then
    sprint_ref="\"$(echo "$objective" | grep -oP 'Sprint \d{4}-\d{2}')\""
  fi
  if echo "$objective" | grep -qoP 'AB#\d+'; then
    pbi_ref="\"$(echo "$objective" | grep -oP 'AB#\d+')\""
  fi

  local new_goal
  new_goal=$(cat <<GOALEOF
{
  "id": "${id}",
  "objective": "${objective}",
  "state": "pursuing",
  "created_at": "${ts}",
  "updated_at": "${ts}",
  "paused_at": null,
  "achieved_at": null,
  "turns_spent": 0,
  "estimated_turns": ${estimated},
  "budget_limit_turns": ${budget},
  "block_reason": null,
  "verification_rounds": 0,
  "sprint_ref": ${sprint_ref},
  "pbi_ref": ${pbi_ref}
}
GOALEOF
)

  write_current "$new_goal"
  append_history "set" "pursuing" "$objective"

  echo ""
  echo "Goal establecido: \"${objective}\""
  echo "   Sprint: ${sprint_ref} · Estimado: ${estimated} turns · Máx: ${budget}"
  echo ""
  echo "   Savia perseguirá este objetivo en cada turno hasta completarlo."
  echo "   Verificación obligatoria antes de marcar achieved (Rule #22)."
}

# ── Pause ─────────────────────────────────────────────────────────────────────

cmd_pause() {
  local cur
  cur=$(read_current)
  if [[ -z "$cur" ]]; then
    echo "No hay goal activo para pausar."
    return 1
  fi

  local state objective
  state=$(echo "$cur" | python3 -c "import sys,json; print(json.load(sys.stdin)['state'])")
  objective=$(echo "$cur" | python3 -c "import sys,json; print(json.load(sys.stdin)['objective'])")

  if [[ "$state" == "paused" ]]; then
    local paused_at
    paused_at=$(echo "$cur" | python3 -c "import sys,json; print(json.load(sys.stdin)['paused_at'])")
    echo "El goal ya está pausado desde ${paused_at}."
    return 0
  fi
  if [[ "$state" != "pursuing" ]]; then
    echo "Solo se puede pausar un goal en estado 'pursuing' (actual: ${state})."
    return 1
  fi

  local ts
  ts=$(now)
  local updated
  updated=$(echo "$cur" | python3 -c "import sys,json; d=json.load(sys.stdin); d['state']='paused'; d['paused_at']='${ts}'; d['updated_at']='${ts}'; print(json.dumps(d))")
  write_current "$updated"
  append_history "pause" "paused" "$objective"

  echo "🟡 Goal pausado. Usa savia-goal.sh resume para continuar."
}

# ── Resume ────────────────────────────────────────────────────────────────────

cmd_resume() {
  local cur
  cur=$(read_current)
  if [[ -z "$cur" ]]; then
    echo "No hay goal para reanudar."
    return 1
  fi

  local state objective
  state=$(echo "$cur" | python3 -c "import sys,json; print(json.load(sys.stdin)['state'])")
  objective=$(echo "$cur" | python3 -c "import sys,json; print(json.load(sys.stdin)['objective'])")

  if [[ "$state" == "pursuing" ]]; then
    echo "El goal ya está activo."
    return 0
  fi
  if [[ "$state" != "paused" ]]; then
    echo "Solo se puede reanudar un goal en estado 'paused' (actual: ${state})."
    return 1
  fi

  local ts
  ts=$(now)
  local updated
  updated=$(echo "$cur" | python3 -c "import sys,json; d=json.load(sys.stdin); d['state']='pursuing'; d['paused_at']=None; d['updated_at']='${ts}'; print(json.dumps(d))")
  write_current "$updated"
  append_history "resume" "pursuing" "$objective"

  local turns budget
  turns=$(echo "$updated" | python3 -c "import sys,json; print(json.load(sys.stdin)['turns_spent'])")
  budget=$(echo "$updated" | python3 -c "import sys,json; print(json.load(sys.stdin)['budget_limit_turns'])")
  echo "🟢 Goal reanudado: ${objective} [${turns}/${budget}]"
}

# ── Clear ─────────────────────────────────────────────────────────────────────

cmd_clear() {
  local cur
  cur=$(read_current)
  if [[ -z "$cur" ]]; then
    echo "No hay goal activo para borrar."
    return 1
  fi

  local objective state
  objective=$(echo "$cur" | python3 -c "import sys,json; print(json.load(sys.stdin)['objective'])")
  state=$(echo "$cur" | python3 -c "import sys,json; print(json.load(sys.stdin)['state'])")

  # Interactive confirm
  echo "¿Borrar goal '${objective}' (${state})? (s/n)"
  read -r confirm
  if [[ "$confirm" != "s" && "$confirm" != "S" && "$confirm" != "si" && "$confirm" != "sí" && "$confirm" != "y" && "$confirm" != "yes" ]]; then
    echo "Cancelado."
    return 0
  fi

  append_history "cleared" "$state" "$objective"
  rm -f "$CURRENT"
  local count
  count=$(wc -l < "$HISTORY" 2>/dev/null || echo "0")
  echo "Goal borrado. ${count} entradas en historial."
}

# ── History ───────────────────────────────────────────────────────────────────

cmd_history() {
  local fmt="${1:-}"
  local n="${2:-10}"

  if [[ "$fmt" == "--json" ]]; then
    if [[ -f "$HISTORY" ]]; then
      tail -n "$n" "$HISTORY" | python3 -c "
import sys, json
lines = [json.loads(l.strip()) for l in sys.stdin if l.strip()]
print(json.dumps(lines, indent=2))
" 2>/dev/null || echo "[]"
    else
      echo "[]"
    fi
    return 0
  fi

  if [[ ! -f "$HISTORY" ]]; then
    echo "No hay historial de goals."
    return 0
  fi

  echo ""
  echo "Historial de goals (últimos ${n}):"
  echo "──────────────────────────────────────────────────────────────"
  tail -n "$n" "$HISTORY" | while IFS= read -r line; do
    local ts event state obj
    ts=$(echo "$line" | python3 -c "import sys,json; print(json.loads(sys.stdin).get('timestamp',''))" 2>/dev/null)
    event=$(echo "$line" | python3 -c "import sys,json; print(json.loads(sys.stdin).get('event',''))" 2>/dev/null)
    state=$(echo "$line" | python3 -c "import sys,json; print(json.loads(sys.stdin).get('state',''))" 2>/dev/null)
    obj=$(echo "$line" | python3 -c "import sys,json; print(json.loads(sys.stdin).get('objective',''))" 2>/dev/null)
    printf "%-20s  %-8s  %-10s  %.60s\n" "${ts:0:19}" "$event" "$state" "$obj"
  done
  echo "──────────────────────────────────────────────────────────────"
}

# ── Advance (called after each turn) ──────────────────────────────────────────

cmd_advance() {
  local cur
  cur=$(read_current)
  if [[ -z "$cur" ]]; then
    return 0  # No goal, no-op
  fi

  local state
  state=$(echo "$cur" | python3 -c "import sys,json; print(json.load(sys.stdin)['state'])")
  if [[ "$state" != "pursuing" ]]; then
    return 0
  fi

  local ts
  ts=$(now)
  local updated
  updated=$(echo "$cur" | python3 -c "
import sys, json
d = json.load(sys.stdin)
d['turns_spent'] = d['turns_spent'] + 1
d['updated_at'] = '${ts}'
print(json.dumps(d))
")
  write_current "$updated"

  local turns budget
  turns=$(echo "$updated" | python3 -c "import sys,json; print(json.load(sys.stdin)['turns_spent'])")
  budget=$(echo "$updated" | python3 -c "import sys,json; print(json.load(sys.stdin)['budget_limit_turns'])")

  # Budget guard
  local pct=$((turns * 100 / budget))
  if [[ $turns -ge $budget ]]; then
    local exceeded
    exceeded=$(echo "$updated" | python3 -c "
import sys, json
d = json.load(sys.stdin)
d['state'] = 'budget_exceeded'
d['updated_at'] = '${ts}'
print(json.dumps(d))
")
    write_current "$exceeded"
    echo "⚠️  GOAL: Presupuesto excedido (${turns}/${budget} turns). Goal marcado como budget_exceeded."
  elif [[ $pct -ge 80 ]]; then
    echo "⚠️  GOAL: ${pct}% del presupuesto consumido (${turns}/${budget} turns). ¿Ajustar presupuesto?"
  fi
}

# ── Verify ────────────────────────────────────────────────────────────────────

cmd_verify() {
  local cur
  cur=$(read_current)
  if [[ -z "$cur" ]]; then
    echo "No hay goal activo para verificar."
    return 1
  fi

  local ts
  ts=$(now)
  local updated
  updated=$(echo "$cur" | python3 -c "
import sys, json
d = json.load(sys.stdin)
d['verification_rounds'] = d['verification_rounds'] + 1
d['updated_at'] = '${ts}'
print(json.dumps(d))
")
  write_current "$updated"

  local rounds objective
  rounds=$(echo "$updated" | python3 -c "import sys,json; print(json.load(sys.stdin)['verification_rounds'])")
  objective=$(echo "$updated" | python3 -c "import sys,json; print(json.load(sys.stdin)['objective'])")
  echo "Verificación ${rounds}/1 completada para: ${objective}"
}

# ── Auto Inject ───────────────────────────────────────────────────────────────

cmd_auto_inject() {
  local cur
  cur=$(read_current)
  if [[ -z "$cur" ]]; then
    return 0  # No goal to inject
  fi

  local state objective turns budget verifications sprint pbi
  state=$(echo "$cur" | python3 -c "import sys,json; print(json.load(sys.stdin)['state'])")
  objective=$(echo "$cur" | python3 -c "import sys,json; print(json.load(sys.stdin)['objective'])")
  turns=$(echo "$cur" | python3 -c "import sys,json; print(json.load(sys.stdin)['turns_spent'])")
  budget=$(echo "$cur" | python3 -c "import sys,json; print(json.load(sys.stdin)['budget_limit_turns'])")
  verifications=$(echo "$cur" | python3 -c "import sys,json; print(json.load(sys.stdin)['verification_rounds'])")
  sprint=$(echo "$cur" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sprint_ref','-'))")
  pbi=$(echo "$cur" | python3 -c "import sys,json; print(json.load(sys.stdin).get('pbi_ref','-'))")

  case "$state" in
    pursuing)
      cat <<INJECT

GOAL ACTIVO: ${objective}
Progreso: ${turns}/${budget} turns · Verificaciones: ${verifications}/1
Sprint: ${sprint} · PBI: ${pbi}

INSTRUCCIÓN: Al final de este turno, verifica el progreso contra el goal.
Si el goal está completado, ejecuta: bash scripts/savia-goal.sh verify
NUNCA marques el goal como achieved sin verification_rounds >= 1 (Rule #22).
INJECT
      ;;
    paused)
      echo ""
      echo "GOAL PAUSADO: ${objective}"
      echo "Usa /savia-goal resume para continuar."
      ;;
    budget_exceeded)
      echo ""
      echo "GOAL EXCEDIDO: ${objective} — ${turns}/${budget} turns."
      echo "Usa /savia-goal clear para descartar o ajusta el presupuesto."
      ;;
    blocked)
      echo ""
      echo "GOAL BLOQUEADO: ${objective}"
      local reason
      reason=$(echo "$cur" | python3 -c "import sys,json; print(json.load(sys.stdin).get('block_reason','Sin razón'))")
      echo "Razón: ${reason}"
      ;;
  esac
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

case "${1:-}" in
  status)     shift; cmd_status "$@" ;;
  set)        shift; cmd_set "$@" ;;
  pause)      cmd_pause ;;
  resume)     cmd_resume ;;
  clear)      cmd_clear ;;
  history)    shift; cmd_history "$@" ;;
  advance)    cmd_advance ;;
  verify)     cmd_verify ;;
  auto-inject) cmd_auto_inject ;;
  -h|--help|help) usage ;;
  "")
    cmd_status
    ;;
  *)
    # Assume it's an objective if no known subcommand
    cmd_set "$@"
    ;;
esac
