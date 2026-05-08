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

# ── Tier-based model resolution (SPEC-127 Slice 1) ────────────────────────────
# Resolves a capability tier (heavy/mid/fast) or legacy short name
# (opus/sonnet/haiku) to the user's provider-specific model ID
# declared in ~/.savia/preferences.yaml.
#
# Falls through to preferences.yaml on first call; caches result in
# SAVIA_MODEL_{HEAVY,MID,FAST} env vars for subsequent calls (no
# repeated YAML parsing).
savia_resolve_model() {
  local tier="$1"
  local prefs_file="${HOME}/.savia/preferences.yaml"

  _read_pref() {
    local key="$1"
    awk -v k="^${key}:" '
      $0 ~ k { sub(k, ""); sub(/^[[:space:]]+/, ""); gsub(/^"|"$/, ""); gsub(/^\047|\047$/, ""); print; exit }
    ' "$prefs_file" 2>/dev/null
  }

  case "$tier" in
    heavy)
      if [[ -z "${SAVIA_MODEL_HEAVY:-}" && -f "$prefs_file" ]]; then
        export SAVIA_MODEL_HEAVY="$(_read_pref "model_heavy")"
      fi
      [[ -n "${SAVIA_MODEL_HEAVY:-}" ]] && echo "${SAVIA_MODEL_HEAVY}" || echo "heavy"
      ;;
    mid)
      if [[ -z "${SAVIA_MODEL_MID:-}" && -f "$prefs_file" ]]; then
        export SAVIA_MODEL_MID="$(_read_pref "model_mid")"
      fi
      [[ -n "${SAVIA_MODEL_MID:-}" ]] && echo "${SAVIA_MODEL_MID}" || echo "mid"
      ;;
    fast)
      if [[ -z "${SAVIA_MODEL_FAST:-}" && -f "$prefs_file" ]]; then
        export SAVIA_MODEL_FAST="$(_read_pref "model_fast")"
      fi
      [[ -n "${SAVIA_MODEL_FAST:-}" ]] && echo "${SAVIA_MODEL_FAST}" || echo "fast"
      ;;
    opus|claude-opus-4-7|claude-opus-4-5)
      savia_resolve_model heavy
      ;;
    sonnet|claude-sonnet-4-6|claude-sonnet-4-5)
      savia_resolve_model mid
      ;;
    haiku|claude-haiku-4-5-20251001)
      savia_resolve_model fast
      ;;
    *)
      echo "$tier"  # pass-through for non-tier, non-legacy names
      ;;
  esac
}
export -f savia_resolve_model

# ── Main (source mode) ───────────────────────────────────────────────────────
# --------------------------------------------------------------------------
# AUTONOMOUS_REVIEWER resolver (autonomous-safety.md)
#
# Fallback chain:
#   1) $SAVIA_AUTONOMOUS_REVIEWER  (explicit env override)
#   2) .claude/rules/pm-config.local.md  AUTONOMOUS_REVIEWER = "..."
#   3) ~/.savia/preferences.yaml         autonomous_reviewer: ...
#   4) git config user.email             (zero-config common case)
#   5) "@local-user"                     (generic fallback, never blocks)
# --------------------------------------------------------------------------
savia_autonomous_reviewer() {
  if [[ -n "${SAVIA_AUTONOMOUS_REVIEWER:-}" ]]; then
    printf '%s\n' "$SAVIA_AUTONOMOUS_REVIEWER"
    return 0
  fi

  local ws; ws="$(_resolve_workspace)"
  local local_cfg="$ws/.claude/rules/pm-config.local.md"
  if [[ -r "$local_cfg" ]]; then
    local v
    v="$(grep -E '^\s*AUTONOMOUS_REVIEWER\s*=' "$local_cfg" 2>/dev/null \
         | head -n1 \
         | sed -E 's/^[^=]*=\s*"?([^"]*)"?\s*$/\1/' \
         | tr -d '[:space:]')"
    if [[ -n "$v" && "$v" != "@local-user" ]]; then
      printf '%s\n' "$v"
      return 0
    fi
  fi

  local prefs="$HOME/.savia/preferences.yaml"
  if [[ -r "$prefs" ]]; then
    local v
    v="$(grep -E '^\s*autonomous_reviewer\s*:' "$prefs" 2>/dev/null \
         | head -n1 \
         | sed -E 's/^[^:]*:\s*"?([^"]*)"?\s*$/\1/' \
         | tr -d '[:space:]')"
    if [[ -n "$v" ]]; then
      printf '%s\n' "$v"
      return 0
    fi
  fi

  if command -v git >/dev/null 2>&1; then
    local email
    email="$(git -C "$ws" config user.email 2>/dev/null)"
    if [[ -n "$email" ]]; then
      # Convert "user.name@example.com" -> "@user-name"
      printf '@%s\n' "${email%@*}"
      return 0
    fi
  fi

  printf '@local-user\n'
}

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  # Sourced from another script: export variables
  export SAVIA_WORKSPACE_DIR="${SAVIA_WORKSPACE_DIR:-$(_resolve_workspace)}"
  export SAVIA_PROVIDER="${SAVIA_PROVIDER:-$(_resolve_provider)}"
else
  # Direct invocation: print requested value
  case "${1:-}" in
    workspace) _resolve_workspace ;;
    provider)  _resolve_provider ;;
    reviewer)  savia_autonomous_reviewer ;;
    json)
      printf '{"workspace":"%s","provider":"%s","reviewer":"%s","has_hooks":%s,"has_slash_commands":%s}\n' \
        "$(_resolve_workspace)" \
        "$(_resolve_provider)" \
        "$(savia_autonomous_reviewer)" \
        "$(savia_has_hooks && echo true || echo false)" \
        "$(savia_has_slash_commands && echo true || echo false)"
      ;;
    *)
      echo "Usage: savia-env.sh <workspace|provider|reviewer|json>" >&2
      exit 2
      ;;
  esac
fi
