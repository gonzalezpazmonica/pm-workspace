#!/usr/bin/env bats
# tests/test-se-216-agent-scratchpad.bats — SE-216 Slice 1: agent-scratchpad.sh
# Ref: docs/propuestas/SE-216-evo-patterns.md

# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------
setup() {
  TMPDIR_BASE="$(mktemp -d)"
  export AGENT_SCRATCHPAD_OUTPUT_DIR="${TMPDIR_BASE}/output"
  mkdir -p "${AGENT_SCRATCHPAD_OUTPUT_DIR}"

  SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/scripts/agent-scratchpad.sh"
  export SCRIPT

  RUN_ID="test-$(date +%s)-$$"
  export RUN_ID
}

teardown() {
  rm -rf "$TMPDIR_BASE"
}

# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------
_generate() {
  bash "$SCRIPT" generate \
    --run-id "$RUN_ID" \
    --agents "code-reviewer security-guardian" \
    "$@"
}

_pad() {
  echo "${AGENT_SCRATCHPAD_OUTPUT_DIR}/scratchpad-${RUN_ID}.md"
}

# ===========================================================================
# 1. Script exists and is executable
# ===========================================================================
@test "script exists and is executable" {
  [[ -f "$SCRIPT" ]]
  [[ -x "$SCRIPT" ]]
}

# ===========================================================================
# 2. set -uo pipefail is present
# ===========================================================================
@test "script has set -uo pipefail" {
  grep -q "set -uo pipefail" "$SCRIPT"
}

# ===========================================================================
# 3. generate creates output/scratchpad-{run_id}.md
# ===========================================================================
@test "generate creates scratchpad file" {
  run _generate
  [[ "$status" -eq 0 ]]
  [[ -f "$(_pad)" ]]
}

# ===========================================================================
# 4. Scratchpad contains the 5 canonical sections
# ===========================================================================
@test "scratchpad contains 5 canonical sections" {
  _generate
  local pad; pad="$(_pad)"
  grep -qF "## Objetivo"                  "$pad"
  grep -qF "## Frontier (tareas pendientes)" "$pad"
  grep -qF "## Anotaciones por agente"    "$pad"
  grep -qF "## What Not To Try"           "$pad"
  grep -qF "## Cross-cutting notes"       "$pad"
}

# ===========================================================================
# 5. annotate adds entry under the correct agent section
# ===========================================================================
@test "annotate adds entry under correct agent" {
  _generate
  run bash "$SCRIPT" annotate \
    --run-id "$RUN_ID" \
    --agent "code-reviewer" \
    --finding "validación faltante en POST /patients" \
    --severity "high"
  [[ "$status" -eq 0 ]]
  grep -qF "### code-reviewer" "$(_pad)"
  grep -qF "[high] validación faltante en POST /patients" "$(_pad)"
}

# ===========================================================================
# 6. Two annotate calls for same agent → two entries (append, no overwrite)
# ===========================================================================
@test "two annotate calls for same agent produce two entries" {
  _generate
  bash "$SCRIPT" annotate \
    --run-id "$RUN_ID" --agent "code-reviewer" \
    --finding "finding one" --severity "med"
  bash "$SCRIPT" annotate \
    --run-id "$RUN_ID" --agent "code-reviewer" \
    --finding "finding two" --severity "low"

  local count
  count=$(grep -c "\[" "$(_pad)" || true)
  # At least 2 finding entries
  [[ "$count" -ge 2 ]]
  grep -qF "finding one" "$(_pad)"
  grep -qF "finding two" "$(_pad)"
}

# ===========================================================================
# 7. discard adds entry in "What Not To Try"
# ===========================================================================
@test "discard adds entry in What Not To Try" {
  _generate
  run bash "$SCRIPT" discard \
    --run-id "$RUN_ID" \
    --hypothesis "Eliminar caché de sesión" \
    --reason "Latencia p95 degradó 80ms → 340ms"
  [[ "$status" -eq 0 ]]
  grep -qF '"Eliminar caché de sesión"' "$(_pad)"
  grep -qF "Latencia p95 degradó" "$(_pad)"
}

# ===========================================================================
# 8. read returns full content
# ===========================================================================
@test "read returns full scratchpad content" {
  _generate --objective "Test objective"
  local content
  content="$(bash "$SCRIPT" read --run-id "$RUN_ID")"
  echo "$content" | grep -qF "# Agent Scratchpad — run-${RUN_ID}"
  echo "$content" | grep -qF "Test objective"
  echo "$content" | grep -qF "## Cross-cutting notes"
}

