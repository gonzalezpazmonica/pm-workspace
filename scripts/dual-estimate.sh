#!/usr/bin/env bash
set -uo pipefail
# dual-estimate.sh — Dual estimation engine: agent-time vs human-time
# Ref: SPEC-078 — Dual Estimation Agent/Human
# Usage: dual-estimate.sh classify|capacity|bottleneck [args]

show_help() {
  cat <<'EOF'
dual-estimate.sh — Dual Estimation Engine (SPEC-078)

Commands:
  classify <type>        Classify task type and recommend agent/human
  capacity <team_h> <agent_tasks> <review_min_per_task>
                         Calculate net human capacity after review load
  bottleneck <team_h> <total_review_min>
                         Check if review load exceeds 30% threshold
  matrix                 Show the full decision matrix
  help                   Show this help

Task types for classify:
  crud, tests, translation, bugfix, refactor, architecture,
  code-review, security-audit, counter-fix, business-decision
EOF
}

classify_task() {
  local type="${1:-}"
  [[ -z "$type" ]] && { echo "Usage: $0 classify <type>" >&2; return 1; }

  case "$type" in
    crud)
      echo "agent_min=5-10 | human_h=2-4 | review_min=15 | risk=low | recommend=AGENT" ;;
    tests)
      echo "agent_min=10-20 | human_h=3-6 | review_min=15 | risk=low | recommend=AGENT" ;;
    translation)
      echo "agent_min=3-5 | human_h=4-8 | review_min=10 | risk=low | recommend=AGENT" ;;
    bugfix)
      echo "agent_min=10-30 | human_h=1-2 | review_min=20 | risk=medium | recommend=AGENT_IF_PATTERN" ;;
    refactor)
      echo "agent_min=30-60 | human_h=4-8 | review_min=45 | risk=high | recommend=HUMAN" ;;
    architecture)
      echo "agent_min=N/A | human_h=4-16 | review_min=N/A | risk=exceeds | recommend=HUMAN_ALWAYS" ;;
    code-review)
      echo "agent_min=N/A | human_h=1-2 | review_min=N/A | risk=N/A | recommend=HUMAN_ALWAYS" ;;
    security-audit)
      echo "agent_min=15-30 | human_h=8-16 | review_min=60 | risk=medium | recommend=AGENT_PLUS_HUMAN" ;;
    counter-fix)
      echo "agent_min=1-2 | human_h=1-2 | review_min=5 | risk=low | recommend=AGENT" ;;
    business-decision)
      echo "agent_min=N/A | human_h=1-4 | review_min=N/A | risk=exceeds | recommend=HUMAN_ALWAYS" ;;
    *)
      echo "Unknown type: $type. Use: crud|tests|translation|bugfix|refactor|architecture|code-review|security-audit|counter-fix|business-decision" >&2
      return 1 ;;
  esac
}

calculate_capacity() {
  local team_h="${1:-}" agent_tasks="${2:-}" review_per_task="${3:-}"
  [[ -z "$team_h" || -z "$agent_tasks" || -z "$review_per_task" ]] && {
    echo "Usage: $0 capacity <team_hours> <agent_task_count> <review_min_per_task>" >&2
    return 1
  }
  local total_review_min=$((agent_tasks * review_per_task))
  local total_review_h=$(echo "scale=1; $total_review_min / 60" | bc 2>/dev/null || echo "$((total_review_min / 60))")
  local net_h=$(echo "scale=1; $team_h - $total_review_h" | bc 2>/dev/null || echo "$((team_h - total_review_min / 60))")

  echo "Team capacity:    ${team_h}h"
  echo "Agent tasks:      $agent_tasks"
  echo "Review per task:  ${review_per_task}min"
  echo "Total review:     ${total_review_min}min (${total_review_h}h)"
  echo "Net human cap:    ${net_h}h"
}

check_bottleneck() {
  local team_h="${1:-}" total_review_min="${2:-}"
  [[ -z "$team_h" || -z "$total_review_min" ]] && {
    echo "Usage: $0 bottleneck <team_hours> <total_review_minutes>" >&2
    return 1
  }
  local team_min=$((team_h * 60))
  local pct=$((total_review_min * 100 / team_min))

  if [[ $pct -gt 30 ]]; then
    echo "BOTTLENECK: review load at ${pct}% (threshold: 30%)"
    echo "  Team spends more time reviewing agent output than implementing."
    echo "  Consider: reduce agent delegation or batch reviews."
    return 1
  else
    echo "OK: review load at ${pct}% (threshold: 30%)"
    return 0
  fi
}

show_matrix() {
  cat <<'EOF'
Dual Estimation Decision Matrix (SPEC-078)

| Task Type        | Agent min | Human h | Review min | Risk    | Recommend       |
|------------------|-----------|---------|------------|---------|-----------------|
| CRUD endpoint    | 5-10      | 2-4     | 15         | low     | Agent           |
| Unit tests       | 10-20     | 3-6     | 15         | low     | Agent           |
| Translation      | 3-5       | 4-8     | 10         | low     | Agent           |
| Bug fix (simple) | 10-30     | 1-2     | 20         | medium  | Agent if clear  |
| Refactor (large) | 30-60     | 4-8     | 45         | high    | Human           |
| Architecture     | N/A       | 4-16    | N/A        | exceeds | Human always    |
| Code review      | N/A       | 1-2     | N/A        | N/A     | Human always    |
| Security audit   | 15-30     | 8-16    | 60         | medium  | Agent + human   |
| Counter fix      | 1-2       | 1-2     | 5          | low     | Agent (100x)    |
| Business decide  | N/A       | 1-4     | N/A        | exceeds | Human always    |

Golden rule: if agent_min < human_h x 10 AND risk <= medium AND no judgment needed → delegate
EOF
}

case "${1:-help}" in
  classify)   shift; classify_task "$@" ;;
  capacity)   shift; calculate_capacity "$@" ;;
  bottleneck) shift; check_bottleneck "$@" ;;
  matrix)     show_matrix ;;
  help|-h|--help) show_help ;;
  *) echo "Unknown: $1" >&2; show_help >&2; exit 1 ;;
esac
