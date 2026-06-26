#!/usr/bin/env bats
# tests/bats/test-spec-032-security-benchmarks.bats — SPEC-032 Security Benchmarks
#
# Tests for the security benchmark framework:
#   - scripts/security-benchmark-runner.sh
#   - scripts/security-benchmark-metrics.py
#   - tests/fixtures/security-benchmark/
#   - docs/rules/domain/security-benchmark-protocol.md
#
# Ref: docs/propuestas/SPEC-032-security-benchmarks.md

REPO_ROOT="$(git rev-parse --show-toplevel)"
RUNNER="$REPO_ROOT/scripts/security-benchmark-runner.sh"
METRICS="$REPO_ROOT/scripts/security-benchmark-metrics.py"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/security-benchmark"
PROTOCOL="$REPO_ROOT/docs/rules/domain/security-benchmark-protocol.md"

# ── Test 1: runner existe y es ejecutable ─────────────────────────────────────
@test "security-benchmark-runner.sh existe y es ejecutable" {
  [[ -f "$RUNNER" ]]
  [[ -x "$RUNNER" ]]
}

# ── Test 2: modo --mock funciona sin Docker ────────────────────────────────────
@test "--mock mode produce JSON sin necesitar Docker" {
  run bash "$RUNNER" --mock
  # Exit 0 = thresholds pass, Exit 1 = thresholds fail (ambos validos para el test)
  # Lo que importa es que la salida sea JSON valido con los campos requeridos
  # Extraemos el JSON (ignoramos lineas de log [INFO]/[WARN] a stderr)
  json_output="$(bash "$RUNNER" --mock 2>/dev/null)"
  [[ -n "$json_output" ]]
  echo "$json_output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'detection_rate' in d"
}

# ── Test 3: expected-findings.json existe y es JSON valido ────────────────────
@test "expected-findings.json existe y es JSON valido" {
  [[ -f "$FIXTURE_DIR/expected-findings.json" ]]
  python3 -c "import json; json.load(open('$FIXTURE_DIR/expected-findings.json'))"
}

# ── Test 4: expected-findings.json tiene 5 findings con campos requeridos ─────
@test "expected-findings.json tiene exactamente 5 findings con campos obligatorios" {
  local fixture_file="$FIXTURE_DIR/expected-findings.json"
  [[ -f "$fixture_file" ]]
  python3 "$REPO_ROOT/tests/fixtures/security-benchmark/../../../scripts/security-benchmark-metrics.py" --help >/dev/null 2>&1 || true
  # Validate structure using python3 with variable interpolated in bash
  run python3 -c "
import json
d = json.load(open('${FIXTURE_DIR}/expected-findings.json'))
assert d.get('total_expected') == 5
findings = d.get('findings', [])
assert len(findings) == 5
for f in findings:
    for k in ['id','cwe','severity','name']:
        assert k in f, f'Missing {k} in {f}'
print('OK')
"
  [[ "$status" -eq 0 ]]
}

# ── Test 5: security-benchmark-metrics.py calcula F1 correctamente ────────────
@test "security-benchmark-metrics.py calcula F1 correctamente (precision=recall=1.0 → F1=1.0)" {
  # Crear actual findings que coinciden exactamente con expected
  tmpdir="$(mktemp -d)"
  ACTUAL="$tmpdir/actual.json"
  EXPECTED="$FIXTURE_DIR/expected-findings.json"

  python3 - << PYEOF
import json
expected = json.load(open("$EXPECTED"))
# Perfect detection: actual == expected findings
actual = {"findings": expected["findings"]}
with open("$ACTUAL", "w") as f:
    json.dump(actual, f)
PYEOF

  run python3 "$METRICS" --actual "$ACTUAL" --expected "$EXPECTED" --json-only
  # Exit 0 = thresholds pass
  [[ "$status" -eq 0 ]]
  f1=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['f1'])")
  # F1 should be 1.0 for perfect detection
  python3 -c "assert abs(float('$f1') - 1.0) < 0.001, f'F1={float(\"$f1\")}, expected ~1.0'"

  rm -rf "$tmpdir"
}

# ── Test 6: protocol.md existe con thresholds documentados ────────────────────
@test "security-benchmark-protocol.md existe y documenta thresholds" {
  [[ -f "$PROTOCOL" ]]
  grep -q "0.70" "$PROTOCOL"
  grep -q "0.30" "$PROTOCOL"
  grep -q "detection_rate" "$PROTOCOL"
  grep -q "false_positive_rate" "$PROTOCOL"
}

# ── Test 7: runner produce JSON con todos los campos requeridos ────────────────
@test "runner --mock produce JSON con campos: agent, app, vulnerabilities_found, total_expected, detection_rate, false_positives, score" {
  json_output="$(bash "$RUNNER" --mock 2>/dev/null)"
  python3 - << PYEOF
import json, sys
d = json.loads("""$json_output""")
required = {"agent", "app", "vulnerabilities_found", "total_expected",
            "detection_rate", "false_positives", "score"}
missing = required - d.keys()
assert not missing, f"Missing fields: {missing}"
print("OK: all required fields present:", list(required))
PYEOF
}

# ── Test 8: vulnerable-code-sample.py tiene las 5 categorias de vulnerabilidad ─
@test "vulnerable-code-sample.py contiene las 5 categorias de vulnerabilidad documentadas" {
  SAMPLE="$FIXTURE_DIR/vulnerable-code-sample.py"
  [[ -f "$SAMPLE" ]]
  # VULN-001 Hardcoded creds
  grep -q "DB_PASSWORD\|API_SECRET_KEY" "$SAMPLE"
  # VULN-002 SQL Injection
  grep -q "execute\|sql.*+" "$SAMPLE"
  # VULN-003 XSS
  grep -q "render_template_string\|template.*request" "$SAMPLE"
  # VULN-004 Path Traversal
  grep -q "os.path.join" "$SAMPLE"
  # VULN-005 Command Injection
  grep -q "shell=True" "$SAMPLE"
}
