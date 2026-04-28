#!/usr/bin/env bats
# Ref: SPEC-SE-035 — Reconciliation Delta Engine for Federated Knowledge
# Spec: docs/propuestas/savia-enterprise/SPEC-SE-035-reconciliation-delta-engine.md
# Slice 1+3: tenant_reconciliation_status() primitive (SQL template) +
# reconciliation-status.sh CLI wrapper + delta-tier.sh helper.
# Pattern source: dreamxist/balance MIT (clean-room re-implementation).

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SCRIPT="scripts/enterprise/reconciliation-status.sh"
  STATUS_ABS="$ROOT_DIR/$SCRIPT"
  DELTA_ABS="$ROOT_DIR/scripts/enterprise/delta-tier.sh"
  TEMPLATE_SQL="$ROOT_DIR/docs/propuestas/savia-enterprise/templates/reconciliation.sql"
  RULE_DOC="$ROOT_DIR/docs/rules/domain/savia-enterprise/reconciliation-delta-engine.md"
  TMPDIR_T=$(mktemp -d)
  VALID_UUID="11111111-2222-3333-4444-555555555555"
}

teardown() {
  rm -rf "$TMPDIR_T"
}

# ── C1 — file-level safety + identity ───────────────────────────────────────

@test "reconciliation-status.sh: file exists, has shebang, executable" {
  [ -f "$STATUS_ABS" ]
  head -1 "$STATUS_ABS" | grep -q '^#!'
  [ -x "$STATUS_ABS" ]
}

@test "delta-tier.sh: file exists, has shebang, executable" {
  [ -f "$DELTA_ABS" ]
  head -1 "$DELTA_ABS" | grep -q '^#!'
  [ -x "$DELTA_ABS" ]
}

@test "reconciliation-status.sh: declares 'set -uo pipefail'" {
  grep -q "set -[uo]o pipefail" "$STATUS_ABS"
}

@test "delta-tier.sh: declares 'set -uo pipefail'" {
  grep -q "set -[uo]o pipefail" "$DELTA_ABS"
}

@test "both CLIs pass bash -n syntax check" {
  bash -n "$STATUS_ABS"
  bash -n "$DELTA_ABS"
}

@test "spec ref: SPEC-SE-035 cited in CLI + helper + rule doc" {
  grep -q "SPEC-SE-035" "$STATUS_ABS"
  grep -q "SPEC-SE-035" "$DELTA_ABS"
  grep -q "SPEC-SE-035" "$RULE_DOC"
}

@test "attribution: dreamxist/balance MIT pattern source cited everywhere" {
  grep -qF "dreamxist/balance" "$STATUS_ABS"
  grep -qF "dreamxist/balance" "$DELTA_ABS"
  grep -qF "dreamxist/balance" "$TEMPLATE_SQL"
  grep -qF "MIT" "$TEMPLATE_SQL"
  grep -qiE "clean.room|re.implement" "$RULE_DOC"
}

# ── C2 — SQL template structure (positive) ──────────────────────────────────

@test "template SQL: defines reconciliation_dimensions registry" {
  [ -f "$TEMPLATE_SQL" ]
  grep -qE "CREATE TABLE.*reconciliation_dimensions" "$TEMPLATE_SQL"
  for col in dimension declared_query computed_query amber_threshold red_threshold active; do
    grep -qE "^\\s+$col" "$TEMPLATE_SQL"
  done
}

@test "template SQL: defines reconciliation_alerts append-only log" {
  grep -qE "CREATE TABLE.*reconciliation_alerts" "$TEMPLATE_SQL"
  grep -qE "tier\\s+text\\s+NOT NULL\\s+CHECK" "$TEMPLATE_SQL"
  grep -qE "alerted_at" "$TEMPLATE_SQL"
}

@test "template SQL: tier CHECK constraint enforces green/amber/red only" {
  grep -qE "CHECK\\s*\\(\\s*tier\\s+IN\\s*\\(\\s*'green'\\s*,\\s*'amber'\\s*,\\s*'red'\\s*\\)\\s*\\)" "$TEMPLATE_SQL"
}

@test "template SQL: tenant_reconciliation_status() function defined STABLE" {
  grep -qE "FUNCTION tenant_reconciliation_status" "$TEMPLATE_SQL"
  grep -qE "LANGUAGE plpgsql STABLE" "$TEMPLATE_SQL"
}

@test "template SQL: function returns jsonb (auditable + structured)" {
  grep -qE "RETURNS jsonb" "$TEMPLATE_SQL"
}

# ── C3 — delta-tier.sh helper (positive + edge) ─────────────────────────────

@test "delta-tier: declared==computed (delta=0) returns green tier" {
  run bash "$DELTA_ABS" 100 100
  [ "$status" -eq 0 ]
  [[ "$output" == *"tier=green"* ]]
}

@test "delta-tier: large delta returns red tier (overflow)" {
  run bash "$DELTA_ABS" 10000 0
  [ "$status" -eq 0 ]
  [[ "$output" == *"tier=red"* ]]
}

@test "delta-tier: medium delta returns amber tier (boundary)" {
  run bash "$DELTA_ABS" 2000 0
  [ "$status" -eq 0 ]
  [[ "$output" == *"tier=amber"* ]]
}

@test "delta-tier: negative delta uses absolute value (zero or below)" {
  run bash "$DELTA_ABS" 0 5500
  [ "$status" -eq 0 ]
  [[ "$output" == *"tier=red"* ]]
}

