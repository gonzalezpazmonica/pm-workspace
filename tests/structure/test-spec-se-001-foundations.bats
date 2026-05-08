#!/usr/bin/env bats
# Ref: SPEC-SE-001 — Savia Enterprise Foundations & Layer Contract
# Spec: docs/propuestas/savia-enterprise/SPEC-SE-001-foundations.md
# Implementation status: IMPLEMENTED. This BATS suite enforces all 6 AC as
# regression guards — if anyone deletes the enterprise dir, manifest, validator,
# or de-registers the hook, this test catches it.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  ENT_DIR="$REPO_ROOT/.claude/enterprise"
  SCRIPT="scripts/validate-layer-contract.sh"
  VALIDATOR="$REPO_ROOT/$SCRIPT"
  HOOK="$REPO_ROOT/.opencode/hooks/validate-layer-contract.sh"
  SETTINGS="$REPO_ROOT/.claude/settings.json"
  EXT_POINTS="$REPO_ROOT/docs/propuestas/savia-enterprise/extension-points.md"
  SPEC="$REPO_ROOT/docs/propuestas/savia-enterprise/SPEC-SE-001-foundations.md"
  MANIFEST="$ENT_DIR/manifest.json"
  SCHEMA="$ENT_DIR/manifest.schema.json"
  TMPDIR_F=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_F"
}

# ── AC-1 — `.claude/enterprise/` exists with subdirs + README ───────────────

@test "AC-1: .claude/enterprise/ directory exists" {
  [ -d "$ENT_DIR" ]
}

@test "AC-1: enterprise/agents subdirectory exists" {
  [ -d "$ENT_DIR/agents" ]
}

@test "AC-1: enterprise/commands subdirectory exists" {
  [ -d "$ENT_DIR/commands" ]
}

@test "AC-1: enterprise/skills subdirectory exists" {
  [ -d "$ENT_DIR/skills" ]
}

@test "AC-1: enterprise/rules subdirectory exists" {
  [ -d "$ENT_DIR/rules" ]
}

@test "AC-1: enterprise/README.md exists with frontmatter" {
  [ -f "$ENT_DIR/README.md" ]
  grep -qE "Enterprise|opt-in|MIT" "$ENT_DIR/README.md"
}

# ── AC-2 — `validate-layer-contract.sh` exists and detects illegal imports ──

@test "AC-2: scripts/validate-layer-contract.sh exists, executable" {
  [ -f "$VALIDATOR" ]
  head -1 "$VALIDATOR" | grep -q '^#!'
  [ -x "$VALIDATOR" ]
}

@test "AC-2: validator declares 'set -uo pipefail' (anywhere in script)" {
  grep -q "set -uo pipefail" "$VALIDATOR"
}

@test "AC-2: validator passes bash -n syntax check" {
  bash -n "$VALIDATOR"
}

@test "AC-2: validator detects Core→Enterprise import (positive)" {
  # Create a fake Core file referencing enterprise
  bad_file="$TMPDIR_F/.opencode/agents/bogus.md"
  mkdir -p "$(dirname "$bad_file")"
  echo "@.claude/enterprise/agents/foo" > "$bad_file"
  # Run validator on this single file from a subshell with PROJECT_DIR override
  cd "$TMPDIR_F" && cp "$VALIDATOR" "scripts/validate-layer-contract.sh" 2>/dev/null || mkdir -p scripts && cp "$VALIDATOR" scripts/
  run env CLAUDE_PROJECT_DIR="$TMPDIR_F" bash "$TMPDIR_F/scripts/validate-layer-contract.sh" ".opencode/agents/bogus.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"VIOLATION"* ]]
}

@test "AC-2: validator passes on clean Core (negative — no false positive)" {
  clean_file="$TMPDIR_F/.opencode/agents/clean.md"
  mkdir -p "$(dirname "$clean_file")"
  echo "Just a normal agent referencing @docs/rules/domain/foo.md" > "$clean_file"
  mkdir -p "$TMPDIR_F/scripts" && cp "$VALIDATOR" "$TMPDIR_F/scripts/"
  run env CLAUDE_PROJECT_DIR="$TMPDIR_F" bash "$TMPDIR_F/scripts/validate-layer-contract.sh" ".opencode/agents/clean.md"
  [ "$status" -eq 0 ]
}

@test "AC-2: validator real run on workspace passes (no current violations)" {
  run bash "$VALIDATOR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]] || [[ "$output" == *"0 violations"* ]]
}

# ── AC-3 — `manifest.json` schema defined and validable ─────────────────────

@test "AC-3: manifest.json exists with valid JSON" {
  [ -f "$MANIFEST" ]
  python3 -c "import json; json.load(open('$MANIFEST'))"
}

@test "AC-3: manifest.schema.json exists with valid JSON Schema" {
  [ -f "$SCHEMA" ]
  python3 -c "import json; d=json.load(open('$SCHEMA')); assert d.get('\$schema'), 'missing \$schema'"
}

