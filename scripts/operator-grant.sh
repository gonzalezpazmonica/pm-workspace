#!/usr/bin/env bash
# operator-grant.sh — Deterministic operator-grant ledger (SE-343)
#
# Replaces manual env-var setup for autonomous skills and the binary
# "never merge" rule with a LOCAL, auditable grant ledger written by Savia
# ONLY on the operator's express request.
#
#   grant  --scope <autonomy:<skill>|merge> --context "<why>" [--ttl-hours N]
#   check  --scope <scope>          # exit 0 vigente | 1 no/expirado | 2 invalido | 3 sin grant
#   revoke --scope <scope>
#   list
#
# Ledger: ~/.savia/grants/<scope>.json  (local infra, CRIT-001 — never in repo)
# Grantor: resolved from .claude/profiles/active-user.md (slug). NEVER "self".
#
# Exit: 0 ok | 1 not valid/expired | 2 invalid invocation | 3 no grant
# Ref: SE-343, SPEC-186, autonomous-safety.md

set -uo pipefail

GRANTS_DIR="${SAVIA_GRANTS_DIR:-$HOME/.savia/grants}"
ACTIVE_USER_FILE=".claude/profiles/active-user.md"

usage() {
  cat <<'USAGE'
Usage: operator-grant.sh <grant|check|revoke|list> --scope SCOPE [opts]

Commands:
  grant   SCOPE  --context "reason" [--ttl-hours N]   emit grant (express request)
  check   SCOPE                                       exit: 0 vigente | 1 no | 2 inval | 3 sin grant
  revoke  SCOPE                                       revoke (remove file)
  list                                                show all grants

Scopes:
  autonomy:<skill>   enables double-optin "intent" factor for the skill
                     (overnight-sprint, code-improvement-loop, adversarial-security,
                      tech-research-agent, savia-dual)
  merge              enables PR merge (--merge in push-pr.sh)

Rules:
  - grantor = active user slug (active-user.md). NEVER "self".
  - source  = express-request (set by Savia on operator request). NEVER "self".
  - default TTL: autonomy:* = 24h, merge = 6h.
  - grant (idempotent): renews expires_at of an existing valid grant.
USAGE
}

# ── Helpers ────────────────────────────────────────────────────────────

active_slug() {
  if [[ -f "$ACTIVE_USER_FILE" ]]; then
    grep -oP 'active_slug:\s*"\K[^"]+' "$ACTIVE_USER_FILE" 2>/dev/null | head -1
  else
    echo ""
  fi
}

now_epoch() { date +%s 2>/dev/null || echo 0; }

default_ttl() {
  case "$1" in
    merge)             echo 6 ;;
    autonomy:*)        echo 24 ;;
    *)                 echo 0 ;;
  esac
}

valid_scope() {
  case "$1" in
    merge) return 0 ;;
    autonomy:overnight-sprint|autonomy:code-improvement-loop|autonomy:adversarial-security|autonomy:tech-research-agent|autonomy:savia-dual) return 0 ;;
    *) return 1 ;;
  esac
}

scope_file() { printf '%s/%s.json' "$GRANTS_DIR" "$1"; }

