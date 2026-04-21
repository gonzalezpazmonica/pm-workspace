#!/usr/bin/env bats
# BATS tests for scripts/mcp-security-audit.sh (SE-058 Slice 1).
# Ref: SE-058, research/agentshield-20260420.md
SCRIPT="scripts/mcp-security-audit.sh"

setup() { export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"; cd "$BATS_TEST_DIRNAME/.."; }
teardown() { cd /; }

@test "exists + executable" { [[ -x "$SCRIPT" ]]; }
@test "uses set -uo pipefail" { run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "passes bash -n" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }
@test "references SE-058" { run grep -c 'SE-058' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "references agentshield" { run grep -ic 'agentshield' "$SCRIPT"; [[ "$output" -ge 1 ]]; }

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"config"* ]]
  [[ "$output" == *"severity"* ]]
}

@test "rejects unknown arg" { run bash "$SCRIPT" --bogus; [ "$status" -eq 2 ]; }
@test "rejects invalid severity" { run bash "$SCRIPT" --severity NOPE; [ "$status" -eq 2 ]; }

@test "default audit runs" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  [[ "$output" == *"VERDICT"* ]]
}

@test "output reports Configs audited" {
  run bash "$SCRIPT"
  [[ "$output" == *"Configs audited:"* ]]
}

@test "--json valid" {
  run bash -c 'bash scripts/mcp-security-audit.sh --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
for k in [\"verdict\",\"configs_audited\",\"servers_audited\",\"findings_count\",\"critical\",\"high\",\"medium\",\"low\",\"findings\"]:
    assert k in d, f\"missing {k}\"
assert isinstance(d[\"findings\"], list)
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "--json verdict is PASS or FAIL" {
  run bash "$SCRIPT" --json
  [[ "$output" == *'"verdict":"PASS"'* || "$output" == *'"verdict":"FAIL"'* ]]
}

# ── Rule detection (synthetic) ────────────────────────────

@test "MCP-01 detects npx -y without version pin" {
  local cfg="$BATS_TEST_TMPDIR/mcp-bad-01.json"
  cat > "$cfg" <<JSON
{"mcpServers": {"bad-1": {"command": "npx", "args": ["-y", "malicious-package"]}}}
JSON
  run bash "$SCRIPT" --config "$cfg" --json
  [ "$status" -eq 1 ]
  [[ "$output" == *"MCP-01"* ]]
}

@test "MCP-02 detects autoApprove true" {
  local cfg="$BATS_TEST_TMPDIR/mcp-bad-02.json"
  cat > "$cfg" <<JSON
{"mcpServers": {"autoapp": {"command": "/opt/bin/srv", "autoApprove": true}}}
JSON
  run bash "$SCRIPT" --config "$cfg" --json
  [ "$status" -eq 1 ]
  [[ "$output" == *"MCP-02"* ]]
  [[ "$output" == *"CRITICAL"* ]]
}

@test "MCP-03 detects hardcoded secrets in env" {
  local cfg="$BATS_TEST_TMPDIR/mcp-bad-03.json"
  cat > "$cfg" <<'JSON'
{"mcpServers": {"leaky": {"command": "/opt/x", "env": {"API_KEY": "sk-1234567890abcdef"}}}}
JSON
  run bash "$SCRIPT" --config "$cfg" --json
  [ "$status" -eq 1 ]
  [[ "$output" == *"MCP-03"* ]]
}

@test "MCP-04 detects shell transport" {
  local cfg="$BATS_TEST_TMPDIR/mcp-bad-04.json"
  cat > "$cfg" <<JSON
{"mcpServers": {"sh": {"command": "/opt/x", "transport": "shell"}}}
JSON
  run bash "$SCRIPT" --config "$cfg" --json
  [ "$status" -eq 1 ]
  [[ "$output" == *"MCP-04"* ]]
}

@test "MCP-08 detects path traversal in server name" {
  local cfg="$BATS_TEST_TMPDIR/mcp-bad-08.json"
  cat > "$cfg" <<JSON
{"mcpServers": {"../evil": {"command": "/opt/x"}}}
JSON
  run bash "$SCRIPT" --config "$cfg" --json
  [ "$status" -eq 1 ]
  [[ "$output" == *"MCP-08"* ]]
}

@test "MCP-11 detects missing description (LOW)" {
  local cfg="$BATS_TEST_TMPDIR/mcp-bad-11.json"
  cat > "$cfg" <<JSON
{"mcpServers": {"no-desc": {"command": "/opt/x"}}}
JSON
  run bash "$SCRIPT" --config "$cfg" --json
  [[ "$output" == *"MCP-11"* ]]
}

# ── Edge cases ────────────────────────────────────────────

@test "edge: empty mcpServers block = no findings" {
  local cfg="$BATS_TEST_TMPDIR/empty.json"
  echo '{"mcpServers": {}}' > "$cfg"
  run bash "$SCRIPT" --config "$cfg" --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"findings_count":0'* ]]
}

@test "edge: nonexistent config is silently skipped" {
  run bash "$SCRIPT" --config /nonexistent/file.json
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "edge: malformed JSON is detected" {
  local cfg="$BATS_TEST_TMPDIR/bad.json"
  echo '{not json' > "$cfg"
  run bash "$SCRIPT" --config "$cfg" --json
  [[ "$output" == *"MCP-00"* ]]
}

@test "edge: --severity CRITICAL filters lower severities" {
  local cfg="$BATS_TEST_TMPDIR/mixed.json"
  cat > "$cfg" <<JSON
{"mcpServers": {"no-desc": {"command": "/opt/x"}}}
JSON
  run bash "$SCRIPT" --config "$cfg" --severity CRITICAL --json
  # LOW finding should be filtered
  [[ "$output" == *'"findings_count":0'* ]]
}

# ── Coverage ──────────────────────────────────────────────

@test "coverage: add_finding function" { run grep -c 'add_finding' "$SCRIPT"; [[ "$output" -ge 2 ]]; }
@test "coverage: sev_rank function" { run grep -c 'sev_rank' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "coverage: audit_config function" { run grep -c 'audit_config' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "coverage: 11 rules referenced" {
  for r in MCP-01 MCP-02 MCP-03 MCP-04 MCP-05 MCP-06 MCP-07 MCP-08 MCP-09 MCP-10 MCP-11; do
    grep -q "$r" "$SCRIPT" || fail "Missing rule $r"
  done
}

# ── Isolation ─────────────────────────────────────────────

@test "isolation: does not modify mcp.json files" {
  local h_before
  h_before=$(md5sum .claude/mcp.json 2>/dev/null | awk '{print $1}' || echo "")
  bash "$SCRIPT" >/dev/null 2>&1 || true
  local h_after
  h_after=$(md5sum .claude/mcp.json 2>/dev/null | awk '{print $1}' || echo "")
  [[ "$h_before" == "$h_after" ]]
}

@test "isolation: exit codes 0/1/2" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}
