#!/usr/bin/env bats
# Ref: SPEC-SE-036 — API-Key → Short-Lived JWT Mint for Agent CLIs
# Spec: docs/propuestas/savia-enterprise/SPEC-SE-036-api-key-jwt-mint.md
# Slice 1: storage (template) + mint primitive (jwt-mint.sh) + canonical rule doc.
# Pattern source: dreamxist/balance MIT (clean-room re-implementation).
# Safety: tests enforce 'set -uo pipefail', scope downscope guard, off-repo signing key.

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SCRIPT="scripts/enterprise/jwt-mint.sh"
  MINT_ABS="$ROOT_DIR/$SCRIPT"
  TEMPLATE_SQL="$ROOT_DIR/docs/propuestas/savia-enterprise/templates/api-keys.sql"
  RULE_DOC="$ROOT_DIR/docs/rules/domain/savia-enterprise/agent-jwt-mint.md"
  TMPDIR_T=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_T"
}

# ── C1 — file existence / shebang / executable ──────────────────────────────

@test "jwt-mint.sh: file exists, has shebang, and is executable" {
  [ -f "$MINT_ABS" ]
  head -1 "$MINT_ABS" | grep -q '^#!'
  [ -x "$MINT_ABS" ]
}

@test "jwt-mint.sh: declares 'set -uo pipefail' for safety" {
  grep -q "set -[uo]o pipefail" "$MINT_ABS"
}

@test "jwt-mint.sh: passes bash -n syntax check" {
  bash -n "$MINT_ABS"
}

@test "spec ref: SPEC-SE-036 cited in jwt-mint.sh and rule doc" {
  grep -q "SPEC-SE-036" "$MINT_ABS"
  grep -q "SPEC-SE-036" "$RULE_DOC"
}

@test "attribution: dreamxist/balance MIT pattern source cited" {
  grep -qF "dreamxist/balance" "$MINT_ABS"
  grep -qF "dreamxist/balance" "$TEMPLATE_SQL"
  grep -qF "MIT" "$TEMPLATE_SQL"
  grep -qiE "clean.room|re.implement" "$RULE_DOC"
}

# ── C2 — SQL template structure (positive) ──────────────────────────────────

@test "template SQL: defines api_keys table with required columns" {
  [ -f "$TEMPLATE_SQL" ]
  grep -qE "CREATE TABLE.*api_keys" "$TEMPLATE_SQL"
  for col in tenant_id key_prefix key_hash scope created_at last_used_at revoked_at; do
    grep -qE "^\\s+$col" "$TEMPLATE_SQL"
  done
}

@test "template SQL: api_keys enforces UNIQUE (tenant_id, key_hash)" {
  grep -qE "UNIQUE\\s*\\(\\s*tenant_id\\s*,\\s*key_hash\\s*\\)" "$TEMPLATE_SQL"
}

@test "template SQL: defines api_key_mints append-only audit table" {
  grep -qE "CREATE TABLE.*api_key_mints" "$TEMPLATE_SQL"
  grep -qE "minted_at|expires_at" "$TEMPLATE_SQL"
}

@test "template SQL: api_key_verify returns the row only when not revoked" {
  grep -qF "api_key_verify" "$TEMPLATE_SQL"
  grep -qF "revoked_at IS NULL" "$TEMPLATE_SQL"
}

@test "template SQL: scope subset helper uses array containment <@" {
  grep -qF "api_key_scope_is_subset" "$TEMPLATE_SQL"
  grep -qE "scope_subset\\s*<@\\s*scope_full" "$TEMPLATE_SQL"
}

@test "template SQL: revocation procedure exists and updates revoked_at" {
  grep -qF "PROCEDURE api_key_revoke" "$TEMPLATE_SQL"
  grep -qE "SET\\s+revoked_at\\s*=\\s*now\\(\\)" "$TEMPLATE_SQL"
}

# ── C3 — Negative paths (CLI failure modes) ─────────────────────────────────

@test "jwt-mint.sh: rejects unknown CLI argument (no-arg edge)" {
  run bash "$MINT_ABS" --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown arg"* ]]
}

@test "jwt-mint.sh: zero-arg invocation exits 2 (boundary)" {
  run bash "$MINT_ABS"
  [ "$status" -eq 2 ]
}

@test "jwt-mint.sh: empty --scope value rejected (empty boundary)" {
  run bash "$MINT_ABS" --key dummy --scope ""
  [ "$status" -eq 2 ]
}

@test "jwt-mint.sh: missing --key (and no --key-stdin) exits 2" {
  run bash "$MINT_ABS" --scope github:read
  [ "$status" -eq 2 ]
  [[ "$output" == *"--key"* ]]
}

@test "jwt-mint.sh: missing --scope exits 2" {
  run bash "$MINT_ABS" --key dummy
  [ "$status" -eq 2 ]
  [[ "$output" == *"--scope"* ]]
}

@test "jwt-mint.sh: TTL out of range [60,3600] is rejected" {
  run bash "$MINT_ABS" --key dummy --scope github:read --ttl 10
  [ "$status" -eq 2 ]
  [[ "$output" == *"--ttl"* ]]
  run bash "$MINT_ABS" --key dummy --scope github:read --ttl 7200
  [ "$status" -eq 2 ]
  [[ "$output" == *"--ttl"* ]]
}

