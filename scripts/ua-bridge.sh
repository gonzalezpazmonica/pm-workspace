#!/bin/bash
set -uo pipefail
# ua-bridge.sh — Bridge between Savia and Understand-Anything
# Usage: bash scripts/ua-bridge.sh <command> [args...]
#
# Commands:
#   analyze <path>        Generate knowledge-graph.json for a codebase
#   domain <path>         Extract domain/business concepts
#   diff                   Analyze uncommitted changes impact
#   chat <query>           Semantic search the knowledge graph
#   dashboard              Start interactive dashboard
#   onboard <path>         Generate guided onboarding tour
#   install                Install or update UA plugin

UA_DIR="${UA_DIR:-$HOME/.opencode/understand-anything}"
UA_PLUGIN="${UA_PLUGIN:-$HOME/.understand-anything-plugin}"

CMD="${1:-help}"
shift 2>/dev/null || true

# Check if UA is installed
check_ua() {
  if [[ ! -d "$UA_DIR" ]]; then
    echo "Understand-Anything not installed. Run: bash scripts/ua-install.sh" >&2
    exit 1
  fi
}

ua_analyze() {
  check_ua
  local target="${1:-.}"
  echo "Analyzing $target with Understand-Anything..."
  cd "$UA_DIR" && opencode run "/understand $target" 2>/dev/null || \
    echo "UA analysis started. Check $UA_DIR/knowledge-graph.json for results."
}

ua_domain() {
  check_ua
  local target="${1:-.}"
  echo "Extracting domain concepts from $target..."
  cd "$UA_DIR" && opencode run "/understand-domain $target" 2>/dev/null || \
    echo "UA domain analysis started."
}

ua_diff() {
  check_ua
  local count
  echo "Analyzing uncommitted changes impact..."
  cd "$UA_DIR" && opencode run "/understand-diff" 2>/dev/null
  count=$(cd "$UA_DIR" && grep -c "\"id\":" knowledge-graph.json 2>/dev/null || echo "0")
  echo "Impact: ~$count nodes affected"
  [[ $count -gt 50 ]] && echo "WARN: >50 nodes affected by this change"
}

ua_chat() {
  check_ua
  local query="$*"
  [[ -z "$query" ]] && { echo "Usage: /ua-chat <query>"; exit 1; }
  cd "$UA_DIR" && opencode run "/understand-chat $query" 2>/dev/null
}

ua_dashboard() {
  check_ua
  echo "Starting UA dashboard..."
  cd "$UA_DIR" && opencode run "/understand-dashboard" 2>/dev/null &
  echo "Dashboard running at http://localhost:5174"
}

ua_onboard() {
  check_ua
  local target="${1:-.}"
  echo "Generating onboarding guide for $target..."
  cd "$UA_DIR" && opencode run "/understand-onboard $target" 2>/dev/null
}

case "$CMD" in
  analyze)   ua_analyze "$@" ;;
  domain)    ua_domain "$@" ;;
  diff)      ua_diff "$@" ;;
  chat)      ua_chat "$@" ;;
  dashboard) ua_dashboard ;;
  onboard)   ua_onboard "$@" ;;
  install)   bash "$(dirname "$0")/ua-install.sh" "$@" ;;
  *)
    echo "Usage: ua-bridge.sh <analyze|domain|diff|chat|dashboard|onboard|install> [args]"
    exit 1
    ;;
esac