# Safe JSON write (best-effort; never readable by others)
write_grant() {
  local scope="$1" context="$2" ttl="$3" slug="$4" grantor="$5"
  local file now exp
  file="$(scope_file "$scope")"
  mkdir -p "$GRANTS_DIR" 2>/dev/null || { echo "ERROR: cannot create $GRANTS_DIR" >&2; exit 2; }
  chmod 700 "$GRANTS_DIR" 2>/dev/null || true
  now="$(now_epoch)"
  exp=$(( now + ttl * 3600 ))
  # Reuse existing grantor if already present (stability); else active slug.
  if [[ -z "$grantor" && -f "$(scope_file "$scope")" ]]; then
    grantor="$(grep -oP '"grantor":\s*"\K[^"]+' "$(scope_file "$scope")" 2>/dev/null | head -1 || true)"
  fi
  [[ -z "$grantor" ]] && grantor="$slug"
  cat > "$file" <<EOF
{"scope":"$scope","grantor":"$grantor","source":"express-request","request_context":"$context","issued_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)","expires_at":"$(date -u -d @"$exp" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -r "$exp" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "epoch-$exp")","expires_epoch":$exp}
EOF
  chmod 600 "$file" 2>/dev/null || true
}

check_scope() {
  local scope="$1" slug="$2"
  local file exp expires_at grantor
  file="$(scope_file "$scope")"
  [[ ! -f "$file" ]] && return 3
  exp="$(grep -oP '"expires_epoch":\s*\K[0-9]+' "$file" 2>/dev/null | head -1)"
  if [[ -z "$exp" ]]; then
    expires_at="$(grep -oP '"expires_at":\s*"\K[^"]+' "$file" 2>/dev/null | head -1)"
    exp="$(date -u -d "$expires_at" +%s 2>/dev/null || echo 0)"
  fi
  [[ "$(( $(now_epoch) ))" -gt "$exp" ]] && return 1
  grantor="$(grep -oP '"grantor":\s*"\K[^"]+' "$file" 2>/dev/null | head -1)"
  # A valid grant must be tied to the ACTIVE operator, never self/empty.
  if [[ -z "$grantor" || "$grantor" == "self" ]]; then return 1; fi
  if [[ -n "$slug" && "$grantor" != "$slug" ]]; then return 1; fi
  return 0
}

# ── Parse ──────────────────────────────────────────────────────────────
ACTION="" SCOPE="" CONTEXT="" TTL="" GRANTOR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    grant|check|revoke|list) ACTION="$1"; shift ;;
    --scope) SCOPE="$2"; shift 2 ;;
    --scope=*) SCOPE="${1#--scope=}"; shift ;;
    --context) CONTEXT="$2"; shift 2 ;;
    --context=*) CONTEXT="${1#--context=}"; shift ;;
    --ttl-hours) TTL="$2"; shift 2 ;;
    --ttl-hours=*) TTL="${1#--ttl-hours=}"; shift ;;
    --grantor) GRANTOR="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) shift ;;
  esac
done

[[ -z "$ACTION" ]] && { echo "ERROR: action required (grant|check|revoke|list)" >&2; usage >&2; exit 2; }
[[ "$ACTION" == "list" ]] && {
  if [[ -d "$GRANTS_DIR" ]]; then
    ls -1 "$GRANTS_DIR"/*.json 2>/dev/null | while read -r f; do
      b="$(basename "$f" .json)"
      if check_scope "$b" ""; then v=yes; else v=no; fi
      printf '%s\tvalid=%s\t%s\n' "$b" "$v" "$(grep -oP '"request_context":\s*"\K[^"]+' "$f" 2>/dev/null | head -1)"
    done
  fi
  exit 0
}

[[ -z "$SCOPE" ]] && { echo "ERROR: --scope required" >&2; exit 2; }
if ! valid_scope "$SCOPE"; then
  echo "ERROR: invalid scope '$SCOPE' (merge | autonomy:<skill>)" >&2; exit 2
fi

SLUG="$(active_slug)"

case "$ACTION" in
  check)
    check_scope "$SCOPE" "$SLUG"
    exit $? ;;
  revoke)
    rm -f "$(scope_file "$SCOPE")" 2>/dev/null; exit 0 ;;
  grant)
    [[ -z "$CONTEXT" ]] && { echo "ERROR: --context required (why is this grant being issued)" >&2; exit 2; }
    [[ -z "$TTL" ]] && TTL="$(default_ttl "$SCOPE")"
    write_grant "$SCOPE" "$CONTEXT" "$TTL" "$SLUG" "$GRANTOR"
    echo "granted: $SCOPE -> $SLUG (ttl ${TTL}h)"
    check_scope "$SCOPE" "$SLUG"; exit $? ;;
esac
exit 2