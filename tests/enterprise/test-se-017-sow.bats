#!/usr/bin/env bats
# test-se-017-sow.bats — SE-017 Project Definition (SOW-as-Code)
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-017-project-definition.md

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SOW_CREATE="${REPO_ROOT}/scripts/enterprise/sow-create.sh"
  SOW_VALIDATE="${REPO_ROOT}/scripts/enterprise/sow-validate.sh"
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR REPO_ROOT
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ── sow-create.sh ────────────────────────────────────────────────────────────

@test "SE-017: sow-create.sh exists and is executable" {
  [[ -f "$SOW_CREATE" ]]
  [[ -x "$SOW_CREATE" ]]
}

@test "SE-017: sow-create.sh --help exits 0" {
  run bash "$SOW_CREATE" --help
  [ "$status" -eq 0 ]
}

@test "SE-017: sow-create.sh fails without required args" {
  run bash "$SOW_CREATE"
  [ "$status" -eq 2 ]
}

@test "SE-017: sow-create.sh creates sow.md with basic template" {
  run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${SOW_CREATE}' \
    --project erp-migration --tenant acme --template basic"
  [ "$status" -eq 0 ]

  local sow_file="${TEST_TMPDIR}/tenants/acme/projects/erp-migration/sow.md"
  [[ -f "$sow_file" ]]
  grep -q "template: basic" "$sow_file"
  grep -qi "## Objective" "$sow_file"
  grep -qi "## Scope" "$sow_file"
  grep -qi "## Deliverables" "$sow_file"
}

@test "SE-017: sow-create.sh creates sow.md with all 3 templates" {
  for tmpl in basic agile fixed-price; do
    local proj="proj-${tmpl}-$$"
    run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${SOW_CREATE}' \
      --project '${proj}' --tenant acme --template '${tmpl}'"
    [ "$status" -eq 0 ]
    [[ -f "${TEST_TMPDIR}/tenants/acme/projects/${proj}/sow.md" ]]
  done
}

@test "SE-017: sow-create.sh rejects invalid template" {
  run bash "$SOW_CREATE" --project p --tenant t --template "waterfall"
  [ "$status" -eq 2 ]
  [[ "$output" == *"basic|agile|fixed-price"* ]]
}

@test "SE-017: sow-create.sh fails on duplicate sow" {
  bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${SOW_CREATE}' \
    --project dup-proj --tenant acme" >/dev/null 2>&1
  run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${SOW_CREATE}' \
    --project dup-proj --tenant acme"
  [ "$status" -eq 1 ]
  [[ "$output" == *"already exists"* ]]
}

# ── sow-validate.sh ──────────────────────────────────────────────────────────

@test "SE-017: sow-validate.sh exists and is executable" {
  [[ -f "$SOW_VALIDATE" ]]
  [[ -x "$SOW_VALIDATE" ]]
}

@test "SE-017: sow-validate.sh validates a complete SOW as complete" {
  bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${SOW_CREATE}' \
    --project complete-proj --tenant acme --template basic" >/dev/null

  run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${SOW_VALIDATE}' \
    --project complete-proj --tenant acme"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"complete\":true"* ]]
  [[ "$output" == *"\"missing_sections\":[]"* ]]
}

@test "SE-017: sow-validate.sh detects missing sections" {
  local partial_sow="${TEST_TMPDIR}/partial-sow.md"
  cat > "$partial_sow" <<'EOF'
---
sow_id: test
---

## Objective

Some objective.

## Scope

Some scope.
EOF

  run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${SOW_VALIDATE}' --file '${partial_sow}'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"\"complete\":false"* ]]
  [[ "$output" == *"missing_sections"* ]]
  [[ "$output" == *"deliverables"* ]]
}

@test "SE-017: sow-validate.sh exits 3 for nonexistent file" {
  run bash "$SOW_VALIDATE" --file "/nonexistent/path/sow.md"
  [ "$status" -eq 3 ]
}

@test "SE-017: sow-validate.sh reports word_count" {
  bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${SOW_CREATE}' \
    --project wc-proj --tenant acme" >/dev/null

  run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${SOW_VALIDATE}' \
    --project wc-proj --tenant acme"
  # word_count should be present and > 0
  [[ "$output" == *"\"word_count\":"* ]]
  wc=$(echo "$output" | grep -o '"word_count":[0-9]*' | cut -d: -f2)
  [[ "$wc" -gt 0 ]]
}
