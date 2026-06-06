#!/usr/bin/env bash
# project-isolation-check.sh — Verifica aislamiento de contexto por proyecto (SPEC-SE-093-ZERO-LEAK)
# REQ-01: Lee proyecto activo desde .claude/profiles/active-user.md o SAVIA_ACTIVE_PROJECT
# REQ-02: Verifica que ~/.savia-memory/projects/{name}/ existe si el proyecto está activo
# REQ-04: Read-only — reporta PASS/WARN/FAIL. No modifica ficheros de proyecto.
# REQ-05: set -uo pipefail, chmod +x
#
# Usage:
#   project-isolation-check.sh            Normal output (PASS/WARN/FAIL)
#   project-isolation-check.sh --json     JSON output con status key
#
# Ref: SE-093, docs/rules/domain/zero-project-leakage.md
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SCRIPT_DIR}/.."
ACTIVE_USER_FILE="${ROOT}/.claude/profiles/active-user.md"
SESSION_LOG="${ROOT}/output/session-action-log.jsonl"
SAVIA_MEMORY_DIR="${HOME}/.savia-memory/projects"

# ── Flags ────────────────────────────────────────────────────────────────────
JSON_MODE=0
[[ "${1:-}" == "--json" ]] && JSON_MODE=1

# ── Counters ─────────────────────────────────────────────────────────────────
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
declare -a MESSAGES=()

_pass() { PASS_COUNT=$((PASS_COUNT + 1)); MESSAGES+=("PASS: $1"); }
_warn() { WARN_COUNT=$((WARN_COUNT + 1)); MESSAGES+=("WARN: $1"); }
_fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); MESSAGES+=("FAIL: $1"); }

# ── REQ-01: Detectar proyecto activo ─────────────────────────────────────────
detect_active_project() {
  # 1. Variable de entorno explícita
  if [[ -n "${SAVIA_ACTIVE_PROJECT:-}" ]]; then
    echo "$SAVIA_ACTIVE_PROJECT"
    return 0
  fi
  # 2. active-user.md: campo active_project
  if [[ -f "$ACTIVE_USER_FILE" ]]; then
    local proj
    proj=$(grep -E '^active_project:' "$ACTIVE_USER_FILE" 2>/dev/null \
          | sed 's/^active_project:[[:space:]]*//' \
          | tr -d '"' \
          | tr -d "'" \
          | tr -d '[:space:]' \
          | head -1)
    if [[ -n "$proj" ]]; then
      echo "$proj"
      return 0
    fi
    # Fallback: active_slug como identificador de usuario (no proyecto)
    local slug
    slug=$(grep -E '^active_slug:' "$ACTIVE_USER_FILE" 2>/dev/null \
           | sed 's/^active_slug:[[:space:]]*//' \
           | tr -d '"' \
           | tr -d "'" \
           | tr -d '[:space:]' \
           | head -1)
    if [[ -n "$slug" ]]; then
      echo "$slug"
      return 0
    fi
  fi
  echo ""
}

ACTIVE_PROJECT="$(detect_active_project)"

# ── Check 1: active-user.md existe ───────────────────────────────────────────
if [[ -f "$ACTIVE_USER_FILE" ]]; then
  _pass "active-user.md exists at expected path"
else
  _fail "active-user.md not found at ${ACTIVE_USER_FILE}"
fi

# ── Check 2: Proyecto activo detectado ───────────────────────────────────────
if [[ -n "$ACTIVE_PROJECT" ]]; then
  _pass "Active project detected: ${ACTIVE_PROJECT}"
else
  _warn "No active project set (SAVIA_ACTIVE_PROJECT empty and no active_project in active-user.md)"
fi

# ── REQ-02: Verificar directorio de memoria por proyecto ─────────────────────
if [[ -n "$ACTIVE_PROJECT" ]]; then
  PROJ_MEMORY_DIR="${SAVIA_MEMORY_DIR}/${ACTIVE_PROJECT}"
  if [[ -d "$PROJ_MEMORY_DIR" ]]; then
    _pass "Project memory dir exists: ${PROJ_MEMORY_DIR}"
  else
    _warn "Project memory dir missing: ${PROJ_MEMORY_DIR} (run /project-activate ${ACTIVE_PROJECT} to create it)"
  fi
fi

# ── REQ-01: Verificar session-action-log por menciones cruzadas ──────────────
if [[ -f "$SESSION_LOG" ]]; then
  # Obtener todos los proyectos disponibles en projects/
  PROJECTS_DIR="${ROOT}/projects"
  declare -a OTHER_PROJECTS=()
  if [[ -d "$PROJECTS_DIR" ]]; then
    while IFS= read -r -d '' d; do
      local_name="$(basename "$d")"
      # Excluir el proyecto activo y savia-web (submodule)
      [[ "$local_name" == "$ACTIVE_PROJECT" ]] && continue
      [[ "$local_name" == "savia-web" ]] && continue
      OTHER_PROJECTS+=("$local_name")
    done < <(find "$PROJECTS_DIR" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
  fi

  CROSS_COUNT=0
  for other in "${OTHER_PROJECTS[@]:-}"; do
    [[ -z "$other" ]] && continue
    if grep -qF "\"$other\"" "$SESSION_LOG" 2>/dev/null \
       || grep -qF "$other" "$SESSION_LOG" 2>/dev/null; then
      CROSS_COUNT=$((CROSS_COUNT + 1))
      _warn "Session log contains references to other project: ${other}"
    fi
  done

  if [[ $CROSS_COUNT -eq 0 ]]; then
    _pass "No cross-project leakage detected in session-action-log.jsonl"
  fi
else
  _pass "No session-action-log.jsonl found (no leakage to check)"
fi

# ── Determinar status global ──────────────────────────────────────────────────
if [[ $FAIL_COUNT -gt 0 ]]; then
  OVERALL="FAIL"
  EXIT_CODE=2
elif [[ $WARN_COUNT -gt 0 ]]; then
  OVERALL="WARN"
  EXIT_CODE=1
else
  OVERALL="PASS"
  EXIT_CODE=0
fi

# ── Output ────────────────────────────────────────────────────────────────────
if [[ $JSON_MODE -eq 1 ]]; then
  # Construir JSON con status key
  MSGS_JSON="["
  FIRST=1
  for msg in "${MESSAGES[@]}"; do
    [[ $FIRST -eq 0 ]] && MSGS_JSON+=","
    MSGS_JSON+="\"$(echo "$msg" | sed 's/"/\\"/g')\""
    FIRST=0
  done
  MSGS_JSON+="]"
  printf '{"status":"%s","pass":%d,"warn":%d,"fail":%d,"active_project":"%s","messages":%s}\n' \
    "$OVERALL" "$PASS_COUNT" "$WARN_COUNT" "$FAIL_COUNT" \
    "${ACTIVE_PROJECT:-}" "$MSGS_JSON"
else
  echo "=== project-isolation-check (SE-093) ==="
  echo "Active project: ${ACTIVE_PROJECT:-(none)}"
  echo ""
  for msg in "${MESSAGES[@]}"; do
    echo "  $msg"
  done
  echo ""
  printf "Overall: %s  (PASS=%d WARN=%d FAIL=%d)\n" \
    "$OVERALL" "$PASS_COUNT" "$WARN_COUNT" "$FAIL_COUNT"
fi

exit $EXIT_CODE
