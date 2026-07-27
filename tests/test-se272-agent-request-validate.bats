#!/usr/bin/env bats
# BATS tests for scripts/agent-request-validate.sh
# SE-272 Slice 3 — Agent request origin validation.
# Ref: docs/propuestas/SE-272-servicio-gestionado.md

SCRIPT="scripts/agent-request-validate.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  TEST_DIR=$(mktemp -d "$TMPDIR/arv-XXXXXX")
  export DATA_DIR="$TEST_DIR/data"
  mkdir -p "$DATA_DIR"
  export PLATFORM_CARDS_FILE="$TEST_DIR/cards.yaml"
}

teardown() {
  rm -rf "$TEST_DIR" 2>/dev/null || true
  cd /
}

@test "script exists" { [[ -f "$SCRIPT" ]]; }
@test "script is executable" { [[ -x "$SCRIPT" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}
@test "SE-272 reference present" {
  run grep -c 'SE-272' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }

# ── CLI ──────────────────────────────────────────────

@test "help: prints usage when no subcommand" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage"* ]]
}

@test "cli: unknown subcommand exits 2" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

# ── validate: human origin ───────────────────────────

@test "validate: human origin accepted without agent-id" {
  run bash "$SCRIPT" validate --origin human
  [ "$status" -eq 0 ]
  [[ "$output" == *"ACCEPT"* ]]
}

@test "validate: human origin ignores agent-id if provided" {
  run bash "$SCRIPT" validate --origin human --agent-id "ext-platform-any"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ACCEPT"* ]]
}

# ── validate: agent origin — no cards file ───────────

@test "validate: agent origin without agent-id fails" {
  run bash "$SCRIPT" validate --origin agent
  [ "$status" -eq 2 ]
}

@test "validate: agent rejected when no cards file present" {
  run bash "$SCRIPT" validate --origin agent --agent-id "ext-platform-missing" --platform-card "$TEST_DIR/missing.yaml"
  [ "$status" -eq 1 ]
  [[ "$output" == *"REJECT"* ]]
}

# ── validate: agent origin — with cards file ─────────

@test "validate: active agent card accepted" {
  cat > "$PLATFORM_CARDS_FILE" << 'YAMLEOF'
version: "1.0"
spec: "SE-272"
cards:
  test-platform:
    id: "ext-platform-test-9999"
    organization: "Test Organization"
    public_key: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGx..."
    exposed_skills:
      - "situacion.query"
    allowed_skills:
      - "situacion.query"
    max_payload_level: 2
    engagement: "engagements/2026-test-001"
    status: active
default: deny
YAMLEOF
  run bash "$SCRIPT" validate --origin agent --agent-id "ext-platform-test-9999" --platform-card "$PLATFORM_CARDS_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ACCEPT"* ]]
}

@test "validate: inactive agent card rejected" {
  cat > "$PLATFORM_CARDS_FILE" << 'YAMLEOF'
version: "1.0"
spec: "SE-272"
cards:
  test-platform-inactive:
    id: "ext-platform-test-8888"
    organization: "Test Org Inactive"
    public_key: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGx..."
    exposed_skills:
      - "situacion.query"
    allowed_skills:
      - "situacion.query"
    max_payload_level: 2
    engagement: "engagements/2026-test-002"
    status: suspended
default: deny
YAMLEOF
  run bash "$SCRIPT" validate --origin agent --agent-id "ext-platform-test-8888" --platform-card "$PLATFORM_CARDS_FILE"
  [ "$status" -eq 1 ]
}

@test "validate: unregistered agent id rejected" {
  cat > "$PLATFORM_CARDS_FILE" << 'YAMLEOF'
version: "1.0"
spec: "SE-272"
cards:
  test-platform:
    id: "ext-platform-test-9999"
    organization: "Test Organization"
    public_key: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGx..."
    exposed_skills: ["situacion.query"]
    allowed_skills: ["situacion.query"]
    max_payload_level: 2
    engagement: "engagements/2026-test-001"
    status: active
default: deny
YAMLEOF
  run bash "$SCRIPT" validate --origin agent --agent-id "ext-platform-nonexistent" --platform-card "$PLATFORM_CARDS_FILE"
  [ "$status" -eq 1 ]
}

# ── identify ─────────────────────────────────────────

@test "identify: human token" {
  run bash "$SCRIPT" identify --token "human:User Name"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ORIGIN: human"* ]]
  [[ "$output" == *"User Name"* ]]
}

@test "identify: agent token" {
  run bash "$SCRIPT" identify --token "agent:ext-platform-test-9999"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ORIGIN: agent"* ]]
}

@test "identify: unknown token exits 1" {
  run bash "$SCRIPT" identify --token "robot:some-bot"
  [ "$status" -eq 1 ]
}

# ── Logging ──────────────────────────────────────────

@test "validate: writes identity log entry" {
  cat > "$PLATFORM_CARDS_FILE" << 'YAMLEOF'
version: "1.0"
spec: "SE-272"
cards:
  test-platform:
    id: "ext-platform-test-9999"
    organization: "Test Organization"
    public_key: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGx..."
    exposed_skills: ["situacion.query"]
    allowed_skills: ["situacion.query"]
    max_payload_level: 2
    engagement: "engagements/2026-test-001"
    status: active
default: deny
YAMLEOF
  export IDENTITY_LOG="$TEST_DIR/identity-log.jsonl"
  run bash "$SCRIPT" validate --origin agent --agent-id "ext-platform-test-9999" --platform-card "$PLATFORM_CARDS_FILE"
  [ "$status" -eq 0 ]
  [[ -f "$IDENTITY_LOG" ]]
  run grep -c "ACCEPT" "$IDENTITY_LOG"
  [[ "$output" -ge 1 ]]
}

# ── Edge cases ───────────────────────────────────────

@test "validate: dies on missing --origin" {
  run bash "$SCRIPT" validate --agent-id "ext-platform-test-9999"
  [ "$status" -eq 2 ]
}

@test "coverage: exit codes 0,1,2 all used" {
  run grep -c 'exit 0\|exit 1\|exit 2' "$SCRIPT"
  [[ "$output" -ge 3 ]]
}
