#!/usr/bin/env bash
# engagement-rotate.sh — SE-271 S3: Seal/rotate client engagement context
# Seals (does not delete) engagement context on completion.
# Prevents retrieval from other client sessions.
# Reactivation requires audit record.
# Personal criterion and relationship ledger never exported with engagement.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENGAGEMENTS_DIR="$ROOT/engagements"

usage() {
  cat <<EOF
Usage: bash scripts/engagement-rotate.sh [options] COMMAND

Commands:
  seal     Seal engagement — prevent retrieval, archive context
  revive   Reactivate sealed engagement with audit record
  status   Show current seal/active status
  list     List all engagements with status

Options:
  --client CLIENT       Client slug (required for seal/revive)
  --engagement NAME     Engagement name (required for seal/revive)
  --reason TEXT         Reason for seal/revive (recorded in audit)
  --operator NAME       Operator authorizing action (recorded in audit)
  --json                Output JSON only
  --force               Skip confirmation prompt
  --help, -h            This help
EOF
}

CMD=""; CLIENT=""; ENGAGEMENT=""; REASON=""; OPERATOR=""; JSON_OUT=false; FORCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    seal|revive|status|list) CMD="$1"; shift ;;
    --client)      CLIENT="$2";      shift 2 ;;
    --engagement)  ENGAGEMENT="$2";  shift 2 ;;
    --reason)      REASON="$2";      shift 2 ;;
    --operator)    OPERATOR="$2";    shift 2 ;;
    --json)        JSON_OUT=true;    shift ;;
    --force)       FORCE=true;       shift ;;
    --help|-h)     usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$CMD" ]]; then
  usage >&2; exit 1
fi

DATE_NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
OPERATOR_VAL="${OPERATOR:-unknown}"

# ── resolve engagement YAML ─────────────────────────────────────────────────────
resolve_yaml() {
  local c="$1" e="$2"
  local yf="$ENGAGEMENTS_DIR/$c/${e}.yaml"
  if [[ -f "$yf" ]]; then
    echo "$yf"
  else
    echo ""
  fi
}

# ── get engagement status from YAML ─────────────────────────────────────────────
get_status() {
  local yf="$1"
  grep -E "^\s+active:" "$yf" 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown"
}

get_wall_mode() {
  local yf="$1"
  grep -E "^\s+mode:" "$yf" 2>/dev/null | head -1 | awk '{print $2}' | tr -d '"' || echo "strict"
}

