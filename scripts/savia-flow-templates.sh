#!/bin/bash
# savia-flow-templates.sh — Scaffolding for Savia Flow project structures
# Sourced by savia-flow.sh — do NOT run directly.

# ── Init project structure ──────────────────────────────────────────
do_init_project() {
  local repo_dir="${1:?Uso: savia-flow.sh init-project <name> [team]}"
  local project_name="${2:?Falta project name}"
  local team_name="${3:-default}"

  local proj_dir="$repo_dir/projects/$project_name"
  mkdir -p "$proj_dir"/{backlog/archive,sprints,specs,decisions,metrics}

  cat > "$proj_dir/README.md" <<EOF
# ${project_name}

## Team
- **Team**: ${team_name}
- **Created**: $(date +%Y-%m-%d)

## Structure
- \`backlog/\` — PBIs as markdown files
- \`sprints/\` — Sprint folders with goals and boards
- \`specs/\` — SDD specifications
- \`decisions/\` — Architecture Decision Records
- \`metrics/\` — Sprint metrics snapshots
EOF

  # Initial current sprint pointer
  echo "current: none" > "$proj_dir/sprints/current.md"

  log_ok "Project '$project_name' initialized at projects/$project_name"
}

# ── Init team ───────────────────────────────────────────────────────
do_init_team() {
  local repo_dir="${1:?Uso: savia-flow.sh init-team <team> <members_csv>}"
  local team_name="${2:?Falta team name}"
  local members_csv="${3:-}"

  local team_dir="$repo_dir/teams/$team_name"
  mkdir -p "$team_dir"

  # team.md with members table
  cat > "$team_dir/team.md" <<EOF
---
name: "${team_name}"
created: "$(date +%Y-%m-%d)"
---

# Team: ${team_name}

| Handle | Name | Role | Capacity (h/day) |
|--------|------|------|-------------------|
EOF

  # Parse CSV: handle:name:role
  if [ -n "$members_csv" ]; then
    IFS=',' read -ra members <<< "$members_csv"
    for m in "${members[@]}"; do
      local h n r
      h=$(echo "$m" | cut -d: -f1)
      n=$(echo "$m" | cut -d: -f2)
      r=$(echo "$m" | cut -d: -f3)
      echo "| @$h | $n | ${r:-Developer} | 8 |" >> "$team_dir/team.md"
    done
  fi

  # ceremonies.md
  cat > "$team_dir/ceremonies.md" <<EOF
# Ceremonies — ${team_name}

| Ceremony | Day | Time | Duration |
|----------|-----|------|----------|
| Sprint Planning | Monday (start) | 10:00 | 4h |
| Daily Standup | Daily | 09:15 | 15min |
| Sprint Review | Friday (end) | 15:00 | 1h |
| Retrospective | Friday (end) | 16:30 | 1.5h |
| Refinement | Wednesday (wk1) | 11:00 | 2h |
EOF

  # velocity.md
  cat > "$team_dir/velocity.md" <<EOF
# Velocity — ${team_name}

| Sprint | Committed (SP) | Done (SP) | Completion % |
|--------|----------------|-----------|--------------|
EOF

  log_ok "Team '$team_name' initialized at teams/$team_name"
}

# ── Init member flow ────────────────────────────────────────────────
do_init_member_flow() {
  local repo_dir="${1:?Uso: savia-flow.sh init-member <handle>}"
  local handle="${2:?Falta handle}"

  local flow_dir="$repo_dir/users/$handle/flow"
  mkdir -p "$flow_dir"/{timesheet,assigned}

  cat > "$flow_dir/focus.md" <<EOF
# Focus — @${handle}

## Current WIP
<!-- Active PBIs go here -->
_No items in progress._

## Notes
EOF

  log_ok "Savia Flow initialized for @$handle"
}
