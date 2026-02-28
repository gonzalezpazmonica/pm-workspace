#!/usr/bin/env bash
# emergency-fallback.sh — Operaciones PM sin LLM
# Uso: ./scripts/emergency-fallback.sh {comando} [opciones]
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

CMD="${1:-help}"

show_help() {
  echo -e "\n${BOLD}${CYAN}PM-Workspace · Emergency Fallback${NC}"
  echo -e "Operaciones de gestión de proyecto que NO requieren LLM.\n"
  echo -e "${BOLD}Uso:${NC} $0 {comando}\n"
  echo -e "${BOLD}Comandos disponibles:${NC}"
  echo -e "  ${CYAN}git-summary${NC}      Resumen de actividad git reciente"
  echo -e "  ${CYAN}board-snapshot${NC}   Exportar estado actual del board a markdown"
  echo -e "  ${CYAN}team-checklist${NC}   Checklist para daily/review/retro"
  echo -e "  ${CYAN}pr-list${NC}          Listar PRs pendientes"
  echo -e "  ${CYAN}branch-status${NC}    Estado de ramas activas"
  echo -e "  ${CYAN}help${NC}             Mostrar esta ayuda"
  echo ""
}

git_summary() {
  echo -e "\n${BOLD}${CYAN}Git Summary${NC} — últimos 7 días\n"

  echo -e "${BOLD}Commits recientes:${NC}"
  git log --oneline --since="7 days ago" --all 2>/dev/null || echo "  (sin commits recientes)"

  echo -e "\n${BOLD}Ficheros modificados (últimas 24h):${NC}"
  git log --oneline --name-status --since="1 day ago" 2>/dev/null | head -30 || echo "  (sin cambios)"

  echo -e "\n${BOLD}Contribuidores activos (7 días):${NC}"
  git log --format='%aN' --since="7 days ago" 2>/dev/null | sort | uniq -c | sort -rn || echo "  (sin actividad)"

  echo -e "\n${BOLD}Ramas con actividad reciente:${NC}"
  git for-each-ref --sort=-committerdate --format='  %(refname:short) — %(committerdate:relative) (%(authorname))' refs/heads/ 2>/dev/null | head -10
  echo ""
}

board_snapshot() {
  echo -e "\n${BOLD}${CYAN}Board Snapshot${NC}\n"

  OUTFILE="output/emergency-board-$(date +%Y%m%d-%H%M).md"
  mkdir -p output

  {
    echo "# Board Snapshot — $(date '+%Y-%m-%d %H:%M')"
    echo ""
    echo "## Ramas Activas (posibles work items en progreso)"
    echo ""
    git for-each-ref --sort=-committerdate --format='- **%(refname:short)** — %(committerdate:relative) (%(authorname))' refs/heads/ 2>/dev/null | head -15
    echo ""
    echo "## Commits Sin Merge a Main"
    echo ""
    for branch in $(git for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null | grep -v '^main$'); do
      AHEAD=$(git rev-list --count main.."$branch" 2>/dev/null || echo 0)
      [[ "$AHEAD" -gt 0 ]] && echo "- **$branch**: $AHEAD commits pendientes"
    done
    echo ""
    echo "## Ficheros con Cambios Sin Commit"
    echo ""
    git status --short 2>/dev/null || echo "(limpio)"
    echo ""
    echo "---"
    echo "*Generado por emergency-fallback.sh — modo offline*"
  } > "$OUTFILE"

  echo -e "  ${GREEN}✓${NC} Snapshot guardado en ${CYAN}$OUTFILE${NC}"
  echo ""
}

team_checklist() {
  echo -e "\n${BOLD}${CYAN}Team Checklist${NC} — Scrum Events Manual\n"

  echo -e "${BOLD}📋 Daily Standup:${NC}"
  echo "  □ ¿Qué hice ayer?"
  echo "  □ ¿Qué haré hoy?"
  echo "  □ ¿Hay impedimentos?"
  echo "  □ ¿Necesito ayuda de alguien?"

  echo -e "\n${BOLD}📋 Sprint Review:${NC}"
  echo "  □ Demo de funcionalidades completadas"
  echo "  □ PBIs completados vs planificados"
  echo "  □ Feedback de stakeholders"
  echo "  □ Actualizar backlog con feedback"

  echo -e "\n${BOLD}📋 Sprint Retrospective:${NC}"
  echo "  □ ¿Qué salió bien?"
  echo "  □ ¿Qué podemos mejorar?"
  echo "  □ ¿Qué acciones tomamos?"
  echo "  □ Priorizar top 3 acciones"

  echo -e "\n${BOLD}📋 Sprint Planning:${NC}"
  echo "  □ Revisar sprint goal"
  echo "  □ Capacity del equipo (vacaciones, formación)"
  echo "  □ Seleccionar PBIs del backlog"
  echo "  □ Descomponer en tasks"
  echo "  □ Estimar tasks en horas"
  echo "  □ Comprometer sprint backlog"
  echo ""
}

pr_list() {
  echo -e "\n${BOLD}${CYAN}Pull Requests Pendientes${NC}\n"
  if command -v gh &>/dev/null; then
    gh pr list --state open 2>/dev/null || echo "  (no hay PRs abiertos o sin acceso)"
  else
    echo "  gh CLI no disponible. PRs desde git:"
    echo ""
    for branch in $(git for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null | grep -v '^main$'); do
      AHEAD=$(git rev-list --count main.."$branch" 2>/dev/null || echo 0)
      [[ "$AHEAD" -gt 0 ]] && echo "  · $branch ($AHEAD commits ahead of main)"
    done
  fi
  echo ""
}

branch_status() {
  echo -e "\n${BOLD}${CYAN}Branch Status${NC}\n"
  echo -e "${BOLD}Ramas locales:${NC}"
  git for-each-ref --sort=-committerdate \
    --format='  %(if)%(HEAD)%(then)* %(else)  %(end)%(refname:short) — %(committerdate:relative) (%(authorname))' \
    refs/heads/ 2>/dev/null | head -15

  echo -e "\n${BOLD}Ramas remotas recientes:${NC}"
  git for-each-ref --sort=-committerdate \
    --format='  %(refname:short) — %(committerdate:relative)' \
    refs/remotes/origin/ 2>/dev/null | head -10
  echo ""
}

# ── Router ───────────────────────────────────────────────────────────────────
case "$CMD" in
  git-summary)     git_summary ;;
  board-snapshot)  board_snapshot ;;
  team-checklist)  team_checklist ;;
  pr-list)         pr_list ;;
  branch-status)   branch_status ;;
  help|--help|-h)  show_help ;;
  *)
    echo -e "${RED}Comando desconocido: $CMD${NC}"
    show_help
    exit 1
    ;;
esac
