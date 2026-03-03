#!/bin/bash
# savia-flow.sh — Git-based project management: PBIs, sprints, boards, timesheets
# Uso: bash scripts/savia-flow.sh {create-pbi|assign|move|log-time|sprint-start|sprint-close|board|metrics|init|help} [args]
#
# Savia Flow stores project management data as markdown files in the company
# repo — no Azure DevOps dependency needed.

set -euo pipefail

# ── Constantes ──────────────────────────────────────────────────────
CONFIG_DIR="$HOME/.pm-workspace"
CONFIG_FILE="$CONFIG_DIR/company-repo"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPTS_DIR/savia-compat.sh"

# ── Colores ─────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
log_info()  { echo -e "${BLUE}i${NC}  $1"; }
log_ok()    { echo -e "${GREEN}OK${NC} $1"; }
log_warn()  { echo -e "${YELLOW}!!${NC}  $1"; }
log_error() { echo -e "${RED}ERR${NC} $1"; }

# ── Config helpers ──────────────────────────────────────────────────
read_config() {
  portable_read_config "$1" "$CONFIG_FILE"
}

get_repo() {
  local path
  path=$(read_config "LOCAL_PATH")
  if [ -z "$path" ] || [ ! -d "$path/.git" ]; then
    log_error "No company repo. Run /company-repo connect first."
    exit 1
  fi
  echo "$path"
}

get_handle() {
  read_config "USER_HANDLE"
}

# ── Validate project exists ────────────────────────────────────────
validate_project() {
  local repo_dir="$1" project="$2"
  if [ ! -d "$repo_dir/projects/$project" ]; then
    log_error "Project '$project' not found in company repo."
    log_info "Available projects:"
    ls -1 "$repo_dir/projects/" 2>/dev/null || echo "  (none)"
    return 1
  fi
}

# ── Source operation modules ────────────────────────────────────────
source "$SCRIPTS_DIR/savia-flow-ops.sh"
source "$SCRIPTS_DIR/savia-flow-sprint.sh"
source "$SCRIPTS_DIR/savia-flow-board.sh"
source "$SCRIPTS_DIR/savia-flow-templates.sh"

# ── Adapter functions for sprint/metrics ────────────────────────────
do_sprint_start() {
  local project="${1:?}" name="${2:?}" goal="${3:?}" start="${4:?}" end="${5:?}"
  local repo_dir; repo_dir=$(get_repo)
  validate_project "$repo_dir" "$project"
  local sprint_dir="$repo_dir/projects/$project/sprints/$name"
  mkdir -p "$sprint_dir"
  cat > "$sprint_dir/sprint.md" <<EOF
---
id: $name
goal: $goal
start_date: $start
end_date: $end
status: "active"
created: $(date +%Y-%m-%d)
---
## Sprint Goal
$goal
EOF
  echo "✅ Sprint $name started for $project"
}

do_sprint_close() {
  local project="${1:?}"
  local repo_dir; repo_dir=$(get_repo)
  local current
  current=$(ls -t "$repo_dir/projects/$project/sprints/" 2>/dev/null | head -1)
  [ -n "$current" ] || { echo "❌ No active sprint"; return 1; }
  local sprint_file="$repo_dir/projects/$project/sprints/$current/sprint.md"
  [ -f "$sprint_file" ] || { echo "❌ Sprint file not found"; return 1; }
  sed -i '' "s/status: \"active\"/status: \"closed\"/" "$sprint_file" 2>/dev/null || \
  sed -i "s/status: \"active\"/status: \"closed\"/" "$sprint_file" 2>/dev/null || true
  echo "✅ Sprint $current closed"
}

do_metrics() {
  local project="${1:?}"
  local repo_dir; repo_dir=$(get_repo)
  validate_project "$repo_dir" "$project"
  local total=0 done_count=0 total_sp=0
  for f in "$repo_dir/projects/$project/backlog"/*.md "$repo_dir/projects/$project/backlog/archive"/*.md; do
    [ -f "$f" ] || continue
    total=$((total + 1))
    local sp; sp=$(portable_yaml_field "story_points" "$f"); sp=${sp:-0}
    total_sp=$((total_sp + sp))
    local status; status=$(portable_yaml_field "status" "$f")
    [ "$status" = "done" ] && done_count=$((done_count + 1))
  done
  echo "📊 Metrics: $project"
  echo "  Total PBIs: $total"
  echo "  Done: $done_count"
  echo "  Story Points: $total_sp"
  echo "  Velocity: ${done_count}/${total} PBIs completed"
}

# ── Main ────────────────────────────────────────────────────────────
main() {
  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    create-pbi)    do_create_pbi "$@" ;;
    assign)        do_assign "$@" ;;
    move)          do_move "$@" ;;
    log-time)      do_log_time "$@" ;;
    sprint-start)  do_sprint_start "$@" ;;
    sprint-close)  do_sprint_close "$@" ;;
    board)         do_board "$@" ;;
    metrics)       do_metrics "$@" ;;
    init-project)  do_init_project "$(get_repo)" "$@" ;;
    init-team)     do_init_team "$(get_repo)" "$@" ;;
    init-member)   do_init_member_flow "$(get_repo)" "$@" ;;
    help|*)
      echo "savia-flow.sh — Git-based project management for Company Savia"
      echo ""
      echo "PBI Management:"
      echo "  create-pbi <project> <title> <desc> [priority] [estimate]"
      echo "  assign <project> <pbi_id> <handle>"
      echo "  move <project> <pbi_id> <status>"
      echo ""
      echo "Sprint Lifecycle:"
      echo "  sprint-start <project> <name> <goal> <start> <end>"
      echo "  sprint-close <project>"
      echo ""
      echo "Views:"
      echo "  board <project>          — ASCII Kanban board"
      echo "  metrics <project>        — PBI counts and velocity"
      echo ""
      echo "Time Tracking:"
      echo "  log-time <project> <pbi_id> <hours> <description>"
      echo ""
      echo "Scaffolding:"
      echo "  init-project <name> [team]"
      echo "  init-team <team> <members_csv>"
      echo "  init-member <handle>"
      ;;
  esac
}

main "$@"
