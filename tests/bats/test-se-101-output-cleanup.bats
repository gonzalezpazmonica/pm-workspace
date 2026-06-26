#!/usr/bin/env bats
# test-se-101-output-cleanup.bats — SE-101: Output dir retention policy
# Verifies output-cleanup.sh behavior: exists, dry-run safety, telemetry protection.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/output-cleanup.sh"
OUTPUT_DIR="$REPO_ROOT/output"

@test "SE-101: output-cleanup.sh script exists and is executable" {
  [ -f "$SCRIPT" ] || { echo "Script missing: $SCRIPT" >&2; false; }
  [ -x "$SCRIPT" ] || { echo "Script not executable: $SCRIPT" >&2; false; }
  # Verify it accepts --dry-run without error
  run bash "$SCRIPT" --dry-run
  # Exit 0 means clean run (even if 0 stale files)
  [ "$status" -eq 0 ] || { echo "--dry-run failed with status $status: $output" >&2; false; }
}

@test "SE-101: --dry-run mode does not delete any files" {
  # Count files before dry-run
  before=$(find "$OUTPUT_DIR" -maxdepth 3 -type f 2>/dev/null | wc -l)
  run bash "$SCRIPT" --dry-run
  [ "$status" -eq 0 ] || { echo "--dry-run exited $status" >&2; false; }
  after=$(find "$OUTPUT_DIR" -maxdepth 3 -type f 2>/dev/null | wc -l)
  # File count must not decrease (cleanup-log may be created, so after >= before-1 is ok,
  # but we allow +1 for the log file itself being created)
  [ "$after" -ge "$before" ] || { echo "Files deleted during dry-run! before=$before after=$after" >&2; false; }
  # Output must mention dry-run
  echo "$output" | grep -qi "dry-run" || { echo "Expected 'dry-run' in output: $output" >&2; false; }
}

@test "SE-101: protected telemetry files are excluded from dry-run candidate list" {
  run bash "$SCRIPT" --dry-run
  [ "$status" -eq 0 ] || { echo "--dry-run exited $status" >&2; false; }
  # These two files must never appear in the stale list
  echo "$output" | grep -qF "anti-adulation-telemetry.jsonl" \
    && { echo "anti-adulation-telemetry.jsonl appeared in cleanup list" >&2; false; }
  echo "$output" | grep -qF "quality-gate-history.jsonl" \
    && { echo "quality-gate-history.jsonl appeared in cleanup list" >&2; false; }
  :  # pass if neither protected file appears
}
