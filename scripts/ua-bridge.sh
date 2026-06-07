#!/usr/bin/env bash
set -uo pipefail
# ua-bridge.sh — Bridge between Savia and Understand-Anything
# Ref: SPEC-SE-088-UA-ADOPT
# Usage: bash scripts/ua-bridge.sh <command> [args...]
#
# Subcommands:
#   check                   Verify if UA is available (exit 0 = yes, exit 1 = no)
#   analyze [path]          Invoke opencode /ua-analyze or report UA not installed
#   diff [--count]          Analyze uncommitted changes; --count returns a number
#   domain [path]           Extract domain/business concepts
#   chat <query>            Semantic search the knowledge graph
#   dashboard               Start interactive dashboard
#   onboard [path]          Generate guided onboarding tour
#   install                 Install or update UA plugin

UA_AGENTS_DIR="${UA_AGENTS_DIR:-$HOME/.agents/skills/ua}"
UA_WHICH=$(command -v understand-anything 2>/dev/null || true)

# ── check: is UA available? ──────────────────────────────────────────────────
_ua_check() {
  if [[ -d "$UA_AGENTS_DIR" ]] || [[ -n "$UA_WHICH" ]]; then
    return 0
  fi
  return 1
}

# ── analyze ──────────────────────────────────────────────────────────────────
_ua_analyze() {
  local target="${1:-.}"
  if ! _ua_check; then
    echo "UA not installed. Run: bash scripts/ua-install.sh" >&2
    exit 0
  fi
  if [[ ! -e "$target" ]]; then
    echo "Path not found: $target — skipping analysis." >&2
    exit 0
  fi
  echo "Analyzing $target with Understand-Anything..."
  opencode run "/ua-analyze $target" 2>/dev/null || \
    bash "$(dirname "$0")/../scripts/knowledge-graph.py" "$target" 2>/dev/null || \
    echo "Fallback: use scripts/knowledge-graph.py manually"
}

# ── diff ─────────────────────────────────────────────────────────────────────
_ua_diff() {
  local count_only=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --count) count_only=true; shift ;;
      *) shift ;;
    esac
  done

  if ! _ua_check; then
    # Graceful: return 0 when UA not installed
    if $count_only; then
      echo "0"
    else
      echo "UA not installed. Diff impact: 0 nodes." >&2
    fi
    exit 0
  fi

  local diff_count=0
  # Try to count changed nodes via git diff
  diff_count=$(git -C "$(pwd)" diff --name-only 2>/dev/null | wc -l | tr -d ' ') || diff_count=0

  if $count_only; then
    echo "$diff_count"
  else
    echo "Diff impact: ~$diff_count nodes affected"
    [[ "$diff_count" -gt 50 ]] && echo "WARN: >50 nodes affected by this change"
  fi
}

# ── domain ───────────────────────────────────────────────────────────────────
_ua_domain() {
  local target="${1:-.}"
  if ! _ua_check; then
    echo "UA not installed. Run: bash scripts/ua-install.sh" >&2
    exit 0
  fi
  if [[ ! -e "$target" ]]; then
    echo "Path not found: $target — skipping domain analysis." >&2
    exit 0
  fi
  echo "Extracting domain concepts from $target..."
  opencode run "/ua-domain $target" 2>/dev/null || \
    echo "Fallback: use scripts/knowledge-graph.py --domain $target"
}

# ── chat ─────────────────────────────────────────────────────────────────────
_ua_chat() {
  local query="$*"
  if ! _ua_check; then
    echo "UA not installed. Run: bash scripts/ua-install.sh" >&2
    exit 0
  fi
  [[ -z "$query" ]] && { echo "Usage: ua-bridge.sh chat <query>" >&2; exit 1; }
  opencode run "/ua-chat $query" 2>/dev/null || echo "UA chat unavailable"
}

# ── dashboard ─────────────────────────────────────────────────────────────────
_ua_dashboard() {
  if ! _ua_check; then
    echo "UA not installed. Run: bash scripts/ua-install.sh" >&2
    exit 0
  fi
  echo "Starting UA dashboard..."
  opencode run "/ua-dashboard" 2>/dev/null || \
    echo "UA dashboard unavailable. Install UA first."
}

# ── onboard ──────────────────────────────────────────────────────────────────
_ua_onboard() {
  local target="${1:-.}"
  if ! _ua_check; then
    echo "UA not installed. Run: bash scripts/ua-install.sh" >&2
    exit 0
  fi
  if [[ ! -e "$target" ]]; then
    echo "Path not found: $target — skipping onboarding." >&2
    exit 0
  fi
  echo "Generating onboarding guide for $target..."
  opencode run "/ua-onboard $target" 2>/dev/null || \
    echo "UA onboard unavailable"
}

# ── dispatch ─────────────────────────────────────────────────────────────────
CMD="${1:-help}"
shift 2>/dev/null || true

case "$CMD" in
  check)
    if _ua_check; then
      echo "UA available"
      exit 0
    else
      echo "UA not installed"
      exit 1
    fi
    ;;
  analyze)   _ua_analyze "$@" ;;
  diff)      _ua_diff "$@" ;;
  domain)    _ua_domain "$@" ;;
  chat)      _ua_chat "$@" ;;
  dashboard) _ua_dashboard ;;
  onboard)   _ua_onboard "$@" ;;
  install)   bash "$(dirname "$0")/ua-install.sh" "$@" ;;
  help|*)
    cat >&2 <<'EOF'
Usage: ua-bridge.sh <subcommand> [args]

Subcommands:
  check              Verify if UA is available (exit 0 = yes, exit 1 = no)
  analyze [path]     Analyze codebase and generate knowledge-graph.json
  diff [--count]     Analyze uncommitted changes; --count prints number only
  domain [path]      Extract business domain concepts
  chat <query>       Semantic search the knowledge graph
  dashboard          Start interactive dashboard
  onboard [path]     Generate guided onboarding tour
  install            Install or update UA plugin

Ref: SPEC-SE-088-UA-ADOPT
EOF
    exit 1
    ;;
esac
