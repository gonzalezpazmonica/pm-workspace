#!/usr/bin/env bats
# tests/test-se-351-poc-verify.bats — SE-351: poc-verify.sh verificador binario de PoCs
# Ref: docs/specs/SE-351-poc-verify.spec.md
# Safety: set -uo pipefail per test; todos los targets son locales, sin red (CRIT-001).
#
# Coverage: modos de oráculo (exit_code_nonzero, regex, combined), timeout,
# errores de uso/infra, recibo JSON, anti-leak de output, zero-red.

PV="${BATS_TEST_DIRNAME}/../scripts/poc-verify.sh"

setup() {
  set -uo pipefail
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR
  export POC_VERIFY_OUT_DIR="$TMP_DIR/out"
  mkdir -p "$POC_VERIFY_OUT_DIR"

  # PoCs de prueba
  echo "SECRET_MARKER_content_here" > "$TMP_DIR/poc-crash.txt"
  echo "innocuous" > "$TMP_DIR/poc-ok.txt"
  echo "semi_marker_absent" > "$TMP_DIR/poc-semi.txt"

  # Oráculos
  cat > "$TMP_DIR/oracle-exit.json" <<'EOF'
{
  "name": "exit-demo",
  "target": { "type": "command", "command": "sh -c 'grep -q SECRET_MARKER {poc} && exit 1 || exit 0'", "timeout_secs": 10, "network": "none" },
  "oracle": { "mode": "exit_code_nonzero", "expected_exit": 0 }
}
EOF
  cat > "$TMP_DIR/oracle-regex.json" <<'EOF'
{
  "name": "regex-demo",
  "target": { "type": "command", "command": "sh -c 'cat {poc}'", "timeout_secs": 10, "network": "none" },
  "oracle": { "mode": "regex", "regex": "SECRET_MARKER" }
}
EOF
  cat > "$TMP_DIR/oracle-combined.json" <<'EOF'
{
  "name": "combined-demo",
  "target": { "type": "command", "command": "sh -c 'cat {poc} | grep SECRET_MARKER && exit 7 || exit 0'", "timeout_secs": 10, "network": "none" },
  "oracle": { "mode": "combined", "expected_exit": 0, "regex": "SECRET_MARKER", "require_all": true }
}
EOF
  cat > "$TMP_DIR/oracle-timeout.json" <<'EOF'
{
  "name": "timeout-demo",
  "target": { "type": "command", "command": "sh -c 'sleep 5; cat {poc}'", "timeout_secs": 1, "network": "none" },
  "oracle": { "mode": "regex", "regex": "SECRET" }
}
EOF
}

