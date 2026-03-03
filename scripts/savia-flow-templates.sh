#!/bin/bash
# savia-flow-templates.sh — Project/team/member scaffolding via branch isolation
# Sourced by savia-flow.sh — do NOT run directly.
set -euo pipefail

# ── Init project structure ──────────────────────────────────────────
do_init_project() {
  local repo_dir="${1:?Uso: savia-flow.sh init-project <name> [team]}"
  local project_name="${2:?Falta project name}"
  local team_name="${3:-default}"

  local team_branch="team/$team_name"
  do_ensure_orphan "$repo_dir" "$team_branch" "init: $team_branch"

  local dirs="projects/${project_name}/backlog/archive projects/${project_name}/sprints projects/${project_name}/specs projects/${project_name}/decisions"
  for dir in $dirs; do
    local readme_content="# $dir"
    do_write "$repo_dir" "$team_branch" "${dir}/.gitkeep" "" "[flow: scaffold] $project_name"
  done

  local proj_readme="# ${project_name}

## Team
- **Team**: ${team_name}
- **Created**: $(date +%Y-%m-%d)

## Structure
- \`backlog/\` — PBIs as markdown files
- \`sprints/\` — Sprint folders with goals and boards
- \`specs/\` — SDD specifications
- \`decisions/\` — Architecture Decision Records"

  do_write "$repo_dir" "$team_branch" "projects/${project_name}/README.md" "$proj_readme" "[flow: project-init] $project_name"
  log_ok "Project '$project_name' initialized on team/$team_name"
}

# ── Init team ───────────────────────────────────────────────────────
do_init_team() {
  local repo_dir="${1:?Uso: savia-flow.sh init-team <team> <members_csv>}"
  local team_name="${2:?Falta team name}"
  local members_csv="${3:-}"

  local team_branch="team/$team_name"
  do_ensure_orphan "$repo_dir" "$team_branch" "init: $team_branch"

  local team_content="---
name: \"${team_name}\"
created: \"$(date +%Y-%m-%d)\"
---

# Team: ${team_name}

| Handle | Name | Role | Capacity (h/day) |
|--------|------|------|-------------------|"

  if [ -n "$members_csv" ]; then
    IFS=',' read -ra members <<< "$members_csv"
    for m in "${members[@]}"; do
      local h n r
      h=$(echo "$m" | cut -d: -f1)
      n=$(echo "$m" | cut -d: -f2)
      r=$(echo "$m" | cut -d: -f3)
      team_content="$team_content
| @$h | $n | ${r:-Developer} | 8 |"
    done
  fi

  do_write "$repo_dir" "$team_branch" "team.md" "$team_content" "[flow: team-init] $team_name"

  local ceremonies_content="# Ceremonies — ${team_name}

| Ceremony | Day | Time | Duration |
|----------|-----|------|----------|
| Sprint Planning | Monday (start) | 10:00 | 4h |
| Daily Standup | Daily | 09:15 | 15min |
| Sprint Review | Friday (end) | 15:00 | 1h |
| Retrospective | Friday (end) | 16:30 | 1.5h |
| Refinement | Wednesday (wk1) | 11:00 | 2h |"

  do_write "$repo_dir" "$team_branch" "ceremonies.md" "$ceremonies_content" "[flow: ceremonies] $team_name"

  log_ok "Team '$team_name' initialized on team/$team_name"
}

# ── Init member flow ────────────────────────────────────────────────
do_init_member_flow() {
  local repo_dir="${1:?Uso: savia-flow.sh init-member <handle>}"
  local handle="${2:?Falta handle}"

  local user_branch="user/$handle"
  do_ensure_orphan "$repo_dir" "$user_branch" "init: $user_branch"

  local focus_content="# Focus — @${handle}

## Current WIP
<!-- Active PBIs go here -->
_No items in progress._

## Notes"

  do_write "$repo_dir" "$user_branch" "flow/focus.md" "$focus_content" "[flow: member-init] @$handle"
  do_write "$repo_dir" "$user_branch" "flow/timesheet/.gitkeep" "" "[flow: member-init] @$handle"
  do_write "$repo_dir" "$user_branch" "flow/assigned/.gitkeep" "" "[flow: member-init] @$handle"

  log_ok "Savia Flow initialized for @$handle"
}
