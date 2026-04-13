#!/usr/bin/env bash
set -uo pipefail
# credential-proxy.sh — Managed Agents pattern: credential isolation
#
# Inspired by Anthropic's Managed Agents "Vault + Proxy" pattern.
# Agents call this proxy instead of reading credential files directly.
# The proxy reads the credential, executes the operation, and returns
# only the result — the credential never enters the agent's context.
#
# Usage:
#   bash scripts/credential-proxy.sh git-push [remote] [branch]
#   bash scripts/credential-proxy.sh git-clone [url] [dest]
#   bash scripts/credential-proxy.sh api-call [service] [endpoint] [method]
#   bash scripts/credential-proxy.sh status
#
# Security: credentials are read from files, used in subshell, never echoed.
# The agent sees only exit codes and sanitized output.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Credential file locations (never hardcoded values)
GITHUB_PAT_FILE="${GITHUB_PAT_FILE:-$HOME/.azure/devops-pat}"
AZDO_PAT_FILE="${AZDO_PAT_FILE:-$HOME/.azure/devops-pat}"
GRAPH_SECRET_FILE="${GRAPH_SECRET_FILE:-$HOME/.azure/graph-secret}"
MIRO_TOKEN_FILE="${MIRO_TOKEN_FILE:-$HOME/.azure/miro-token}"

# Audit log (append-only, gitignored)
AUDIT_LOG="${CREDENTIAL_PROXY_LOG:-$HOME/.savia/credential-proxy-audit.jsonl}"

log_audit() {
  local operation="$1" service="$2" result="$3"
  mkdir -p "$(dirname "$AUDIT_LOG")"
  printf '{"ts":"%s","op":"%s","service":"%s","result":"%s","pid":%d}\n' \
    "$(date -Iseconds)" "$operation" "$service" "$result" $$ >> "$AUDIT_LOG"
}

sanitize_output() {
  # Strip any credential-like patterns from command output
  sed -E \
    -e 's/(https?:\/\/)[^@]*@/\1***@/g' \
    -e 's/(Authorization: )(Bearer |Basic )[^ ]*/\1\2***/g' \
    -e 's/(password|token|secret|pat)[=: ]+[^ "'\'']+/\1=***/gi'
}

# ── Operations ─────────────────────────────────────────────────────────────

cmd_git_push() {
  local remote="${1:-origin}" branch="${2:-}"
  [[ -z "$branch" ]] && branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

  if [[ ! -f "$GITHUB_PAT_FILE" ]]; then
    echo "ERROR: PAT file not found at $GITHUB_PAT_FILE" >&2
    log_audit "git-push" "github" "error:no-pat-file"
    return 1
  fi

  # Read PAT in subshell — never exported to caller environment
  local result
  result=$(
    _PAT=$(cat "$GITHUB_PAT_FILE" 2>/dev/null | tr -d '[:space:]')
    # Temporarily configure credential helper
    git -c credential.helper="!f() { echo password=$_PAT; };" \
      push "$remote" "$branch" 2>&1
  ) || {
    echo "$result" | sanitize_output >&2
    log_audit "git-push" "github" "error:push-failed"
    return 1
  }

  echo "$result" | sanitize_output
  log_audit "git-push" "github" "ok"
}

cmd_git_clone() {
  local url="${1:-}" dest="${2:-.}"

  if [[ -z "$url" ]]; then
    echo "ERROR: URL required" >&2
    return 1
  fi

  if [[ ! -f "$GITHUB_PAT_FILE" ]]; then
    echo "ERROR: PAT file not found" >&2
    log_audit "git-clone" "github" "error:no-pat-file"
    return 1
  fi

  local result
  result=$(
    _PAT=$(cat "$GITHUB_PAT_FILE" 2>/dev/null | tr -d '[:space:]')
    # Inject PAT into URL for clone (stripped after)
    local auth_url
    auth_url=$(echo "$url" | sed "s|https://|https://x-access-token:${_PAT}@|")
    git clone "$auth_url" "$dest" 2>&1
    # Remove credential from remote config
    cd "$dest" 2>/dev/null && git remote set-url origin "$url" 2>/dev/null
  ) || {
    echo "$result" | sanitize_output >&2
    log_audit "git-clone" "github" "error:clone-failed"
    return 1
  }

  echo "$result" | sanitize_output
  log_audit "git-clone" "github" "ok"
}

cmd_api_call() {
  local service="${1:-}" endpoint="${2:-}" method="${3:-GET}"

  case "$service" in
    azdo|azure-devops)
      if [[ ! -f "$AZDO_PAT_FILE" ]]; then
        echo "ERROR: Azure DevOps PAT not found" >&2
        log_audit "api-call" "azdo" "error:no-pat"
        return 1
      fi
      local result
      result=$(
        _PAT=$(cat "$AZDO_PAT_FILE" 2>/dev/null | tr -d '[:space:]')
        _AUTH=$(printf ':%.0s' {1..1}; printf '%s' "$_PAT" | base64 -w0 2>/dev/null || printf '%s' "$_PAT" | base64 2>/dev/null)
        curl -s -X "$method" "$endpoint" \
          -H "Authorization: Basic $_AUTH" \
          -H "Content-Type: application/json" 2>&1
      )
      echo "$result" | sanitize_output
      log_audit "api-call" "azdo" "ok"
      ;;
    graph|microsoft-graph)
      if [[ ! -f "$GRAPH_SECRET_FILE" ]]; then
        echo "ERROR: Graph secret not found" >&2
        log_audit "api-call" "graph" "error:no-secret"
        return 1
      fi
      echo "ERROR: Graph API calls require OAuth flow — use MCP connector" >&2
      log_audit "api-call" "graph" "error:not-implemented"
      return 1
      ;;
    *)
      echo "ERROR: Unknown service '$service'. Supported: azdo, graph" >&2
      return 1
      ;;
  esac
}

cmd_status() {
  echo "Credential Proxy Status (Managed Agents pattern)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  _check_cred() {
    local name="$1" path="$2"
    if [[ -f "$path" ]]; then
      local age_h
      age_h=$(( ($(date +%s) - $(stat -c %Y "$path" 2>/dev/null || stat -f %m "$path" 2>/dev/null || echo 0)) / 3600 ))
      printf "  %-20s %-8s %s (age: %dh)\n" "$name" "OK" "$path" "$age_h"
    else
      printf "  %-20s %-8s %s\n" "$name" "MISSING" "$path"
    fi
  }

  _check_cred "GitHub/AzDO PAT" "$GITHUB_PAT_FILE"
  _check_cred "Graph Secret" "$GRAPH_SECRET_FILE"
  _check_cred "Miro Token" "$MIRO_TOKEN_FILE"

  echo ""
  if [[ -f "$AUDIT_LOG" ]]; then
    local count
    count=$(wc -l < "$AUDIT_LOG")
    echo "  Audit log: $AUDIT_LOG ($count entries)"
    echo "  Last 3 operations:"
    tail -3 "$AUDIT_LOG" | while IFS= read -r line; do
      echo "    $line"
    done
  else
    echo "  Audit log: not yet created"
  fi
}

# ── Main ───────────────────────────────────────────────────────────────────

case "${1:-status}" in
  git-push)   shift; cmd_git_push "$@" ;;
  git-clone)  shift; cmd_git_clone "$@" ;;
  api-call)   shift; cmd_api_call "$@" ;;
  status)     cmd_status ;;
  *)          echo "Usage: credential-proxy.sh {git-push|git-clone|api-call|status}" >&2; exit 1 ;;
esac
