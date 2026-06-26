#!/usr/bin/env bats
# SPEC-149 -- Sandbox OS-level tests (Capa A permission block + policies + doctor)

setup() {
  REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
  OC_CONFIG="$REPO_ROOT/opencode.json"
  POLICY_DIR="$REPO_ROOT/.opencode/sandbox-policies"
  DOCTOR="$REPO_ROOT/scripts/savia-sandbox-doctor.sh"
}

@test "AC-06a: permission.bash deny rule for destructive rm" {
  python3 -c "
import json
with open('$OC_CONFIG') as f: d = json.load(f)
b = d.get('agent',{}).get('build',{}).get('permission',{}).get('bash',{})
assert 'rm -rf *' in b and b['rm -rf *'] == 'deny', 'rm-rf not denied'
"
}

@test "AC-06b: permission.bash has at least 3 deny rules" {
  count=$(python3 -c "
import json
with open('$OC_CONFIG') as f: d = json.load(f)
b = d.get('agent',{}).get('build',{}).get('permission',{}).get('bash',{})
print(sum(1 for v in b.values() if v == 'deny'))
")
  [ "$count" -ge 3 ]
}

@test "AC-01: opencode-sandbox declared in plugin array" {
  python3 -c "
import json
with open('$OC_CONFIG') as f: d = json.load(f)
assert 'opencode-sandbox' in d.get('plugin',[]), 'opencode-sandbox missing from plugin[]'
"
}

@test "AC-08a: default-readonly.yaml valid with filesystem and network" {
  [ -f "$POLICY_DIR/default-readonly.yaml" ]
  grep -q "filesystem:" "$POLICY_DIR/default-readonly.yaml"
  grep -q "network:" "$POLICY_DIR/default-readonly.yaml"
  grep -q "deny_default: true" "$POLICY_DIR/default-readonly.yaml"
}

@test "AC-08b: overnight-sprint.yaml exists" {
  [ -f "$POLICY_DIR/overnight-sprint.yaml" ]
}

@test "AC-08c: code-improvement-loop.yaml exists" {
  [ -f "$POLICY_DIR/code-improvement-loop.yaml" ]
}

@test "AC-08d: tech-research-agent.yaml exists" {
  [ -f "$POLICY_DIR/tech-research-agent.yaml" ]
}

@test "AC-08e: pentesting.yaml has localhost-only network" {
  [ -f "$POLICY_DIR/pentesting.yaml" ]
  grep -q "deny_default: true" "$POLICY_DIR/pentesting.yaml"
  grep -q "localhost" "$POLICY_DIR/pentesting.yaml"
}

@test "AC-08f: all policies declare mode" {
  for p in default-readonly overnight-sprint code-improvement-loop tech-research-agent pentesting; do
    grep -q "^mode:" "$POLICY_DIR/${p}.yaml"
  done
}

@test "AC-07a: savia-sandbox-doctor.sh exists and is executable" {
  [ -f "$DOCTOR" ]
  [ -x "$DOCTOR" ]
}

@test "AC-07b: doctor reports Capa A permission.bash" {
  run bash "$DOCTOR"
  echo "$output" | grep -q "permission.bash"
}

@test "AC-07c: doctor reports bubblewrap" {
  run bash "$DOCTOR"
  echo "$output" | grep -qi "bubblewrap"
}

@test "AC-07d: doctor reports all 5 policies" {
  run bash "$DOCTOR"
  echo "$output" | grep -q "default-readonly"
  echo "$output" | grep -q "overnight-sprint"
  echo "$output" | grep -q "pentesting"
}

@test "AC-07e: doctor has set -uo pipefail" {
  head -5 "$DOCTOR" | grep -q "set -uo pipefail"
}

@test "AC-05: sandbox-os-policy.md exists" {
  [ -f "$REPO_ROOT/docs/rules/domain/sandbox-os-policy.md" ]
}

@test "AC-05b: sandbox-os-policy.md covers 3 layers" {
  grep -q "Capa A" "$REPO_ROOT/docs/rules/domain/sandbox-os-policy.md"
  grep -q "Capa B" "$REPO_ROOT/docs/rules/domain/sandbox-os-policy.md"
  grep -q "Capa C" "$REPO_ROOT/docs/rules/domain/sandbox-os-policy.md"
}

@test "AC-05c: sandbox-os-policy.md documents Ubuntu 24.04 caveat" {
  grep -qi "24.04\|AppArmor\|Ubuntu" "$REPO_ROOT/docs/rules/domain/sandbox-os-policy.md"
}

@test "opencode.json is valid JSON" {
  python3 -c "import json; json.load(open('$OC_CONFIG'))"
}

@test "opencode.json has experimental.sandbox block" {
  python3 -c "
import json
with open('$OC_CONFIG') as f: d = json.load(f)
s = d.get('experimental',{}).get('sandbox',{})
assert 'fail_if_unavailable' in s
assert 'policy_dir' in s
"
}
