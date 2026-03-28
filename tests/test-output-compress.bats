#!/usr/bin/env bats

setup() {
  export SCRIPT="scripts/output-compress.sh"
  export FIX="tests/fixtures/output-compress"
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
