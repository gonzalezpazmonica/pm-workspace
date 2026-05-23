#!/usr/bin/env bats
# SPEC-141 · MCP catalog tests

setup() {
  cd "$BATS_TEST_DIRNAME/.."
}

@test "AC-01: at least 7 templates exist in .opencode/mcp-templates/" {
  count=$(find .opencode/mcp-templates -name '*.jsonc.example' | wc -l)
  [ "$count" -ge 7 ]
}

@test "AC-01: README.md exists in mcp-templates/" {
  [ -f .opencode/mcp-templates/README.md ]
}

@test "AC-02: audit-mcp-templates.sh exists and is executable" {
  [ -x scripts/audit-mcp-templates.sh ]
}

@test "AC-02: audit-mcp-templates.sh passes on all templates" {
  run bash scripts/audit-mcp-templates.sh
  [ "$status" -eq 0 ]
  [[ "$output" =~ "0 fail" ]]
}

@test "AC-02: audit detects hardcoded GitHub PAT" {
  tmpdir=$(mktemp -d)
  cat > "$tmpdir/bad.jsonc.example" <<EOF
{
  "mcp": {
    "bad": {
      "type": "local",
      "command": ["echo", "ghp_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"],
      "_savia_meta": {"scope": "test"}
    }
  }
}
EOF
  run bash scripts/audit-mcp-templates.sh "$tmpdir"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "hardcoded secret" ]]
  rm -rf "$tmpdir"
}

@test "AC-02: audit detects missing _savia_meta.scope" {
  tmpdir=$(mktemp -d)
  cat > "$tmpdir/bad.jsonc.example" <<EOF
{ "mcp": { "bad": { "type": "local", "command": ["true"] } } }
EOF
  run bash scripts/audit-mcp-templates.sh "$tmpdir"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "scope not declared" ]]
  rm -rf "$tmpdir"
}

@test "AC-02: audit detects invalid type" {
  tmpdir=$(mktemp -d)
  cat > "$tmpdir/bad.jsonc.example" <<EOF
{ "mcp": { "bad": { "type": "bogus", "_savia_meta": {"scope": "x"} } } }
EOF
  run bash scripts/audit-mcp-templates.sh "$tmpdir"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "type must be local or remote" ]]
  rm -rf "$tmpdir"
}

@test "AC-03: savia-memory MCP stdio wrapper exists and is executable" {
  [ -x scripts/savia-memory-mcp-stdio.sh ]
}

@test "AC-03: savia-memory MCP wrapper responds to tools/list" {
  result=$(echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | bash scripts/savia-memory-mcp-stdio.sh)
  [[ "$result" =~ "memory_recall" ]]
  [[ "$result" =~ "memory_save" ]]
  [[ "$result" =~ "memory_stats" ]]
}

@test "AC-03: savia-memory MCP wrapper responds to initialize" {
  result=$(echo '{"jsonrpc":"2.0","id":0,"method":"initialize"}' | bash scripts/savia-memory-mcp-stdio.sh)
  [[ "$result" =~ "savia-memory" ]]
  [[ "$result" =~ "2024-11-05" ]]
}

@test "AC-04: Server Cards exist for 3 own servers" {
  [ -f .well-known/mcp-server-card/savia-memory.json ]
  [ -f .well-known/mcp-server-card/savia-recall.json ]
  [ -f .well-known/mcp-server-card/knowledge-graph.json ]
}

@test "AC-04: Server Cards are valid JSON with required fields" {
  for card in .well-known/mcp-server-card/*.json; do
    run jq -e '.name and .version and .protocol_version and .tools' "$card"
    [ "$status" -eq 0 ]
  done
}

@test "AC-05: mcp-catalog-policy.md exists with BlueRock checklist" {
  [ -f docs/rules/domain/mcp-catalog-policy.md ]
  grep -q "BlueRock" docs/rules/domain/mcp-catalog-policy.md
  grep -q "SSRF" docs/rules/domain/mcp-catalog-policy.md
}

@test "AC-05: policy doc mentions Streamable HTTP workaround" {
  grep -q "mcp-remote" docs/rules/domain/mcp-catalog-policy.md
  grep -q "8058" docs/rules/domain/mcp-catalog-policy.md
}
