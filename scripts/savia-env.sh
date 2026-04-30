#!/usr/bin/env bash
set -uo pipefail
# savia-env.sh — provider-agnostic environment loader (SPEC-127 Slice 1)
#
# Single source of truth for workspace path, active provider detection, and
# capability probes across any frontend × any inference provider. Source from
# any hook or script:
#
#   source "$(dirname "$0")/../scripts/savia-env.sh"
#   echo "Workspace: $SAVIA_WORKSPACE_DIR"
#   echo "Provider:  $SAVIA_PROVIDER"
#
# Or invoke standalone:
#
#   bash scripts/savia-env.sh print
#   bash scripts/savia-env.sh workspace
#   bash scripts/savia-env.sh provider
#   bash scripts/savia-env.sh has-hooks
#   bash scripts/savia-env.sh has-task-fan-out
#   bash scripts/savia-env.sh has-slash-commands
#
# This script does NOT hard-code any vendor. It reads
# `~/.savia/preferences.yaml` if present (managed by `savia-preferences.sh`)
# and falls back to env-var autodetection when preferences are absent.
#
# Reference: SPEC-127 (docs/propuestas/SPEC-127-savia-opencode-provider-agnostic.md)
# Reference: docs/rules/domain/provider-agnostic-env.md
# Reference: docs/rules/domain/autonomous-safety.md

# ── Preferences file (per-user, never in repo) ──────────────────────────────
SAVIA_PREFS_FILE="${SAVIA_PREFS_FILE:-${HOME:-/tmp}/.savia/preferences.yaml}"

# Read a top-level scalar from the preferences yaml. Minimal parser, no deps.
# Returns empty string if file or key absent.
_savia_pref() {
  local key="$1"
  [[ -f "$SAVIA_PREFS_FILE" ]] || return 0
  awk -v k="^${key}:" '
    $0 ~ k {
      sub(k, ""); sub(/^[[:space:]]+/, "")
      gsub(/^"|"$/, "")
      gsub(/^'\''|'\''$/, "")
      print
      exit
    }
  ' "$SAVIA_PREFS_FILE"
}

# ── Workspace dir resolution ────────────────────────────────────────────────
# Fallback chain (first non-empty wins):
#   1. SAVIA_WORKSPACE_DIR  — explicit override (any provider)
#   2. CLAUDE_PROJECT_DIR   — Claude Code native
#   3. OPENCODE_PROJECT_DIR — OpenCode v1.14+ native
#   4. git rev-parse --show-toplevel — VCS fallback
#   5. pwd — last resort
savia_workspace_dir() {
  if [[ -n "${SAVIA_WORKSPACE_DIR:-}" ]]; then
    echo "$SAVIA_WORKSPACE_DIR"; return 0
  fi
  if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    echo "$CLAUDE_PROJECT_DIR"; return 0
  fi
  if [[ -n "${OPENCODE_PROJECT_DIR:-}" ]]; then
    echo "$OPENCODE_PROJECT_DIR"; return 0
  fi
  local root
  if root=$(git rev-parse --show-toplevel 2>/dev/null); then
    echo "$root"; return 0
  fi
  pwd
}

# ── Provider detection ──────────────────────────────────────────────────────
# Order:
#   1. SAVIA_PROVIDER explicit env override (operator one-shot)
#   2. preferences.yaml `provider:` key
#   3. autodetect via env vars when frontend leaves a clear signal
#   4. unknown
# Provider name is a free-form string (vendor name, "localai", "ollama",
# "claude", "custom-corp", whatever the user declared). Callers MUST NOT
# branch on hardcoded vendor names — branch on capability probes instead.
savia_provider() {
  if [[ -n "${SAVIA_PROVIDER:-}" ]]; then
    echo "$SAVIA_PROVIDER"; return 0
  fi
  local pref
  pref=$(_savia_pref "provider")
  if [[ -n "$pref" ]]; then
    echo "$pref"; return 0
  fi
  # Autodetect — agnostic signals only
  if [[ -n "${ANTHROPIC_BASE_URL:-}" ]]; then
    case "${ANTHROPIC_BASE_URL}" in
      *localhost*|*127.0.0.1*|*localai*|*ollama*) echo "local"; return 0 ;;
    esac
  fi
  if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    echo "claude-code"; return 0
  fi
  if [[ -n "${OPENCODE_PROJECT_DIR:-}" ]]; then
    echo "opencode"; return 0
  fi
  echo "unknown"
}

