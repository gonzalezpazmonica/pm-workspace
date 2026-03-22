#!/bin/bash
# pr-context-loader.sh — SPEC-022 F4: Load project context before PR creation
# Reads project rules, specs, and team info to enrich PR descriptions.
# Usage: bash scripts/pr-context-loader.sh [--project NAME] [--branch BRANCH]
#   source scripts/pr-context-loader.sh && pr_context_summary
set -uo pipefail

ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

pr_context_summary() {
    local project="${1:-}" branch="${2:-}"

    # Auto-detect project from branch name if not provided
    if [[ -z "$project" ]]; then
        branch="${branch:-$(git -C "$ROOT" branch --show-current 2>/dev/null || echo "")}"
        # Try to extract project from branch: feat/projectname-feature
        project=$(echo "$branch" | sed 's|.*/||' | cut -d'-' -f1 || true)
    fi

    local project_dir="$ROOT/projects/$project"
    local context=""

    # 1. Load business rules (if project exists)
    if [[ -f "$project_dir/reglas-negocio.md" ]]; then
        local rules_count=$(grep -c '^- \|^RN-' "$project_dir/reglas-negocio.md" 2>/dev/null || echo 0)
        context="Business rules: $rules_count rules in reglas-negocio.md"
    fi

    # 2. Load team info
    if [[ -f "$project_dir/equipo.md" ]]; then
        local team_size=$(grep -c '^|.*|.*|' "$project_dir/equipo.md" 2>/dev/null || echo 0)
        team_size=$((team_size > 1 ? team_size - 1 : 0))  # subtract header
        context="${context:+$context\n}Team: $team_size members in equipo.md"
    fi

    # 3. Find related specs
    local specs=""
    if [[ -d "$project_dir/specs" ]]; then
        specs=$(ls "$project_dir/specs/"*.md 2>/dev/null | wc -l)
        context="${context:+$context\n}Specs: $specs in project specs/"
    fi

    # 4. Recent decisions from memory
    local store="$ROOT/output/.memory-store.jsonl"
    if [[ -f "$store" && -n "$project" ]]; then
        local recent_decisions=$(grep "\"project\":\"$project\"" "$store" 2>/dev/null | \
            grep '"type":"decision"' | tail -3 | \
            while IFS= read -r line; do
                echo "$line" | grep -o '"title":"[^"]*"' | cut -d'"' -f4
            done | tr '\n' '; ' || true)
        [[ -n "$recent_decisions" ]] && context="${context:+$context\n}Recent decisions: $recent_decisions"
    fi

    # 5. Suggested reviewers from team
    if [[ -f "$project_dir/equipo.md" ]]; then
        local reviewers=$(grep -i 'lead\|senior\|architect' "$project_dir/equipo.md" 2>/dev/null | \
            grep -o '[A-Z][a-z]* [A-Z][a-z]*' | head -3 | tr '\n' ', ' || true)
        [[ -n "$reviewers" ]] && context="${context:+$context\n}Suggested reviewers: $reviewers"
    fi

    # Output
    if [[ -n "$context" ]]; then
        echo "--- PR Context ($project) ---"
        echo -e "$context"
        echo "---"
    else
        echo "No project context found for '$project'"
    fi
}

# If run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    project="" branch=""
    while [[ $# -gt 0 ]]; do
        case "$1" in --project) project="$2"; shift 2;; --branch) branch="$2"; shift 2;; *) shift;; esac
    done
    pr_context_summary "$project" "$branch"
fi
