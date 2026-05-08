#!/usr/bin/env bash
# project-context.sh — Project isolation for Savia (SE-093)
# Usage:
#   project-context.sh detect          Print active project name or empty
#   project-context.sh set <project>   Set active project
#   project-context.sh list            List available projects
#   project-context.sh clear           Clear active project
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SCRIPT_DIR}/.."
if [[ -f "${SCRIPT_DIR}/savia-env.sh" ]]; then
  source "${SCRIPT_DIR}/savia-env.sh"
fi
WORKSPACE="${SAVIA_WORKSPACE_DIR:-$ROOT}"
ACTIVE_FILE="${WORKSPACE}/.savia/active-project"
PROJECTS_DIR="${WORKSPACE}/projects"

# ── List available projects ─────────────────────────────────────────────────────
list_projects() {
  if [[ ! -d "$PROJECTS_DIR" ]]; then
    echo "No projects directory found" >&2
    return 1
  fi
  for d in "$PROJECTS_DIR"/*/; do
    [[ -d "$d" ]] || continue
    local name; name=$(basename "$d")
    [[ "$name" == "savia-web" ]] && continue  # skip savia-web submodule
    local claude_md="${d}CLAUDE.md"
    local desc=""
    [[ -f "$claude_md" ]] && desc=$(head -3 "$claude_md" 2>/dev/null | grep -oP '(?<=# ).*' | head -1 || echo "")
    echo "${name}|${desc}"
  done
}

# ── Detect active project ───────────────────────────────────────────────────────
detect_active() {
  # 1. Explicit override via env var
  if [[ -n "${SAVIA_ACTIVE_PROJECT:-}" ]]; then
    echo "$SAVIA_ACTIVE_PROJECT"
    return 0
  fi
  # 2. Saved state
  if [[ -f "$ACTIVE_FILE" ]]; then
    local saved; saved=$(head -1 "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]')
    if [[ -n "$saved" ]]; then
      echo "$saved"
      return 0
    fi
  fi
  # 3. No project active
  echo ""
}

# ── Set active project ──────────────────────────────────────────────────────────
set_active() {
  local project="$1"
  [[ -z "$project" ]] && { echo "ERROR: specify project name" >&2; return 1; }

  # Validate project exists
  if [[ ! -d "${PROJECTS_DIR}/${project}" ]]; then
    echo "ERROR: project '${project}' not found in ${PROJECTS_DIR}" >&2
    echo "Available projects:" >&2
    list_projects | while IFS='|' read -r name desc; do
      echo "  - $name" >&2
    done
    return 1
  fi

  mkdir -p "$(dirname "$ACTIVE_FILE")" 2>/dev/null || true
  echo "$project" > "$ACTIVE_FILE"
  echo "$project"
}

# ── Clear active project ────────────────────────────────────────────────────────
clear_active() {
  rm -f "$ACTIVE_FILE"
  echo "Project cleared"
}

# ── Show active project status ──────────────────────────────────────────────────
show_status() {
  local active; active=$(detect_active)
  if [[ -z "$active" ]]; then
    echo "No active project. Use 'project-context.sh set <name>' to select one."
    echo ""
    echo "Available projects:"
    list_projects | while IFS='|' read -r name desc; do
      printf "  %-30s %s\n" "$name" "${desc:0:50}"
    done
  else
    echo "Active project: $active"
    local claude_md="${PROJECTS_DIR}/${active}/CLAUDE.md"
    if [[ -f "$claude_md" ]]; then
      echo ""
      head -10 "$claude_md" 2>/dev/null | grep -E '^#|^>|^-' | head -5
    fi
  fi
}

# ── Dispatch ─────────────────────────────────────────────────────────────────────
case "${1:-}" in
  detect)   detect_active ;;
  set)      shift; set_active "$@" ;;
  list)     list_projects | while IFS='|' read -r name desc; do echo "$name"; done ;;
  clear)    clear_active ;;
  status|"") show_status ;;
  *)
    echo "Usage: project-context.sh <detect|set|list|clear|status>" >&2
    exit 2
    ;;
esac
