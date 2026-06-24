#!/usr/bin/env bats
# test-se-101-output-cleanup.bats — SE-101: Output dir retention policy
# Verifies output-cleanup.sh behavior: exists, dry-run safety, telemetry protection.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/output-cleanup.sh"
OUTPUT_DIR="$REPO_ROOT/output"

@test "SE-101: output-cleanup.sh script exists and is executable" {
  [ -f "$SCRIPT" ] || fail "Script missing: $SCRIPT"
  [ -x "$SCRIPT" ] || fail "Script not executable: $SCRIPT"
  # Verify it accepts --dry-run without error
  run bash "$SCRIPT" --dry-run
  # Exit 0 means clean run (even if 0 stale files)
  [ "$status" -eq 0 ] || fail "--dry-run failed with status $status: $output"
}

@test "SE-101: --dry-run mode does not delete any files" {
  # Count files before dry-run
  before=$(find "$OUTPUT_DIR" -maxdepth 3 -type f 2>/dev/null | wc -l)
  run bash "$SCRIPT" --dry-run
  [ "$status" -eq 0 ] || fail "--dry-run exited $status"
  after=$(find "$OUTPUT_DIR" -maxdepth 3 -type f 2>/dev/null | wc -l)
  # File count must not decrease (cleanup-log may be created, so after >= before-1 is ok,
  # but we allow +1 for the log file itself being created)
  [ "$after" -ge "$before" ] || fail "Files deleted during dry-run! before=$before after=$after"
  # Output must mention dry-run
  echo "$output" | grep -qi "dry-run" || fail "Expected 'dry-run' in output: $output"
}

@test "SE-101: protected telemetry files are excluded from dry-run candidate list" {
  run bash "$SCRIPT" --dry-run
  [ "$status" -eq 0 ] || fail "--dry-run exited $status"
  # These two files must never appear in the stale list
  echo "$output" | grep -qF "anti-adulation-telemetry.jsonl" \
    && fail "anti-adulation-telemetry.jsonl appeared in cleanup list"
  echo "$output" | grep -qF "quality-gate-history.jsonl" \
    && fail "quality-gate-history.jsonl appeared in cleanup list"
  :  # pass if neither protected file appears
}
