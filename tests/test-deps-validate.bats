#!/usr/bin/env bats
# BATS tests for scripts/deps-validate.sh (SPEC-SE-020 Slice 1).
# Validates the deps.yaml schema validator: required keys, enum validation,
# date format, contact handle format, JSON output, negatives, edges.
#
# Ref: SPEC-SE-020, docs/rules/domain/portfolio-as-graph.md, ROADMAP §Tier 5.12
# Safety: script under test has `set -uo pipefail`, read-only.

SCRIPT="scripts/deps-validate.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() {
  cd /
}

# ── Structure / safety ──────────────────────────────────────────────────────

@test "script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "script uses set -uo pipefail" {
  run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "script passes bash -n syntax check" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script references SPEC-SE-020" {
  run grep -c 'SPEC-SE-020' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "rule doc exists and references SPEC-SE-020" {
  [[ -f "docs/rules/domain/portfolio-as-graph.md" ]]
  run grep -c 'SPEC-SE-020' docs/rules/domain/portfolio-as-graph.md
  [[ "$output" -ge 1 ]]
}

@test "rule doc stays under 150 lines (acceptance criterion)" {
  local lines
  lines=$(wc -l < docs/rules/domain/portfolio-as-graph.md)
  [[ "$lines" -le 150 ]]
}

@test "sample deps.yaml exists" {
  [[ -f "docs/examples/deps.yaml.sample" ]]
}

# ── CLI surface ─────────────────────────────────────────────────────────────

@test "script accepts --help and exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"schema"* ]]
  [[ "$output" == *"deps.yaml"* ]]
}

@test "script rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "script requires --file argument" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"file required"* ]]
}

@test "script rejects nonexistent file" {
  run bash "$SCRIPT" --file /does/not/exist.yaml
  [ "$status" -eq 2 ]
  [[ "$output" == *"not found"* ]]
}

# ── Positive cases ──────────────────────────────────────────────────────────

@test "sample deps.yaml validates successfully" {
  run bash "$SCRIPT" --file docs/examples/deps.yaml.sample
  [ "$status" -eq 0 ]
  [[ "$output" == *"VALID"* ]]
  [[ "$output" == *"erp-migration"* ]]
}

@test "minimal valid deps.yaml (only upstream) validates" {
  local tmp="$BATS_TEST_TMPDIR/min.yaml"
  cat > "$tmp" <<EOF
project: "my-proj"
tenant: "my-tenant"
dependencies:
  upstream:
    - project: "upstream-one"
      type: "blocks"
      deliverable: "D-001"
      needed_by: "2026-12-31"
      status: "on-track"
EOF
  run bash "$SCRIPT" --file "$tmp"
  [ "$status" -eq 0 ]
  [[ "$output" == *"VALID"* ]]
}

@test "valid deps.yaml counts upstream/downstream/shared correctly" {
  run bash "$SCRIPT" --file docs/examples/deps.yaml.sample
  [ "$status" -eq 0 ]
  [[ "$output" == *"1 upstream"* ]]
  [[ "$output" == *"1 downstream"* ]]
  [[ "$output" == *"1 shared_resource"* ]]
}

# ── Negative: missing keys ──────────────────────────────────────────────────

@test "missing project key fails validation" {
  local tmp="$BATS_TEST_TMPDIR/no-proj.yaml"
  cat > "$tmp" <<EOF
tenant: "x"
dependencies:
  upstream: []
EOF
  run bash "$SCRIPT" --file "$tmp"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing required key 'project'"* ]]
}

@test "missing tenant key fails validation" {
  local tmp="$BATS_TEST_TMPDIR/no-tenant.yaml"
  cat > "$tmp" <<EOF
project: "x"
dependencies:
  upstream: []
EOF
  run bash "$SCRIPT" --file "$tmp"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing required key 'tenant'"* ]]
}

@test "missing dependencies key fails validation" {
  local tmp="$BATS_TEST_TMPDIR/no-deps.yaml"
  cat > "$tmp" <<EOF
project: "x"
tenant: "y"
EOF
  run bash "$SCRIPT" --file "$tmp"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing required key 'dependencies'"* ]]
}

# ── Negative: enum violations ───────────────────────────────────────────────

@test "invalid type value is rejected" {
  local tmp="$BATS_TEST_TMPDIR/bad-type.yaml"
  cat > "$tmp" <<EOF
project: "x"
tenant: "y"
dependencies:
  upstream:
    - project: "u"
      type: "not-a-real-type"
      deliverable: "D"
      needed_by: "2026-01-01"
      status: "on-track"
EOF
  run bash "$SCRIPT" --file "$tmp"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid 'type'"* ]]
}

@test "invalid status value is rejected" {
  local tmp="$BATS_TEST_TMPDIR/bad-status.yaml"
  cat > "$tmp" <<EOF
project: "x"
tenant: "y"
dependencies:
  upstream:
    - project: "u"
      type: "blocks"
      deliverable: "D"
      needed_by: "2026-01-01"
      status: "wrong-status"
EOF
  run bash "$SCRIPT" --file "$tmp"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid 'status'"* ]]
}

# ── Negative: date format ───────────────────────────────────────────────────

