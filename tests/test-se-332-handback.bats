#!/usr/bin/env bats
# tests/test-se-332-handback.bats — SE-332 Handback Obligation
# Ref: docs/specs/SE-332-handback-obligation.spec.md
# Covers: resolution per mode, invariant exit 5, reference-first schema,
# enum, audit log, artifact emission.

SCRIPT="${BATS_TEST_DIRNAME}/../scripts/handback-resolve.sh"
ENVSH="${BATS_TEST_DIRNAME}/../scripts/savia-env.sh"
AUTOSAFE="${BATS_TEST_DIRNAME}/../docs/rules/domain/autonomous-safety.md"
TSP="${BATS_TEST_DIRNAME}/../docs/rules/domain/terminal-state-protocol.md"

setup() {
  set -uo pipefail
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR
  export SAVIA_WORKSPACE_DIR="$TMP_DIR"
  export SAVIA_AUTONOMOUS_REVIEWER="@test-reviewer"
}

teardown() {
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

# --- AC-1 / AC-2: normative docs -------------------------------------------------

@test "se-332: autonomous-safety.md has Handback Obligation section" {
  grep -q "Handback Obligation" "$AUTOSAFE"
}

@test "se-332: terminal-state-protocol.md enum includes handback" {
  grep -q "handback" "$TSP"
}

# --- Chain resolution per mode (AC-4) -------------------------------------------

@test "se-332: overnight-sprint resolves to AUTONOMOUS_REVIEWER" {
  source "$ENVSH"
  run savia_handback_chain "overnight-sprint"
  [ "$status" -eq 0 ]
  [ "$output" = "@test-reviewer" ]
}

@test "se-332: code-improvement-loop resolves to AUTONOMOUS_REVIEWER" {
  source "$ENVSH"
  run savia_handback_chain "code-improvement-loop"
  [ "$status" -eq 0 ]
  [ "$output" = "@test-reviewer" ]
}

@test "se-332: tech-research-agent resolves to AUTONOMOUS_REVIEWER" {
  source "$ENVSH"
  run savia_handback_chain "tech-research-agent"
  [ "$status" -eq 0 ]
  [ "$output" = "@test-reviewer" ]
}

@test "se-332: court-orchestrator resolves to dev-orchestrator" {
  source "$ENVSH"
  run savia_handback_chain "court-orchestrator"
  [ "$status" -eq 0 ]
  [ "$output" = "dev-orchestrator" ]
}

@test "se-332: truth-tribunal-orchestrator resolves to dev-orchestrator" {
  source "$ENVSH"
  run savia_handback_chain "truth-tribunal-orchestrator"
  [ "$status" -eq 0 ]
  [ "$output" = "dev-orchestrator" ]
}

@test "se-332: recommendation-tribunal-orchestrator resolves to dev-orchestrator" {
  source "$ENVSH"
  run savia_handback_chain "recommendation-tribunal-orchestrator"
  [ "$status" -eq 0 ]
  [ "$output" = "dev-orchestrator" ]
}

@test "se-332: subagent resolves to invoking orchestrator (env override)" {
  export SAVIA_HANDBACK_PARENT="dev-orchestrator"
  source "$ENVSH"
  run savia_handback_chain "subagent"
  [ "$status" -eq 0 ]
  [ "$output" = "dev-orchestrator" ]
}

# --- Invariant exit 5 (AC-5) ----------------------------------------------------

@test "se-332: unknown mode returns exit 5 (chain not manual)" {
  source "$ENVSH"
  run savia_handback_chain "unknown-mode"
  [ "$status" -eq 5 ]
}

@test "se-332: handback-resolve.sh exits 5 for unknown mode" {
  run bash "$SCRIPT" --modo "bogus-mode" --contexto-dir "$TMP_DIR"
  [ "$status" -eq 5 ]
}

# --- Artifact emission + reference-first schema (AC-4/AC-6) -----------------------

@test "se-332: emits artifact with reference-first contexto_ref (paths only)" {
  mkdir -p "$TMP_DIR/runctx"
  touch "$TMP_DIR/runctx/run-record.jsonl" "$TMP_DIR/runctx/terminal-state.jsonl"
  run bash "$SCRIPT" --modo "overnight-sprint" --contexto-dir "$TMP_DIR/runctx" \
    --motivo "guardrail_rechazo" --intentos-restantes 2
  [ "$status" -eq 0 ]
  artifact="$TMP_DIR/output/agent-runs/overnight-sprint-$(date +%Y%m%d)-handback.md"
  [ -f "$artifact" ]
  grep -q "escalado_a: @test-reviewer" "$artifact"
  grep -q "motivo: guardrail_rechazo" "$artifact"
  grep -q "intentos_restantes: 2" "$artifact"
  grep -q "contexto_ref:" "$artifact"
  # reference-first: contains routes, not bodies
  grep -q "runctx/run-record.jsonl" "$artifact"
  grep -q "runctx/terminal-state.jsonl" "$artifact"
  ! grep -q '{"' "$artifact"
}

@test "se-332: artifact is emitted under output/agent-runs/" {
  mkdir -p "$TMP_DIR/ctx"
  touch "$TMP_DIR/ctx/terminal-state.jsonl"
  bash "$SCRIPT" --modo "court-orchestrator" --contexto-dir "$TMP_DIR/ctx" >/dev/null
  [ -d "$TMP_DIR/output/agent-runs" ]
}

# --- Audit trail (AC-7) -----------------------------------------------------------

@test "se-332: audit log records handback_to" {
  mkdir -p "$TMP_DIR/ctx"
  touch "$TMP_DIR/ctx/terminal-state.jsonl"
  bash "$SCRIPT" --modo "court-orchestrator" --contexto-dir "$TMP_DIR/ctx" >/dev/null
  audit="$TMP_DIR/output/agent-runs/court-orchestrator-$(date +%Y%m%d)-audit.log"
  [ -f "$audit" ]
  grep -q "handback_to=dev-orchestrator" "$audit"
}

# --- Usage / failure paths ---------------------------------------------------------

@test "se-332: missing --contexto-dir is a usage error (exit 2)" {
  run bash "$SCRIPT" --modo "overnight-sprint"
  [ "$status" -eq 2 ]
}

@test "se-332: nonexistent contexto-dir is a usage error (exit 2)" {
  run bash "$SCRIPT" --modo "overnight-sprint" --contexto-dir "$TMP_DIR/nope"
  [ "$status" -eq 2 ]
}
