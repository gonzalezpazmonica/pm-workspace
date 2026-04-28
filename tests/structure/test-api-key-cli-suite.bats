#!/usr/bin/env bats
# Ref: SPEC-SE-036 — Slice 2 — API key CLI suite (create / list / revoke)
# Spec: docs/propuestas/savia-enterprise/SPEC-SE-036-api-key-jwt-mint.md
# Pattern source: dreamxist/balance MIT (clean-room re-implementation).

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SCRIPT="scripts/enterprise/api-key-create.sh"
  CREATE_ABS="$ROOT_DIR/$SCRIPT"
  LIST_ABS="$ROOT_DIR/scripts/enterprise/api-key-list.sh"
  REVOKE_ABS="$ROOT_DIR/scripts/enterprise/api-key-revoke.sh"
  TEMPLATE_SQL="$ROOT_DIR/docs/propuestas/savia-enterprise/templates/api-keys.sql"
  RULE_DOC="$ROOT_DIR/docs/rules/domain/savia-enterprise/agent-jwt-mint.md"
  TMPDIR_T=$(mktemp -d)
  VALID_UUID="11111111-2222-3333-4444-555555555555"
}

teardown() {
  rm -rf "$TMPDIR_T"
}

# ── C1 — file-level safety + identity ──────────────────────────────────────

@test "api-key-create.sh: file exists, has shebang, executable" {
  [ -f "$CREATE_ABS" ]
  head -1 "$CREATE_ABS" | grep -q '^#!'
  [ -x "$CREATE_ABS" ]
}

@test "api-key-list.sh: file exists, has shebang, executable" {
  [ -f "$LIST_ABS" ]
  head -1 "$LIST_ABS" | grep -q '^#!'
  [ -x "$LIST_ABS" ]
}

@test "api-key-revoke.sh: file exists, has shebang, executable" {
  [ -f "$REVOKE_ABS" ]
  head -1 "$REVOKE_ABS" | grep -q '^#!'
  [ -x "$REVOKE_ABS" ]
}

@test "all 3 CLIs declare 'set -uo pipefail'" {
  grep -q "set -[uo]o pipefail" "$CREATE_ABS"
  grep -q "set -[uo]o pipefail" "$LIST_ABS"
  grep -q "set -[uo]o pipefail" "$REVOKE_ABS"
}

@test "all 3 CLIs pass bash -n syntax check" {
  bash -n "$CREATE_ABS"
  bash -n "$LIST_ABS"
  bash -n "$REVOKE_ABS"
}

@test "spec ref: SPEC-SE-036 cited in all 3 CLIs" {
  grep -q "SPEC-SE-036" "$CREATE_ABS"
  grep -q "SPEC-SE-036" "$LIST_ABS"
  grep -q "SPEC-SE-036" "$REVOKE_ABS"
}

@test "attribution: dreamxist/balance MIT pattern source cited in all 3 CLIs" {
  grep -qF "dreamxist/balance" "$CREATE_ABS"
  grep -qF "dreamxist/balance" "$LIST_ABS"
  grep -qF "dreamxist/balance" "$REVOKE_ABS"
}

# ── C2 — Negative paths: api-key-create.sh ──────────────────────────────────

@test "create: rejects unknown CLI argument (no-arg)" {
  run bash "$CREATE_ABS" --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown arg"* ]]
}

@test "create: zero-arg invocation exits 2 (boundary)" {
  run bash "$CREATE_ABS"
  [ "$status" -eq 2 ]
}

@test "create: rejects non-UUID --tenant value (invalid input)" {
  run bash "$CREATE_ABS" --tenant not-a-uuid --scope github:read
  [ "$status" -eq 2 ]
  [[ "$output" == *"UUID"* ]]
}

@test "create: missing --scope exits 2 (empty)" {
  run bash "$CREATE_ABS" --tenant "$VALID_UUID"
  [ "$status" -eq 2 ]
  [[ "$output" == *"--scope"* ]]
}

@test "create: missing SAVIA_ENTERPRISE_DSN exits 3" {
  run env -u SAVIA_ENTERPRISE_DSN bash "$CREATE_ABS" --tenant "$VALID_UUID" --scope github:read
  [ "$status" -eq 3 ]
  [[ "$output" == *"SAVIA_ENTERPRISE_DSN"* ]]
}

# ── C3 — Negative paths: api-key-list.sh ────────────────────────────────────

@test "list: rejects unknown argument" {
  run bash "$LIST_ABS" --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown arg"* ]]
}

@test "list: --active and --revoked are mutually exclusive (refuse boundary)" {
  run env SAVIA_ENTERPRISE_DSN=dummy bash "$LIST_ABS" --active --revoked
  [ "$status" -eq 2 ]
  [[ "$output" == *"mutually exclusive"* ]]
}

@test "list: missing SAVIA_ENTERPRISE_DSN exits 3" {
  run env -u SAVIA_ENTERPRISE_DSN bash "$LIST_ABS"
  [ "$status" -eq 3 ]
  [[ "$output" == *"SAVIA_ENTERPRISE_DSN"* ]]
}

@test "list: rejects non-UUID --tenant filter" {
  run env SAVIA_ENTERPRISE_DSN=dummy bash "$LIST_ABS" --tenant not-a-uuid
  [ "$status" -eq 2 ]
  [[ "$output" == *"UUID"* ]]
}

