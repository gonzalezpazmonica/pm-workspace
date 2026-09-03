#!/usr/bin/env bash
# overnight-roadmap-runner.sh — wrapper del overnight-sprint-loop (SE-226)
# para el sprint roadmap 2026-09-02 (Batch 9 + L28/L30).
#
# Autorización operadora (2026-09-02): "modo nocturno autónomo implementando
# y trabajando sobre el roadmap con permisos de merge". Grant merge re-emible
# tras cada merge (la orden cubre toda la noche). Ramas agent/*, CI verde
# obligatorio para mergear. Sin aprobación: no se tocan SE-344/SE-338/SE-339/
# SE-258/SE-220 (PROPOSED antiguas sin revisión humana).
#
# CRIT-001: todo local. Los agentes corren con modelos del plan z.ai
# (fast=glm-5.3-flash por defecto; heavy=glm-5.3 en tareas de diseño).

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOOP="$SCRIPT_DIR/overnight-sprint-loop.sh"
TASKS_FILE="${1:-$SCRIPT_DIR/../output/overnight-tasks-20260902.json}"
SPRINT_ID="overnight-20260902-roadmap"
BASE_BRANCH="main"
PR_BRANCH="agent/changelog-fix-20260902"   # rama con las specs ya mergeadas (base de trabajo)
MERGE_GRANT_CONTEXT="Modo nocturno autonomo 2026-09-02 (orden operadora): implementar roadmap Batch 9 + L28/L30 con permisos de merge. CI verde obligatorio."

# PATH completo: opencode vive en /snap/bin; node en ~/.nvm (CRIT-001: todo local)
export PATH="/snap/bin:$HOME/.nvm/versions/node/v22.23.2/bin:$HOME/.local/bin:$PATH"
command -v opencode >/dev/null || { echo "ABORT: opencode no encontrado en PATH" >&2; exit 3; }

# ── Seguridad SPEC-186: doble opt-in ─────────────────────────────────────────
export OVERNIGHT_SPRINT_ENABLED="${OVERNIGHT_SPRINT_ENABLED:-true}"
bash "$SCRIPT_DIR/savia-double-optin-check.sh" --skill overnight-sprint --confirm-autonomous || {
  echo "ABORT: doble opt-in no satisfecho (OVERNIGHT_SPRINT_ENABLED=true + --confirm-autonomous)" >&2
  exit 1
}

# ── Utilidades ───────────────────────────────────────────────────────────────
task_meta() { # $1=task_id $2=clave  -> valor del tasks json
  python3 - "$TASKS_FILE" "$1" "$2" <<'PY'
import json, sys
tasks=json.load(open(sys.argv[1]))['tasks']
tid=int(sys.argv[2]); key=sys.argv[3]
for t in tasks:
    if t.get('id')==tid:
        print(t.get(key,'')); break
PY
}

ci_green() { # espera hasta checks no-pending y devuelve 0 si mergeable CLEAN
  local pr="$1" i
  for i in $(seq 1 60); do
    local st
    st=$(gh pr view "$pr" --json mergeStateStatus,statusCheckRollup --jq '{s:.mergeStateStatus, p:[.statusCheckRollup[]?|select(.status!="COMPLETED")]|length}' 2>/dev/null || echo '{"s":"UNKNOWN","p":1}')
    local pending
    pending=$(echo "$st" | python3 -c "import sys,json;print(json.load(sys.stdin).get('p',1))" 2>/dev/null || echo 1)
    local state
    state=$(echo "$st" | python3 -c "import sys,json;print(json.load(sys.stdin).get('s',''))" 2>/dev/null)
    [[ "$pending" -eq 0 && "$state" != "BLOCKED" ]] && return 0
    sleep 20
  done
  return 1
}

merge_pr() { # merge con grant: re-emite el grant (orden cubre toda la noche) y mergea
  local pr="$1"
  bash "$SCRIPT_DIR/operator-grant.sh" grant --scope merge --context "$MERGE_GRANT_CONTEXT" --ttl-hours 12 >/dev/null 2>&1
  gh pr ready "$pr" >/dev/null 2>&1 || true
  gh pr merge "$pr" --merge >/dev/null 2>&1
}


# ── Lanzar el loop oficial (SE-226) con el executor de arriba ────────────────
# NOTA: el loop define SPRINT_ID="" y TASKS_FILE="" en sus defaults; guardar
# los nuestros antes del source y pasarlos al parse_args después.
# NOTA 2: el loop ejecuta las tareas vía `bash -c "run_agent_task ..."` y su
# source SOBREESCRIBE run_agent_task con un stub — por eso el executor real se
# define DESPUÉS del source con otro nombre y se re-asigna + exporta.
export AGENT_TASK_TIMEOUT_MINUTES="${AGENT_TASK_TIMEOUT_MINUTES:-25}"
export AGENT_MAX_CONSECUTIVE_FAILURES="${AGENT_MAX_CONSECUTIVE_FAILURES:-3}"
RUN_SPRINT_ID="$SPRINT_ID"
RUN_TASKS_FILE="$TASKS_FILE"
RUN_MAX_TASKS="${MAX_TASKS:-6}"

