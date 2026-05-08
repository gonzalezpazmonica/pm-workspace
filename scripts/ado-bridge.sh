#!/usr/bin/env bash
# ado-bridge.sh — Azure DevOps REST API v7.1 bridge for Savia PM commands
# Usage: bash scripts/ado-bridge.sh <get|post|patch|wiql> <path> [body]
#        bash scripts/ado-bridge.sh cache-clear
# Reads org URL from pm-config.md, PAT from ~/.azure/devops-pat
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SCRIPT_DIR}/.."
CACHE_DIR="${TMPDIR:-/tmp}/ado-cache-${USER:-default}"
CACHE_TTL=60

# ── Resolve config ──────────────────────────────────────────────────────────────
resolve_config() {
  ADO_ORG="${AZURE_DEVOPS_ORG_URL:-}"
  if [[ -z "$ADO_ORG" ]]; then
    ADO_ORG=$(awk -F'"' '/AZURE_DEVOPS_ORG_URL/{print $2}' "$ROOT/docs/rules/domain/pm-config.md" 2>/dev/null | head -1 || true)
  fi
  ADO_ORG="${ADO_ORG%/}"
  if [[ -z "$ADO_ORG" || "$ADO_ORG" == "https://dev.azure.com/MI-ORGANIZACION" || "$ADO_ORG" == *"MI-ORGANIZACIÓN"* ]]; then
    echo '{"error":"AZURE_DEVOPS_ORG_URL not configured. Set in pm-config.local.md"}' >&2
    return 1
  fi

  ADO_PAT="${AZURE_DEVOPS_EXT_PAT:-}"
  if [[ -z "$ADO_PAT" ]] && [[ -f "$HOME/.azure/devops-pat" ]]; then
    ADO_PAT=$(cat "$HOME/.azure/devops-pat" 2>/dev/null | tr -d '\n\r')
  fi
  [[ -z "$ADO_PAT" ]] && { echo '{"error":"PAT not found in ~/.azure/devops-pat"}' >&2; return 1; }

  ADO_AUTH=$(echo -n ":$ADO_PAT" | base64 -w0 2>/dev/null || echo -n ":$ADO_PAT" | base64 2>/dev/null)
  ADO_API_VERSION="7.1"
}

# ── Cache helpers ───────────────────────────────────────────────────────────────
cache_key() { local k="$1"; echo "$k" | sha256sum 2>/dev/null | cut -c1-16 || echo "$k" | cksum 2>/dev/null | cut -d' ' -f1 || echo "0"; }

cache_get() {
  local key="$1" f="${CACHE_DIR}/${key}.json"
  [[ -f "$f" ]] && [[ $(($(date +%s) - $(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo 0))) -lt $CACHE_TTL ]] && cat "$f" && return 0
  return 1
}

cache_set() {
  local key="$1" data="$2"
  mkdir -p "$CACHE_DIR"
  echo "$data" > "${CACHE_DIR}/${key}.json"
}

# ── API calls ───────────────────────────────────────────────────────────────────
ado_get() {
  local path="$1"
  [[ "$path" != *"?"* ]] && path="${path}?api-version=${ADO_API_VERSION}" || path="${path}&api-version=${ADO_API_VERSION}"
  local ck; ck=$(cache_key "$path")
  if data=$(cache_get "$ck"); then echo "$data"; return 0; fi

  local resp
  resp=$(curl -sS -H "Authorization: Basic ${ADO_AUTH}" "${ADO_ORG}/${path}" 2>/dev/null) || true
  if [[ -z "$resp" ]]; then echo '{"error":"no response from Azure DevOps"}' >&2; return 1; fi
  if echo "$resp" | grep -q '"innerException"\|"Microsoft\.TeamFoundation"'; then
    echo "$resp" >&2; return 1
  fi
  cache_set "$ck" "$resp"
  echo "$resp"
}

ado_post() {
  local path="$1" body="${2:-}" ct="application/json"
  [[ "$path" != *"?"* ]] && path="${path}?api-version=${ADO_API_VERSION}" || path="${path}&api-version=${ADO_API_VERSION}"
  curl -sS -H "Authorization: Basic ${ADO_AUTH}" -H "Content-Type: $ct" -d "$body" "${ADO_ORG}/${path}" 2>/dev/null
}

ado_patch() {
  local path="$1" body="${2:-}" ct="application/json-patch+json"
  [[ "$path" != *"?"* ]] && path="${path}?api-version=${ADO_API_VERSION}" || path="${path}&api-version=${ADO_API_VERSION}"
  curl -sS -H "Authorization: Basic ${ADO_AUTH}" -H "Content-Type: $ct" -d "$body" -X PATCH "${ADO_ORG}/${path}" 2>/dev/null
}

ado_wiql() {
  local project="$1" query="$2" top="${3:-100}"
  local body; body=$(python3 -c "import sys,json; json.dump({'query':sys.argv[1]},sys.stdout)" "$query" 2>/dev/null || echo "{\"query\":\"$query\"}")
  local result
  result=$(ado_post "${project}/_apis/wit/wiql?\$top=${top}" "$body")
  echo "$result"
}

ado_get_workitems() {
  local ids="$1"  # comma-separated integer IDs
  [[ -z "$ids" ]] && { echo '{"count":0,"value":[]}'; return 0; }
  ado_get "_apis/wit/workitems?ids=${ids}&\$expand=all" 2>/dev/null || echo '{"count":0,"value":[]}'
}

# ── Health check ────────────────────────────────────────────────────────────────
ado_health() {
  resolve_config || return 1
  local resp
  resp=$(ado_get "_apis/projects?\$top=1") || { echo '{"status":"unreachable"}'; return 1; }
  echo '{"status":"connected"}'
}

# ── Cache management ────────────────────────────────────────────────────────────
ado_cache_clear() {
  rm -rf "$CACHE_DIR" && echo "Cache cleared" || echo "Cache clear failed"
}

# ── Dispatch ─────────────────────────────────────────────────────────────────────
resolve_config || exit 1

case "${1:-}" in
  get)       shift; ado_get "$@" ;;
  post)      shift; ado_post "$@" ;;
  patch)     shift; ado_patch "$@" ;;
  wiql)      shift; ado_wiql "$@" ;;
  workitems) shift; ado_get_workitems "$@" ;;
  health)    ado_health ;;
  cache-clear) ado_cache_clear ;;
  *)
    echo "Usage: ado-bridge.sh <get|post|patch|wiql|workitems|health|cache-clear> [args]" >&2
    exit 2
    ;;
esac
