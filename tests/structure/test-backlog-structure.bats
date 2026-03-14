#!/usr/bin/env bats
# Tests for Era 107.1 — Backlog Sovereignty: Structure and CRUD

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  ROOT="$PWD"
  TEST_PROJECT="$ROOT/projects/savia-web"
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
  [ "$output" -ge 1 ]
}

@test "backlog-query JSON format is valid" {
  run bash -c "echo '' | $ROOT/scripts/backlog-query.sh --project savia-web --format json"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)"
}