@test "invalid needed_by date format is rejected" {
  local tmp="$BATS_TEST_TMPDIR/bad-date.yaml"
  cat > "$tmp" <<EOF
project: "x"
tenant: "y"
dependencies:
  upstream:
    - project: "u"
      type: "blocks"
      deliverable: "D"
      needed_by: "15/07/2026"
      status: "on-track"
EOF
  run bash "$SCRIPT" --file "$tmp"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid 'needed_by' date"* ]]
}

@test "valid ISO date YYYY-MM-DD accepted" {
  local tmp="$BATS_TEST_TMPDIR/ok-date.yaml"
  cat > "$tmp" <<EOF
project: "x"
tenant: "y"
dependencies:
  upstream:
    - project: "u"
      type: "blocks"
      deliverable: "D"
      needed_by: "2026-12-31"
      status: "on-track"
EOF
  run bash "$SCRIPT" --file "$tmp"
  [ "$status" -eq 0 ]
}

# ── Warnings: contact format ────────────────────────────────────────────────

@test "non-handle contact triggers warning but still valid" {
  local tmp="$BATS_TEST_TMPDIR/bad-contact.yaml"
  cat > "$tmp" <<EOF
project: "x"
tenant: "y"
dependencies:
  upstream:
    - project: "u"
      type: "blocks"
      deliverable: "D"
      needed_by: "2026-01-01"
      status: "on-track"
      contact: "email@bad.com"
EOF
  run bash "$SCRIPT" --file "$tmp"
  [ "$status" -eq 0 ]
  [[ "$output" == *"@handle"* ]]
}

@test "strict mode: warnings become errors" {
  local tmp="$BATS_TEST_TMPDIR/warn.yaml"
  cat > "$tmp" <<EOF
project: "x"
tenant: "BAD_SLUG"
dependencies:
  upstream:
    - project: "u"
      type: "blocks"
      deliverable: "D"
      needed_by: "2026-01-01"
      status: "on-track"
EOF
  run bash "$SCRIPT" --file "$tmp"
  [ "$status" -eq 0 ]
  run bash "$SCRIPT" --file "$tmp" --strict
  [ "$status" -eq 1 ]
}

# ── JSON output ─────────────────────────────────────────────────────────────

@test "json output is valid JSON with expected keys" {
  run bash -c 'bash '"$SCRIPT"' --file docs/examples/deps.yaml.sample --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert \"valid\" in d; assert \"project\" in d; assert \"upstream\" in d; assert \"errors\" in d; print(\"ok\")"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "json shows valid:true for passing file" {
  run bash "$SCRIPT" --file docs/examples/deps.yaml.sample --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"valid":true'* ]]
}

@test "json shows valid:false with errors list for failing file" {
  local tmp="$BATS_TEST_TMPDIR/broken.yaml"
  cat > "$tmp" <<EOF
project: "x"
dependencies:
  upstream: []
EOF
  run bash "$SCRIPT" --file "$tmp" --json
  [ "$status" -eq 1 ]
  [[ "$output" == *'"valid":false'* ]]
  [[ "$output" == *"missing required key"* ]]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: all 4 type enums accepted" {
  for t in blocks feeds shared-resource shared-platform; do
    local tmp="$BATS_TEST_TMPDIR/type-$t.yaml"
    cat > "$tmp" <<EOF
project: "x"
tenant: "y"
dependencies:
  upstream:
    - project: "u"
      type: "$t"
      deliverable: "D"
      needed_by: "2026-01-01"
      status: "on-track"
EOF
    run bash "$SCRIPT" --file "$tmp"
    [ "$status" -eq 0 ]
  done
}

@test "edge: all 4 status enums accepted" {
  for s in on-track at-risk blocked delivered; do
    local tmp="$BATS_TEST_TMPDIR/status-$s.yaml"
    cat > "$tmp" <<EOF
project: "x"
tenant: "y"
dependencies:
  upstream:
    - project: "u"
      type: "blocks"
      deliverable: "D"
      needed_by: "2026-01-01"
      status: "$s"
EOF
    run bash "$SCRIPT" --file "$tmp"
    [ "$status" -eq 0 ]
  done
}

@test "edge: empty dependencies block accepted" {
  local tmp="$BATS_TEST_TMPDIR/empty.yaml"
  cat > "$tmp" <<EOF
project: "x"
tenant: "y"
dependencies:
  upstream: []
  downstream: []
EOF
  run bash "$SCRIPT" --file "$tmp"
  [ "$status" -eq 0 ]
}

# ── Isolation ──────────────────────────────────────────────────────────────

@test "isolation: script does not modify input file" {
  local tmp="$BATS_TEST_TMPDIR/ro.yaml"
  cp docs/examples/deps.yaml.sample "$tmp"
  local hash_before
  hash_before=$(md5sum "$tmp" | awk '{print $1}')
  bash "$SCRIPT" --file "$tmp" >/dev/null 2>&1
  local hash_after
  hash_after=$(md5sum "$tmp" | awk '{print $1}')
  [[ "$hash_before" == "$hash_after" ]]
}

@test "isolation: exit codes are 0 (valid), 1 (invalid), or 2 (usage)" {
  run bash "$SCRIPT" --file docs/examples/deps.yaml.sample
  [[ "$status" -eq 0 ]]
  run bash "$SCRIPT" --bogus
  [[ "$status" -eq 2 ]]
}
