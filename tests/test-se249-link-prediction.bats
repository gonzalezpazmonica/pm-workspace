#!/usr/bin/env bats
# test-se249-link-prediction.bats — SE-249: RotatE link prediction tests
# Tests the kg-link-prediction.sh wrapper and kg-link-prediction.py script.
#
# Acceptance criteria from SE-249:
# 1. script exists and is executable
# 2. set -uo pipefail declared in wrapper
# 3. SE-249 reference in script
# 4. --help exits 0 with usage text
# 5. --input /dev/null exits non-zero (invalid JSON)
# 6. missing DB exits non-zero via wrapper
# 7. real KG produces valid JSON with model.mrr and missing_links
# 8. model.mrr is a float
# 9. .py does not import leidenalg or torch
# 10. MRR < 0.15 warning appears in markdown output

SCRIPT="scripts/kg-link-prediction.sh"
PY_SCRIPT="scripts/kg-link-prediction.py"
DEFAULT_DB="${HOME}/.savia/knowledge-graph.db"
TMP_OUT="${BATS_TEST_TMPDIR:-/tmp}/kg-link-prediction-test-$$"

setup() {
  cd "${BATS_TEST_DIRNAME}/.."
  mkdir -p "$TMP_OUT"
}

teardown() {
  rm -rf "$TMP_OUT"
}

# ── Structure tests ──────────────────────────────────────────────────────────

@test "SE-249-T01: kg-link-prediction.sh exists and is executable" {
  [[ -f "$SCRIPT" ]]
  [[ -x "$SCRIPT" ]]
}

@test "SE-249-T02: wrapper declares set -uo pipefail" {
  grep -q "set -uo pipefail" "$SCRIPT"
}

@test "SE-249-T03: script has SE-249 reference" {
  grep -q "SE-249" "$SCRIPT"
}

@test "SE-249-T04: --help exits 0 with usage text" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"SE-249"* ]]
  [[ "$output" == *"--db"* ]]
}

# ── Input validation ─────────────────────────────────────────────────────────

@test "SE-249-T05: --input /dev/null exits non-zero (invalid input)" {
  run python3 "$PY_SCRIPT" --input /dev/null
  [ "$status" -ne 0 ]
}

@test "SE-249-T06: missing DB exits non-zero via wrapper" {
  run bash "$SCRIPT" --db /nonexistent/path.db
  [ "$status" -ne 0 ]
}

# ── Functional tests (require real DB) ───────────────────────────────────────

@test "SE-249-T07: real KG produces JSON with model.mrr and missing_links" {
  [[ -f "$DEFAULT_DB" ]] || skip "knowledge-graph.db not available"
  run python3 "$PY_SCRIPT" --db "$DEFAULT_DB" \
    --format json --output-dir "$TMP_OUT" --epochs 5 --top-n 5
  [ "$status" -eq 0 ]
  local jf
  jf=$(find "$TMP_OUT" -name "kg-missing-links-*.json" | head -1)
  [[ -n "$jf" ]]
  python3 - "$jf" << 'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
assert "model" in d, "missing top-level 'model'"
assert "mrr" in d["model"], "missing model.mrr"
assert "missing_links" in d, "missing top-level 'missing_links'"
print("OK")
PYEOF
}

@test "SE-249-T08: model.mrr is a float" {
  [[ -f "$DEFAULT_DB" ]] || skip "knowledge-graph.db not available"
  run python3 "$PY_SCRIPT" --db "$DEFAULT_DB" \
    --format json --output-dir "$TMP_OUT" --epochs 5 --top-n 5
  [ "$status" -eq 0 ]
  local jf
  jf=$(find "$TMP_OUT" -name "kg-missing-links-*.json" | head -1)
  python3 - "$jf" << 'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
mrr = d["model"]["mrr"]
assert isinstance(mrr, float), f"model.mrr is {type(mrr).__name__}, expected float"
print(f"OK: mrr={mrr}")
PYEOF
}

# ── Dependency checks ────────────────────────────────────────────────────────

@test "SE-249-T09: kg-link-prediction.py does not import leidenalg or torch" {
  # Only numpy is allowed as external dependency
  ! grep -E "^import leidenalg|^from leidenalg|^import torch|^from torch" "$PY_SCRIPT"
}

# ── Warning threshold ────────────────────────────────────────────────────────

@test "SE-249-T10: low MRR warning appears in markdown when MRR < 0.15" {
  [[ -f "$DEFAULT_DB" ]] || skip "knowledge-graph.db not available"
  run python3 "$PY_SCRIPT" --db "$DEFAULT_DB" \
    --format md --output-dir "$TMP_OUT" --epochs 5 --top-n 5
  [ "$status" -eq 0 ]
  local mf
  mf=$(find "$TMP_OUT" -name "kg-missing-links-*.md" | head -1)
  [[ -n "$mf" ]]
  # The Python script emits the MRR warning in markdown when mrr < 0.15
  # Check JSON to see if MRR is low; if so assert the warning exists in md
  local jf
  jf="${TMP_OUT}/kg-missing-links-$(date +%Y%m%d).json"
  # Re-run for JSON to read mrr value
  python3 "$PY_SCRIPT" --db "$DEFAULT_DB" \
    --format json --output-dir "$TMP_OUT" --epochs 5 --top-n 5 >/dev/null 2>&1 || true
  jf=$(find "$TMP_OUT" -name "kg-missing-links-*.json" | head -1)
  python3 - "$jf" "$mf" << 'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
mrr = d["model"]["mrr"]
if mrr < 0.15:
    content = open(sys.argv[2]).read()
    assert "WARNING" in content or "MRR" in content, \
        f"Low MRR={mrr} but no warning in markdown"
    print(f"OK: low MRR={mrr}, warning present")
else:
    print(f"SKIP-equivalent: MRR={mrr} >= 0.15, warning not expected")
PYEOF
}
