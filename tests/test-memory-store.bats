#!/usr/bin/env bats
# Tests for memory-store.sh — JSONL persistent memory store

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/memory-store.sh"
  TMPDIR_MS=$(mktemp -d)
  export PROJECT_ROOT="$TMPDIR_MS"
  export SAVIA_TEST_MODE=true
  mkdir -p "$TMPDIR_MS/output"
}

teardown() {
  rm -rf "$TMPDIR_MS"
}

@test "help shows usage" {
  run bash "$SCRIPT" help
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Commands:"* ]]
}

@test "unknown command fails" {
  run bash "$SCRIPT" bogus
  [[ "$status" -eq 1 ]]
}

@test "stats on empty store succeeds" {
  run bash "$SCRIPT" stats
  [[ "$status" -eq 0 ]]
}

@test "save requires type and title" {
  run bash "$SCRIPT" save
  [[ "$status" -ne 0 ]] || [[ "$output" == *"type"* ]] || [[ "$output" == *"title"* ]]
}

@test "save creates JSONL entry" {
  run bash "$SCRIPT" save --type decision --title "Test decision" --content "Test content"
  [[ "$status" -eq 0 ]]
  [[ -f "$TMPDIR_MS/output/.memory-store.jsonl" ]]
  grep -q "Test decision" "$TMPDIR_MS/output/.memory-store.jsonl"
}

@test "search on empty store handles gracefully" {
  run bash "$SCRIPT" search "nonexistent"
  # Search may return 0 (no results) or 1 (no store file) — both acceptable
  [[ "$status" -le 1 ]]
}

@test "suggest-topic generates slug" {
  run bash "$SCRIPT" suggest-topic decision "My Test Decision"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"decision/"* ]]
}

@test "suggest-topic without args shows usage" {
  run bash "$SCRIPT" suggest-topic
  [[ "$status" -ne 0 ]] || [[ "$output" == *"Uso"* ]]
}

@test "save then search finds entry" {
  bash "$SCRIPT" save --type bug --title "Login broken" --content "Session expired"
  run bash "$SCRIPT" search "Login"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Login"* ]] || [[ "$output" == *"login"* ]]
}

@test "multiple saves accumulate in JSONL" {
  bash "$SCRIPT" save --type decision --title "Decision A" --content "A"
  bash "$SCRIPT" save --type decision --title "Decision B" --content "B"
  local count
  count=$(wc -l < "$TMPDIR_MS/output/.memory-store.jsonl")
  [[ "$count" -ge 2 ]]
}
