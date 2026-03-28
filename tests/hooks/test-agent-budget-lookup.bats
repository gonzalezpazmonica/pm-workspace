#!/usr/bin/env bats

setup() {
  export SCRIPT="scripts/agent-budget-lookup.sh"
}

@test "known agent returns correct budget (Heavy)" {
  result=$(bash "$SCRIPT" architect)
  [[ "$result" == "13000" ]]
}

@test "known agent returns correct budget (Standard)" {
  result=$(bash "$SCRIPT" dotnet-developer)
  [[ "$result" == "8500" ]]
}

@test "known agent returns correct budget (Light)" {
  result=$(bash "$SCRIPT" tech-writer)
  [[ "$result" == "4500" ]]
}

@test "known agent returns correct budget (Minimal)" {
  result=$(bash "$SCRIPT" azure-devops-operator)
  [[ "$result" == "2200" ]]
}

@test "unknown agent returns 0" {
  result=$(bash "$SCRIPT" nonexistent-agent)
  [[ "$result" == "0" ]]
}

@test "no argument returns 0" {
  result=$(bash "$SCRIPT")
  [[ "$result" == "0" ]]
}

@test "exit code is always 0" {
  bash "$SCRIPT" nonexistent-agent
  [[ $? -eq 0 ]]
  bash "$SCRIPT"
  [[ $? -eq 0 ]]
}