# ── Capability probes (4 orthogonal axes) ──────────────────────────────────
# Each probe reads preferences.yaml first (user declared), then falls back to
# autodetect by frontend signal. NEVER hard-codes vendor-specific assumptions.
# Returns 0 (yes) or 1 (no). `unknown` defaults to permissive — callers can
# tighten with explicit preference.

# _capability: returns 0 (yes), 1 (no), or 2 (autodetect — caller falls through)
_capability() {
  local key="$1"
  local pref
  pref=$(_savia_pref "$key")
  case "$pref" in
    yes|true|1)        return 0 ;;
    no|false|0)        return 1 ;;
    autodetect|""|*)   return 2 ;;
  esac
}

# Hook surface: does the frontend expose tool-call telemetry to workspace
# scripts? Autodetect: yes if Claude Code (CLAUDE_PROJECT_DIR set + hook
# stdin pattern), no otherwise. User can override in preferences.yaml.
savia_has_hooks() {
  _capability "has_hooks"
  case $? in
    0) return 0 ;;
    1) return 1 ;;
    *) [[ -n "${CLAUDE_PROJECT_DIR:-}" ]] && return 0 || return 1 ;;
  esac
}

# Slash command surface: does the frontend support /command-name invocation?
# Autodetect: yes if Claude Code or OpenCode native, permissive otherwise.
# User can override in preferences.yaml.
savia_has_slash_commands() {
  _capability "has_slash_commands"
  case $? in
    0) return 0 ;;
    1) return 1 ;;
    *)
      [[ -n "${CLAUDE_PROJECT_DIR:-}" ]] && return 0
      [[ -n "${OPENCODE_PROJECT_DIR:-}" ]] && return 0
      return 0  # permissive default — caller probes when uncertain
      ;;
  esac
}

# Subagent fan-out: does the frontend / provider support Task tool?
# Autodetect: yes if Claude Code, no otherwise (most providers don't).
# User can override in preferences.yaml.
savia_has_task_fan_out() {
  _capability "has_task_fan_out"
  case $? in
    0) return 0 ;;
    1) return 1 ;;
    *) [[ -n "${CLAUDE_PROJECT_DIR:-}" ]] && return 0 || return 1 ;;
  esac
}

# Export normalized values when sourced
SAVIA_WORKSPACE_DIR="$(savia_workspace_dir)"
export SAVIA_WORKSPACE_DIR
SAVIA_PROVIDER="$(savia_provider)"
export SAVIA_PROVIDER

# ── CLI dispatch ────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-print}" in
    print)
      printf 'SAVIA_WORKSPACE_DIR=%s\n' "$SAVIA_WORKSPACE_DIR"
      printf 'SAVIA_PROVIDER=%s\n' "$SAVIA_PROVIDER"
      printf 'has_hooks=%s\n' "$(savia_has_hooks && echo yes || echo no)"
      printf 'has_slash_commands=%s\n' "$(savia_has_slash_commands && echo yes || echo no)"
      printf 'has_task_fan_out=%s\n' "$(savia_has_task_fan_out && echo yes || echo no)"
      printf 'preferences_file=%s%s\n' "$SAVIA_PREFS_FILE" \
        "$([[ -f "$SAVIA_PREFS_FILE" ]] && echo " (present)" || echo " (absent — defaults applied)")"
      ;;
    workspace) echo "$SAVIA_WORKSPACE_DIR" ;;
    provider)  echo "$SAVIA_PROVIDER" ;;
    has-hooks)
      savia_has_hooks && echo yes || echo no
      ;;
    has-slash-commands)
      savia_has_slash_commands && echo yes || echo no
      ;;
    has-task-fan-out)
      savia_has_task_fan_out && echo yes || echo no
      ;;
    --help|-h)
      cat <<USG
Usage: savia-env.sh [print|workspace|provider|has-hooks|has-slash-commands|has-task-fan-out]

When sourced (set SAVIA_WORKSPACE_DIR / SAVIA_PROVIDER for caller):
  source scripts/savia-env.sh

When invoked:
  bash scripts/savia-env.sh print              # all values
  bash scripts/savia-env.sh workspace          # workspace dir only
  bash scripts/savia-env.sh provider           # provider name only
  bash scripts/savia-env.sh has-hooks          # yes|no
  bash scripts/savia-env.sh has-slash-commands # yes|no
  bash scripts/savia-env.sh has-task-fan-out   # yes|no

Preferences source: \$SAVIA_PREFS_FILE (default ~/.savia/preferences.yaml).
Configure via: bash scripts/savia-preferences.sh init
USG
      ;;
    *) echo "unknown subcommand: $1" >&2; exit 2 ;;
  esac
fi
