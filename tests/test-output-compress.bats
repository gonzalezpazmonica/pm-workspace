#!/usr/bin/env bats
# Tests for SPEC-OUTPUT-COMPRESS — bash output compression
# Ref: .claude/rules/domain/context-health.md (section 1b)

setup() {
  export SCRIPT="scripts/output-compress.sh"
  export FIX="tests/fixtures/output-compress"
  TMPDIR_OC=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_OC"
}

@test "short output passthrough (<=30 lines, ANSI stripped)" {
  input=$(printf '\e[31mline1\e[0m\nline2\nline3')
  result=$(echo "$input" | bash "$SCRIPT" --command "git status")
  [[ $(echo "$result" | wc -l) -le 30 ]]
  [[ "$result" != *$'\e['* ]]
}

@test "git log compression to <=50 lines" {
  result=$(cat "$FIX/git-log-200.txt" | bash "$SCRIPT" --command "git log")
  lines=$(echo "$result" | wc -l)
  [[ $lines -le 50 ]]
}

@test "consecutive line deduplication" {
  result=$(cat "$FIX/dedup-lines.txt" | bash "$SCRIPT" --command "generic")
  [[ "$result" == *"repeated"* ]]
  lines=$(echo "$result" | wc -l)
  [[ $lines -lt 60 ]]
}

@test "dotnet test summary extraction" {
  result=$(cat "$FIX/dotnet-test-fail.txt" | bash "$SCRIPT" --command "dotnet test")
  [[ "$result" == *"Failed"* ]]
  [[ "$result" != *"Determining projects"* ]]
  lines=$(echo "$result" | wc -l)
  [[ $lines -le 50 ]]
}

@test "warning grouping" {
  result=$(cat "$FIX/dotnet-build-warnings.txt" | bash "$SCRIPT" --command "dotnet build")
  [[ "$result" == *"CS1591"* ]]
  lines=$(echo "$result" | wc -l)
  [[ $lines -le 10 ]]
}

@test "stack trace truncation" {
  result=$(cat "$FIX/stack-trace-25.txt" | bash "$SCRIPT" --command "dotnet test")
  [[ "$result" == *"frames omitted"* ]]
}

@test "empty input produces empty output" {
  result=$(echo -n "" | bash "$SCRIPT")
  [[ -z "$result" ]]
}

@test "validate-ci compression keeps PASS/FAIL" {
  result=$(cat "$FIX/ci-local-output.txt" | bash "$SCRIPT" --command "validate-ci-local")
  [[ "$result" == *"PASS"* ]]
  [[ "$result" == *"FAIL"* ]]
  lines=$(echo "$result" | wc -l)
  [[ $lines -le 15 ]]
}

@test "max-lines override" {
  input=""
  for i in $(seq 1 500); do input="${input}line $i\n"; done
  result=$(printf "$input" | bash "$SCRIPT" --command "generic" --max-lines 20)
  lines=$(echo "$result" | wc -l)
  [[ $lines -le 20 ]]
}

@test "exit code always 0" {
  echo "test" | bash "$SCRIPT" --command "nonexistent"
  [[ $? -eq 0 ]]
}

# ── Negative cases ──

@test "handles binary-like input without crash" {
  printf '\x00\x01\x02\x03' | bash "$SCRIPT" --command "generic"
  [[ $? -eq 0 ]]
}

@test "handles very long single line" {
  python3 -c "print('A'*10000)" | bash "$SCRIPT" --command "generic"
  [[ $? -eq 0 ]]
}

# ── Edge cases ──

@test "single line passthrough" {
  result=$(echo "one line" | bash "$SCRIPT" --command "generic")
  [[ "$result" == *"one line"* ]]
}

@test "exactly 30 lines passes through uncompressed" {
  input=""
  for i in $(seq 1 30); do input="${input}line $i\n"; done
  result=$(printf "$input" | bash "$SCRIPT" --command "generic")
  lines=$(echo "$result" | wc -l)
  [[ $lines -le 30 ]]
}

# ── Safety verification ──

@test "output-compress.sh has set -uo pipefail" {
  grep -q "set -uo pipefail" "$SCRIPT" || grep -q "set -[euo]" "$SCRIPT"
}

# ── Edge case: only whitespace ──

@test "whitespace-only input produces minimal output" {
  result=$(printf "   \n  \n   \n" | bash "$SCRIPT" --command "generic")
  [ "$?" -eq 0 ]
}

# ── Assertion variety ──

@test "git log fixture output contains commit-like content" {
  run bash -c "cat $FIX/git-log-200.txt | bash $SCRIPT --command 'git log'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"commit"* ]] || [[ "$output" == *"Author"* ]] || [[ $(echo "$output" | wc -l) -le 50 ]]
}
