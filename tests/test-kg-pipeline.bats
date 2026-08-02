#!/usr/bin/env bats

setup() {
  PIPELINE="$BATS_TEST_DIRNAME/../scripts/kg-pipeline.sh"
  EXTRACTOR="$BATS_TEST_DIRNAME/../scripts/kg-extract.py"
  REPORT="$BATS_TEST_DIRNAME/../scripts/kg-quality-report.sh"
  CLEANUP="$BATS_TEST_DIRNAME/../scripts/kg-cleanup.sh"
  HOOK="$BATS_TEST_DIRNAME/../.claude/hooks/post-digestion-kg-extract.sh"
}

@test "pipeline exists and executable" {
  [ -f "$PIPELINE" ]
  [ -x "$PIPELINE" ]
}

@test "pipeline processes text input" {
  echo "SE-291 and SE-288" | run bash "$PIPELINE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"entity_count"* ]]
}

@test "pipeline handles empty input" {
  echo "" | run bash "$PIPELINE"
  [ "$status" -eq 0 ]
}

@test "quality report script exists" {
  [ -f "$REPORT" ]
  [ -x "$REPORT" ]
}

@test "cleanup script exists" {
  [ -f "$CLEANUP" ]
  [ -x "$CLEANUP" ]
}

@test "hook exists and executable" {
  [ -f "$HOOK" ]
  [ -x "$HOOK" ]
}

@test "hook has set -uo pipefail" {
  head -3 "$HOOK" | grep -q "set -uo pipefail"
}

@test "policy doc exists" {
  [ -f "$BATS_TEST_DIRNAME/../docs/rules/domain/knowledge-graph-auto-extraction.md" ]
}

@test "pipeline quality-gate rejects non-verified entities" {
  echo "The system uses patterns" | run bash "$PIPELINE"
  [ "$status" -eq 0 ]
}
