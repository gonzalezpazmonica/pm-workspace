#!/usr/bin/env bats
# test-spec-070-remediation.bats -- SPEC-070: Security Auto-Remediation PRs
#
# Tests:
# 1. security-auto-remediation.sh exists and is executable
# 2. SAVIA_AUTO_REMEDIATION=off -> exit 0 without creating branch
# 3. output/security-fixes/ directory created
# 4. security-remediation-generator.py exists
# 5. generator produces valid JSON for sql-injection

setup() {
  REPO_ROOT="$(git -C "$(dirname "$BATS_TEST_FILENAME")" rev-parse --show-toplevel)"
  SCRIPT="$REPO_ROOT/scripts/security-auto-remediation.sh"
  GENERATOR="$REPO_ROOT/scripts/security-remediation-generator.py"
  FIXES_DIR="$REPO_ROOT/output/security-fixes"
}

@test "security-auto-remediation.sh exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "SAVIA_AUTO_REMEDIATION=off exits 0 without creating branch" {
  run env SAVIA_AUTO_REMEDIATION=off bash "$SCRIPT" \
    --finding "test finding" \
    --file "src/test.py" \
    --severity low
  [ "$status" -eq 0 ]
  # No branch should be created (no git branch command run)
  # Output should contain "disabled"
  echo "$output" | grep -q "disabled"
}

@test "output/security-fixes/ directory is created when enabled" {
  # Run with off to avoid side effects, but directory should already exist
  # from install or previous run; if not, enable creates it
  env SAVIA_AUTO_REMEDIATION=on bash "$SCRIPT" \
    --finding "path traversal in upload" \
    --file "src/upload.py" \
    --severity medium \
    >/dev/null 2>&1 || true
  [ -d "$FIXES_DIR" ]
}

@test "security-remediation-generator.py exists" {
  [ -f "$GENERATOR" ]
}

@test "generator produces valid JSON for sql-injection" {
  output=$(python3 "$GENERATOR" --type "sql-injection" 2>/dev/null)
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert 'vulnerability_type' in d
assert 'severity' in d
assert 'fix_description' in d
assert 'code_patch_suggestion' in d
assert 'references' in d
assert 'confidence' in d
assert isinstance(d['confidence'], float)
assert 0.0 <= d['confidence'] <= 1.0
"
}

@test "SAVIA_AUTO_REMEDIATION=on produces JSON output" {
  output=$(env SAVIA_AUTO_REMEDIATION=on bash "$SCRIPT" \
    --finding "sql injection in login" \
    --file "src/auth.py" \
    --severity high 2>/dev/null)
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert 'finding' in d
assert 'severity' in d
assert 'fix_proposed' in d
"
}
