#!/usr/bin/env bats
# Tests for Era 110 — Autonomous Pipeline Engine

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  ROOT="$PWD"
}

@test "pipeline-engine.sh exists and is executable" {
  [ -x "$ROOT/scripts/pipeline-engine.sh" ]
}

@test "pipeline-stage-runner.sh exists and is executable" {
  [ -x "$ROOT/scripts/pipeline-stage-runner.sh" ]
}

@test "CI template exists" {
  [ -f "$ROOT/.claude/templates/pipeline/ci-template.yaml" ]
}

@test "pipeline-local-run command exists" {
  [ -f "$ROOT/.claude/commands/pipeline-local-run.md" ]
}

@test "pipeline engine dry-run parses template" {
  run bash -c "echo '' | $ROOT/scripts/pipeline-engine.sh $ROOT/.claude/templates/pipeline/ci-template.yaml --dry-run"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "dry-run"
  echo "$output" | grep -q "build"
}

@test "stage runner outputs valid JSON result" {
  local tmp; tmp=$(mktemp -d)
  run bash -c "echo '' | $ROOT/scripts/pipeline-stage-runner.sh --name test-stage --command 'echo ok' --output-dir $tmp"
  [ "$status" -eq 0 ]
  [ -f "$tmp/stage-test-stage.json" ]
  python3 -c "import json; json.load(open('$tmp/stage-test-stage.json'))"
  rm -rf "$tmp"
}

@test "stage runner handles failing command" {
  local tmp; tmp=$(mktemp -d)
  run bash -c "echo '' | $ROOT/scripts/pipeline-stage-runner.sh --name fail-stage --command 'exit 1' --output-dir $tmp"
  [ "$status" -ne 0 ]
  grep -q '"status": "failed"' "$tmp/stage-fail-stage.json"
  rm -rf "$tmp"
}
