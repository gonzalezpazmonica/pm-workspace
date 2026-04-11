#!/usr/bin/env bash
# tenant-resolver.sh — Resolves the active Savia tenant slug
# SPEC: SPEC-SE-002 Multi-Tenant & RBAC
# Layer: Enterprise (extension point #5 from SE-001)
#
# Resolution order:
#   1. $SAVIA_TENANT env var
#   2. Current working directory under tenants/{slug}/
#   3. Active user profile (tenant: <slug> in identity.md)
#   4. Fallback: empty string (single-tenant mode, Core untouched)
#
# Usage:
#   Sourced:   source tenant-resolver.sh && slug=$(tenant_resolve)
#   Standalone: bash tenant-resolver.sh   (prints slug to stdout)

set -uo pipefail

tenant_resolve() {
  local slug=""
  local project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"

  # 1. Env var wins
  if [[ -n "${SAVIA_TENANT:-}" ]]; then
    printf '%s' "$SAVIA_TENANT"
    return 0
  fi

  # 2. Cwd under tenants/{slug}/
  local cwd
  cwd=$(pwd)
  if [[ "$cwd" == *"/tenants/"* ]]; then
    slug=$(printf '%s' "$cwd" | sed -n 's|.*/tenants/\([^/][^/]*\).*|\1|p')
    if [[ -n "$slug" ]]; then
      printf '%s' "$slug"
      return 0
    fi
  fi

  # 3. Active user profile
  local active_file="$project_dir/.claude/profiles/active-user.md"
  if [[ -f "$active_file" ]]; then
    local active_slug
    active_slug=$(grep -E '^active_slug:' "$active_file" 2>/dev/null | head -1 | sed -E 's/^active_slug:[[:space:]]*//' | tr -d '"'"'"' ')
    if [[ -n "$active_slug" ]]; then
      local identity="$project_dir/.claude/profiles/users/$active_slug/identity.md"
      if [[ -f "$identity" ]]; then
        slug=$(grep -E '^tenant:' "$identity" 2>/dev/null | head -1 | sed -E 's/^tenant:[[:space:]]*//' | tr -d '"'"'"' ')
        if [[ -n "$slug" ]]; then
          printf '%s' "$slug"
          return 0
        fi
      fi
    fi
  fi

  # 4. Fallback: empty = single-tenant mode
  printf ''
  return 0
}

# If run directly (not sourced), print the resolved slug
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  tenant_resolve
  echo
fi
