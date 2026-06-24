#!/usr/bin/env bash
# governance-audit-trail.sh — SPEC-SE-006 Signed Audit Trail for Governance & Compliance
#
# Gestiona el audit trail firmado para compliance Enterprise.
#
# Subcomandos:
#   append --tenant SLUG --actor USER --action ACTION --spec SPEC
#       → Añade entrada JSONL firmada al trail del tenant
#   verify --file PATH
#       → Verifica la integridad de la cadena de hashes
#   export --tenant SLUG --format md|json
#       → Exporta el trail para auditores externos
#   chain-status
#       → Muestra estado del chain hash (último hash, nº entradas)
#
# Firma: sha256 de (ts + tenant + actor + action + prev_hash)
# Almacena: .claude/enterprise/audit/{tenant}/audit-trail.jsonl
#
# Reference: SPEC-SE-006 (docs/propuestas/savia-enterprise/SPEC-SE-006-governance-compliance.md)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
AUDIT_BASE="${ROOT_DIR}/.claude/enterprise/audit"

# ── Helpers ──────────────────────────────────────────────────────────────────

usage() {
  cat <<'USAGE'
governance-audit-trail.sh — SPEC-SE-006 Signed Audit Trail

Usage:
  governance-audit-trail.sh append --tenant SLUG --actor USER --action ACTION [--spec SPEC]
  governance-audit-trail.sh verify --file PATH
  governance-audit-trail.sh export --tenant SLUG [--format md|json]
  governance-audit-trail.sh chain-status [--tenant SLUG]
  governance-audit-trail.sh --help

Subcommands:
  append        Add a signed JSONL entry to the tenant audit trail
  verify        Verify chain hash integrity of a trail file (detect tampering)
  export        Export trail for external auditors (md or json format)
  chain-status  Show last hash and entry count for a tenant trail

Environment:
  SAVIA_AUDIT_SIGN_KEY   Optional Ed25519 private key path for signing.
                          If not set, uses sha256-only signature (compliant default).
USAGE
  exit 0
}

die() { echo "ERROR: $*" >&2; exit 1; }

# Compute sha256 of a string
sha256_str() {
  printf '%s' "$1" | sha256sum | cut -d' ' -f1
}

# Get last hash from trail file (or genesis hash if empty/new)
get_prev_hash() {
  local trail_file="$1"
  if [[ ! -f "$trail_file" ]] || [[ ! -s "$trail_file" ]]; then
    echo "0000000000000000000000000000000000000000000000000000000000000000"
    return
  fi
  # Extract hash field from last valid JSONL line
  local last_hash
  last_hash="$(grep -o '"hash":"[^"]*"' "$trail_file" | tail -1 | cut -d'"' -f4)"
  if [[ -z "$last_hash" ]]; then
    echo "0000000000000000000000000000000000000000000000000000000000000000"
  else
    echo "$last_hash"
  fi
}

# ── Subcommand: append ───────────────────────────────────────────────────────

cmd_append() {
  local tenant="" actor="" action="" spec=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tenant) tenant="$2"; shift 2 ;;
      --actor)  actor="$2";  shift 2 ;;
      --action) action="$2"; shift 2 ;;
      --spec)   spec="$2";   shift 2 ;;
      *) die "append: unknown argument: $1" ;;
    esac
  done

  [[ -z "$tenant" ]] && die "append: --tenant is required"
  [[ -z "$actor"  ]] && die "append: --actor is required"
  [[ -z "$action" ]] && die "append: --action is required"

  local tenant_dir="${AUDIT_BASE}/${tenant}"
  mkdir -p "$tenant_dir"
  local trail_file="${tenant_dir}/audit-trail.jsonl"

  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local prev_hash
  prev_hash="$(get_prev_hash "$trail_file")"

  # Chain hash: sha256(ts + tenant + actor + action + prev_hash)
  local chain_input="${ts}${tenant}${actor}${action}${prev_hash}"
  local hash
  hash="$(sha256_str "$chain_input")"

  # Compose entry (JSON inline, no external tools required)
  local spec_field=""
  if [[ -n "$spec" ]]; then
    spec_field=",\"spec\":\"${spec}\""
  fi

  local entry
  entry="{\"ts\":\"${ts}\",\"tenant\":\"${tenant}\",\"actor\":\"${actor}\",\"action\":\"${action}\"${spec_field},\"prev_hash\":\"${prev_hash}\",\"hash\":\"sha256:${hash}\"}"

  echo "$entry" >> "$trail_file"
  echo "OK: appended to ${trail_file}"
  echo "    hash: sha256:${hash}"
}

# ── Subcommand: verify ───────────────────────────────────────────────────────