@test "jwt-mint.sh: TTL non-integer is rejected" {
  run bash "$MINT_ABS" --key dummy --scope github:read --ttl abc
  [ "$status" -eq 2 ]
  [[ "$output" == *"--ttl"* ]]
}

@test "jwt-mint.sh: missing SAVIA_ENTERPRISE_DSN exits 3" {
  run env -u SAVIA_ENTERPRISE_DSN bash "$MINT_ABS" --key dummy --scope github:read
  [ "$status" -eq 3 ]
  [[ "$output" == *"SAVIA_ENTERPRISE_DSN"* ]]
}

@test "jwt-mint.sh: missing JWT_SIGNING_KEY exits 4" {
  run env -u JWT_SIGNING_KEY SAVIA_ENTERPRISE_DSN=dummy \
      bash "$MINT_ABS" --key dummy --scope github:read
  [ "$status" -eq 4 ]
  [[ "$output" == *"JWT_SIGNING_KEY"* ]]
}

# ── C4 — Edge cases ─────────────────────────────────────────────────────────

@test "edge: jwt-mint.sh declares --key-stdin to avoid leaking key via ps" {
  grep -qF -- "--key-stdin" "$MINT_ABS"
  grep -qF "KEY_STDIN" "$MINT_ABS"
}

@test "edge: jwt-mint.sh uses HS256 (HMAC-SHA256), not asymmetric" {
  grep -qF "HS256" "$MINT_ABS"
  grep -qE "openssl dgst -sha256 -mac HMAC" "$MINT_ABS"
}

@test "edge: jwt-mint.sh base64url-encodes (RFC 4648 §5: + → -, / → _, strip =)" {
  grep -qE "tr '\\+/' '-_'" "$MINT_ABS"
  grep -qE "tr -d '='" "$MINT_ABS"
}

@test "edge: jwt-mint.sh emits scope as JSON array in payload" {
  grep -qF '"scope":' "$MINT_ABS"
}

@test "edge: jwt-mint.sh records mint via api_key_record_mint() — audit trail" {
  grep -qF "api_key_record_mint" "$MINT_ABS"
}

@test "edge: jwt-mint.sh refuses upscoping (subset check returns 't' or exit 8)" {
  grep -qF "api_key_scope_is_subset" "$MINT_ABS"
  grep -qF "exit 8" "$MINT_ABS"
}

# ── C5 — Rule canonical doc ─────────────────────────────────────────────────

@test "rule doc: exists and references SPEC-SE-036" {
  [ -f "$RULE_DOC" ]
  grep -q "SPEC-SE-036" "$RULE_DOC"
}

@test "rule doc: explains why DB does not sign JWT (signing key would leak to logs)" {
  grep -qiE "current_setting|application code|firma JWT.*application" "$RULE_DOC"
}

@test "rule doc: documents JWT_SIGNING_KEY off-repo storage + mode 600" {
  grep -qF "JWT_SIGNING_KEY" "$RULE_DOC"
  grep -qiE "off.repo|~/\\.savia/secrets|mode 600" "$RULE_DOC"
}

@test "rule doc: cross-references SPEC-SE-002 (RLS) + SPEC-SE-037 (audit)" {
  grep -qF "SPEC-SE-002" "$RULE_DOC"
  grep -qF "SPEC-SE-037" "$RULE_DOC"
}

@test "rule doc: documents Slice 2 + Slice 3 deferred items explicitly" {
  grep -qiE "Slice 2|Slice 3" "$RULE_DOC"
  grep -qiE "block-pat-file-write|sunset" "$RULE_DOC"
}

@test "rule doc: enforces scope downscoping (never upscoping) policy" {
  grep -qiE "downscoping|never upscope|NEVER upscope|upscoping" "$RULE_DOC"
}

# ── C6 — CLAUDE.md Rule #1 reinforcement ────────────────────────────────────

@test "rule doc: cites CLAUDE.md Rule #1 (convención → infraestructura)" {
  grep -qF "Rule #1" "$RULE_DOC"
  # Use byte-class to avoid locale-dependent multibyte matching of 'ó'
  grep -qiE "convenci.{1,2}n.*infraestructura|infraestructura.*convenci.{1,2}n" "$RULE_DOC"
}

@test "spec ref: docs/propuestas/savia-enterprise/SPEC-SE-036 referenced in this test file" {
  grep -q "docs/propuestas/savia-enterprise/SPEC-SE-036" "$BATS_TEST_FILENAME"
}

# ── C7 — exit code documentation reinforcement ──────────────────────────────

@test "jwt-mint.sh: documents all 7 distinct exit codes (2,3,4,5,6,7,8)" {
  for code in 2 3 4 5 6 7 8; do
    grep -qE "exit $code|^#.*\\b$code\\b" "$MINT_ABS"
  done
}

@test "jwt-mint.sh: --ttl default is 900 (15 min, AC-04)" {
  grep -qE "TTL=900" "$MINT_ABS"
}
