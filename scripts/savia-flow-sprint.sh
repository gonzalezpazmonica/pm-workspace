#!/bin/bash
# savia-flow-sprint.sh — Sprint lifecycle via branch isolation
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPTS_DIR/savia-branch.sh"
source "$SCRIPTS_DIR/savia-compat.sh"

# Expects repo_dir, team from context
sprint_create() {
    local repo_dir="${1:?}" team="${2:?}" goal="${3:?}" start_date="${4:?}" end_date="${5:?}"
    local capacity_h="${6:-120}"

    local year=$(date +%Y)
    local sprints; sprints=$(do_list "$repo_dir" "team/$team" "projects/backlog/sprints") || echo ""
    local seq; seq=$(echo "$sprints" | grep -c "SPR-${year}" || echo 0)
    seq=$((seq + 1))
    local sprint_id="SPR-${year}-$(printf '%02d' $seq)"

    local sprint_content="---
id: $sprint_id
goal: $goal
start_date: $start_date
end_date: $end_date
capacity_h: $capacity_h
status: active
created: $(date +%Y-%m-%d)
closed: null
velocity: 0
---

## Sprint Goal

$goal

## Key Results

- [ ] Result 1"

    do_write "$repo_dir" "team/$team" "projects/backlog/sprints/${sprint_id}/sprint.md" "$sprint_content" "[flow: sprint-create] $sprint_id"
    echo "✅ Created $sprint_id: $goal"
}

sprint_close() {
    local repo_dir="${1:?}" team="${2:?}" sprint_id="${3:?}"
    [[ -n "$sprint_id" ]] || { echo "❌ Usage: sprint_close <sprint_id>"; return 1; }

    local sprint_path="projects/backlog/sprints/${sprint_id}/sprint.md"
    local content; content=$(do_read "$repo_dir" "team/$team" "$sprint_path") || { echo "❌ Sprint $sprint_id not found"; return 1; }

    content=$(echo "$content" | sed "s/^status: .*/status: closed/")
    content=$(echo "$content" | sed "s/^closed: .*/closed: $(date +%Y-%m-%d)/")

    do_write "$repo_dir" "team/$team" "$sprint_path" "$content" "[flow: sprint-close] $sprint_id"
    echo "✅ Closed $sprint_id"
}

sprint_board() {
    local repo_dir="${1:?}" team="${2:?}" sprint_id="${3:?}"
    [[ -n "$sprint_id" ]] || { echo "❌ Usage: sprint_board <sprint_id>"; return 1; }
    echo "📊 Sprint Board: $sprint_id (via team/$team)"
}

sprint_velocity() {
    local repo_dir="${1:?}" team="${2:?}"
    echo "📈 Historical Velocity (via team/$team)"
}
