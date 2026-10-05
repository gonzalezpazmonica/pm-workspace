#!/usr/bin/env bash
set -uo pipefail
# ua-bridge.sh — Bridge between Savia and Understand-Anything
# Ref: SPEC-SE-088-UA-ADOPT
# Usage: bash scripts/ua-bridge.sh <command> [args...]
#
# Subcommands:
#   check                   Verify if UA is available (exit 0 = yes, exit 1 = no)
#   analyze [path]          Invoke opencode /ua-analyze or report UA not installed
#   diff [--count]          Count changed tracked files (staged + unstaged); --count prints the number
#   domain [path]           Extract domain/business concepts
#   chat <query>            Semantic search the knowledge graph
#   dashboard               Start interactive dashboard
#   onboard [path]          Generate guided onboarding tour
#   install                 Install or update UA plugin
#
# Exit codes: 0 ok or UA not installed (graceful degradation), 1 invalid input
# or UA run failed, 2 opencode missing while UA is installed.

UA_AGENTS_DIR="${UA_AGENTS_DIR:-$HOME/.agents/skills/ua}"
UA_WHICH=$(command -v understand-anything 2>/dev/null || true)

# ── check: is UA available? ──────────────────────────────────────────────────
_ua_check() {
  if [[ -d "$UA_AGENTS_DIR" ]] || [[ -n "$UA_WHICH" ]]; then
    return 0
  fi
  return 1
}

# ── run a UA slash command through opencode ──────────────────────────────────
# Never fall back to running Python sources with bash: the fallback graph
# (scripts/knowledge-graph.py) is a memory graph, not a codebase analysis,
# so a failed UA run is reported as a failure instead of a fake success.
_ua_run() {
  local slash="$1"
  if ! command -v opencode >/dev/null 2>&1; then
    echo "ERROR: opencode not found in PATH — cannot run $slash." >&2
    echo "Fallback (memory graph, not codebase): python3 scripts/knowledge-graph.py build" >&2
    exit 2
  fi
  if ! opencode run "$slash"; then
    echo "ERROR: UA command failed: $slash" >&2
    exit 1
  fi
}

# Guard for path-based subcommands: UA missing → graceful exit 0;
# UA present but path missing → invalid input, exit 1.
_ua_require_path() {
  local target="$1"
  if ! _ua_check; then
    echo "UA not installed. Run: bash scripts/ua-install.sh" >&2
    exit 0
  fi
  if [[ ! -e "$target" ]]; then
    echo "Path not found: $target" >&2
    exit 1
  fi
}

# ── analyze ──────────────────────────────────────────────────────────────────
_ua_analyze() {
  local target="${1:-.}"
  _ua_require_path "$target"
  echo "Analyzing $target with Understand-Anything..."
  _ua_run "/ua-analyze $target"
}

# ── diff ─────────────────────────────────────────────────────────────────────
# Counts changed tracked files (staged + unstaged, deduplicated). It is a file
# count used as a proxy for graph impact, not a node count.
_ua_diff() {
  local count_only=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --count) count_only=true; shift ;;
      *) echo "Unknown option for diff: $1" >&2; exit 1 ;;
    esac
  done

  if ! _ua_check; then
    # Graceful: return 0 when UA not installed
    if $count_only; then
      echo "0"
    else
      echo "UA not installed. Diff impact: 0 files." >&2
    fi
    exit 0
  fi

  local diff_count=0
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "WARN: not a git work tree — diff impact reported as 0." >&2
  else
    # A failing git diff must not yield a silently partial count.
    local staged unstaged
    if ! staged=$(git diff --name-only --cached) || ! unstaged=$(git diff --name-only); then
      echo "ERROR: git diff failed — cannot count changed files." >&2
      exit 1
    fi
    diff_count=$(printf '%s\n%s\n' "$staged" "$unstaged" | sort -u | grep -c .)
  fi

  if $count_only; then
    echo "$diff_count"
  else
    echo "Diff impact: ~$diff_count files changed"
    if [[ "$diff_count" -gt 50 ]]; then
      echo "WARN: >50 files affected by this change"
    fi
  fi
  exit 0
}

# ── domain ───────────────────────────────────────────────────────────────────
_ua_domain() {
  local target="${1:-.}"
  _ua_require_path "$target"
  echo "Extracting domain concepts from $target..."
  _ua_run "/ua-domain $target"
}

# ── chat ─────────────────────────────────────────────────────────────────────
_ua_chat() {
  local query="$*"
  [[ -z "$query" ]] && { echo "Usage: ua-bridge.sh chat <query>" >&2; exit 1; }
  if ! _ua_check; then
    echo "UA not installed. Run: bash scripts/ua-install.sh" >&2
    exit 0
  fi
  _ua_run "/ua-chat $query"
}

# ── dashboard ─────────────────────────────────────────────────────────────────
_ua_dashboard() {
  if ! _ua_check; then
    echo "UA not installed. Run: bash scripts/ua-install.sh" >&2
    exit 0
  fi
  echo "Starting UA dashboard..."
  _ua_run "/ua-dashboard"
}

# ── onboard ──────────────────────────────────────────────────────────────────
_ua_onboard() {
  local target="${1:-.}"
  _ua_require_path "$target"
  echo "Generating onboarding guide for $target..."
  _ua_run "/ua-onboard $target"
}

# ── usage ────────────────────────────────────────────────────────────────────
_ua_usage() {
  cat >&2 <<'EOF'
Usage: ua-bridge.sh <subcommand> [args]

Subcommands:
  check              Verify if UA is available (exit 0 = yes, exit 1 = no)
  analyze [path]     Analyze codebase and generate knowledge-graph.json
  diff [--count]     Changed tracked files (staged + unstaged); --count prints number only
  domain [path]      Extract business domain concepts
  chat <query>       Semantic search the knowledge graph
  dashboard          Start interactive dashboard
  onboard [path]     Generate guided onboarding tour
  install            Install or update UA plugin

Exit codes: 0 ok or UA not installed, 1 invalid input or UA run failed,
2 opencode missing.
Ref: SPEC-SE-088-UA-ADOPT
EOF
}

# ── dispatch ─────────────────────────────────────────────────────────────────
CMD="${1:-}"
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
  help|-h|--help)
    _ua_usage
    exit 0
    ;;
  "")
    _ua_usage
    exit 1
    ;;
  *)
    echo "Unknown subcommand: $CMD" >&2
    _ua_usage
    exit 1
    ;;
esac
