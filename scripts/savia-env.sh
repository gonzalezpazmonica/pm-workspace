#!/usr/bin/env bash
# savia-env.sh — Provider-agnostic environment layer (SPEC-127 Slice 1)
#
# Single source of truth for workspace path and provider detection.
# Hooks, scripts and skills MUST source this instead of hard-coding
# CLAUDE_PROJECT_DIR or assuming a specific provider.
#
# Usage:
#   source scripts/savia-env.sh          # export SAVIA_WORKSPACE_DIR + SAVIA_PROVIDER
#   bash scripts/savia-env.sh workspace  # one-shot: print SAVIA_WORKSPACE_DIR
#   bash scripts/savia-env.sh provider   # one-shot: print SAVIA_PROVIDER
set -uo pipefail

# ── Capability probes ────────────────────────────────────────────────────────
savia_has_hooks() {
  case "${SAVIA_PROVIDER:-}" in
    copilot)  return 1 ;;  # OpenCode-Copilot Enterprise: zero hook surface
    localai)  return 0 ;;  # LocalAI runs under Claude Code shell
    claude)   return 0 ;;  # Full PreToolUse/PostToolUse/Stop surface
    unknown)  return 0 ;;  # Permissive: let downstream gates catch gaps
    *)        return 0 ;;  # OpenCode-Claude: ~25 events via plugin TS
  esac
}

savia_has_slash_commands() {
  case "${SAVIA_PROVIDER:-}" in
    copilot)  return 1 ;;  # Zero slash mechanism
    claude)   return 0 ;;  # Native slash commands
    localai)  return 0 ;;  # Claude Code shell
    unknown)  return 0 ;;  # Permissive
    *)        return 0 ;;  # OpenCode-Claude: .opencode/commands/
  esac
}

# ── Resolve workspace dir (fallback chain) ───────────────────────────────────
_resolve_workspace() {
  # 1. Explicit override (any provider)
  if [[ -n "${SAVIA_WORKSPACE_DIR:-}" ]]; then
    echo "$SAVIA_WORKSPACE_DIR"
    return
  fi

  # 2. Claude Code native
  if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    echo "$CLAUDE_PROJECT_DIR"
    return
  fi

  # 3. OpenCode v1.14+
  if [[ -n "${OPENCODE_PROJECT_DIR:-}" ]]; then
    echo "$OPENCODE_PROJECT_DIR"
    return
  fi

  # 4. git root
  local git_root
  git_root=$(git rev-parse --show-toplevel 2>/dev/null) || true
  if [[ -n "${git_root:-}" ]]; then
    echo "$git_root"
    return
  fi

  # 5. Last resort
  pwd
}

# ── Detect provider (precedence chain) ───────────────────────────────────────
_resolve_provider() {
  # 1. Operator override
  if [[ -n "${SAVIA_PROVIDER:-}" ]]; then
    echo "$SAVIA_PROVIDER"
    return
  fi

  # 2. ANTHROPIC_BASE_URL points to localhost/localai
  local base_url="${ANTHROPIC_BASE_URL:-}"
  if [[ -n "$base_url" ]] && [[ "$base_url" == *"localhost"* || "$base_url" == *"127.0.0.1"* || "$base_url" == *"localai"* ]]; then
    echo "localai"
    return
  fi

  # 3. Copilot tokens present
  if [[ -n "${COPILOT_TOKEN:-}" || -n "${GITHUB_COPILOT_TOKEN:-}" ]]; then
    echo "copilot"
    return
  fi

  # 4. OpenCode provider env
  if [[ -n "${OPENCODE_PROVIDER:-}" ]]; then
    echo "$OPENCODE_PROVIDER"
    return
  fi

  # 5. Claude Code native
  if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    echo "claude"
    return
  fi

  # 6. Unknown
  echo "unknown"
}

# ── Main (source mode) ───────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  # Sourced from another script: export variables
  export SAVIA_WORKSPACE_DIR="${SAVIA_WORKSPACE_DIR:-$(_resolve_workspace)}"
  export SAVIA_PROVIDER="${SAVIA_PROVIDER:-$(_resolve_provider)}"
else
  # Direct invocation: print requested value
  case "${1:-}" in
    workspace) _resolve_workspace ;;
    provider)  _resolve_provider ;;
    json)
      printf '{"workspace":"%s","provider":"%s","has_hooks":%s,"has_slash_commands":%s}\n' \
        "$(_resolve_workspace)" \
        "$(_resolve_provider)" \
        "$(savia_has_hooks && echo true || echo false)" \
        "$(savia_has_slash_commands && echo true || echo false)"
      ;;
    *)
      echo "Usage: savia-env.sh <workspace|provider|json>" >&2
      exit 2
      ;;
  esac
fi
