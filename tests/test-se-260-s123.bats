#!/usr/bin/env bats
# tests/test-se-260-s123.bats — Combined tests for SE-260 S1+S2+S3

# ── S1: Court rules ──

@test "S1-T01: court.rules.yaml exists and is valid YAML" {
  [[ -f "rules/court.rules.yaml" ]]
  python3 -c "import yaml; yaml.safe_load(open('rules/court.rules.yaml'))"
}

@test "S1-T02: court rules has required keys" {
  python3 -c "
import yaml
d = yaml.safe_load(open('rules/court.rules.yaml'))
assert d['version'] == 1
assert 'budget' in d
assert 'freeze' in d
assert 'verification' in d
assert 'paths' in d
assert d['verification']['mode'] == 'directed'
"
}

@test "S1-T03: court rules budget values are positive" {
  python3 -c "
import yaml
d = yaml.safe_load(open('rules/court.rules.yaml'))
assert d['budget']['max_fix_turns'] > 0
assert d['budget']['max_fix_tokens'] > 0
assert d['budget']['timeout_per_judge_seconds'] > 0
"
}

@test "S1-T04: scoring thresholds are within range" {
  python3 -c "
import yaml
d = yaml.safe_load(open('rules/court.rules.yaml'))
assert 0 <= d['scoring']['pass_threshold'] <= 100
assert 0 <= d['scoring']['conditional_threshold'] <= d['scoring']['pass_threshold']
"
}

# ── S2: Native delegation ──

@test "S2-T01: native-delegation.yaml exists" {
  [[ -f "config/native-delegation.yaml" ]]
}

@test "S2-T02: native-delegation has only explore allowed" {
  python3 -c "
import yaml
d = yaml.safe_load(open('config/native-delegation.yaml'))
assert d['version'] == 1
assert d['native_agents']['explore']['allow'] == True
assert d['native_agents']['general']['allow'] == False
assert d['default'] == 'deny'
"
}

@test "S2-T03: general is denied for safety" {
  python3 -c "
import yaml
d = yaml.safe_load(open('config/native-delegation.yaml'))
assert d['native_agents']['general']['allow'] == False
assert 'write' in d['native_agents']['general']['reason'].lower() or 'write access' in d['native_agents']['general']['reason']
"
}

# ── S3: Managed artifacts ──

@test "S3-T01: contract document exists" {
  [[ -f "docs/managed-artifacts-contract.md" ]]
}

@test "S3-T02: inventory document exists" {
  [[ -f "docs/managed-artifacts-inventory.md" ]]
}

@test "S3-T03: inventory has at least 1 adapted artifact" {
  grep -q "adapted" docs/managed-artifacts-inventory.md
}

@test "S3-T04: managed_artifacts.py exists and is executable" {
  [[ -f "scripts/lib/managed_artifacts.py" ]]
  [[ -x "scripts/lib/managed_artifacts.py" ]]
}

@test "S3-T05: managed_artifacts.py init validates git repo" {
  run python3 scripts/lib/managed_artifacts.py init --root .
  [[ "$status" -eq 0 ]]
}

@test "S3-T06: managed_artifacts.py probe detects missing artifact" {
  run python3 scripts/lib/managed_artifacts.py probe \
    --root /tmp --artifact-id test --target /tmp/nonexistent --template /dev/null
  [[ "$status" -eq 2 ]]
}

@test "S3-T07: managed_artifacts.py contract has all 6 operations" {
  local src="scripts/lib/managed_artifacts.py"
  grep -q "def init_artifact" "$src"
  grep -q "def install_artifact" "$src"
  grep -q "def sync_artifact" "$src"
  grep -q "def uninstall_artifact" "$src"
  grep -q "def probe_artifact" "$src"
  grep -q "def backup_artifact" "$src"
}

@test "S3-T08: contract document mentions all 6 operations" {
  local doc="docs/managed-artifacts-contract.md"
  grep -qi "init" "$doc"
  grep -qi "install" "$doc"
  grep -qi "sync" "$doc"
  grep -qi "uninstall" "$doc"
  grep -qi "probe" "$doc"
  grep -qi "backup" "$doc"
}
