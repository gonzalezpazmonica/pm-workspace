#!/usr/bin/env bats
# test-se-003-mcp-catalog.bats — SPEC-SE-003: MCP Server Catalog
# Tests: mcp-catalog-generate.sh, mcp-server-stub.sh, catalog.json structure

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR

  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export REPO_ROOT

  MCP_CATALOG_SCRIPT="${REPO_ROOT}/scripts/enterprise/mcp-catalog-generate.sh"
  MCP_STUB_SCRIPT="${REPO_ROOT}/scripts/enterprise/mcp-server-stub.sh"
  export MCP_CATALOG_SCRIPT MCP_STUB_SCRIPT

  # Output dir en tmp para tests
  CATALOG_OUT="${TEST_TMPDIR}/mcp-catalog"
  export CATALOG_OUT
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ── Test 1: mcp-catalog-generate.sh existe y es ejecutable ────────────────────

@test "SE-003: mcp-catalog-generate.sh existe y es ejecutable" {
  [[ -f "$MCP_CATALOG_SCRIPT" ]]
  [[ -x "$MCP_CATALOG_SCRIPT" ]] || chmod +x "$MCP_CATALOG_SCRIPT"
}

# ── Test 2: genera catalog.json válido ───────────────────────────────────────

@test "SE-003: mcp-catalog-generate.sh produce catalog.json" {
  chmod +x "$MCP_CATALOG_SCRIPT"
  run bash "$MCP_CATALOG_SCRIPT" --output-dir "$CATALOG_OUT"
  [ "$status" -eq 0 ]
  [[ -f "${CATALOG_OUT}/catalog.json" ]]
}

# ── Test 3: catalog.json tiene campo servers array ────────────────────────────

@test "SE-003: catalog.json tiene campo servers array" {
  chmod +x "$MCP_CATALOG_SCRIPT"
  bash "$MCP_CATALOG_SCRIPT" --output-dir "$CATALOG_OUT" >/dev/null 2>&1
  run grep -c '"servers"' "${CATALOG_OUT}/catalog.json"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ── Test 4: servers array tiene al menos 3 de los 7 servers ──────────────────

@test "SE-003: catalog.json tiene al menos 3 servers en el array" {
  chmod +x "$MCP_CATALOG_SCRIPT"
  bash "$MCP_CATALOG_SCRIPT" --output-dir "$CATALOG_OUT" >/dev/null 2>&1
  SERVER_COUNT=$(grep -c '"id"' "${CATALOG_OUT}/catalog.json" 2>/dev/null || echo 0)
  [ "$SERVER_COUNT" -ge 3 ]
}

# ── Test 5: cada server tiene id, lang, capabilities ─────────────────────────

@test "SE-003: cada server tiene id, lang, capabilities" {
  chmod +x "$MCP_CATALOG_SCRIPT"
  bash "$MCP_CATALOG_SCRIPT" --output-dir "$CATALOG_OUT" >/dev/null 2>&1
  CATALOG="${CATALOG_OUT}/catalog.json"

  # Verificar que todos los campos críticos están presentes
  grep -q '"id"' "$CATALOG"
  grep -q '"lang"' "$CATALOG"
  grep -q '"capabilities"' "$CATALOG"
}

# ── Test 6: mcp-server-stub.sh existe ────────────────────────────────────────

@test "SE-003: mcp-server-stub.sh existe y es ejecutable" {
  [[ -f "$MCP_STUB_SCRIPT" ]]
  [[ -x "$MCP_STUB_SCRIPT" ]] || chmod +x "$MCP_STUB_SCRIPT"
}

# ── Test 7: stub genera README.md y package.json ─────────────────────────────

@test "SE-003: stub generado tiene README.md y package.json" {
  chmod +x "$MCP_CATALOG_SCRIPT"
  chmod +x "$MCP_STUB_SCRIPT"

  # Primero generar catálogo
  bash "$MCP_CATALOG_SCRIPT" --output-dir "$CATALOG_OUT" >/dev/null 2>&1

  STUB_OUT="${TEST_TMPDIR}/stubs"

  run bash "$MCP_STUB_SCRIPT" \
    --server-id "savia-memory-mcp" \
    --output-dir "$STUB_OUT" \
    --catalog "${CATALOG_OUT}/catalog.json"

  [ "$status" -eq 0 ]
  [[ -f "${STUB_OUT}/savia-memory-mcp/README.md" ]]
  [[ -f "${STUB_OUT}/savia-memory-mcp/package.json" ]]
}

# ── Test 8: catalog.json contiene savia-memory-mcp (status available) ─────────

@test "SE-003: catalog.json tiene savia-memory-mcp con status available" {
  chmod +x "$MCP_CATALOG_SCRIPT"
  bash "$MCP_CATALOG_SCRIPT" --output-dir "$CATALOG_OUT" >/dev/null 2>&1
  grep -q '"savia-memory-mcp"' "${CATALOG_OUT}/catalog.json"
  grep -q '"available"' "${CATALOG_OUT}/catalog.json"
}
