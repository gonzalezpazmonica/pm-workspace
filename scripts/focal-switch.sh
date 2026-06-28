#!/usr/bin/env bash
# focal-switch.sh — Off-load de contexto antes de cambiar de nido (SE-230 Slice 1)
# Usage: focal-switch.sh --from <nido> --to <nido>
#        focal-switch.sh --save-only [--nido <name>] [--task "desc"]
set -uo pipefail

SAVIA_DIR="${HOME}/.savia"
FOCAL_DIR="${SAVIA_DIR}/focal-state"
SWITCH_LOG="${SAVIA_DIR}/.switch-log"
LOCK_FILE="${SAVIA_DIR}/focal-state.lock"

mkdir -p "$FOCAL_DIR"

# ── Parse args ───────────────────────────────────────────────────────────────
FROM_NIDO=""
TO_NIDO=""
TASK_DESC=""
SAVE_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from)      FROM_NIDO="$2";  shift 2 ;;
    --to)        TO_NIDO="$2";    shift 2 ;;
    --nido)      FROM_NIDO="$2";  shift 2 ;;
    --task)      TASK_DESC="$2";  shift 2 ;;
    --save-only) SAVE_ONLY=1;     shift ;;
    *)           shift ;;
  esac
done

# Inferir nido actual si no se especificó
if [[ -z "$FROM_NIDO" ]]; then
  if [[ -n "${SAVIA_NIDO:-}" ]]; then
    FROM_NIDO="$SAVIA_NIDO"
  else
    # Inferir desde cwd
    NIDOS_BASE="${HOME}/.savia/nidos"
    if [[ "$PWD" == "${NIDOS_BASE}"/* ]]; then
      FROM_NIDO="${PWD#"${NIDOS_BASE}"/}"
      FROM_NIDO="${FROM_NIDO%%/*}"
    fi
  fi
fi

if [[ -z "$FROM_NIDO" ]]; then
  echo "ERROR: no se pudo determinar el nido origen. Usa --from <nido> o --nido <nido>." >&2
  exit 1
fi

_now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
_now_epoch() { date +%s; }

_json_field() {
  local json="$1" key="$2"
  local val
  val=$(printf '%s' "$json" | grep -oP "\"${key}\"\\s*:\\s*\"\\K[^\"]*" 2>/dev/null || true)
  if [[ -z "$val" ]]; then
    val=$(printf '%s' "$json" | grep -oP "\"${key}\"\\s*:\\s*\\K(true|false|null|[0-9]+)" 2>/dev/null || true)
  fi
  printf '%s' "$val"
}

STATE_FILE="${FOCAL_DIR}/${FROM_NIDO}.json"

# ── Leer estado actual ────────────────────────────────────────────────────────
existing_json="{}"
if [[ -f "$STATE_FILE" ]]; then
  existing_json=$(cat "$STATE_FILE" 2>/dev/null) || existing_json="{}"
fi

# ── Obtener context_summary ────────────────────────────────────────────────────
context_summary=""
if [[ -n "$TASK_DESC" ]]; then
  context_summary="$TASK_DESC"
else
  # Leer contexto existente
  context_summary=$(_json_field "$existing_json" "context_summary")
fi

if [[ -z "$context_summary" && $SAVE_ONLY -eq 0 && -t 0 ]]; then
  # Pedir al usuario solo si es terminal interactivo
  read -r -p "Describe brevemente el estado actual de ${FROM_NIDO} (Enter para omitir): " context_summary || true
fi
[[ -z "$context_summary" ]] && context_summary="Estado guardado por focal-switch"

# ── Recuperar campos existentes ────────────────────────────────────────────────
nido_val=$(_json_field "$existing_json" "nido")
[[ -z "$nido_val" ]] && nido_val="$FROM_NIDO"

branch_val=$(_json_field "$existing_json" "branch")
if [[ -z "$branch_val" ]]; then
  branch_val=$(git -C "${HOME}/.savia/nidos/${FROM_NIDO}" branch --show-current 2>/dev/null || echo "N/A")
fi

task_val=$(_json_field "$existing_json" "task")
last_action=$(_json_field "$existing_json" "last_action")
last_commit=$(_json_field "$existing_json" "last_commit_hash")
if [[ -z "$last_commit" ]]; then
  last_commit=$(git -C "${HOME}/.savia/nidos/${FROM_NIDO}" rev-parse --short HEAD 2>/dev/null || echo "")
fi
created_at=$(_json_field "$existing_json" "created_at")
[[ -z "$created_at" ]] && created_at=$(_now_iso)

waiting_for=$(_json_field "$existing_json" "waiting_for")
[[ -z "$waiting_for" ]] && waiting_for="null"

interval=$(_json_field "$existing_json" "check_in_interval_min")
[[ -z "$interval" ]] && interval=10

# ── Construir nuevo JSON ───────────────────────────────────────────────────────
now=$(_now_iso)

# Determinar status
new_status="paused"
[[ $SAVE_ONLY -eq 1 ]] && new_status="paused"

# Preservar next_human_decision si existía
nhd_block=""
nhd_block=$(printf '%s' "$existing_json" | grep -oP '"next_human_decision"\s*:\s*\{[^}]*\}' 2>/dev/null || true)
if [[ -n "$nhd_block" ]]; then
  nhd_section="\"next_human_decision\": ${nhd_block#*\"next_human_decision\": }"
else
  nhd_section='"next_human_decision": null'
fi

# Escapar para JSON
_esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

new_json=$(cat <<EOF
{
  "nido": "$(_esc "$nido_val")",
  "branch": "$(_esc "$branch_val")",
  "task": "$(_esc "$task_val")",
  "status": "$new_status",
  "last_action": "$(_esc "$last_action")",
  "context_summary": "$(_esc "${context_summary:0:200}")",
  "waiting_for": $(if [[ "$waiting_for" == "null" || -z "$waiting_for" ]]; then echo "null"; else echo "\"$(_esc "$waiting_for")\""; fi),
  ${nhd_section},
  "check_in_interval_min": ${interval},
  "session_pid": $$,
  "last_commit_hash": "$(_esc "$last_commit")",
  "created_at": "$(_esc "$created_at")",
  "updated_at": "$now"
}
EOF
)

# ── Escribir con flock ─────────────────────────────────────────────────────────
(
  flock -w 5 200 || { echo "ERROR: flock timeout en focal-switch" >&2; exit 1; }
  printf '%s\n' "$new_json" > "$STATE_FILE"
) 200>"$LOCK_FILE"

# ── Registrar en .switch-log ───────────────────────────────────────────────────
if [[ $SAVE_ONLY -eq 0 && -n "$TO_NIDO" ]]; then
  printf '%s %s→%s\n' "$now" "$FROM_NIDO" "$TO_NIDO" >> "$SWITCH_LOG"
fi

# ── Heartbeat en session-registry (SE-229 Slice 4) ────────────────────────────
REGISTRY="${HOME}/.savia/nidos/se229-session-sync/scripts/session-registry.sh"
if [[ -f "$REGISTRY" && -x "$REGISTRY" ]]; then
  bash "$REGISTRY" heartbeat --nido "$FROM_NIDO" >/dev/null 2>&1 || true
fi

# ── Mostrar contexto del nido destino ─────────────────────────────────────────
if [[ $SAVE_ONLY -eq 0 && -n "$TO_NIDO" ]]; then
  to_state="${FOCAL_DIR}/${TO_NIDO}.json"
  if [[ -f "$to_state" ]]; then
    to_json=$(cat "$to_state" 2>/dev/null) || to_json="{}"
    to_summary=$(_json_field "$to_json" "context_summary")
    to_branch=$(_json_field "$to_json" "branch")
    to_task=$(_json_field "$to_json" "task")
    echo "--- Contexto de ${TO_NIDO} ---"
    [[ -n "$to_branch" ]] && echo "Rama: $to_branch"
    [[ -n "$to_task" ]]   && echo "Tarea: $to_task"
    [[ -n "$to_summary" ]] && echo "Resumen: $to_summary"
    echo "---"
  else
    echo "Nido destino ${TO_NIDO}: sin estado guardado"
  fi
  echo "Cambio registrado: ${FROM_NIDO} → ${TO_NIDO}"
else
  echo "Estado de ${FROM_NIDO} guardado (status=paused)"
fi

exit 0
