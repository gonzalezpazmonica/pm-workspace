#!/usr/bin/env bats
# test-se223-codebase-memory-mcp.bats — SE-223 Slice 1 smoke test
# Verifica que codebase-memory-mcp está instalado, indexado y responde queries.

CBM="${HOME}/.local/bin/codebase-memory-mcp"
PROJECT="home-monica-savia"

setup() {
  export PATH="${HOME}/.local/bin:${PATH}"
  export CLAUDE_PROJECT_DIR="${BATS_TEST_DIRNAME}/.."
}

# --- instalación ---

@test "binary exists and is executable" {
  [[ -x "$CBM" ]]
}

@test "version outputs semver" {
  run "$CBM" --version
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "opencode.json has codebase-memory-mcp entry" {
  [[ -f "${HOME}/.config/opencode/opencode.json" ]]
  grep -q "codebase-memory-mcp" "${HOME}/.config/opencode/opencode.json"
}

# --- indexación ---

@test "project is indexed (list_projects)" {
  run bash -c "'$CBM' cli list_projects 2>&1 | grep -v '^level='"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "$PROJECT" ]]
}

@test "index has >1000 nodes" {
  result=$("$CBM" cli get_architecture "{\"project\":\"$PROJECT\",\"aspects\":[\"languages\"]}" 2>&1 | grep -v "^level=")
  nodes=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('total_nodes',0))" 2>/dev/null)
  [[ "$nodes" -gt 1000 ]]
}

# --- queries funcionales ---

@test "search_graph returns results for cmd_save" {
  result=$("$CBM" cli search_graph "{\"project\":\"$PROJECT\",\"name_pattern\":\"cmd_save\",\"limit\":3}" 2>&1 | grep -v "^level=")
  total=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('total',0))" 2>/dev/null)
  [[ "$total" -gt 0 ]]
}

@test "search_graph latency <200ms" {
  start=$(date +%s%3N)
  "$CBM" cli search_graph "{\"project\":\"$PROJECT\",\"name_pattern\":\"confidentiality_sign\",\"limit\":3}" >/dev/null 2>&1
  end=$(date +%s%3N)
  elapsed=$((end - start))
  [[ "$elapsed" -lt 200 ]]
}

@test "get_architecture returns languages list" {
  result=$("$CBM" cli get_architecture "{\"project\":\"$PROJECT\",\"aspects\":[\"languages\"]}" 2>&1 | grep -v "^level=")
  [[ "$result" =~ "Bash" ]]
}

@test "trace_path inbound does not crash" {
  run bash -c "'$CBM' cli trace_path '{\"project\":\"$PROJECT\",\"function_name\":\"cmd_save\",\"direction\":\"inbound\",\"depth\":1}' 2>&1 | grep -v '^level='"
  [[ "$status" -eq 0 ]]
}

# --- code-twin-agent update ---

@test "code-twin-agent references codebase-memory-mcp" {
  grep -q "codebase-memory-mcp" .opencode/agents/code-twin-agent.md
}

@test "code-twin-agent has MCP protocol section" {
  grep -q "Protocolo MCP" .opencode/agents/code-twin-agent.md
}

@test "code-twin-agent has CTF fallback section" {
  grep -q "Protocolo CTF" .opencode/agents/code-twin-agent.md
}

@test "code-twin-agent size under 4096 bytes" {
  size=$(wc -c < .opencode/agents/code-twin-agent.md)
  [[ "$size" -lt 4096 ]]
}