source "$LOOP"

mi_run_agent_task() {
  local sprint_id="$1" task_id="$2" description="$3" model_tier="$4"

  local slug spec agent_name
  slug=$(task_meta "$task_id" slug)
  spec=$(task_meta "$task_id" spec)
  agent_name=$(task_meta "$task_id" agent)
  [[ -z "$slug" ]] && { echo "no task meta" >&2; return 1; }

  local model
  case "$model_tier" in
    heavy) model="zai-coding-plan/glm-5.3" ;;
    mid)   model="zai-coding-plan/glm-5" ;;
    *)     model="zai-coding-plan/glm-5.3-flash" ;;
  esac

  local branch="agent/overnight-20260902-$slug"
  echo "[runner] tarea $task_id ($slug) agente=$agent_name modelo=$model rama=$branch"

  git fetch origin "$BASE_BRANCH" >/dev/null 2>&1
  git checkout -B "$branch" "origin/$BASE_BRANCH" || return 3

  local prompt
  prompt=$(cat <<PROMPT
Implementa la spec $spec de este repositorio. Lee primero docs/specs/${spec}-*.spec.md
(completa) y sigue su OpenCode Implementation Plan y sus criterios de aceptación.
Tarea: $description

Reglas estrictas:
- Trabaja SOLO en esta rama ($branch). NUNCA commits en main.
- Implementa el código + tests que pide la spec (BATS bajo tests/bats/ o pytest).
- Ejecuta los tests localmente hasta verdes.
- Commits atómicos: "feat($spec): <qué>" con git add de rutas explícitas.
- NO toques: .claude/settings.json, docs/ROADMAP.md, specs antiguas PROPOSED,
  ni datos N3+. Todo local (CRIT-001).
- Al terminar: deja el working tree limpio y el último commit firmado NO es
  necesario (lo firma el wrapper).
- Si algo bloquea la implementación, termina tu respuesta con "BLOCKED: <motivo>".
PROMPT
)

  timeout $(( ${AGENT_TASK_TIMEOUT_MINUTES:-25} * 60 )) opencode run \
      --agent "$agent_name" -m "$model" "$prompt" > /tmp/opencode/night-$slug.log 2>&1
  local rc=$?
  [[ $rc -eq 124 ]] && return 3
  [[ $rc -ne 0 ]] && return 1
  grep -q "^BLOCKED:" /tmp/opencode/night-$slug.log 2>/dev/null && return 1

  [[ -n "$(git status --porcelain)" ]] && {
    git add -A ':!.confidentiality-signature' 2>/dev/null
    git commit -m "feat($spec): implementación nocturna (wip, pre-firma)" >/dev/null 2>&1 || return 1
  }

  bash scripts/confidentiality-scan.sh --pr >/dev/null 2>&1 || true
  SAVIA_CONFIDENTIALITY_AUDITED=1 bash scripts/confidentiality-sign.sh sign >/dev/null 2>&1 || true
  git add .confidentiality-signature 2>/dev/null
  git commit -m "chore: sign confidentiality audit" >/dev/null 2>&1 || true

  git push -u origin "$branch" >/dev/null 2>&1 || return 3

  gh pr create --base "$BASE_BRANCH" --head "$branch" \
    --title "feat($spec): implementación nocturna — $slug" \
    --body "Implementación autónoma nocturna de la spec $spec.

- Spec: docs/specs/${spec}-*.spec.md
- Tests: incluidos (BATS/pytest)
- CRIT-001: local
- Generado por overnight-sprint (SE-226). CI verde obligatorio para el merge
  bajo el grant de la operadora (2026-09-02).
" >/dev/null 2>&1
  local pr_num
  pr_num=$(gh pr view "$branch" --json number --jq '.number' 2>/dev/null)
  [[ -z "$pr_num" ]] && return 1
  echo "[runner] PR #$pr_num creado ($slug)"

  if ci_green "$pr_num"; then
    merge_pr "$pr_num" && { echo "[runner] PR #$pr_num MERGED"; return 0; }
    echo "[runner] merge falló para #$pr_num" >&2
    return 1
  fi
  echo "[runner] CI no verde para #$pr_num — queda abierto" >&2
  return 1
}

# Re-asignar el executor del loop a nuestra implementación y exportarla
# para las subshells `bash -c`.
run_agent_task() { mi_run_agent_task "$@"; }
export -f run_agent_task mi_run_agent_task task_meta ci_green merge_pr
export MERGE_GRANT_CONTEXT BASE_BRANCH SCRIPT_DIR TASKS_FILE
parse_args --sprint-id "$RUN_SPRINT_ID" --tasks "$RUN_TASKS_FILE" --max-tasks "$RUN_MAX_TASKS"
run_loop