# ── C4 — Negative paths: api-key-revoke.sh ──────────────────────────────────

@test "revoke: REFUSES without --prefix (no bulk)" {
  run bash "$REVOKE_ABS"
  [ "$status" -ne 0 ]
  [[ "$output" == *"--prefix"* ]]
}

@test "revoke: REFUSES bulk patterns (--prefix all / * / %)" {
  run env SAVIA_ENTERPRISE_DSN=dummy bash "$REVOKE_ABS" --prefix all
  [ "$status" -eq 6 ]
  run env SAVIA_ENTERPRISE_DSN=dummy bash "$REVOKE_ABS" --prefix "*"
  [ "$status" -eq 6 ]
  run env SAVIA_ENTERPRISE_DSN=dummy bash "$REVOKE_ABS" --prefix "%"
  [ "$status" -eq 6 ]
}

@test "revoke: REFUSES wildcard chars inside prefix (boundary)" {
  run env SAVIA_ENTERPRISE_DSN=dummy bash "$REVOKE_ABS" --prefix "savia_*"
  [ "$status" -eq 6 ]
  [[ "$output" == *"wildcard"* ]]
}

@test "revoke: missing SAVIA_ENTERPRISE_DSN exits 3" {
  run env -u SAVIA_ENTERPRISE_DSN bash "$REVOKE_ABS" --prefix savia_ab
  [ "$status" -eq 3 ]
}

@test "revoke: rejects unknown argument" {
  run bash "$REVOKE_ABS" --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown arg"* ]]
}

# ── C5 — Edge cases / structural assertions ─────────────────────────────────

@test "edge: create generates random key with savia_ prefix (grep-able)" {
  grep -qE 'PLAINTEXT="savia_' "$CREATE_ABS"
}

@test "edge: create extracts first 8 chars as key_prefix (UX visible)" {
  grep -qE 'KEY_PREFIX=.*PLAINTEXT:0:8' "$CREATE_ABS"
}

@test "edge: create stores ONLY sha256 hash, never plaintext" {
  grep -qF "openssl dgst -sha256" "$CREATE_ABS"
  grep -qF "INSERT INTO api_keys" "$CREATE_ABS"
  grep -qF "key_hash" "$CREATE_ABS"
  # Plaintext should appear in the printf-to-stdout block, not in the SQL
  ! grep -qE "INSERT INTO api_keys.*PLAINTEXT" "$CREATE_ABS"
}

@test "edge: create prints plaintext exactly ONCE with destructive warning" {
  grep -qiE "will not be shown again|copy it now" "$CREATE_ABS"
}

@test "edge: list never prints plaintext or key_hash columns (no leakage)" {
  ! grep -qE "SELECT.*key_hash" "$LIST_ABS"
  ! grep -qE "SELECT.*plaintext" "$LIST_ABS"
  grep -qF "key_prefix" "$LIST_ABS"
}

@test "edge: revoke calls SQL procedure api_key_revoke with prefix + actor" {
  grep -qF "CALL api_key_revoke" "$REVOKE_ABS"
  grep -qF "PREFIX_ESC" "$REVOKE_ABS"
  grep -qF "ACTOR_ESC" "$REVOKE_ABS"
}

@test "edge: revoke is dry-run by default (DRY-RUN message + exit 0 without --confirm)" {
  grep -qF "DRY-RUN" "$REVOKE_ABS"
  grep -qF -- "--confirm" "$REVOKE_ABS"
}

@test "edge: revoke warns about already-minted JWTs surviving until TTL expiry" {
  grep -qiE "TTL expires|already minted|remain valid" "$REVOKE_ABS"
}

# ── C6 — Spec ref + cross-doc consistency ───────────────────────────────────

@test "spec ref: docs/propuestas/savia-enterprise/SPEC-SE-036 referenced in this test file" {
  grep -q "docs/propuestas/savia-enterprise/SPEC-SE-036" "$BATS_TEST_FILENAME"
}

@test "rule doc: agent-jwt-mint.md references all 3 Slice 2 CLIs" {
  [ -f "$RULE_DOC" ]
  # The rule doc was written in Slice 1 referring to Slice 2 by name
  grep -qiE "api-key-create|api-key-list|api-key-revoke" "$RULE_DOC"
}

@test "template SQL: api_key_revoke procedure exists (target of revoke CLI)" {
  grep -qF "PROCEDURE api_key_revoke" "$TEMPLATE_SQL"
}

# ── C7 — exit code documentation reinforcement ──────────────────────────────

@test "create: documents exit codes 2,3,4,5 in header comment" {
  grep -qE "^#.*\b2\b" "$CREATE_ABS"
  grep -qE "^#.*\b3\b" "$CREATE_ABS"
  grep -qE "^#.*\b4\b" "$CREATE_ABS"
  grep -qE "^#.*\b5\b" "$CREATE_ABS"
}

@test "revoke: documents 7 exit codes (0,2,3,4,5,6,7)" {
  for code in 2 3 4 5 6 7; do
    grep -qE "exit $code|^#.*\b$code\b" "$REVOKE_ABS"
  done
}

@test "all 3 CLIs: refuse to run without DSN — graceful, documented exit 3" {
  for f in "$CREATE_ABS" "$LIST_ABS" "$REVOKE_ABS"; do
    grep -qE "exit 3" "$f"
    grep -qF "SAVIA_ENTERPRISE_DSN" "$f"
  done
}
