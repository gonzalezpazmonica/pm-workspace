#!/usr/bin/env bats
# BATS tests for SE-032 Cross-Project Lessons Pipeline
# SPEC: docs/propuestas/savia-enterprise/SPEC-SE-032-cross-project-lessons.md
# SCRIPT: scripts/lesson-pipeline.sh
# Quality gate: SPEC-055 (audit score >=80)
# Safety: tests use BATS run/status guards; target script has set -uo pipefail
# Status: active
# Date: 2026-04-13
# Era: 231
# Problem: lessons learned in project A don't reach project B automatically
# Solution: 3-phase pipeline — extract, catalogue, search across projects
# Acceptance: extract creates valid frontmatter, search finds by domain, PII sanitized
# Dependencies: lesson-pipeline.sh

## Problem: no cross-pollination of lessons between projects
## Solution: extract→catalogue→search pipeline with PII sanitization
## Acceptance: extract writes frontmatter, search finds by domain/keyword, PII removed

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/lesson-pipeline.sh"
  export SPEC="$REPO_ROOT/docs/propuestas/savia-enterprise/SPEC-SE-032-cross-project-lessons.md"
  TMPDIR_LP=$(mktemp -d)
  export LESSONS_DIR="$TMPDIR_LP/lessons"
}
teardown() {
  rm -rf "$TMPDIR_LP"
}

## Structural tests

@test "lesson-pipeline.sh exists and is executable" {
  [[ -x "$SCRIPT" ]]
}
@test "uses set -uo pipefail" {
  head -3 "$SCRIPT" | grep -q "set -uo pipefail"
}
@test "spec file exists" {
  [[ -f "$SPEC" ]]
}

## Status and stats modes

@test "status runs without error" {
  run bash "$SCRIPT" status
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Lesson Pipeline Status"* ]]
}
@test "stats runs without error on empty dir" {
  run bash "$SCRIPT" stats
  [[ "$status" -eq 0 ]]
}

## Extract — cmd_extract positive cases

@test "extract creates lesson file with valid frontmatter" {
  run bash "$SCRIPT" extract --domain "testing" --problem "Flaky tests in CI" --solution "Add retry with deterministic seeds"
  [[ "$status" -eq 0 ]]
  local lesson_file
  lesson_file=$(echo "$output" | tail -1)
  [[ -f "$lesson_file" ]]
  grep -q "^domain: testing" "$lesson_file"
  grep -q "^confidence:" "$lesson_file"
  grep -q "## Problem" "$lesson_file"
  grep -q "## Solution" "$lesson_file"
}
@test "extract updates index.jsonl" {
  run bash "$SCRIPT" extract --domain "architecture" --problem "Coupling between modules" --solution "Introduce interface layer"
  [[ "$status" -eq 0 ]]
  [[ -f "$LESSONS_DIR/index.jsonl" ]]
  grep -q "architecture" "$LESSONS_DIR/index.jsonl"
}
@test "extract with projects and agents populates frontmatter" {
  run bash "$SCRIPT" extract --domain "security" --problem "SQL injection" --solution "Use parameterized queries" --projects "alpha,beta" --agents "dotnet-developer"
  [[ "$status" -eq 0 ]]
  local lesson_file
  lesson_file=$(echo "$output" | tail -1)
  grep -q "alpha" "$lesson_file"
  grep -q "dotnet-developer" "$lesson_file"
}

## Extract — negative and error cases

@test "extract fails without required arguments" {
  run bash "$SCRIPT" extract --domain "testing"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Usage"* ]]
}
@test "extract fails with missing problem" {
  run bash "$SCRIPT" extract --domain "testing" --solution "fix"
  [[ "$status" -eq 1 ]]
}

## Search — cmd_search

@test "search finds lesson by domain" {
  bash "$SCRIPT" extract --domain "performance" --problem "N+1 query" --solution "Eager loading" >/dev/null
  run bash "$SCRIPT" search --domain "performance"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"N+1 query"* ]]
}
@test "search finds lesson by keyword query" {
  bash "$SCRIPT" extract --domain "deployment" --problem "Container OOM kills" --solution "Set memory limits" >/dev/null
  run bash "$SCRIPT" search --query "OOM"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Container OOM"* ]]
}
@test "search with no matches returns zero results" {
  # Create dir with a lesson that won't match the query
  bash "$SCRIPT" extract --domain "unrelated" --problem "Something else" --solution "Fix it" >/dev/null
  run bash "$SCRIPT" search --query "nonexistent-keyword-xyz"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Found: 0"* ]]
}

## Edge cases — empty, nonexistent, boundary, zero, invalid

@test "search on empty lessons dir returns gracefully" {
  run bash "$SCRIPT" search --query "anything"
  [[ "$status" -eq 0 ]]
}
@test "extract sanitizes email PII from problem text" {
  run bash "$SCRIPT" extract --domain "security" --problem "Leaked user@company.com in logs" --solution "Mask PII"
  local lesson_file
  lesson_file=$(echo "$output" | tail -1)
  ! grep -q "user@company.com" "$lesson_file"
  grep -q "\[email\]" "$lesson_file"
}
@test "extract sanitizes IP addresses from solution text" {
  run bash "$SCRIPT" extract --domain "networking" --problem "Connection failed" --solution "Changed server from 192.168.1.100 to load balancer"
  local lesson_file
  lesson_file=$(echo "$output" | tail -1)
  ! grep -q "192.168.1.100" "$lesson_file"
  grep -q "\[ip\]" "$lesson_file"
}
@test "invalid subcommand exits with error" {
  run bash "$SCRIPT" nonexistent-mode
  [[ "$status" -eq 1 ]]
}

## Coverage: cmd_extract, cmd_search, cmd_stats, cmd_status, sanitize_pii
