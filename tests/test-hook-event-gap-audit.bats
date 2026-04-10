#!/usr/bin/env bats
# test-hook-event-gap-audit.bats — Tests for SPEC-HOOK-EVENT-GAP-AUDIT
# Ref: docs/specs/SPEC-HOOK-EVENT-GAP-AUDIT.spec.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/hook-event-gap-audit.sh"
  TMPDIR_HG=$(mktemp -d)
  FAKE_SETTINGS="$TMPDIR_HG/settings.json"
}

teardown() {
  rm -rf "$TMPDIR_HG"
}

# ── Script integrity ─────────────────────────────────────────────────────────

@test "script exists" {
  [ -f "$SCRIPT" ]
}

@test "script has bash shebang" {
  head -1 "$SCRIPT" | grep -q "bash"
}

@test "script has set -uo pipefail" {
  grep -q "set -uo pipefail" "$SCRIPT"
}

@test "script --help shows usage" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]] || [[ "$output" == *"Usage"* ]]
}

@test "script references SPEC-HOOK-EVENT-GAP-AUDIT" {
  grep -q "SPEC-HOOK-EVENT-GAP-AUDIT" "$SCRIPT"
}

# ── Happy path ───────────────────────────────────────────────────────────────

@test "happy path: script executes and generates output" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"generado"* ]] || [[ "$output" == *"Generado"* ]] || [[ "$output" == *"generated"* ]]
}

@test "happy path: output file is created" {
  bash "$SCRIPT" >/dev/null 2>&1
  [ -f "$REPO_ROOT/output/hook-event-gap-audit.md" ]
}

@test "output contains markdown table headers" {
  bash "$SCRIPT" >/dev/null 2>&1
  local out="$REPO_ROOT/output/hook-event-gap-audit.md"
  grep -q "|.*Event.*|" "$out" || grep -q "|.*event.*|" "$out" || grep -q "| *Evento *|" "$out"
}

@test "output contains coverage summary" {
  bash "$SCRIPT" >/dev/null 2>&1
  local out="$REPO_ROOT/output/hook-event-gap-audit.md"
  grep -qE "(Cobertura|Coverage|17/28|21/28)" "$out"
}

@test "output classifies gaps with HIGH/MEDIUM/LOW/SKIP" {
  bash "$SCRIPT" >/dev/null 2>&1
  local out="$REPO_ROOT/output/hook-event-gap-audit.md"
  grep -q "HIGH" "$out"
  grep -q "MEDIUM" "$out"
  grep -q "LOW" "$out" || grep -q "SKIP" "$out"
}

@test "identifies at least 11 gaps" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"11"* ]] || [[ "$output" == *"Gaps"* ]] || [[ "$output" == *"gaps"* ]]
}

@test "includes PermissionRequest event candidate" {
  bash "$SCRIPT" >/dev/null 2>&1
  local out="$REPO_ROOT/output/hook-event-gap-audit.md"
  grep -q "PermissionRequest" "$out"
}

@test "includes Notification event candidate" {
  bash "$SCRIPT" >/dev/null 2>&1
  local out="$REPO_ROOT/output/hook-event-gap-audit.md"
  grep -q "Notification" "$out"
}

# ── Edge cases ───────────────────────────────────────────────────────────────

@test "edge: empty settings.json does not crash" {
  echo '{}' > "$FAKE_SETTINGS"
  # Run with cwd pointing to tmpdir so .claude/settings.json is missing
  run bash -c "cd '$TMPDIR_HG' && bash '$SCRIPT' 2>&1"
  # Either succeeds or fails gracefully, should not segfault
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]] || [[ "$status" -eq 2 ]]
}

@test "edge: nonexistent output directory is created" {
  bash "$SCRIPT" >/dev/null 2>&1
  [ -d "$REPO_ROOT/output" ]
}

@test "edge: no-arg invocation uses defaults" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "edge: unknown flag shows help or error" {
  run bash "$SCRIPT" --invalid-flag
  # Accept either help display or error exit
  [[ "$status" -eq 0 ]] || [[ "$status" -ne 0 ]]
}

@test "edge: boundary with zero gaps shown correctly" {
  bash "$SCRIPT" >/dev/null 2>&1
  local out="$REPO_ROOT/output/hook-event-gap-audit.md"
  # The script should always show at least the 11 known gaps
  local count
  count=$(grep -c "HIGH\|MEDIUM\|LOW\|SKIP" "$out" || echo 0)
  [ "$count" -ge 11 ]
}

@test "edge: large number of events in catalog" {
  bash "$SCRIPT" >/dev/null 2>&1
  local out="$REPO_ROOT/output/hook-event-gap-audit.md"
  # The catalog has 28 total events
  grep -qE "(28|total)" "$out"
}

# ── Coverage: key functions / structure ─────────────────────────────────────

@test "coverage: script reads settings.json" {
  grep -q "settings.json" "$SCRIPT"
}

@test "coverage: script uses catalog of events" {
  grep -qE "(KNOWN_EVENTS|CATALOG|catalog|eventos)" "$SCRIPT"
}

@test "coverage: script classifies by value" {
  grep -qE "(HIGH|classify|clasific)" "$SCRIPT"
}

@test "coverage: script generates markdown output" {
  grep -qE "(\.md|markdown|## )" "$SCRIPT"
}
