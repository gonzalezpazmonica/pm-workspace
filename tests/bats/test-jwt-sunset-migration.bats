#!/usr/bin/env bats
# test-jwt-sunset-migration.bats — SPEC-SE-036 Slice 3: JWT sunset + PAT migration tools
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-036-api-key-jwt-mint.md
# Tests: block-pat-file-write.sh hook, agent-jwt-mint.md doc, block-credential-leak.sh pattern

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOOK="$REPO_ROOT/.opencode/hooks/block-pat-file-write.sh"
  CRED_HOOK="$REPO_ROOT/.opencode/hooks/block-credential-leak.sh"
  DOC="$REPO_ROOT/docs/rules/domain/savia-enterprise/agent-jwt-mint.md"
  export REPO_ROOT HOOK CRED_HOOK DOC
}

# ─────────────────────────────────────────────────────────────────
# T1: Hook exists and is executable
# ─────────────────────────────────────────────────────────────────

@test "block-pat-file-write.sh exists and is executable" {
  [[ -x "$HOOK" ]]
}

# ─────────────────────────────────────────────────────────────────
# T2: Write to path with "pat" in name → exit 2 when SAVIA_PAT_BLOCK=on
# ─────────────────────────────────────────────────────────────────

@test "Write to path with 'pat' in name exits 2 when SAVIA_PAT_BLOCK=on" {
  run env SAVIA_PAT_BLOCK=on bash "$HOOK" --path /tmp/devops-pat
  [[ "$status" -eq 2 ]]
}

# ─────────────────────────────────────────────────────────────────
# T3: SAVIA_PAT_BLOCK=off → exit 0 always
# ─────────────────────────────────────────────────────────────────

@test "SAVIA_PAT_BLOCK=off exits 0 for any path" {
  run env SAVIA_PAT_BLOCK=off bash "$HOOK" --path /tmp/devops-pat
  [[ "$status" -eq 0 ]]
}

# ─────────────────────────────────────────────────────────────────
# T4: Write to tests/ path with "pat" → exit 0 (exception)
# ─────────────────────────────────────────────────────────────────

@test "Write to tests/test-pat.bats exits 0 (test exception)" {
  run env SAVIA_PAT_BLOCK=on bash "$HOOK" --path "$REPO_ROOT/tests/bats/test-pat.bats"
  [[ "$status" -eq 0 ]]
}

# ─────────────────────────────────────────────────────────────────
# T5: Write to docs/ with "pat" in path → exit 0 (exception)
# ─────────────────────────────────────────────────────────────────

@test "Write to docs/ with 'pat' in path exits 0 (docs exception)" {
  run env SAVIA_PAT_BLOCK=on bash "$HOOK" \
    --path "$REPO_ROOT/docs/rules/domain/savia-enterprise/agent-jwt-mint.md"
  [[ "$status" -eq 0 ]]
}

# ─────────────────────────────────────────────────────────────────
# T6: Hook contains set -uo pipefail
# ─────────────────────────────────────────────────────────────────

@test "block-pat-file-write.sh contains set -uo pipefail" {
  grep -q "set -uo pipefail" "$HOOK"
}

# ─────────────────────────────────────────────────────────────────
# T7: agent-jwt-mint.md exists with "Proceso de migración" section
# ─────────────────────────────────────────────────────────────────

@test "agent-jwt-mint.md exists with Proceso de migración section" {
  [[ -f "$DOC" ]]
  grep -q "Proceso de migración" "$DOC"
}

# ─────────────────────────────────────────────────────────────────
# T8: block-credential-leak.sh contains PAT-shaped 40+ char pattern
# ─────────────────────────────────────────────────────────────────

@test "block-credential-leak.sh contains PAT-shaped 40+ char detection pattern" {
  grep -q 'A-Za-z0-9' "$CRED_HOOK"
  grep -qE '\{40' "$CRED_HOOK"
}

# ─────────────────────────────────────────────────────────────────
# T9: No PAT path is blocked when path is empty (no crash)
# ─────────────────────────────────────────────────────────────────

@test "block-pat-file-write.sh exits 0 when no path provided" {
  run env SAVIA_PAT_BLOCK=on bash "$HOOK"
  [[ "$status" -eq 0 ]]
}

# ─────────────────────────────────────────────────────────────────
# T10: path with "token" in filename is blocked
# ─────────────────────────────────────────────────────────────────

@test "Write to path with 'token' in filename exits 2 when SAVIA_PAT_BLOCK=on" {
  run env SAVIA_PAT_BLOCK=on bash "$HOOK" --path /tmp/azure-token
  [[ "$status" -eq 2 ]]
}

# ─────────────────────────────────────────────────────────────────
# T11: agent-jwt-mint.md contains Rollback section
# ─────────────────────────────────────────────────────────────────

@test "agent-jwt-mint.md contains Rollback section" {
  grep -q "Rollback" "$DOC"
}

# ─────────────────────────────────────────────────────────────────
# T12: agent-jwt-mint.md references CLAUDE.md Rule #1
# ─────────────────────────────────────────────────────────────────

@test "agent-jwt-mint.md references CLAUDE.md Rule #1" {
  grep -q "Rule #1" "$DOC"
}
