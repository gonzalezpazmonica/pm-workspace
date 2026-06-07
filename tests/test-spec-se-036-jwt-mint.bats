#!/usr/bin/env bats
# tests/test-spec-se-036-jwt-mint.bats
# SPEC-SE-036: API key → JWT ephemeral mint — BATS test suite
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-036-api-key-jwt-mint.md

SCRIPT="${BATS_TEST_DIRNAME}/../scripts/jwt-mint.sh"
BLOCK_SCRIPT="${BATS_TEST_DIRNAME}/../scripts/block-pat-file-write.sh"
DOC_FILE="${BATS_TEST_DIRNAME}/../docs/rules/domain/agent-jwt-mint.md"

_require_sqlite_or_skip() {
  command -v sqlite3 >/dev/null 2>&1 || skip "sqlite3 CLI not installed"
}

setup() {
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR
  export PROJECT_ROOT="$TMP_DIR"
  mkdir -p "$TMP_DIR/.savia"
}

teardown() {
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

# ── Slice 1: jwt-mint.sh existence + safety ────────────────────────────────────

@test "jwt-mint.sh exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "jwt-mint.sh uses set -uo pipefail" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "jwt-mint.sh references SPEC-SE-036" {
  grep -q 'SPEC-SE-036' "$SCRIPT"
}

# ── Slice 1: init creates schema ───────────────────────────────────────────────

@test "init creates both tables in SQLite DB" {
  _require_sqlite_or_skip
  run bash "$SCRIPT" init
  [[ "$status" -eq 0 ]]
  [[ -f "$TMP_DIR/.savia/api-keys.db" ]]
  # Verify tables exist
  tables="$(sqlite3 "$TMP_DIR/.savia/api-keys.db" ".tables")"
  [[ "$tables" == *"api_keys"* ]]
  [[ "$tables" == *"api_key_mints"* ]]
}

@test "init outputs 'schema OK'" {
  _require_sqlite_or_skip
  run bash "$SCRIPT" init
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"schema OK"* ]]
}

@test "init --json returns ok:true with tables array" {
  _require_sqlite_or_skip
  run bash "$SCRIPT" --json init
  [[ "$status" -eq 0 ]]
  [[ "$output" == *'"ok":true'* ]]
  [[ "$output" == *'api_keys'* ]]
  [[ "$output" == *'api_key_mints'* ]]
}

# ── Slice 1: create ────────────────────────────────────────────────────────────

@test "create outputs key_prefix (8 chars) and full key to stdout" {
  _require_sqlite_or_skip
  bash "$SCRIPT" init
  run bash "$SCRIPT" create --name "test-agent"
  [[ "$status" -eq 0 ]]
  # key_prefix line
  prefix_line="$(echo "$output" | grep 'key_prefix:')"
  [[ -n "$prefix_line" ]]
  prefix="$(echo "$prefix_line" | awk '{print $2}')"
  [[ "${#prefix}" -eq 8 ]]
  # full key line (64 hex chars)
  key_line="$(echo "$output" | grep '^key:')"
  key="$(echo "$key_line" | awk '{print $2}')"
  [[ "${#key}" -eq 64 ]]
}

@test "create stores key in DB — key_prefix appears in api_keys" {
  _require_sqlite_or_skip
  bash "$SCRIPT" init
  prefix="$(bash "$SCRIPT" create --name "db-test" | grep 'key_prefix:' | awk '{print $2}')"
  count="$(sqlite3 "$TMP_DIR/.savia/api-keys.db" \
    "SELECT COUNT(*) FROM api_keys WHERE key_prefix='${prefix}';")"
  [[ "$count" -eq 1 ]]
}

@test "create respects --scope flag" {
  _require_sqlite_or_skip
  bash "$SCRIPT" init
  prefix="$(bash "$SCRIPT" create --name "scoped" --scope "github:write" \
    | grep 'key_prefix:' | awk '{print $2}')"
  scope="$(sqlite3 "$TMP_DIR/.savia/api-keys.db" \
    "SELECT scope FROM api_keys WHERE key_prefix='${prefix}';")"
  [[ "$scope" == "github:write" ]]
}

