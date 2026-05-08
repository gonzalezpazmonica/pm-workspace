#!/usr/bin/env bats
# Tests for block-infra-destructive.sh hook
# Ref: docs/rules/domain/infrastructure-as-code.md

setup() {
  TMPDIR=$(mktemp -d)
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOOK="$REPO_ROOT/.opencode/hooks/block-infra-destructive.sh"
}

teardown() {
  rm -rf "$TMPDIR"
}

run_hook() {
  run bash -c "echo '$1' | bash '$HOOK'"
}

make_input() {
  echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$1\"}}"
}

@test "target has safety flags" {
  grep -q "set -[euo]" "$HOOK"
}

@test "empty command passes" {
  run_hook '{"tool_name":"Bash","tool_input":{"command":""}}'
  [ "$status" -eq 0 ]
}

@test "terraform plan passes" {
  run_hook "$(make_input 'terraform plan -out=plan.tfplan')"
  [ "$status" -eq 0 ]
}

@test "kubectl get pods passes" {
  run_hook "$(make_input 'kubectl get pods -n myapp')"
  [ "$status" -eq 0 ]
}

@test "BLOCKS terraform destroy" {
  run_hook "$(make_input 'terraform destroy')"
  [ "$status" -eq 2 ]
}

@test "BLOCKS terraform apply in production" {
  run_hook "$(make_input 'terraform apply -var env=production')"
  [ "$status" -eq 2 ]
}

@test "BLOCKS terraform apply in staging" {
  run_hook "$(make_input 'terraform apply -var env=staging')"
  [ "$status" -eq 2 ]
}

@test "BLOCKS az group delete" {
  run_hook "$(make_input 'az group delete --name myResourceGroup --yes')"
  [ "$status" -eq 2 ]
}

@test "BLOCKS aws cloudformation delete-stack" {
  run_hook "$(make_input 'aws cloudformation delete-stack --stack-name mystack')"
  [ "$status" -eq 2 ]
}

@test "BLOCKS kubectl delete namespace" {
  run_hook "$(make_input 'kubectl delete namespace production')"
  [ "$status" -eq 2 ]
}

@test "safe kubectl delete pod passes" {
  run_hook "$(make_input 'kubectl delete pod mypod-abc123 -n dev')"
  [ "$status" -eq 0 ]
}

@test "terraform apply in dev passes" {
  run_hook "$(make_input 'terraform apply plan.tfplan')"
  [ "$status" -eq 0 ]
}

# ── Edge cases ──

@test "docker system prune passes (not infra-destructive)" {
  run_hook "$(make_input 'docker system prune -f')"
  [ "$status" -eq 0 ]
  [[ ! "$output" == *"BLOCK"* ]]
}

@test "empty JSON object does not crash" {
  run_hook '{}'
  [ "$status" -eq 0 ]
  python3 -c "assert True"
}

@test "target script has safety flags" {
  grep -q "set -[euo]" "$BATS_TEST_DIRNAME/../../.opencode/hooks/block-infra-destructive.sh"
}

@test "edge: empty input produces no error" {
  run bash -c "echo '{}' | SAVIA_HOOK_PROFILE=minimal bash '$BATS_TEST_DIRNAME/../../.opencode/hooks/validate-bash-global.sh' 2>&1"
  [ "$status" -eq 0 ]
}
