#!/usr/bin/env bash
# tenant-isolation-gate.sh — Cross-tenant access prevention hook
# SPEC: SPEC-SE-002 Multi-Tenant & RBAC
# Layer: Enterprise (PreToolUse: Edit|Write|Read)
#
# Blocks any attempt to read/write a path under tenants/<other-slug>/
# when the active tenant is X. Allows:
#   - Own tenant paths (tenants/<active>/...)
#   - Core dirs (.claude/, scripts/, docs/, tests/, output/)
# No-op when multi-tenant module is disabled or no tenant is active.
#
# Audit log: output/tenant-audit.jsonl (append-only)

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
MANIFEST="$PROJECT_DIR/.claude/enterprise/manifest.json"
AUDIT_LOG="$PROJECT_DIR/output/tenant-audit.jsonl"
RESOLVER="$PROJECT_DIR/.claude/enterprise/hooks/tenant-resolver.sh"

# Gate: only run if Enterprise multi-tenant module is enabled
if [[ ! -f "$MANIFEST" ]]; then
  exit 0
fi

if command -v jq >/dev/null 2>&1; then
  ENABLED=$(jq -r '.modules["multi-tenant"].enabled // false' "$MANIFEST" 2>/dev/null)
else
  ENABLED=$(grep -A2 '"multi-tenant"' "$MANIFEST" 2>/dev/null | grep '"enabled"' | grep -o 'true\|false' | head -1)
fi
[[ "$ENABLED" != "true" ]] && exit 0

# Resolve active tenant
if [[ -f "$RESOLVER" ]]; then
  # shellcheck source=/dev/null
  source "$RESOLVER"
  ACTIVE_TENANT=$(tenant_resolve)
else
  ACTIVE_TENANT="${SAVIA_TENANT:-}"
fi

# No active tenant → no-op (single-tenant mode)
[[ -z "$ACTIVE_TENANT" ]] && exit 0

# Read stdin JSON
INPUT=""
if [[ ! -t 0 ]]; then
  if command -v timeout >/dev/null 2>&1 && timeout --version >/dev/null 2>&1; then
    INPUT=$(timeout 3 cat 2>/dev/null) || true
  else
    INPUT=$(cat 2>/dev/null) || true
  fi
fi
[[ -z "$INPUT" ]] && exit 0

# Extract file_path (graceful on malformed JSON)
FILE_PATH=""
if command -v jq >/dev/null 2>&1; then
  FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null) || FILE_PATH=""
fi
[[ -z "$FILE_PATH" ]] && exit 0

# Normalize path (resolve ../ and backslashes)
NORM_PATH="$FILE_PATH"
if command -v python3 >/dev/null 2>&1; then
  NORM_PATH=$(python3 -c "import os,sys;print(os.path.normpath(sys.argv[1]).replace(chr(92),'/'))" "$FILE_PATH" 2>/dev/null) || NORM_PATH="$FILE_PATH"
fi

log_decision() {
  local verdict="$1" reason="$2"
  mkdir -p "$(dirname "$AUDIT_LOG")" 2>/dev/null
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
  printf '{"ts":"%s","tenant_id":"%s","path":"%s","verdict":"%s","reason":"%s"}\n' \
    "$ts" "$ACTIVE_TENANT" "$NORM_PATH" "$verdict" "$reason" >> "$AUDIT_LOG" 2>/dev/null || true
}

# Allowlist: Core dirs — always permitted regardless of tenant
case "$NORM_PATH" in
  */.claude/*|.claude/*|*/scripts/*|scripts/*|*/docs/*|docs/*|*/tests/*|tests/*|*/output/*|output/*)
    log_decision "ALLOW" "core-dir"
    exit 0
    ;;
esac

# Tenant path check
if [[ "$NORM_PATH" == *"/tenants/"* || "$NORM_PATH" == tenants/* ]]; then
  TARGET_TENANT=$(printf '%s' "$NORM_PATH" | sed -n 's|.*/tenants/\([^/][^/]*\).*|\1|p;s|^tenants/\([^/][^/]*\).*|\1|p' | head -1)

  if [[ -z "$TARGET_TENANT" ]]; then
    # tenants/ root itself — allow
    log_decision "ALLOW" "tenants-root"
    exit 0
  fi

  if [[ "$TARGET_TENANT" == "$ACTIVE_TENANT" ]]; then
    log_decision "ALLOW" "own-tenant"
    exit 0
  fi

  # Cross-tenant access → BLOCK
  log_decision "BLOCK" "cross-tenant"
  echo "BLOQUEADO [tenant-isolation]: acceso cross-tenant denegado" >&2
  echo "  Active tenant:  $ACTIVE_TENANT" >&2
  echo "  Target tenant:  $TARGET_TENANT" >&2
  echo "  Path:           $NORM_PATH" >&2
  exit 2
fi

# Outside tenants/ and outside Core allowlist → allow (project-level files, etc.)
log_decision "ALLOW" "non-tenant"
exit 0