# ── Slice 1: list ──────────────────────────────────────────────────────────────

@test "list shows created keys" {
  _require_sqlite_or_skip
  bash "$SCRIPT" init
  bash "$SCRIPT" create --name "list-test" >/dev/null
  run bash "$SCRIPT" list
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"list-test"* ]]
}

# ── Slice 1: revoke ────────────────────────────────────────────────────────────

@test "revoke changes key status to revoked" {
  _require_sqlite_or_skip
  bash "$SCRIPT" init
  prefix="$(bash "$SCRIPT" create --name "revoke-test" | grep 'key_prefix:' | awk '{print $2}')"
  run bash "$SCRIPT" revoke "$prefix"
  [[ "$status" -eq 0 ]]
  status_val="$(sqlite3 "$TMP_DIR/.savia/api-keys.db" \
    "SELECT status FROM api_keys WHERE key_prefix='${prefix}';")"
  [[ "$status_val" == "revoked" ]]
}

# ── Slice 1: mint ──────────────────────────────────────────────────────────────

@test "mint returns JWT with 3 dot-separated parts" {
  _require_sqlite_or_skip
  bash "$SCRIPT" init
  prefix="$(bash "$SCRIPT" create --name "mint-test" | grep 'key_prefix:' | awk '{print $2}')"
  run bash "$SCRIPT" mint "$prefix"
  [[ "$status" -eq 0 ]]
  # Count dots (should be exactly 2 → 3 parts)
  dot_count="$(echo "$output" | tr -cd '.' | wc -c)"
  [[ "$dot_count" -eq 2 ]]
}

@test "mint JWT payload decodes to JSON with sub, scope, exp" {
  _require_sqlite_or_skip
  bash "$SCRIPT" init
  prefix="$(bash "$SCRIPT" create --name "payload-test" | grep 'key_prefix:' | awk '{print $2}')"
  jwt="$(bash "$SCRIPT" mint "$prefix")"
  # Extract payload (second part)
  payload_b64="$(echo "$jwt" | cut -d'.' -f2)"
  # Add padding for base64 decode
  padded="${payload_b64}$(printf '%0.s=' $(seq 1 $(( (4 - ${#payload_b64} % 4) % 4 ))))"
  payload_json="$(echo "$padded" | tr '_-' '/+' | base64 -d 2>/dev/null || \
                  echo "$padded" | openssl base64 -d -A 2>/dev/null)"
  [[ "$payload_json" == *'"sub"'* ]]
  [[ "$payload_json" == *'"scope"'* ]]
  [[ "$payload_json" == *'"exp"'* ]]
}

@test "mint default TTL is 900 seconds" {
  _require_sqlite_or_skip
  bash "$SCRIPT" init
  prefix="$(bash "$SCRIPT" create --name "ttl-test" | grep 'key_prefix:' | awk '{print $2}')"
  jwt="$(bash "$SCRIPT" mint "$prefix")"
  payload_b64="$(echo "$jwt" | cut -d'.' -f2)"
  padded="${payload_b64}$(printf '%0.s=' $(seq 1 $(( (4 - ${#payload_b64} % 4) % 4 ))))"
  payload_json="$(echo "$padded" | tr '_-' '/+' | base64 -d 2>/dev/null || \
                  echo "$padded" | openssl base64 -d -A 2>/dev/null)"
  iat="$(echo "$payload_json" | grep -o '"iat":[0-9]*' | cut -d: -f2)"
  exp="$(echo "$payload_json" | grep -o '"exp":[0-9]*' | cut -d: -f2)"
  ttl=$(( exp - iat ))
  [[ "$ttl" -eq 900 ]]
}

