#!/usr/bin/env bash
set -uo pipefail
# savia-env.sh — provider-agnostic environment loader (SPEC-127 Slice 1)
#
# Single source of truth for workspace path and active provider detection
# across Claude Code, OpenCode-Claude, OpenCode-Copilot Enterprise, and
# LocalAI emergency fallback. Source from any hook or script:
#
#   source "$(dirname "$0")/../scripts/savia-env.sh"
#   echo "Workspace: $SAVIA_WORKSPACE_DIR"
#   echo "Provider:  $SAVIA_PROVIDER"
#
# Or invoke standalone for a one-shot resolve:
#
#   bash scripts/savia-env.sh print
#   bash scripts/savia-env.sh workspace
#   bash scripts/savia-env.sh provider
#
# Reference: SPEC-127 (docs/propuestas/SPEC-127-savia-opencode-copilot-enterprise-compat.md)
# Reference: docs/rules/domain/provider-agnostic-env.md
# Reference: docs/rules/domain/autonomous-safety.md

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
# Order matters — most specific signal wins:
#   1. SAVIA_PROVIDER explicit (operator override)
#   2. ANTHROPIC_BASE_URL points to LocalAI (emergency mode, SPEC-122)
#   3. COPILOT_TOKEN / GITHUB_COPILOT_* present (Copilot Enterprise)
#   4. OPENCODE_PROVIDER set (OpenCode dispatch)
#   5. CLAUDE_PROJECT_DIR present (Claude Code native)
#   6. unknown — caller must handle
savia_provider() {
  if [[ -n "${SAVIA_PROVIDER:-}" ]]; then
    echo "$SAVIA_PROVIDER"; return 0
  fi
  local base="${ANTHROPIC_BASE_URL:-}"
  if [[ -n "$base" ]]; then
    case "$base" in
      *localai*|*127.0.0.1*|*localhost*)
        echo "localai"; return 0
        ;;
    esac
  fi
  if [[ -n "${COPILOT_TOKEN:-}" || -n "${GITHUB_COPILOT_TOKEN:-}" ]]; then
    echo "copilot"; return 0
  fi
  if [[ -n "${OPENCODE_PROVIDER:-}" ]]; then
    echo "$OPENCODE_PROVIDER"; return 0
  fi
  if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    echo "claude"; return 0
  fi
  echo "unknown"
}

# ── Hook surface availability ───────────────────────────────────────────────
# Returns 0 if running under a frontend that exposes hook events to the
# workspace. Copilot Enterprise has zero hook surface — callers should
# degrade gracefully (TIER-2 git pre-commit, TIER-3 CI-only, TIER-4 lost).
savia_has_hooks() {
  case "$(savia_provider)" in
    claude|localai) return 0 ;;
    copilot)        return 1 ;;
    *)              return 0 ;;  # default to permissive — caller verifies
  esac
}

# ── Slash command surface availability ──────────────────────────────────────
# OpenCode has partial slash command support, Copilot has zero. Callers that
# need to register a command surface should branch on this.
savia_has_slash_commands() {
  case "$(savia_provider)" in
    claude)         return 0 ;;
    localai)        return 0 ;;
    copilot)        return 1 ;;  # MCP shim required (SPEC-127 Slice 3)
    *)              return 0 ;;
  esac
}

# Export normalized values when sourced
SAVIA_WORKSPACE_DIR="$(savia_workspace_dir)"
export SAVIA_WORKSPACE_DIR
SAVIA_PROVIDER="$(savia_provider)"
export SAVIA_PROVIDER

# ── CLI dispatch (only when invoked, not sourced) ───────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-print}" in
    print)
      printf 'SAVIA_WORKSPACE_DIR=%s\n' "$SAVIA_WORKSPACE_DIR"
      printf 'SAVIA_PROVIDER=%s\n' "$SAVIA_PROVIDER"
      printf 'has_hooks=%s\n' "$(savia_has_hooks && echo yes || echo no)"
      printf 'has_slash_commands=%s\n' "$(savia_has_slash_commands && echo yes || echo no)"
      ;;
    workspace) echo "$SAVIA_WORKSPACE_DIR" ;;
    provider)  echo "$SAVIA_PROVIDER" ;;
    has-hooks)
      savia_has_hooks && echo yes || echo no
      ;;
    has-slash-commands)
      savia_has_slash_commands && echo yes || echo no
      ;;
    --help|-h)
      cat <<USG
Usage: savia-env.sh [print|workspace|provider|has-hooks|has-slash-commands]

When sourced (set SAVIA_WORKSPACE_DIR / SAVIA_PROVIDER for caller):
  source scripts/savia-env.sh

When invoked:
  bash scripts/savia-env.sh print     # all values
  bash scripts/savia-env.sh workspace # workspace dir only
  bash scripts/savia-env.sh provider  # provider name only
USG
      ;;
    *) echo "unknown subcommand: $1" >&2; exit 2 ;;
  esac
fi