# ===========================================================================
# 9. generate with non-existent --context-files does not fail
# ===========================================================================
@test "generate with non-existent context-files does not fail" {
  run bash "$SCRIPT" generate \
    --run-id "$RUN_ID" \
    --agents "code-reviewer" \
    --context-files "/nonexistent/file.md /another/missing.md"
  [[ "$status" -eq 0 ]]
  [[ -f "$(_pad)" ]]
}

# ===========================================================================
# 10. Two simultaneous annotate calls do not corrupt the file (flock)
# ===========================================================================
@test "two simultaneous annotate calls do not corrupt the scratchpad" {
  _generate
  bash "$SCRIPT" annotate \
    --run-id "$RUN_ID" --agent "security-guardian" \
    --finding "concurrent finding A" --severity "high" &
  bash "$SCRIPT" annotate \
    --run-id "$RUN_ID" --agent "security-guardian" \
    --finding "concurrent finding B" --severity "med" &
  wait

  # File must still be valid (contain required sections)
  grep -qF "## Anotaciones por agente" "$(_pad)"
  grep -qF "## What Not To Try"        "$(_pad)"
  # Both findings must appear
  grep -qF "concurrent finding A" "$(_pad)"
  grep -qF "concurrent finding B" "$(_pad)"
}

# ===========================================================================
# 11. generate without --run-id exits with error
# ===========================================================================
@test "generate without --run-id exits with error" {
  run bash "$SCRIPT" generate --agents "code-reviewer"
  [[ "$status" -ne 0 ]]
  echo "$output" | grep -qi "run-id"
}

# ===========================================================================
# 12. annotate without --agent exits with error
# ===========================================================================
@test "annotate without --agent exits with error" {
  _generate
  run bash "$SCRIPT" annotate \
    --run-id "$RUN_ID" --finding "x" --severity "low"
  [[ "$status" -ne 0 ]]
  echo "$output" | grep -qi "agent"
}

# ===========================================================================
# 13. discard without --hypothesis exits with error
# ===========================================================================
@test "discard without --hypothesis exits with error" {
  _generate
  run bash "$SCRIPT" discard \
    --run-id "$RUN_ID" --reason "some reason"
  [[ "$status" -ne 0 ]]
  echo "$output" | grep -qi "hypothesis"
}

# ===========================================================================
# 14. read with non-existent run_id exits with clear error
# ===========================================================================
@test "read with non-existent run-id exits with clear error" {
  run bash "$SCRIPT" read --run-id "run-does-not-exist-99999"
  [[ "$status" -ne 0 ]]
  echo "$output" | grep -qi "not found\|not exist\|no such"
}

# ===========================================================================
# 15. Timestamp in annotations is a valid ISO8601 or Unix timestamp
# ===========================================================================
@test "annotation timestamp is ISO8601 format" {
  _generate
  bash "$SCRIPT" annotate \
    --run-id "$RUN_ID" --agent "drift-auditor" \
    --finding "timestamp test" --severity "low"
  # ISO8601 pattern: YYYY-MM-DDTHH:MM:SSZ
  grep -qE "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z" "$(_pad)"
}

# ===========================================================================
# 16. generate twice for same run_id overwrites (does not duplicate header)
# ===========================================================================
@test "generate twice for same run-id overwrites not duplicates" {
  _generate --objective "First objective"
  _generate --objective "Second objective"

  local pad; pad="$(_pad)"
  # Only one scratchpad header
  local header_count
  header_count=$(grep -c "# Agent Scratchpad — run-${RUN_ID}" "$pad" || true)
  [[ "$header_count" -eq 1 ]]
  # Second objective wins
  grep -qF "Second objective" "$pad"
  run grep -F "First objective" "$pad"
  [[ "$status" -ne 0 ]]
}

# ===========================================================================
# 17. discard adds multiple entries without overwriting previous ones
# ===========================================================================
@test "multiple discard calls append without overwriting" {
  _generate
  bash "$SCRIPT" discard \
    --run-id "$RUN_ID" --hypothesis "Hypo A" --reason "Reason A"
  bash "$SCRIPT" discard \
    --run-id "$RUN_ID" --hypothesis "Hypo B" --reason "Reason B"

  grep -qF '"Hypo A"' "$(_pad)"
  grep -qF '"Hypo B"' "$(_pad)"
}
