#!/usr/bin/env bats
# test-se-102-eras-timeline.bats — Tests for SE-102: Eras Timeline Consolidation
# Tests: eras-timeline.md exists with table, columns, and script is executable

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  TIMELINE="$REPO_ROOT/docs/eras-timeline.md"
  SCRIPT="$REPO_ROOT/scripts/eras-timeline-generate.sh"
}

@test "SE-102: docs/eras-timeline.md exists" {
  [ -f "$TIMELINE" ]
}

@test "SE-102: eras-timeline.md contains a markdown table" {
  # Table must have at least one row separator and data rows
  grep -q "^|" "$TIMELINE"
  grep -q "Era | Versión | Fecha" "$TIMELINE"
}

@test "SE-102: table has required columns Era, Versión, Fecha" {
  local header
  header=$(grep "Era | Versión | Fecha" "$TIMELINE")
  [[ "$header" =~ "Era" ]]
  [[ "$header" =~ "Versión" ]]
  [[ "$header" =~ "Fecha" ]]
  [[ "$header" =~ "Estado" ]]
}

@test "SE-102: eras-timeline.md covers at least 20 eras" {
  local count
  # Count table data rows (lines starting with | that are not header or separator)
  count=$(grep -c "^| [0-9]" "$TIMELINE" || true)
  [ "$count" -ge 20 ]
}

@test "SE-102: eras-timeline.md has generation footer" {
  grep -q "generado de ROADMAP.md" "$TIMELINE"
}

@test "SE-102: scripts/eras-timeline-generate.sh exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "SE-102: eras-timeline-generate.sh --check mode passes on current file" {
  run bash "$SCRIPT" --check
  [ "$status" -eq 0 ]
}

@test "SE-102: eras-timeline-generate.sh regenerates without error" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "$REPO_ROOT/docs/eras-timeline.md" ]
}
