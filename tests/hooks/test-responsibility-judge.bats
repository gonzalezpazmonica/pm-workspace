#!/usr/bin/env bats
# Tests for SPEC-043 Responsibility Judge Hook
# Ref: .claude/rules/domain/hook-profiles.md

setup() {
  TMPDIR=$(mktemp -d)
  HOOK=".claude/hooks/responsibility-judge.sh"
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "target has safety flags" {
  grep -q "set -[euo]" "$HOOK"
}

@test "responsibility-judge.sh exists and is executable" {
  [ -f "$HOOK" ]
  [ -x "$HOOK" ]
}

@test "responsibility-judge.sh has set -uo pipefail" {
  head -5 "$HOOK" | grep -q "set -uo pipefail"
}

@test "responsibility-judge.sh uses profile-gate standard" {
  grep -q 'profile_gate "standard"' "$HOOK"
}

@test "NO override mechanism exists" {
  ! grep -qi "OVERRIDE" "$HOOK"
}

@test "S-01: blocks threshold lowering in test files" {
  INPUT='{"tool_input":{"file_path":"tests/eval/test-accuracy.bats","new_string":"MIN_ACCURACY = 0.60"}}'
  run bash -c "echo '$INPUT' | SAVIA_HOOK_PROFILE=standard bash $HOOK"
  [ "$status" -eq 2 ]
  [[ "$output" == *"S-01"* ]]
}

@test "S-02: blocks test skip annotation" {
  INPUT='{"tool_input":{"file_path":"src/Service.cs","new_string":"[Skip] public void TestAuth()"}}'
  run bash -c "echo '$INPUT' | SAVIA_HOOK_PROFILE=standard bash $HOOK"
  [ "$status" -eq 2 ]
  [[ "$output" == *"S-02"* ]]
}

@test "S-03: blocks empty catch handler" {
  INPUT='{"tool_input":{"file_path":"src/Handler.py","new_string":"except: pass"}}'
  run bash -c "echo '$INPUT' | SAVIA_HOOK_PROFILE=standard bash $HOOK"
  [ "$status" -eq 2 ]
  [[ "$output" == *"S-03"* ]]
}

@test "S-04: blocks quality gate bypass" {
  INPUT='{"tool_input":{"file_path":"scripts/deploy.sh","new_string":"git commit --no-verify"}}'
  run bash -c "echo '$INPUT' | SAVIA_HOOK_PROFILE=standard bash $HOOK"
  [ "$status" -eq 2 ]
  [[ "$output" == *"S-04"* ]]
}

@test "S-06: blocks TODO without ticket" {
  INPUT='{"tool_input":{"file_path":"src/app.ts","new_string":"// TODO: fix later"}}'
  run bash -c "echo '$INPUT' | SAVIA_HOOK_PROFILE=standard bash $HOOK"
  [ "$status" -eq 2 ]
  [[ "$output" == *"S-06"* ]]
}

@test "S-06: allows TODO with ticket reference" {
  INPUT='{"tool_input":{"file_path":"src/app.ts","new_string":"// TODO(AB#1234) fix auth"}}'
  run bash -c "echo '$INPUT' | SAVIA_HOOK_PROFILE=standard bash $HOOK"
  [ "$status" -eq 0 ]
}

@test "passes clean code with no shortcuts" {
  INPUT='{"tool_input":{"file_path":"src/service.py","new_string":"def calculate(x): return x * 2"}}'
  run bash -c "echo '$INPUT' | SAVIA_HOOK_PROFILE=standard bash $HOOK"
  [ "$status" -eq 0 ]
}

@test "self-test exclusion for judge test file" {
  INPUT='{"tool_input":{"file_path":"tests/hooks/test-responsibility-judge.bats","new_string":"MIN_ACCURACY = 0.60"}}'
  run bash -c "echo '$INPUT' | SAVIA_HOOK_PROFILE=standard bash $HOOK"
  [ "$status" -eq 0 ]
}

@test "disabled via env var" {
  INPUT='{"tool_input":{"file_path":"tests/test.bats","new_string":"MIN_ACCURACY = 0.60"}}'
  run bash -c "echo '$INPUT' | RESPONSIBILITY_JUDGE_ENABLED=false SAVIA_HOOK_PROFILE=standard bash $HOOK"
  [ "$status" -eq 0 ]
}

@test "skipped in minimal profile" {
  INPUT='{"tool_input":{"file_path":"tests/test.bats","new_string":"MIN_ACCURACY = 0.60"}}'
  run bash -c "echo '$INPUT' | SAVIA_HOOK_PROFILE=minimal bash $HOOK"
  [ "$status" -eq 0 ]
}

@test "registered in settings.json" {
  grep -q "responsibility-judge.sh" .claude/settings.json
}

@test "SPEC-043 document exists" {
  [ -f "docs/propuestas/SPEC-043-responsibility-judge.md" ]
}