teardown() {
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

# ── Structural ────────────────────────────────────────────────────────────

@test "poc-verify.sh exists, is executable, no syntax errors" {
  [[ -f "$PV" ]]
  [[ -x "$PV" ]]
  bash -n "$PV"
}

@test "poc-verify.sh uses set -uo pipefail" {
  head -3 "$PV" | grep -q "set -uo pipefail"
}

# ── exit_code_nonzero mode ────────────────────────────────────────────────

@test "exit_code_nonzero: PoC que crashea → VERIFIED (exit 0)" {
  run bash "$PV" verify --oracle "$TMP_DIR/oracle-exit.json" --poc "$TMP_DIR/poc-crash.txt"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "VERDICT: VERIFIED"
}

@test "exit_code_nonzero: PoC inofensivo → NOT_VERIFIED (exit 1)" {
  run bash "$PV" verify --oracle "$TMP_DIR/oracle-exit.json" --poc "$TMP_DIR/poc-ok.txt"
  [[ "$status" -eq 1 ]]
  echo "$output" | grep -q "VERDICT: NOT_VERIFIED"
}

# ── regex mode ────────────────────────────────────────────────────────────

@test "regex: output matchea → VERIFIED" {
  run bash "$PV" verify --oracle "$TMP_DIR/oracle-regex.json" --poc "$TMP_DIR/poc-crash.txt"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "VERDICT: VERIFIED"
}

@test "regex: output no matchea → NOT_VERIFIED" {
  run bash "$PV" verify --oracle "$TMP_DIR/oracle-regex.json" --poc "$TMP_DIR/poc-ok.txt"
  [[ "$status" -eq 1 ]]
  echo "$output" | grep -q "VERDICT: NOT_VERIFIED"
}

# ── combined mode ─────────────────────────────────────────────────────────

@test "combined: exit≠0 Y regex → VERIFIED (require_all)" {
  run bash "$PV" verify --oracle "$TMP_DIR/oracle-combined.json" --poc "$TMP_DIR/poc-crash.txt"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "VERDICT: VERIFIED"
}

@test "combined: exit≠0 pero sin regex → NOT_VERIFIED (require_all)" {
  run bash "$PV" verify --oracle "$TMP_DIR/oracle-combined.json" --poc "$TMP_DIR/poc-semi.txt"
  [[ "$status" -eq 1 ]]
  echo "$output" | grep -q "VERDICT: NOT_VERIFIED"
}

# ── timeout ───────────────────────────────────────────────────────────────

@test "timeout del target → exit 124 y VERDICT TIMEOUT" {
  run bash "$PV" verify --oracle "$TMP_DIR/oracle-timeout.json" --poc "$TMP_DIR/poc-crash.txt" --timeout 1
  [[ "$status" -eq 124 ]]
  echo "$output" | grep -q "TIMEOUT"
}

# ── errores de uso / infra ────────────────────────────────────────────────

@test "--poc inexistente → exit 2" {
  run bash "$PV" verify --oracle "$TMP_DIR/oracle-regex.json" --poc "$TMP_DIR/missing.txt"
  [[ "$status" -eq 2 ]]
  echo "$output" | grep -qi "poc not found"
}

@test "--oracle inexistente → exit 2" {
  run bash "$PV" verify --oracle "$TMP_DIR/missing.json" --poc "$TMP_DIR/poc-crash.txt"
  [[ "$status" -eq 2 ]]
  echo "$output" | grep -qi "oracle not found"
}

@test "verify sin --poc → exit 2" {
  run bash "$PV" verify --oracle "$TMP_DIR/oracle-regex.json"
  [[ "$status" -eq 2 ]]
}

@test "sin subcomando → exit 2" {
  run bash "$PV"
  [[ "$status" -eq 2 ]]
}

# ── recibo JSON ───────────────────────────────────────────────────────────

@test "verify escribe recibo JSON con hash y verdict" {
  bash "$PV" verify --oracle "$TMP_DIR/oracle-regex.json" --poc "$TMP_DIR/poc-crash.txt" >/dev/null
  receipt=$(ls "$POC_VERIFY_OUT_DIR"/poc-verify-*.json | head -1)
  [[ -f "$receipt" ]]
  python3 -c "import json,sys; d=json.load(open('$receipt')); assert d['verdict']=='VERIFIED', d; assert len(d['poc_sha256'])==64, d"
}

@test "recibo no contiene el output completo (anti-leak N3+)" {
  # PoC con contenido largo
  python3 -c "open('$TMP_DIR/big.txt','w').write('A'*100000)"
  bash "$PV" verify --oracle "$TMP_DIR/oracle-regex.json" --poc "$TMP_DIR/big.txt" >/dev/null 2>&1 || true
  receipt=$(ls "$POC_VERIFY_OUT_DIR"/poc-verify-*.json | head -1)
  python3 -c "
import json
d = json.load(open('$receipt'))
assert d['output_bytes'] < 5000, d['output_bytes']  # acotado
assert len(d['output_preview']) <= 2048, len(d['output_preview'])
"
}

# ── CRIT-001 (zero red) ───────────────────────────────────────────────────

@test "script no contiene llamadas de red a proveedor externo" {
  # No debe haber URLs http(s) a hosts externos (solo se permite el target
  # local de los oráculos; el type=http es opt-in por el operador).
  if grep -vE '^\s*#' "$PV" | grep -qE 'https?://[a-zA-Z0-9.-]+'; then
    return 1
  fi
  return 0
}

@test "sample subcommand imprime command resuelto" {
  run bash "$PV" sample --oracle "$TMP_DIR/oracle-regex.json" --poc "$TMP_DIR/poc-crash.txt"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "cat"
}