# ── list all engagements ────────────────────────────────────────────────────────
cmd_list() {
  if [[ ! -d "$ENGAGEMENTS_DIR" ]]; then
    $JSON_OUT && echo '{"engagements":[]}' || echo "No engagements directory found."
    return
  fi

  local entries="["
  local first=true
  for client_dir in "$ENGAGEMENTS_DIR"/*/; do
    [[ -d "$client_dir" ]] || continue
    local cslug
    cslug=$(basename "$client_dir")
    for yf in "$client_dir"/*.yaml; do
      [[ -f "$yf" ]] || continue
      local ename status wmode
      ename=$(basename "$yf" .yaml)
      status=$(get_status "$yf")
      wmode=$(get_wall_mode "$yf")
      if $JSON_OUT; then
        if ! $first; then entries+=","; fi
        first=false
        local sealed_ts=""
        sealed_ts=$(grep "sealed_at:" "$yf" 2>/dev/null | head -1 | awk '{print $2}' | tr -d '"' || echo "")
        entries+="{\"client\":\"$cslug\",\"engagement\":\"$ename\",\"active\":$([[ "$status" == "true" ]] && echo 'true' || echo 'false'),\"wall\":\"$wmode\",\"sealed_at\":\"${sealed_ts:-null}\"}"
      else
        local marker="+"
        [[ "$status" != "true" ]] && marker="-"
        echo "  [$marker] $cslug / $ename  (wall: $wmode)"
      fi
    done
  done
  entries+="]"
  $JSON_OUT && echo "$entries"
}

# ── show status ─────────────────────────────────────────────────────────────────
cmd_status() {
  if [[ -z "$CLIENT" ]]; then
    echo '{"error":"--client required for status"}' >&2; exit 1
  fi
  local yf
  yf=$(resolve_yaml "$CLIENT" "${ENGAGEMENT:-}")
  if [[ -z "$yf" ]] && [[ -n "$ENGAGEMENT" ]]; then
    $JSON_OUT && echo '{"error":"engagement not found","client":"'"$CLIENT"'","engagement":"'"$ENGAGEMENT"'"}' || echo "Engagement not found: $CLIENT / $ENGAGEMENT"
    exit 1
  fi

  if [[ -z "$ENGAGEMENT" ]]; then
    # Show all engagements for client
    $JSON_OUT && echo '{"client":"'"$CLIENT"'","engagements":[]}' || echo "Client: $CLIENT"
    for yf in "$ENGAGEMENTS_DIR/$CLIENT"/*.yaml; do
      [[ -f "$yf" ]] || continue
      local ename status
      ename=$(basename "$yf" .yaml)
      status=$(get_status "$yf")
      local mark="[active]"
      [[ "$status" != "true" ]] && mark="[sealed]"
      echo "  $mark $ename"
    done
  else
    local status
    status=$(get_status "$yf")
    local sealed_at
    sealed_at=$(grep "sealed_at:" "$yf" 2>/dev/null | head -1 | awk '{print $2}' | tr -d '"' || echo "")
    local seal_reason
    seal_reason=$(grep "seal_reason:" "$yf" 2>/dev/null | head -1 | cut -d'"' -f2 || echo "")
    if $JSON_OUT; then
      python3 -c "
import json
print(json.dumps({
    'client': '$CLIENT',
    'engagement': '${ENGAGEMENT:-}',
    'active': $([[ "$status" == "true" ]] && echo 'true' || echo 'false'),
    'sealed_at': '${sealed_at:-null}',
    'seal_reason': '${seal_reason:-}',
    'wall': '$(get_wall_mode "$yf")'
}, indent=2))
" 2>/dev/null || echo '{"error":"json-gen-failed"}'
    else
      echo "Engagement: $CLIENT / ${ENGAGEMENT:-}"
      echo "  Status:    $([[ "$status" == "true" ]] && echo 'ACTIVE' || echo 'SEALED')"
      [[ -n "$sealed_at" ]] && echo "  Sealed:    $sealed_at"
      [[ -n "$seal_reason" ]] && echo "  Reason:    $seal_reason"
      echo "  Wall:      $(get_wall_mode "$yf")"
    fi
  fi
}

# ── seal engagement ─────────────────────────────────────────────────────────────
cmd_seal() {
  if [[ -z "$CLIENT" ]]; then
    echo '{"error":"--client required for seal"}' >&2; exit 1
  fi
  local yf
  yf=$(resolve_yaml "$CLIENT" "${ENGAGEMENT:-}")
  if [[ -z "$yf" ]]; then
    echo "{\"error\":\"engagement not found: $CLIENT / ${ENGAGEMENT:-}\"}" >&2
    exit 1
  fi

  local cur_status
  cur_status=$(get_status "$yf")
  if [[ "$cur_status" != "true" ]]; then
    $JSON_OUT && echo '{"error":"engagement already sealed","client":"'"$CLIENT"'","engagement":"'"${ENGAGEMENT:-}"'"}'
    echo "Engagement already sealed: $CLIENT / ${ENGAGEMENT:-}" >&2
    exit 0
  fi

  # Confirm
  if ! $FORCE; then
    echo "WARNING: This will seal engagement '$CLIENT / ${ENGAGEMENT:-}'"
    echo "  Context will be inaccessible from other client sessions."
    echo "  Personal criterion and relationship ledger will NOT be exported."
    echo ""
    read -r -p "Continue? [y/N] " confirm
    [[ "$confirm" != "y" && "$confirm" != "yes" ]] && { echo "Aborted."; exit 0; }
  fi

  local seal_ts="$DATE_NOW"

  # 1. Archive active context: move memory to sealed archive
  local eng_dir="$ENGAGEMENTS_DIR/$CLIENT"
  local seal_dir="$eng_dir/sealed/${ENGAGEMENT:-context}-${DATE_NOW//[:]/-}"
  mkdir -p "$seal_dir"

  # Copy engagement artifacts to sealed archive
  if [[ -d "$eng_dir/artifacts" ]]; then
    cp -r "$eng_dir/artifacts" "$seal_dir/artifacts" 2>/dev/null || true
  fi
  if [[ -d "$eng_dir/memory" ]]; then
    cp -r "$eng_dir/memory" "$seal_dir/memory" 2>/dev/null || true
  fi

  # 2. Append seal audit entry to wall ledger
  local wall_ledger="$eng_dir/wall/wall-ledger.jsonl"
  local prev_hash="seal-${seal_ts}"
  if [[ -f "$wall_ledger" ]]; then
    prev_hash=$(tail -1 "$wall_ledger" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('hash','seal-genesis'))" 2>/dev/null || echo "seal-genesis")
  fi
  local entry_hash
  entry_hash=$(echo -n "${seal_ts}SEAL${CLIENT}${ENGAGEMENT}${REASON}${prev_hash}" | sha256sum 2>/dev/null | awk '{print $1}' || echo "seal-hash-missing")

  python3 -c "
import json
entry = {
    'ts': '$seal_ts',
    'event': 'ENGAGEMENT_SEALED',
    'client': '$CLIENT',
    'engagement': '${ENGAGEMENT:-}',
    'reason': '''${REASON:-engagement-completed}''',
    'operator': '$OPERATOR_VAL',
    'seal_dir': '$seal_dir',
    'prev_hash': '$prev_hash',
    'hash': '$entry_hash'
}
print(json.dumps(entry))
" >> "$wall_ledger" 2>/dev/null || true

  # 3. Update engagement YAML: set active=false, record seal metadata
  local tmp_yaml="${yf}.tmp"
  while IFS= read -r line; do
    echo "$line" >> "$tmp_yaml"
    if [[ "$line" =~ ^[[:space:]]+active:\ true ]]; then
      echo "  sealed_at: \"$seal_ts\"" >> "$tmp_yaml"
      echo "  sealed_by: \"$OPERATOR_VAL\"" >> "$tmp_yaml"
      echo "  seal_reason: \"${REASON:-engagement-completed}\"" >> "$tmp_yaml"
      echo "  seal_audit_hash: \"$entry_hash\"" >> "$tmp_yaml"
      echo "  seal_archive: \"$seal_dir\"" >> "$tmp_yaml"
      echo "  personal_criterion_exported: false" >> "$tmp_yaml"
      echo "  relationship_ledger_exported: false" >> "$tmp_yaml"
    fi
  done < "$yf"
  sed -i 's/^\s*active:\ true/  active: false/' "$tmp_yaml" 2>/dev/null || true
  mv "$tmp_yaml" "$yf"

  # 4. Set seal marker file (quick check for active context)
  echo "sealed:true" > "$eng_dir/wall/seal-marker"
  echo "sealed_at:$seal_ts" >> "$eng_dir/wall/seal-marker"
  echo "sealed_by:$OPERATOR_VAL" >> "$eng_dir/wall/seal-marker"

  # 5. Create seal manifest
  local seal_manifest="$seal_dir/seal-manifest.yaml"
  cat > "$seal_manifest" << MANIFEST
# Seal Manifest — SE-271 S3
engagement: $CLIENT / ${ENGAGEMENT:-}
sealed_at: $seal_ts
sealed_by: $OPERATOR_VAL
reason: ${REASON:-engagement-completed}
personal_criterion_exported: false
relationship_ledger_exported: false
audit_hash: $entry_hash
MANIFEST

  if $JSON_OUT; then
    python3 -c "
import json
print(json.dumps({
    'sealed': True,
    'client': '$CLIENT',
    'engagement': '${ENGAGEMENT:-}',
    'sealed_at': '$seal_ts',
    'seal_dir': '$seal_dir',
    'audit_hash': '$entry_hash',
    'personal_criterion_exported': False,
    'relationship_ledger_exported': False
}, indent=2))
" 2>/dev/null || echo '{"sealed":true,"client":"'"$CLIENT"'","engagement":"'"${ENGAGEMENT:-}"'"}'
  else
    echo "=== Engagement sealed: $CLIENT / ${ENGAGEMENT:-} ==="
    echo "  Sealed at:  $seal_ts"
    echo "  Archive:    $seal_dir"
    echo "  Audit hash: $entry_hash"
    echo "  Personal criterion NOT exported"
    echo "  Relationship ledger NOT exported"
  fi
}

# ── revive engagement ───────────────────────────────────────────────────────────
cmd_revive() {
  if [[ -z "$CLIENT" ]]; then
    echo '{"error":"--client required for revive"}' >&2; exit 1
  fi
  local yf
  yf=$(resolve_yaml "$CLIENT" "${ENGAGEMENT:-}")
  if [[ -z "$yf" ]]; then
    echo "{\"error\":\"engagement not found: $CLIENT / ${ENGAGEMENT:-}\"}" >&2
    exit 1
  fi

  local cur_status
  cur_status=$(get_status "$yf")
  if [[ "$cur_status" == "true" ]]; then
    $JSON_OUT && echo '{"error":"engagement already active","client":"'"$CLIENT"'","engagement":"'"${ENGAGEMENT:-}"'"}'
    echo "Engagement already active: $CLIENT / ${ENGAGEMENT:-}" >&2
    exit 0
  fi

  # Confirm
  if ! $FORCE; then
    echo "WARNING: Reviving sealed engagement '$CLIENT / ${ENGAGEMENT:-}'"
    echo "  Requires audit record. Are you authorized?"
    read -r -p "Continue? [y/N] " confirm
    [[ "$confirm" != "y" && "$confirm" != "yes" ]] && { echo "Aborted."; exit 0; }
  fi

  local revive_ts="$DATE_NOW"

  # 1. Record revocation audit entry
  local eng_dir="$ENGAGEMENTS_DIR/$CLIENT"
  local wall_ledger="$eng_dir/wall/wall-ledger.jsonl"
  local prev_hash="revive-${revive_ts}"
  if [[ -f "$wall_ledger" ]]; then
    prev_hash=$(tail -1 "$wall_ledger" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('hash','revive-genesis'))" 2>/dev/null || echo "revive-genesis")
  fi
  local entry_hash
  entry_hash=$(echo -n "${revive_ts}REVIVE${CLIENT}${ENGAGEMENT}${REASON}${prev_hash}" | sha256sum 2>/dev/null | awk '{print $1}' || echo "revive-hash-missing")

  python3 -c "
import json
entry = {
    'ts': '$revive_ts',
    'event': 'ENGAGEMENT_REVIVED',
    'client': '$CLIENT',
    'engagement': '${ENGAGEMENT:-}',
    'reason': '''${REASON:-reactivation-requested}''',
    'operator': '$OPERATOR_VAL',
    'prev_hash': '$prev_hash',
    'hash': '$entry_hash'
}
print(json.dumps(entry))
" >> "$wall_ledger" 2>/dev/null || true

  # 2. Update engagement YAML: set active=true
  local tmp_yaml="${yf}.tmp"
  while IFS= read -r line; do
    if [[ "$line" =~ sealed_at: ]] || [[ "$line" =~ sealed_by: ]] || [[ "$line" =~ seal_reason: ]] || [[ "$line" =~ seal_audit_hash: ]] || [[ "$line" =~ seal_archive: ]] || [[ "$line" =~ personal_criterion_exported ]] || [[ "$line" =~ relationship_ledger_exported ]]; then
      : # skip seal metadata lines
    else
      echo "$line" >> "$tmp_yaml"
    fi
  done < "$yf"
  sed -i 's/^\s*active:\ false/  active: true/' "$tmp_yaml" 2>/dev/null || true
  echo "  revived_at: \"$revive_ts\"" >> "$tmp_yaml"
  echo "  revived_by: \"$OPERATOR_VAL\"" >> "$tmp_yaml"
  echo "  revive_reason: \"${REASON:-reactivation-requested}\"" >> "$tmp_yaml"
  echo "  revive_audit_hash: \"$entry_hash\"" >> "$tmp_yaml"
  mv "$tmp_yaml" "$yf"

  # 3. Remove seal marker
  rm -f "$eng_dir/wall/seal-marker"

  if $JSON_OUT; then
    echo '{"revived":true,"client":"'"$CLIENT"'","engagement":"'"${ENGAGEMENT:-}"'","revived_at":"'"$revive_ts"'","audit_hash":"'"$entry_hash"'"}'
  else
    echo "=== Engagement revived: $CLIENT / ${ENGAGEMENT:-} ==="
    echo "  Revived at: $revive_ts"
    echo "  Audit hash: $entry_hash"
  fi
}

# ── Dispatch ────────────────────────────────────────────────────────────────────
case "$CMD" in
  list)   cmd_list ;;
  status) cmd_status ;;
  seal)   cmd_seal ;;
  revive) cmd_revive ;;
  *)      echo "ERROR: unknown command '$CMD'" >&2; exit 1 ;;
esac
