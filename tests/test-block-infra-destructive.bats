#!/usr/bin/env bats
# BATS tests for block-infra-destructive.sh
# SCRIPT=.opencode/hooks/block-infra-destructive.sh
# SPEC: SPEC-081 — Hook test coverage

SCRIPT=".opencode/hooks/block-infra-destructive.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export SAVIA_HOOK_PROFILE="standard"
  export CLAUDE_PROJECT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

teardown() {
  unset SAVIA_HOOK_PROFILE CLAUDE_PROJECT_DIR
}

@test "script exists and is executable" {
  cd "$BATS_TEST_DIRNAME/.."
  [[ -x "$SCRIPT" ]]
}

@test "script has set -uo pipefail" {
  cd "$BATS_TEST_DIRNAME/.."
  head -3 "$SCRIPT" | grep -q "set -uo pipefail"
}

@test "allow: safe terraform plan command" {
  cd "$BATS_TEST_DIRNAME/.."
  echo '{"tool_input":{"command":"terraform plan -out=plan.tfplan"}}' | bash "$SCRIPT"
}

@test "allow: terraform init command" {
  cd "$BATS_TEST_DIRNAME/.."
  echo '{"tool_input":{"command":"terraform init"}}' | bash "$SCRIPT"
}

@test "allow: terraform apply in dev without -auto-approve flag" {
  cd "$BATS_TEST_DIRNAME/.."
  echo '{"tool_input":{"command":"terraform apply dev/plan.tfplan"}}' | bash "$SCRIPT"
}

@test "allow: kubectl get pods" {
  cd "$BATS_TEST_DIRNAME/.."
  echo '{"tool_input":{"command":"kubectl get pods -n default"}}' | bash "$SCRIPT"
}

@test "allow: az group list" {
  cd "$BATS_TEST_DIRNAME/.."
  echo '{"tool_input":{"command":"az group list"}}' | bash "$SCRIPT"
}

@test "block: terraform destroy" {
  cd "$BATS_TEST_DIRNAME/.."
  run bash -c 'echo "{\"tool_input\":{\"command\":\"terraform destroy -auto-approve\"}}" | bash '"$SCRIPT"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"BLOQUEADO"* ]]
}

@test "block: terraform apply in production" {
  cd "$BATS_TEST_DIRNAME/.."
  run bash -c 'echo "{\"tool_input\":{\"command\":\"terraform apply -auto-approve -target=production\"}}" | bash '"$SCRIPT"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"BLOQUEADO"* ]]
}

@test "block: terraform apply in pre" {
  cd "$BATS_TEST_DIRNAME/.."
  run bash -c 'echo "{\"tool_input\":{\"command\":\"terraform apply pre/main.tf\"}}" | bash '"$SCRIPT"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"BLOQUEADO"* ]]
}

@test "block: terraform apply in staging" {
  cd "$BATS_TEST_DIRNAME/.."
  run bash -c 'echo "{\"tool_input\":{\"command\":\"terraform apply -var-file=staging.tfvars\"}}" | bash '"$SCRIPT"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"BLOQUEADO"* ]]
}

@test "block: az group delete" {
  cd "$BATS_TEST_DIRNAME/.."
  run bash -c 'echo "{\"tool_input\":{\"command\":\"az group delete --name rg-myapp-prod --yes\"}}" | bash '"$SCRIPT"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"BLOQUEADO"* ]]
}

@test "block: aws cloudformation delete-stack" {
  cd "$BATS_TEST_DIRNAME/.."
  run bash -c 'echo "{\"tool_input\":{\"command\":\"aws cloudformation delete-stack --stack-name myapp\"}}" | bash '"$SCRIPT"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"BLOQUEADO"* ]]
}

@test "block: kubectl delete namespace" {
  cd "$BATS_TEST_DIRNAME/.."
  run bash -c 'echo "{\"tool_input\":{\"command\":\"kubectl delete namespace production\"}}" | bash '"$SCRIPT"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"BLOQUEADO"* ]]
}

@test "edge: empty input exits 0" {
  cd "$BATS_TEST_DIRNAME/.."
  echo '{}' | bash "$SCRIPT"
}

@test "edge: missing command field exits 0" {
  cd "$BATS_TEST_DIRNAME/.."
  echo '{"tool_input":{}}' | bash "$SCRIPT"
}

@test "edge: malformed JSON handled gracefully" {
  cd "$BATS_TEST_DIRNAME/.."
  echo 'not valid json' | bash "$SCRIPT"
}

@test "coverage: uses jq for JSON parsing" {
  cd "$BATS_TEST_DIRNAME/.."
  grep -q "jq" "$SCRIPT"
}

@test "coverage: checks for terraform destroy" {
  cd "$BATS_TEST_DIRNAME/.."
  grep -q "terraform.*destroy" "$SCRIPT"
}

@test "coverage: security tier in profile gate" {
  cd "$BATS_TEST_DIRNAME/.."
  grep -q 'profile_gate "security"' "$SCRIPT"
}
