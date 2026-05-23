#!/usr/bin/env bats
# SPEC-141 · MCP catalog tests
# Coverage: AC-01..07 + negative + edge cases

set -uo pipefail

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR_TEST="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

# ── AC-01: Templates and README ──────────────────────────────────────────────

@test "AC-01: at least 7 templates exist in .opencode/mcp-templates/" {
  count=$(find .opencode/mcp-templates -name '*.jsonc.example' | wc -l)
  [ "$count" -ge 7 ]
}

@test "AC-01: README.md exists and references BlueRock checklist" {
  [ -f .opencode/mcp-templates/README.md ]
  grep -q "BlueRock" .opencode/mcp-templates/README.md
}

@test "AC-01: every template has matching _savia_meta block" {
  for f in .opencode/mcp-templates/*.jsonc.example; do
    grep -q "_savia_meta" "$f"
  done
}

# ── AC-02: Audit script ──────────────────────────────────────────────────────

@test "AC-02: audit-mcp-templates.sh exists and is executable" {
  [ -x scripts/audit-mcp-templates.sh ]
}

@test "AC-02: audit-mcp-templates.sh passes on all templates" {
  run bash scripts/audit-mcp-templates.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"0 fail"* ]]
}

@test "AC-02 (neg): audit detects hardcoded GitHub PAT" {
  cat > "$TMPDIR_TEST/bad.jsonc.example" <<EOF
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
  run bash scripts/audit-mcp-templates.sh "$TMPDIR_TEST"
  [ "$status" -ne 0 ]
  [[ "$output" == *"hardcoded secret"* ]]
}

@test "AC-02 (neg): audit detects missing _savia_meta.scope" {
  cat > "$TMPDIR_TEST/bad.jsonc.example" <<EOF
{ "mcp": { "bad": { "type": "local", "command": ["true"] } } }
EOF
  run bash scripts/audit-mcp-templates.sh "$TMPDIR_TEST"
  [ "$status" -ne 0 ]
  [[ "$output" == *"scope not declared"* ]]
}

@test "AC-02 (neg): audit detects invalid type" {
  cat > "$TMPDIR_TEST/bad.jsonc.example" <<EOF
{ "mcp": { "bad": { "type": "bogus", "_savia_meta": {"scope": "x"} } } }
EOF
  run bash scripts/audit-mcp-templates.sh "$TMPDIR_TEST"
  [ "$status" -ne 0 ]
  [[ "$output" == *"type must be local or remote"* ]]
}

@test "AC-02 (neg): audit detects remote without oauth" {
  cat > "$TMPDIR_TEST/bad.jsonc.example" <<EOF
{ "mcp": { "bad": { "type": "remote", "url": "https://x.example", "_savia_meta": {"scope": "x"} } } }
EOF
  run bash scripts/audit-mcp-templates.sh "$TMPDIR_TEST"
  [ "$status" -ne 0 ]
  [[ "$output" == *"oauth"* ]]
}

@test "AC-02 (neg): audit detects AWS access key pattern" {
  cat > "$TMPDIR_TEST/bad.jsonc.example" <<EOF
{
  "mcp": {
    "bad": {
      "type": "local",
      "command": ["echo", "AKIAIOSFODNN7EXAMPLE"],
      "_savia_meta": {"scope": "test"}
    }
  }
}
EOF
  run bash scripts/audit-mcp-templates.sh "$TMPDIR_TEST"
  [ "$status" -ne 0 ]
  [[ "$output" == *"hardcoded secret"* ]]
}

@test "AC-02 (edge): empty templates directory exits 0 with no failures" {
  run bash scripts/audit-mcp-templates.sh "$TMPDIR_TEST"
  [ "$status" -eq 0 ]
  [[ "$output" == *"0 fail"* ]]
}

@test "AC-02 (edge): nonexistent directory exits non-zero" {
  run bash scripts/audit-mcp-templates.sh "$TMPDIR_TEST/does-not-exist"
  [ "$status" -ne 0 ]
}

@test "AC-02 (edge): invalid JSON template is detected" {
  cat > "$TMPDIR_TEST/broken.jsonc.example" <<EOF
{ "mcp": { broken json here
EOF
  run bash scripts/audit-mcp-templates.sh "$TMPDIR_TEST"
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid JSON"* ]]
}

# ── AC-03: Own MCP stdio wrapper ─────────────────────────────────────────────

@test "AC-03: savia-memory MCP stdio wrapper exists and is executable" {
  [ -x scripts/savia-memory-mcp-stdio.sh ]
}

@test "AC-03: savia-memory MCP wrapper responds to tools/list" {
  result=$(echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | bash scripts/savia-memory-mcp-stdio.sh)
  [[ "$result" == *"memory_recall"* ]]
  [[ "$result" == *"memory_save"* ]]
  [[ "$result" == *"memory_stats"* ]]
}

@test "AC-03: savia-memory MCP wrapper responds to initialize" {
  result=$(echo '{"jsonrpc":"2.0","id":0,"method":"initialize"}' | bash scripts/savia-memory-mcp-stdio.sh)
  [[ "$result" == *"savia-memory"* ]]
  [[ "$result" == *"2024-11-05"* ]]
}

@test "AC-03 (neg): savia-memory wrapper rejects malformed JSON gracefully" {
  result=$(echo 'not-json' | bash scripts/savia-memory-mcp-stdio.sh 2>&1 || true)
  # Should not crash with bash error; either returns JSON-RPC error or empty
  [[ "$result" != *"command not found"* ]]
}

@test "AC-03 (edge): savia-memory wrapper handles empty stdin" {
  result=$(echo '' | bash scripts/savia-memory-mcp-stdio.sh 2>&1 || true)
  [[ "$result" != *"unbound variable"* ]]
}

# ── AC-04: Server Cards ──────────────────────────────────────────────────────

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

@test "AC-04 (edge): Server Cards declare protocol_version 2024-11-05" {
  for card in .well-known/mcp-server-card/*.json; do
    pv=$(jq -r '.protocol_version' "$card")
    [ "$pv" = "2024-11-05" ]
  done
}

# ── AC-05: Policy doc ────────────────────────────────────────────────────────

@test "AC-05: mcp-catalog-policy.md exists with BlueRock checklist" {
  [ -f docs/rules/domain/mcp-catalog-policy.md ]
  grep -q "BlueRock" docs/rules/domain/mcp-catalog-policy.md
  grep -q "SSRF" docs/rules/domain/mcp-catalog-policy.md
}

@test "AC-05: policy doc mentions Streamable HTTP workaround" {
  grep -q "mcp-remote" docs/rules/domain/mcp-catalog-policy.md
  grep -q "8058" docs/rules/domain/mcp-catalog-policy.md
}

# ── AC-06/07: General hygiene ────────────────────────────────────────────────

@test "AC-06 (neg): no template hardcodes a real GitHub token prefix in inline value" {
  # All third-party templates must use ${env:VAR} pattern, never inline secrets
  for f in .opencode/mcp-templates/*.jsonc.example; do
    if grep -qE '^[^#]*"(token|api_key|secret|password)"\s*:\s*"[A-Za-z0-9_]{20,}"' "$f"; then
      echo "Hardcoded literal secret in $f"
      return 1
    fi
  done
}

@test "AC-07 (edge): no template lacks .jsonc.example extension" {
  for f in .opencode/mcp-templates/*; do
    [[ "$f" == *.jsonc.example || "$f" == *README.md ]]
  done
}