@test "mint with custom --ttl stores correct TTL" {
  _require_sqlite_or_skip
  bash "$SCRIPT" init
  prefix="$(bash "$SCRIPT" create --name "custom-ttl" | grep 'key_prefix:' | awk '{print $2}')"
  jwt="$(bash "$SCRIPT" mint "$prefix" --ttl 300)"
  payload_b64="$(echo "$jwt" | cut -d'.' -f2)"
  padded="${payload_b64}$(printf '%0.s=' $(seq 1 $(( (4 - ${#payload_b64} % 4) % 4 ))))"
  payload_json="$(echo "$padded" | tr '_-' '/+' | base64 -d 2>/dev/null || \
                  echo "$padded" | openssl base64 -d -A 2>/dev/null)"
  iat="$(echo "$payload_json" | grep -o '"iat":[0-9]*' | cut -d: -f2)"
  exp="$(echo "$payload_json" | grep -o '"exp":[0-9]*' | cut -d: -f2)"
  ttl=$(( exp - iat ))
  [[ "$ttl" -eq 300 ]]
}

@test "mint writes audit record to api_key_mints" {
  _require_sqlite_or_skip
  bash "$SCRIPT" init
  prefix="$(bash "$SCRIPT" create --name "audit-test" | grep 'key_prefix:' | awk '{print $2}')"
  bash "$SCRIPT" mint "$prefix" >/dev/null
  count="$(sqlite3 "$TMP_DIR/.savia/api-keys.db" \
    "SELECT COUNT(*) FROM api_key_mints WHERE key_prefix='${prefix}';")"
  [[ "$count" -ge 1 ]]
}

# ── Edge: revoked key must not mint ───────────────────────────────────────────

@test "mint with revoked key exits non-zero" {
  _require_sqlite_or_skip
  bash "$SCRIPT" init
  prefix="$(bash "$SCRIPT" create --name "revoke-mint" | grep 'key_prefix:' | awk '{print $2}')"
  bash "$SCRIPT" revoke "$prefix" >/dev/null
  run bash "$SCRIPT" mint "$prefix"
  [[ "$status" -ne 0 ]]
}

# ── Edge: nonexistent key must not mint ───────────────────────────────────────

@test "mint with nonexistent key exits non-zero" {
  _require_sqlite_or_skip
  bash "$SCRIPT" init
  run bash "$SCRIPT" mint "deadbeef"
  [[ "$status" -ne 0 ]]
}

# ── Slice 2: block-pat-file-write.sh ──────────────────────────────────────────

@test "block-pat-file-write.sh exists and is executable" {
  [[ -x "$BLOCK_SCRIPT" ]]
}

@test "block-pat-file-write.sh exits 2 for PAT path" {
  run bash "$BLOCK_SCRIPT" --path "/home/user/.azure/devops-pat"
  [[ "$status" -eq 2 ]]
}

@test "block-pat-file-write.sh exits 2 for ANTHROPIC_API_KEY path" {
  run bash "$BLOCK_SCRIPT" --path "/home/user/ANTHROPIC_API_KEY_FILE"
  [[ "$status" -eq 2 ]]
}

@test "block-pat-file-write.sh exits 0 for normal path" {
  run bash "$BLOCK_SCRIPT" --path "/home/user/projects/myapp/README.md"
  [[ "$status" -eq 0 ]]
}

@test "block-pat-file-write.sh --check-only exits 0 even for PAT path" {
  run bash "$BLOCK_SCRIPT" --check-only --path "/home/user/.azure/devops-pat"
  [[ "$status" -eq 0 ]]
}

# ── Slice 3: doc exists ────────────────────────────────────────────────────────

@test "agent-jwt-mint.md doc exists" {
  [[ -f "$DOC_FILE" ]]
}

@test "agent-jwt-mint.md has SAVIA_JWT_MINT_ENABLED feature flag" {
  grep -q 'SAVIA_JWT_MINT_ENABLED' "$DOC_FILE"
}
