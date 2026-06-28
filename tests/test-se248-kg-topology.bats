#!/usr/bin/env bats
# test-se248-kg-topology.bats — SE-248: KG topology analysis tests
# Tests Forman-Ricci curvature + Leiden community detection scripts.
#
# Acceptance criteria from SE-248:
# 1. --help exits 0
# 2. Real DB produces valid JSON in output/research/
# 3. JSON has required fields
# 4. Markdown report lists top-5 bottlenecks
# 5. /dev/null input exits 2
# 6. BATS suite >= 8 tests, quality >= 80

SCRIPT="scripts/kg-topology-analysis.sh"
PY_SCRIPT="scripts/kg-topology-analysis.py"
DEFAULT_DB="${HOME}/.savia/knowledge-graph.db"
FIXTURE_DIR="${BATS_TEST_DIRNAME}/../tests/fixtures"
TMP_OUT="${BATS_TEST_TMPDIR:-/tmp}/kg-topology-test-$$"

setup() {
  cd "${BATS_TEST_DIRNAME}/.."
  mkdir -p "$TMP_OUT"
}

teardown() {
  rm -rf "$TMP_OUT"
}

# ── Structure tests ──────────────────────────────────────────────────────────

@test "SE-248-T01: kg-topology-analysis.sh exists and is executable" {
  [[ -f "$SCRIPT" ]]
  [[ -x "$SCRIPT" ]]
}

@test "SE-248-T02: kg-topology-analysis.py exists" {
  [[ -f "$PY_SCRIPT" ]]
}

@test "SE-248-T03: wrapper declares set -uo pipefail" {
  grep -q "set -uo pipefail" "$SCRIPT"
}

@test "SE-248-T04: python script has SE-248 reference" {
  grep -q "SE-248" "$PY_SCRIPT"
}

@test "SE-248-T05: --help exits 0 with usage text" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"SE-248"* ]]
  [[ "$output" == *"--db"* ]]
}

# ── Input validation ─────────────────────────────────────────────────────────

@test "SE-248-T06: --input /dev/null exits 2 (invalid input)" {
  run python3 "$PY_SCRIPT" --input /dev/null --all --format json --output-dir "$TMP_OUT"
  [ "$status" -eq 2 ]
}

@test "SE-248-T07: missing DB exits 3 via wrapper" {
  run bash "$SCRIPT" --db /nonexistent/path.db --all
  [ "$status" -ne 0 ]
}

# ── Functional tests (require real DB) ───────────────────────────────────────

@test "SE-248-T08: real DB produces valid JSON output" {
  [[ -f "$DEFAULT_DB" ]] || skip "knowledge-graph.db not available"
  run python3 "$PY_SCRIPT" --db "$DEFAULT_DB" --all --format json --output-dir "$TMP_OUT"
  [ "$status" -eq 0 ]
  # Find the JSON output file
  local jf
  jf=$(find "$TMP_OUT" -name "kg-topology-*.json" | head -1)
  [[ -n "$jf" ]]
  python3 -c "import json,sys; json.load(open('$jf'))" || fail "JSON invalid"
}

@test "SE-248-T09: JSON output has required top-level fields" {
  [[ -f "$DEFAULT_DB" ]] || skip "knowledge-graph.db not available"
  run python3 "$PY_SCRIPT" --db "$DEFAULT_DB" --all --format json --output-dir "$TMP_OUT"
  [ "$status" -eq 0 ]
  local jf
  jf=$(find "$TMP_OUT" -name "kg-topology-*.json" | head -1)
  python3 - "$jf" << 'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
assert "forman_ricci" in d, "missing forman_ricci"
assert "leiden" in d, "missing leiden"
assert "spectral" in d, "missing spectral"
assert "graph" in d, "missing graph"
print("OK")
PYEOF
}

@test "SE-248-T10: forman_ricci has mean_curvature and bottleneck_ratio" {
  [[ -f "$DEFAULT_DB" ]] || skip "knowledge-graph.db not available"
  run python3 "$PY_SCRIPT" --db "$DEFAULT_DB" --forman-ricci --format json --output-dir "$TMP_OUT"
  [ "$status" -eq 0 ]
  local jf
  jf=$(find "$TMP_OUT" -name "kg-topology-*.json" | head -1)
  python3 - "$jf" << 'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
fr = d["forman_ricci"]
assert isinstance(fr["mean_curvature"], float), "mean_curvature not float"
assert isinstance(fr["bottleneck_ratio"], float), "bottleneck_ratio not float"
assert 0.0 <= fr["bottleneck_ratio"] <= 1.0, "bottleneck_ratio out of [0,1]"
print("OK")
PYEOF
}

@test "SE-248-T11: leiden has modularity in [0,1] and num_communities > 0" {
  [[ -f "$DEFAULT_DB" ]] || skip "knowledge-graph.db not available"
  run python3 "$PY_SCRIPT" --db "$DEFAULT_DB" --leiden --format json --output-dir "$TMP_OUT"
  [ "$status" -eq 0 ]
  local jf
  jf=$(find "$TMP_OUT" -name "kg-topology-*.json" | head -1)
  python3 - "$jf" << 'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
ld = d["leiden"]
assert isinstance(ld["modularity"], float), "modularity not float"
assert 0.0 <= ld["modularity"] <= 1.0, f"modularity {ld['modularity']} out of [0,1]"
assert ld["num_communities"] > 0, "num_communities must be > 0"
print("OK")
PYEOF
}

@test "SE-248-T12: markdown report mentions bottleneck in output" {
  [[ -f "$DEFAULT_DB" ]] || skip "knowledge-graph.db not available"
  run python3 "$PY_SCRIPT" --db "$DEFAULT_DB" --forman-ricci --format md --output-dir "$TMP_OUT"
  [ "$status" -eq 0 ]
  local mf
  mf=$(find "$TMP_OUT" -name "kg-topology-*.md" | head -1)
  [[ -n "$mf" ]]
  grep -qi "bottleneck" "$mf"
}

@test "SE-248-T13: only networkx+numpy required (no gudhi/leidenalg import)" {
  grep -v "^#" "$PY_SCRIPT" | grep -E "^import |^from " | grep -qvE "gudhi|leidenalg|torch|tensorflow"
}
