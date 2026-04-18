#!/usr/bin/env bats
# Tests for SE-030 — receipts validator
# Ref: docs/rules/domain/receipts-protocol.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/context-receipts-validate.sh"
  export PROTOCOL="$REPO_ROOT/docs/rules/domain/receipts-protocol.md"
  TMPDIR_RC="$(mktemp -d)"
  export TMPDIR_RC

  # Valid: claim with receipts block and real file
  cat > "$TMPDIR_RC/valid.md" <<'F'
claim: "CLAUDE.md exists"
receipts:
  - file: CLAUDE.md
    line: 1
  - spec: SPEC-120
F

  # Unverified: claim without receipts
  cat > "$TMPDIR_RC/unverified.md" <<'F'
claim: "This probably works"

Some random text here.
F

  # Broken: file receipt but file doesn't exist
  cat > "$TMPDIR_RC/broken-file.md" <<'F'
claim: "nonexistent file reference"
receipts:
  - file: nonexistent/fake-file-xyz.md
    line: 1
F

  # Broken: spec not found
  cat > "$TMPDIR_RC/broken-spec.md" <<'F'
claim: "reference fake spec"
receipts:
  - spec: SPEC-99999
F

  # Mixed: some valid, some unverified
  cat > "$TMPDIR_RC/mixed.md" <<'F'
claim: "good one"
receipts:
  - file: CLAUDE.md
    line: 1

claim: "bad one without proof"
F
}

teardown() {
  rm -rf "$TMPDIR_RC" 2>/dev/null || true
}

# ── Safety ─────────────────────────────────────────────────────────────────

@test "safety: script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "safety: script has set -uo pipefail" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "safety: script references SE-030" {
  grep -q "SE-030" "$SCRIPT"
}

@test "safety: protocol doc exists and is non-empty" {
  [ -f "$PROTOCOL" ]
  [ -s "$PROTOCOL" ]
}

# ── Positive ───────────────────────────────────────────────────────────────

@test "positive: valid file with receipt returns exit 0" {
  run bash "$SCRIPT" --input "$TMPDIR_RC/valid.md"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE "PASS.*1 claims"
}

@test "positive: --help returns exit 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
}

@test "positive: --json produces parseable output" {
  run bash "$SCRIPT" --input "$TMPDIR_RC/valid.md" --json
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['verified']==1"
}

@test "positive: protocol doc references SE-030" {
  grep -q "SE-030" "$PROTOCOL"
}

@test "positive: protocol doc documents receipt formats" {
  grep -qE "file:|spec:|decision:|commit:" "$PROTOCOL"
}

# ── Negative / Warn cases ──────────────────────────────────────────────────

@test "negative: unverified claim returns exit 1 (WARN)" {
  run bash "$SCRIPT" --input "$TMPDIR_RC/unverified.md"
  [ "$status" -eq 1 ]
  echo "$output" | grep -qE "WARN"
}

@test "negative: broken file receipt returns exit 2 (FAIL)" {
  run bash "$SCRIPT" --input "$TMPDIR_RC/broken-file.md"
  [ "$status" -eq 2 ]
  echo "$output" | grep -qE "FAIL.*broken"
}

@test "negative: broken spec receipt returns exit 2 (FAIL)" {
  run bash "$SCRIPT" --input "$TMPDIR_RC/broken-spec.md"
  [ "$status" -eq 2 ]
}

@test "negative: --strict upgrades WARN to FAIL (exit 2)" {
  run bash "$SCRIPT" --input "$TMPDIR_RC/unverified.md" --strict
  [ "$status" -eq 2 ]
}

@test "negative: nonexistent input file errors with exit 2" {
  run bash "$SCRIPT" --input "/nonexistent-path-xyz.md"
  [ "$status" -eq 2 ]
}

@test "negative: missing --input rejected" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "negative: unknown flag rejected" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: mixed valid+unverified returns exit 1 with both counts" {
  run bash "$SCRIPT" --input "$TMPDIR_RC/mixed.md" --json
  [ "$status" -eq 1 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['verified']==1; assert d['unverified']==1"
}

@test "edge: empty file has 0 claims" {
  : > "$TMPDIR_RC/empty.md"
  run bash "$SCRIPT" --input "$TMPDIR_RC/empty.md" --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['total']==0"
}

@test "edge: file without claims returns exit 0" {
  echo "Just some text without any claim field." > "$TMPDIR_RC/no-claims.md"
  run bash "$SCRIPT" --input "$TMPDIR_RC/no-claims.md"
  [ "$status" -eq 0 ]
}

# ── Isolation ──────────────────────────────────────────────────────────────

@test "isolation: script does not modify input file" {
  hash_before=$(sha256sum "$TMPDIR_RC/valid.md" | awk '{print $1}')
  bash "$SCRIPT" --input "$TMPDIR_RC/valid.md" >/dev/null 2>&1 || true
  hash_after=$(sha256sum "$TMPDIR_RC/valid.md" | awk '{print $1}')
  [ "$hash_before" = "$hash_after" ]
}

@test "isolation: exit codes are 0, 1, or 2" {
  run bash "$SCRIPT" --input "$TMPDIR_RC/mixed.md"
  [[ "$status" == "0" || "$status" == "1" || "$status" == "2" ]]
}