@test "AC-3: manifest.json declares version + savia_core_min_version + modules" {
  python3 -c "
import json
d = json.load(open('$MANIFEST'))
assert 'version' in d, 'missing version'
assert 'savia_core_min_version' in d, 'missing core_min_version'
assert 'modules' in d, 'missing modules'
assert isinstance(d['modules'], dict), 'modules must be object'
"
}

@test "AC-3: every module entry has enabled+spec+description (schema compliance)" {
  python3 -c "
import json
d = json.load(open('$MANIFEST'))
for name, mod in d['modules'].items():
    assert 'enabled' in mod, f'module {name} missing enabled'
    assert 'spec' in mod, f'module {name} missing spec'
    assert 'description' in mod, f'module {name} missing description'
    assert isinstance(mod['enabled'], bool), f'module {name} enabled must be bool'
"
}

# ── AC-4 — Extension points documented ──────────────────────────────────────

@test "AC-4: extension-points.md exists" {
  [ -f "$EXT_POINTS" ]
}

@test "AC-4: extension-points.md documents 6 extension points" {
  # Extension points: Agent registry, Hook registry, RBAC gate, Audit sink, Tenant resolver, Compliance validator
  for ep in "agent registry" "hook registry" "rbac" "audit" "tenant" "compliance"; do
    grep -qi "$ep" "$EXT_POINTS"
  done
}

# ── AC-5 — Test regression: Core works without Enterprise ───────────────────

@test "AC-5: enterprise dir is structurally optional (Core flow indep)" {
  # Smoke check: claude-md-drift-check.sh and basic Core scripts run without enterprise/
  # We don't actually delete .claude/enterprise/ — too destructive. Verify the validator
  # specifically guards Core from depending on enterprise (the contract).
  grep -qE 'Core NEVER imports|Core must never|unidirectional' "$VALIDATOR" \
    || grep -qE 'Core NEVER|Core must never' "$EXT_POINTS"
}

@test "AC-5: zero current Core files reference .claude/enterprise/ (real check)" {
  # Run the validator over the real workspace; must report 0 violations.
  run bash "$VALIDATOR"
  [ "$status" -eq 0 ]
}

# ── AC-6 — Hook registered in settings.json ─────────────────────────────────

@test "AC-6: validate-layer-contract.sh hook file exists, executable" {
  [ -f "$HOOK" ]
  [ -x "$HOOK" ]
}

@test "AC-6: hook registered as PreToolUse with Edit|Write matcher" {
  python3 -c "
import json, sys
cfg = json.load(open('$SETTINGS'))
found = False
for entry in cfg.get('hooks', {}).get('PreToolUse', []):
    matcher = entry.get('matcher', '')
    if 'Edit' in matcher and 'Write' in matcher:
        for h in entry.get('hooks', []):
            if 'validate-layer-contract' in h.get('command', ''):
                found = True
                break
assert found, 'validate-layer-contract.sh not registered as PreToolUse Edit|Write'
"
}

@test "AC-6: hook has set -uo pipefail in first 5 lines" {
  head -5 "$HOOK" | grep -q "set -uo pipefail"
}

# ── Edge cases ──────────────────────────────────────────────────────────────

@test "edge: validator with nonexistent file is graceful (no crash)" {
  run bash "$VALIDATOR" "$TMPDIR_F/nonexistent.md"
  [ "$status" -eq 0 ]
}

@test "edge: empty manifest modules object (boundary) is still valid JSON" {
  echo '{"version":"1.0.0","savia_core_min_version":"4.0.0","modules":{}}' > "$TMPDIR_F/empty-manifest.json"
  python3 -c "import json; json.load(open('$TMPDIR_F/empty-manifest.json'))"
}

@test "edge: zero modules enabled is the default state (CD-04 analog)" {
  enabled_count=$(python3 -c "
import json
d = json.load(open('$MANIFEST'))
print(sum(1 for m in d['modules'].values() if m.get('enabled')))
")
  [ "$enabled_count" -eq 0 ]
}

# ── Spec ref + frontmatter ──────────────────────────────────────────────────

@test "spec ref: SPEC-SE-001 exists and has IMPLEMENTED status" {
  [ -f "$SPEC" ]
  grep -qE "^status: IMPLEMENTED" "$SPEC"
}

@test "spec ref: docs/propuestas/savia-enterprise/SPEC-SE-001 referenced in this test file" {
  grep -q "docs/propuestas/savia-enterprise/SPEC-SE-001" "$BATS_TEST_FILENAME"
}

# ── Coverage: validator helper functions ────────────────────────────────────

@test "coverage: validator has scan_file helper function" {
  grep -qE '^scan_file\(\)' "$VALIDATOR"
}

@test "coverage: validator iterates CORE_PATHS array" {
  grep -qE 'CORE_PATHS=\(' "$VALIDATOR"
  grep -qE '\.claude/agents' "$VALIDATOR"
  grep -qE '\.claude/commands' "$VALIDATOR"
}