@test "delta-tier: float arithmetic precision (boundary numbers)" {
  run bash "$DELTA_ABS" 1000.5 0.0
  [ "$status" -eq 0 ]
  [[ "$output" == *"tier=amber"* ]]
}

@test "delta-tier: --json mode emits parseable JSON" {
  run bash "$DELTA_ABS" --json 100 100
  [ "$status" -eq 0 ]
  [[ "$output" == *'"tier":"green"'* ]]
  [[ "$output" == *'"declared":100'* ]]
}

@test "delta-tier: invalid number rejected (exit 3)" {
  run bash "$DELTA_ABS" abc 100
  [ "$status" -eq 3 ]
}

@test "delta-tier: missing args rejected (exit 2)" {
  run bash "$DELTA_ABS" 100
  [ "$status" -eq 2 ]
}

# ── C4 — reconciliation-status.sh negative paths ────────────────────────────

@test "status: rejects unknown CLI argument (no-arg edge)" {
  run bash "$STATUS_ABS" --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown arg"* ]]
}

@test "status: zero-arg invocation exits 2 (boundary)" {
  run bash "$STATUS_ABS"
  [ "$status" -eq 2 ]
}

@test "status: missing --tenant exits 2" {
  run bash "$STATUS_ABS" --json
  [ "$status" -eq 2 ]
  [[ "$output" == *"--tenant"* ]]
}

@test "status: rejects non-UUID --tenant (invalid input)" {
  run bash "$STATUS_ABS" --tenant not-a-uuid
  [ "$status" -eq 2 ]
  [[ "$output" == *"UUID"* ]]
}

@test "status: rejects invalid --fail-on value (boundary)" {
  run bash "$STATUS_ABS" --tenant "$VALID_UUID" --fail-on yellow
  [ "$status" -eq 2 ]
  [[ "$output" == *"green|amber|red"* ]]
}

@test "status: missing SAVIA_ENTERPRISE_DSN exits 3" {
  run env -u SAVIA_ENTERPRISE_DSN bash "$STATUS_ABS" --tenant "$VALID_UUID"
  [ "$status" -eq 3 ]
  [[ "$output" == *"SAVIA_ENTERPRISE_DSN"* ]]
}

# ── C5 — Edge cases / structural assertions ─────────────────────────────────

@test "edge: status accepts --fail-on red|amber|green (3 valid options)" {
  for tier in red amber green; do
    grep -qE "\"$tier\"" "$STATUS_ABS"
  done
}

@test "edge: status calls SQL primitive tenant_reconciliation_status()" {
  grep -qF "tenant_reconciliation_status(" "$STATUS_ABS"
}

@test "edge: status reads only active dimensions (where active=true)" {
  grep -qF "active = true" "$STATUS_ABS"
}

@test "edge: status alarm exit code 7 documented + implemented" {
  grep -qE "exit 7" "$STATUS_ABS"
  grep -qF "ALARM:" "$STATUS_ABS"
}

@test "edge: status renders ANSI colors for terminal output" {
  grep -qE "033\\[32m" "$STATUS_ABS"  # green
  grep -qE "033\\[33m" "$STATUS_ABS"  # amber
  grep -qE "033\\[31m" "$STATUS_ABS"  # red
}

# ── C6 — Rule canonical doc ─────────────────────────────────────────────────

@test "rule doc: exists and references SPEC-SE-035" {
  [ -f "$RULE_DOC" ]
  grep -q "SPEC-SE-035" "$RULE_DOC"
}

@test "rule doc: explains green/amber/red tier semantics with thresholds" {
  grep -qiE "green.*amber.*red|tier.*threshold" "$RULE_DOC"
  grep -qF "1000" "$RULE_DOC"
  grep -qF "5000" "$RULE_DOC"
}

@test "rule doc: documents seed dimensions plan (Slice 2 follow-up)" {
  grep -qF "backlog_sp" "$RULE_DOC"
  grep -qF "budget" "$RULE_DOC"
  grep -qF "capacity" "$RULE_DOC"
  grep -qF "knowledge_catalog_hash" "$RULE_DOC"
}

@test "rule doc: cross-references SPEC-SE-002 (RLS) + SPEC-SE-037 (audit) + SPEC-SE-018 (billing)" {
  grep -qF "SPEC-SE-002" "$RULE_DOC"
  grep -qF "SPEC-SE-037" "$RULE_DOC"
  grep -qF "SPEC-SE-018" "$RULE_DOC"
}

@test "rule doc: documents recursion + race condition mitigations (deferred Slice 4)" {
  grep -qiE "advisory_lock|recursi|race|rate.limit" "$RULE_DOC"
}

@test "rule doc: explains why STABLE (not IMMUTABLE, not VOLATILE)" {
  grep -qiE "STABLE|tablas vivas|cache" "$RULE_DOC"
}

# ── C7 — Spec ref + exit code reinforcement ─────────────────────────────────

@test "spec ref: docs/propuestas/savia-enterprise/SPEC-SE-035 referenced in this test file" {
  grep -q "docs/propuestas/savia-enterprise/SPEC-SE-035" "$BATS_TEST_FILENAME"
}

@test "status: documents 6 distinct exit codes (0,2,3,4,5,7)" {
  for code in 2 3 4 5 7; do
    grep -qE "exit $code|^#.*\b$code\b" "$STATUS_ABS"
  done
}

@test "status: --fail-on alarm triggers exit 7 (documented + implemented)" {
  grep -qF -- "--fail-on" "$STATUS_ABS"
  grep -qE "exit 7" "$STATUS_ABS"
}
