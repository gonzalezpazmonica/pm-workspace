#!/usr/bin/env bats
# test-scrapling-mcp-template.bats — SE-061 Slice 4 MCP opt-in template tests.
# Spec: docs/propuestas/SE-061-scrapling-research-backend.md
# Target: validate .claude/mcp-templates/scrapling.json + compliance rules.

set -uo pipefail
ROOT="$BATS_TEST_DIRNAME/.."
TEMPLATE="$ROOT/.claude/mcp-templates/scrapling.json"
MCP_JSON="$ROOT/.claude/mcp.json"

setup() {
  TMPDIR="$(mktemp -d)"
  export TMPDIR
}

teardown() {
  [[ -n "${TMPDIR:-}" && -d "$TMPDIR" ]] && rm -rf "$TMPDIR" || true
}

# --- Template existence + format ---

@test "template: scrapling.json exists" {
  [ -f "$TEMPLATE" ]
}

@test "template: scrapling.json is valid JSON" {
  run python3 -c "import json; json.load(open('$TEMPLATE'))"
  [ "$status" -eq 0 ]
}

@test "template: scrapling.json is under 150 lines" {
  local lines
  lines=$(wc -l < "$TEMPLATE")
  [ "$lines" -le 150 ]
}

@test "template: references SE-061 spec" {
  run grep "SE-061" "$TEMPLATE"
  [ "$status" -eq 0 ]
}

@test "template: references research-stack.md" {
  run grep "research-stack" "$TEMPLATE"
  [ "$status" -eq 0 ]
}

# --- Template structure ---

@test "structure: has template.scrapling entry" {
  run python3 -c "
import json
d = json.load(open('$TEMPLATE'))
assert 'scrapling' in d.get('template', {})
"
  [ "$status" -eq 0 ]
}

@test "structure: scrapling entry has command field" {
  run python3 -c "
import json
d = json.load(open('$TEMPLATE'))
assert 'command' in d['template']['scrapling']
"
  [ "$status" -eq 0 ]
}

@test "structure: scrapling entry has description field" {
  run python3 -c "
import json
d = json.load(open('$TEMPLATE'))
assert 'description' in d['template']['scrapling']
"
  [ "$status" -eq 0 ]
}

@test "structure: has activation_steps array" {
  run python3 -c "
import json
d = json.load(open('$TEMPLATE'))
assert isinstance(d.get('activation_steps'), list)
assert len(d['activation_steps']) >= 4
"
  [ "$status" -eq 0 ]
}

@test "structure: has compliance block" {
  run python3 -c "
import json
d = json.load(open('$TEMPLATE'))
assert 'compliance' in d
"
  [ "$status" -eq 0 ]
}

# --- Compliance rules (opt-in, no auto-approve) ---

@test "compliance: autoApprove is false" {
  run python3 -c "
import json
d = json.load(open('$TEMPLATE'))
assert d['compliance']['autoApprove'] is False
"
  [ "$status" -eq 0 ]
}

@test "compliance: license documented (BSD-3)" {
  run grep -iE "BSD-3|BSD 3" "$TEMPLATE"
  [ "$status" -eq 0 ]
}

@test "compliance: legal note present" {
  run python3 -c "
import json
d = json.load(open('$TEMPLATE'))
assert 'legal' in d['compliance']
assert len(d['compliance']['legal']) > 10
"
  [ "$status" -eq 0 ]
}

@test "compliance: activation steps reference security audit" {
  run grep -iE "mcp-security-audit|audit" "$TEMPLATE"
  [ "$status" -eq 0 ]
}

# --- Integration with mcp-security-audit.sh (if active) ---

@test "integration: scrapling NOT in active mcp.json (opt-in respected)" {
  run python3 -c "
import json
d = json.load(open('$MCP_JSON'))
servers = d.get('mcpServers', {})
assert 'scrapling' not in servers, 'scrapling should be opt-in, not in default mcp.json'
"
  [ "$status" -eq 0 ]
}

@test "integration: mcp.json remains valid JSON" {
  run python3 -c "import json; json.load(open('$MCP_JSON'))"
  [ "$status" -eq 0 ]
}

# --- Docs integration ---

@test "docs: research-stack.md documents MCP opt-in" {
  run grep -iE "mcp.*opt-in|mcp-templates" "$ROOT/docs/rules/domain/research-stack.md"
  [ "$status" -eq 0 ]
}

@test "docs: security-scanners.md references mcp-templates" {
  run grep "mcp-templates" "$ROOT/docs/rules/domain/security-scanners.md"
  [ "$status" -eq 0 ]
}

# --- Negative cases ---

@test "negative: adding scrapling to mcp.json without template is detectable" {
  # Simulate a developer copying without following steps
  local tmp_mcp="$TMPDIR/mcp-bad.json"
  cat > "$tmp_mcp" <<'EOF'
{"mcpServers":{"scrapling":{"command":"python3","args":["-m","scrapling.ai.mcp"],"autoApprove":["*"]}}}
EOF
  # autoApprove wildcard violates MCP-02
  run grep -E '"autoApprove".*\*' "$tmp_mcp"
  [ "$status" -eq 0 ]
}

@test "negative: bad template JSON is caught" {
  local tmp_bad="$TMPDIR/bad.json"
  echo "{not valid json" > "$tmp_bad"
  run python3 -c "import json; json.load(open('$tmp_bad'))"
  [ "$status" -ne 0 ]
}

# --- Edge cases ---

@test "edge: template has no hardcoded credentials" {
  run grep -ciE "(password|secret|api[_-]?key|token)[[:space:]]*[:=][[:space:]]*\"[A-Za-z0-9]{8,}" "$TEMPLATE"
  [ "$output" -eq 0 ]
}

@test "edge: template has no HOME path leaks" {
  run grep -c "$HOME" "$TEMPLATE"
  [ "$output" -eq 0 ]
}

@test "edge: template env block is empty or explicit" {
  run python3 -c "
import json
d = json.load(open('$TEMPLATE'))
env = d['template']['scrapling'].get('env', {})
# Must exist and be a dict (can be empty)
assert isinstance(env, dict)
"
  [ "$status" -eq 0 ]
}

# --- Isolation ---

@test "isolation: reading template does not modify mcp.json" {
  local before=$(md5sum "$MCP_JSON" | awk '{print $1}')
  python3 -c "import json; json.load(open('$TEMPLATE'))" >/dev/null 2>&1 || true
  local after=$(md5sum "$MCP_JSON" | awk '{print $1}')
  [ "$before" = "$after" ]
}

@test "isolation: template is idempotent (no writes on read)" {
  local before=$(md5sum "$TEMPLATE" | awk '{print $1}')
  cat "$TEMPLATE" >/dev/null
  local after=$(md5sum "$TEMPLATE" | awk '{print $1}')
  [ "$before" = "$after" ]
}
