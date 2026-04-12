#!/usr/bin/env bats
# BATS tests for multica tactical patterns adoption
# SPEC: output/research/multica-brief.md
# SCRIPT: scripts/path-redact.sh
# Ref: .claude/schemas/agent-result.schema.json
# Quality gate: SPEC-055 (audit score ≥80)
# Safety: tests use BATS run/status guards; target scripts have set -uo pipefail
# Status: active
# Date: 2026-04-12
# Era: 223
# Problem: PII leakage via filesystem paths, inaccurate agent cost tracking,
#   sequential overnight execution, no skill integrity verification
# Solution: path-redact.sh, agent-result schema, concurrent-executor, skills-lock
# Acceptance: 4 scripts functional, schema valid, redaction works, lock verifies
# Dependencies: path-redact.sh, skills-lock.sh, concurrent-executor.sh, agent-result.schema.json

## Problem: 4 tactical gaps identified from multica-ai/multica research
## Solution: path redaction, agent result schema, concurrent executor, skills lock
## Acceptance: all scripts pass syntax, functional tests cover happy + edge paths

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export PATH_REDACT="$REPO_ROOT/scripts/path-redact.sh"
  export SKILLS_LOCK="$REPO_ROOT/scripts/skills-lock.sh"
  export EXECUTOR="$REPO_ROOT/scripts/lib/concurrent-executor.sh"
  export SCHEMA="$REPO_ROOT/.claude/schemas/agent-result.schema.json"
}

## Path redaction tests

@test "path-redact.sh exists, executable, valid syntax" {
  [[ -x "$PATH_REDACT" ]]
  bash -n "$PATH_REDACT"
}

@test "redacts HOME path from stdin" {
  result=$(echo "$HOME/project/file.txt" | bash "$PATH_REDACT")
  [[ "$result" == "~/project/file.txt" ]]
}

@test "leaves clean text unchanged" {
  result=$(echo "no paths here" | bash "$PATH_REDACT")
  [[ "$result" == "no paths here" ]]
}

@test "check mode detects path in file" {
  local tmp; tmp=$(mktemp)
  echo "Found at $HOME/secret/file.txt" > "$tmp"
  run bash "$PATH_REDACT" --check "$tmp"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"FOUND"* ]]
  rm "$tmp"
}

@test "check mode passes for clean file" {
  local tmp; tmp=$(mktemp)
  echo "No paths here, just text" > "$tmp"
  run bash "$PATH_REDACT" --check "$tmp"
  [[ "$status" -eq 0 ]]
  rm "$tmp"
}

@test "redacts nonexistent file with error" {
  run bash "$PATH_REDACT" /nonexistent/path.txt
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"ERROR"* ]]
}

@test "empty stdin produces empty output" {
  result=$(echo "" | bash "$PATH_REDACT")
  [[ -z "$result" ]]
}

## Agent result schema tests

@test "agent-result schema exists and is valid JSON" {
  [[ -f "$SCHEMA" ]]
  python3 -c "import json; json.load(open('$SCHEMA'))"
}

@test "schema requires agent, status, timestamps, duration" {
  for field in agent status started_at finished_at duration_ms; do
    grep -q "\"$field\"" "$SCHEMA"
  done
}

@test "schema defines token tracking fields" {
  grep -q '"input"' "$SCHEMA"
  grep -q '"output"' "$SCHEMA"
  grep -q '"cache_read"' "$SCHEMA"
}

@test "schema status enum includes all 5 states" {
  for state in completed failed timeout aborted escalated; do
    grep -q "\"$state\"" "$SCHEMA"
  done
}

## Concurrent executor tests

@test "concurrent-executor.sh exists and valid syntax" {
  [[ -f "$EXECUTOR" ]]
  bash -n "$EXECUTOR"
}

@test "executor defines init, submit, drain functions" {
  source "$EXECUTOR"
  declare -f executor_init >/dev/null
  declare -f executor_submit >/dev/null
  declare -f executor_drain >/dev/null
}

## Skills lock tests

@test "skills-lock.sh exists, executable, valid syntax" {
  [[ -x "$SKILLS_LOCK" ]]
  bash -n "$SKILLS_LOCK"
}

@test "generate creates lock file with entries" {
  cd "$REPO_ROOT"
  run bash "$SKILLS_LOCK" generate
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Generated"* ]]
  [[ -f ".skills-lock.json" ]]
}

@test "verify passes after fresh generate" {
  cd "$REPO_ROOT"
  bash "$SKILLS_LOCK" generate >/dev/null 2>&1
  run bash "$SKILLS_LOCK" verify
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"0 changed"* ]]
}

@test "lock file has valid JSON with version and entries" {
  cd "$REPO_ROOT"
  bash "$SKILLS_LOCK" generate >/dev/null 2>&1
  python3 -c "
import json
d = json.load(open('.skills-lock.json'))
assert d['version'] == 1
assert d['total_entries'] > 0
assert len(d['entries']) > 0
"
}

@test "empty subcommand shows usage" {
  run bash "$SKILLS_LOCK"
  [[ "$output" == *"Usage"* ]]
}

@test "verify detects nonexistent lock file" {
  cd "$(mktemp -d)"
  run bash "$SKILLS_LOCK" verify
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"ERROR"* ]]
}
