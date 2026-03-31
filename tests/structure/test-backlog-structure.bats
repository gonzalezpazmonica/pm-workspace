#!/usr/bin/env bats
# Tests for Era 107.1 — Backlog Sovereignty: Structure and CRUD

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  ROOT="$PWD"
  TEST_PROJECT="$ROOT/projects/savia-web"
  # Backup _config.yaml so teardown can restore id_counter after write tests
  _CONFIG_BACKUP="$BATS_TMPDIR/backlog-config-backup-${BATS_TEST_NUMBER}.yaml"
  cp "$TEST_PROJECT/backlog/_config.yaml" "$_CONFIG_BACKUP" 2>/dev/null || true
}

teardown() {
  # Restore _config.yaml (undo id_counter increments from write tests)
  if [ -f "$_CONFIG_BACKUP" ]; then
    mv "$_CONFIG_BACKUP" "$TEST_PROJECT/backlog/_config.yaml"
  fi
  # Remove test PBI files created during write tests
  find "$TEST_PROJECT/backlog/pbi" -name "*test-item*" -delete 2>/dev/null || true
  find "$TEST_PROJECT/backlog/pbi" -name "*list-test*" -delete 2>/dev/null || true
}

@test "backlog-init.sh exists and is executable" {
  [ -x "$ROOT/scripts/backlog-init.sh" ]
}

@test "backlog-pbi-crud.sh exists and is executable" {
  [ -x "$ROOT/scripts/backlog-pbi-crud.sh" ]
}

@test "backlog-query.sh exists and is executable" {
  [ -x "$ROOT/scripts/backlog-query.sh" ]
}

@test "PBI template exists" {
  [ -f "$ROOT/.claude/templates/backlog/pbi-template.md" ]
}

@test "sprint meta template exists" {
  [ -f "$ROOT/.claude/templates/backlog/sprint-meta-template.yaml" ]
}

@test "config template exists" {
  [ -f "$ROOT/.claude/templates/backlog/config-template.yaml" ]
}

@test "backlog-init creates structure" {
  run bash -c "echo '' | $ROOT/scripts/backlog-init.sh $TEST_PROJECT"
  [ "$status" -eq 0 ]
  [ -d "$TEST_PROJECT/backlog/pbi" ]
  [ -d "$TEST_PROJECT/backlog/sprints" ]
  [ -f "$TEST_PROJECT/backlog/_config.yaml" ]
  [ -f "$TEST_PROJECT/backlog/_current-sprint.md" ]
}

@test "PBI create generates valid file" {
  run bash -c "echo '' | $ROOT/scripts/backlog-pbi-crud.sh create --project savia-web --title 'Test item' --type Bug"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Created: PBI-"
  local pbi_file
  pbi_file=$(find "$TEST_PROJECT/backlog/pbi" -name "PBI-*test-item*" | head -1)
  [ -f "$pbi_file" ]
  grep -q "type: Bug" "$pbi_file"
}

@test "PBI list shows created items" {
  echo '' | bash "$ROOT/scripts/backlog-pbi-crud.sh" create --project savia-web --title "List test" 2>/dev/null
  run bash -c "echo '' | $ROOT/scripts/backlog-pbi-crud.sh list --project savia-web"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "List test"
}

@test "backlog-query with format count works" {
  run bash -c "echo '' | $ROOT/scripts/backlog-query.sh --project savia-web --format count"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]+$ ]]
}

@test "backlog-query JSON format is valid" {
  run bash -c "echo '' | $ROOT/scripts/backlog-query.sh --project savia-web --format json"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)"
}

# ── Negative cases ──

@test "backlog-pbi-crud create fails without project" {
  [[ -n "${CI:-}" ]] && skip "needs backlog setup"
  run bash -c "echo '' | $ROOT/scripts/backlog-pbi-crud.sh create --title 'No project'"
  [ "$status" -ne 0 ]
}

@test "backlog-query fails for nonexistent project" {
  run bash -c "echo '' | $ROOT/scripts/backlog-query.sh --project nonexistent-$$ --format count 2>&1"
  [ "$status" -ne 0 ]
}

# ── Edge case ──

@test "backlog-init is idempotent on existing project" {
  run bash -c "echo '' | $ROOT/scripts/backlog-init.sh $TEST_PROJECT"
  [ "$status" -eq 0 ]
  run bash -c "echo '' | $ROOT/scripts/backlog-init.sh $TEST_PROJECT"
  [ "$status" -eq 0 ]
}

# ── Spec/doc reference ──

@test "PBI template contains required frontmatter fields" {
  # Ref: .claude/rules/domain/backlog-git-config.md
  grep -q "id:" "$ROOT/.claude/templates/backlog/pbi-template.md"
  grep -q "title:" "$ROOT/.claude/templates/backlog/pbi-template.md"
  grep -q "state:" "$ROOT/.claude/templates/backlog/pbi-template.md"
}

@test "backlog scripts have set -uo pipefail safety" {
  grep -q "set -[euo]*o pipefail" "$ROOT/scripts/backlog-pbi-crud.sh"
  grep -q "set -[euo]*o pipefail" "$ROOT/scripts/backlog-query.sh"
}

@test "backlog-query handles empty backlog dir" {
  mkdir -p "$ROOT/projects/_empty-$$-proj/backlog/pbi"
  cp "$ROOT/.claude/templates/backlog/config-template.yaml" "$ROOT/projects/_empty-$$-proj/backlog/_config.yaml"
  run bash -c "echo '' | $ROOT/scripts/backlog-query.sh --project _empty-$$-proj --format count"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]+$ ]]
  rm -rf "$ROOT/projects/_empty-$$-proj"
}