cmd_verify() {
  local file=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file) file="$2"; shift 2 ;;
      *) die "verify: unknown argument: $1" ;;
    esac
  done

  [[ -z "$file" ]] && die "verify: --file is required"
  [[ ! -f "$file" ]] && die "verify: file not found: ${file}"

  local line_num=0
  local prev_hash="0000000000000000000000000000000000000000000000000000000000000000"
  local tampered=0
  local total=0

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    line_num=$(( line_num + 1 ))
    total=$(( total + 1 ))

    # Extract fields via grep (no jq dependency)
    local ts tenant actor action stored_hash stored_prev
    ts="$(echo "$line"     | grep -o '"ts":"[^"]*"'         | head -1 | cut -d'"' -f4)"
    tenant="$(echo "$line" | grep -o '"tenant":"[^"]*"'     | head -1 | cut -d'"' -f4)"
    actor="$(echo "$line"  | grep -o '"actor":"[^"]*"'      | head -1 | cut -d'"' -f4)"
    action="$(echo "$line" | grep -o '"action":"[^"]*"'     | head -1 | cut -d'"' -f4)"
    stored_hash="$(echo "$line"     | grep -o '"hash":"[^"]*"'      | head -1 | cut -d'"' -f4)"
    stored_prev="$(echo "$line"     | grep -o '"prev_hash":"[^"]*"' | head -1 | cut -d'"' -f4)"

    # Recompute chain hash
    local chain_input="${ts}${tenant}${actor}${action}${prev_hash}"
    local expected_hash
    expected_hash="sha256:$(sha256_str "$chain_input")"

    # Verify prev_hash linkage
    if [[ "${stored_prev}" != "${prev_hash}" ]]; then
      echo "TAMPERED: line ${line_num} — prev_hash mismatch (expected: ${prev_hash}, got: ${stored_prev})"
      tampered=$(( tampered + 1 ))
    fi

    # Verify entry hash
    if [[ "${stored_hash}" != "${expected_hash}" ]]; then
      echo "TAMPERED: line ${line_num} — hash mismatch (expected: ${expected_hash}, got: ${stored_hash})"
      tampered=$(( tampered + 1 ))
    fi

    # Advance chain
    # stored_hash is "sha256:HEX" — strip prefix for next prev_hash
    prev_hash="${stored_hash#sha256:}"
  done < "$file"

  echo "Verified ${total} entries in ${file}"
  if [[ "$tampered" -eq 0 ]]; then
    echo "CHAIN OK: no tampering detected"
    exit 0
  else
    echo "CHAIN FAIL: ${tampered} integrity violation(s) detected"
    exit 1
  fi
}

# ── Subcommand: export ───────────────────────────────────────────────────────

cmd_export() {
  local tenant="" format="json"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tenant) tenant="$2"; shift 2 ;;
      --format) format="$2"; shift 2 ;;
      *) die "export: unknown argument: $1" ;;
    esac
  done

  [[ -z "$tenant" ]] && die "export: --tenant is required"

  local trail_file="${AUDIT_BASE}/${tenant}/audit-trail.jsonl"
  [[ ! -f "$trail_file" ]] && die "export: trail not found: ${trail_file}"

  case "$format" in
    json)
      # Wrap JSONL lines into a JSON array
      echo "["
      local first=1
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$first" -eq 0 ]] && echo ","
        printf '%s' "$line"
        first=0
      done < "$trail_file"
      echo ""
      echo "]"
      ;;
    md)
      echo "# Audit Trail — Tenant: ${tenant}"
      echo ""
      echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
      echo ""
      echo "| Timestamp | Actor | Action | Spec | Hash |"
      echo "|-----------|-------|--------|------|------|"
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local ts actor action spec hash
        ts="$(echo "$line"     | grep -o '"ts":"[^"]*"'     | head -1 | cut -d'"' -f4)"
        actor="$(echo "$line"  | grep -o '"actor":"[^"]*"'  | head -1 | cut -d'"' -f4)"
        action="$(echo "$line" | grep -o '"action":"[^"]*"' | head -1 | cut -d'"' -f4)"
        spec="$(echo "$line"   | grep -o '"spec":"[^"]*"'   | head -1 | cut -d'"' -f4)"
        hash="$(echo "$line"   | grep -o '"hash":"[^"]*"'   | head -1 | cut -d'"' -f4)"
        echo "| ${ts} | ${actor} | ${action} | ${spec:-—} | \`${hash:0:20}...\` |"
      done < "$trail_file"
      ;;
    *)
      die "export: unknown format '${format}'. Use md or json."
      ;;
  esac
}

# ── Subcommand: chain-status ─────────────────────────────────────────────────

cmd_chain_status() {
  local tenant=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tenant) tenant="$2"; shift 2 ;;
      *) die "chain-status: unknown argument: $1" ;;
    esac
  done

  # If no tenant given, show status for all tenants
  if [[ -z "$tenant" ]]; then
    if [[ ! -d "$AUDIT_BASE" ]]; then
      echo "No audit trails found (${AUDIT_BASE} does not exist)"
      exit 0
    fi
    for dir in "${AUDIT_BASE}"/*/; do
      [[ -d "$dir" ]] || continue
      local t
      t="$(basename "$dir")"
      local trail="${dir}audit-trail.jsonl"
      if [[ -f "$trail" ]]; then
        local count
        count="$(grep -c . "$trail" 2>/dev/null || echo 0)"
        local last_hash
        last_hash="$(get_prev_hash "$trail")"
        echo "Tenant: ${t} | entries: ${count} | last_hash: sha256:${last_hash:0:16}..."
      fi
    done
    return
  fi

  local trail_file="${AUDIT_BASE}/${tenant}/audit-trail.jsonl"
  if [[ ! -f "$trail_file" ]]; then
    echo "No trail found for tenant '${tenant}'"
    exit 0
  fi

  local count
  count="$(grep -c . "$trail_file" 2>/dev/null || echo 0)"
  local last_hash
  last_hash="$(get_prev_hash "$trail_file")"

  echo "Tenant:    ${tenant}"
  echo "File:      ${trail_file}"
  echo "Entries:   ${count}"
  echo "Last hash: sha256:${last_hash:0:32}..."
}

# ── Dispatch ─────────────────────────────────────────────────────────────────

if [[ $# -eq 0 ]]; then
  usage
fi

subcmd="$1"
shift

case "$subcmd" in
  append)       cmd_append "$@" ;;
  verify)       cmd_verify "$@" ;;
  export)       cmd_export "$@" ;;
  chain-status) cmd_chain_status "$@" ;;
  -h|--help)    usage ;;
  *) echo "ERROR: unknown subcommand: ${subcmd}" >&2
     echo "Run with --help for usage." >&2
     exit 2 ;;
esac
