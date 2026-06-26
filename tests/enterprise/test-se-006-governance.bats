#!/usr/bin/env bats
# test-se-006-governance.bats — SPEC-SE-006 Governance & Compliance Pack
# Tests for governance-audit-trail.sh, model-card-generator.sh, compliance-check.sh
# Reference: docs/propuestas/savia-enterprise/SPEC-SE-006-governance-compliance.md

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR

  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export REPO_ROOT

  AUDIT_TRAIL="${REPO_ROOT}/scripts/enterprise/governance-audit-trail.sh"
  MODEL_CARD_GEN="${REPO_ROOT}/scripts/enterprise/model-card-generator.sh"
  COMPLIANCE_CHECK="${REPO_ROOT}/scripts/enterprise/compliance-check.sh"
  PROTOCOL_DOC="${REPO_ROOT}/docs/rules/domain/enterprise-governance-protocol.md"
  export AUDIT_TRAIL MODEL_CARD_GEN COMPLIANCE_CHECK PROTOCOL_DOC

  # Override audit base to tmpdir for isolation
  export CLAUDE_ENTERPRISE_AUDIT_BASE="${TEST_TMPDIR}/audit"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ── Test 1: governance-audit-trail.sh exists and is executable ────────────────

@test "governance-audit-trail.sh exists and is executable" {
  [[ -f "$AUDIT_TRAIL" ]]
  [[ -x "$AUDIT_TRAIL" ]]
}

# ── Test 2: governance-audit-trail.sh --help exits 0 ─────────────────────────

@test "governance-audit-trail.sh --help exits 0" {
  run "$AUDIT_TRAIL" --help
  [ "$status" -eq 0 ]
}

# ── Test 3: append generates JSONL with required fields ──────────────────────

@test "append generates JSONL with ts, tenant, actor, action, hash" {
  # Use tmpdir as audit base by overriding the path via env
  local audit_dir="${TEST_TMPDIR}/audit/test-tenant"
  mkdir -p "$audit_dir"

  # Patch the script to use our tmp audit base
  # We do this by creating a wrapper that sets ROOT_DIR to test temp
  local wrapper="${TEST_TMPDIR}/audit-trail-wrapper.sh"
  cat > "$wrapper" << EOF
#!/usr/bin/env bash
# Wrapper that overrides AUDIT_BASE to TEST_TMPDIR
export AUDIT_BASE="${TEST_TMPDIR}/audit"
exec "${AUDIT_TRAIL}" "\$@"
EOF
  chmod +x "$wrapper"

  run bash -c "
    AUDIT_BASE='${TEST_TMPDIR}/audit'
    . <(grep -v '^AUDIT_BASE=' '${AUDIT_TRAIL}' | head -5 || true)
    mkdir -p '${TEST_TMPDIR}/audit/test-tenant'
    # Run directly, overriding AUDIT_BASE inside the script
    sed 's|AUDIT_BASE=\".*\"|AUDIT_BASE=\"${TEST_TMPDIR}/audit\"|' '${AUDIT_TRAIL}' > '${TEST_TMPDIR}/patched-trail.sh'
    chmod +x '${TEST_TMPDIR}/patched-trail.sh'
    '${TEST_TMPDIR}/patched-trail.sh' append --tenant test-tenant --actor user1 --action spec_approved --spec SE-006
  "
  [ "$status" -eq 0 ]

  local trail="${TEST_TMPDIR}/audit/test-tenant/audit-trail.jsonl"
  [[ -f "$trail" ]]

  local line
  line="$(cat "$trail")"

  # Verify required fields
  echo "$line" | grep -q '"ts"'
  echo "$line" | grep -q '"tenant":"test-tenant"'
  echo "$line" | grep -q '"actor":"user1"'
  echo "$line" | grep -q '"action":"spec_approved"'
  echo "$line" | grep -q '"hash":"sha256:'
}

# ── Test 4: verify detects tampering ─────────────────────────────────────────

@test "verify detects tampering when hash does not match" {
  local trail_file="${TEST_TMPDIR}/tampered-trail.jsonl"

  # Create a trail with one valid entry then tamper it
  echo '{"ts":"2026-01-01T00:00:00Z","tenant":"t1","actor":"a1","action":"test","prev_hash":"0000000000000000000000000000000000000000000000000000000000000000","hash":"sha256:badhash"}' > "$trail_file"

  run "$AUDIT_TRAIL" verify --file "$trail_file"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "TAMPERED" ]] || [[ "$output" =~ "CHAIN FAIL" ]]
}

# ── Test 5: model-card-generator.sh exists and produces cards ────────────────

@test "model-card-generator.sh exists and is executable" {
  [[ -f "$MODEL_CARD_GEN" ]]
  [[ -x "$MODEL_CARD_GEN" ]]
}

@test "model-card-generator.sh produces cards in output dir" {
  local cards_dir="${TEST_TMPDIR}/model-cards"
  run "$MODEL_CARD_GEN" --output-dir "$cards_dir"
  [ "$status" -eq 0 ]
  # Should have generated at least one card
  local count
  count="$(find "$cards_dir" -name "*.md" 2>/dev/null | wc -l)"
  [ "$count" -gt 0 ]
}

# ── Test 6: compliance-check.sh returns JSON with score ──────────────────────

@test "compliance-check.sh returns JSON with score field" {
  run "$COMPLIANCE_CHECK" --framework eu-ai-act
  # exit 0 or 1 (0=100%, 1=gaps found) — both acceptable
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
  # Output must contain score field
  echo "$output" | grep -q '"score"'
}

# ── Test 7: eu-ai-act detects absence of model cards ─────────────────────────

@test "eu-ai-act framework detects absence of model cards" {
  # Run against a minimal fake root with no model-cards
  local fake_root="${TEST_TMPDIR}/fake-root"
  mkdir -p "${fake_root}/docs/rules/domain"
  mkdir -p "${fake_root}/.claude/enterprise"
  mkdir -p "${fake_root}/scripts/enterprise"

  # Patch compliance-check to use fake root
  sed "s|ROOT_DIR=.*|ROOT_DIR=\"${fake_root}\"|" "$COMPLIANCE_CHECK" > "${TEST_TMPDIR}/patched-check.sh"
  chmod +x "${TEST_TMPDIR}/patched-check.sh"

  run "${TEST_TMPDIR}/patched-check.sh" --framework eu-ai-act
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
  echo "$output" | grep -q '"passed":false' || echo "$output" | grep -q '"passed": false'
}

# ── Test 8: enterprise-governance-protocol.md exists ─────────────────────────

@test "enterprise-governance-protocol.md exists" {
  [[ -f "$PROTOCOL_DOC" ]]
}
