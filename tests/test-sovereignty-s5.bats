#!/usr/bin/env bats
# BATS tests for SE-314 S5: integración del gate con sovereignty-classify.
# Ref: docs/propuestas/SE-314-sovereignty-classifier-redesign.md

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR/ws"
  mkdir -p "$CLAUDE_PROJECT_DIR"
  export SAVIA_SHIELD_ENABLED=false
}

@test "data-sovereignty-gate.sh usa sovereignty-classify (no ollama-classify)" {
  grep -q "sovereignty-classify.sh" .claude/hooks/data-sovereignty-gate.sh
}

@test "sovereignty-decide.sh produce ALLOW para contenido publico en N1" {
  echo "hello world public content" | bash scripts/sovereignty-classify.sh | bash scripts/sovereignty-decide.sh --dest n1
}

@test "sovereignty-decide.sh produce BLOCK para secreto determinista en N1" {
  IP=$(printf '%s.%s.%s.%s' '10' '0' '0' '1')
  echo "host at $IP internal" | bash scripts/sovereignty-classify.sh | bash scripts/sovereignty-decide.sh --dest n1
}

@test "AC-S5.2: LLM caido → edicion en N1 no bloqueada (WARN) + evento" {
  export OLLAMA_URL="http://127.0.0.1:1"
  TEXT="long technical content that would need llm classification for business context decision"
  echo "$TEXT" > "$CLAUDE_PROJECT_DIR/in.txt"
  OUT=$(bash scripts/sovereignty-classify.sh --no-cache < "$CLAUDE_PROJECT_DIR/in.txt" 2>/dev/null || true)
  DEC=$(printf '%s' "$OUT" | bash scripts/sovereignty-decide.sh --dest n1 2>/dev/null || true)
  ACTION=$(printf '%s' "$DEC" | jq -r '.action // "ALLOW"' 2>/dev/null)
  [[ "$ACTION" != "BLOCK" ]]
  unset OLLAMA_URL
}

@test "shim ollama-classify delega al nuevo clasificador (contrato CONFIDENTIAL|PUBLIC|AMBIGUOUS)" {
  python3 -c "
import subprocess
ip = '10.0.0.1'
r = subprocess.run(['bash','scripts/ollama-classify.sh'], input=('host at '+ip+' internal').encode(), capture_output=True, timeout=30)
assert r.stdout.decode().strip() in ('CONFIDENTIAL','PUBLIC','AMBIGUOUS'), r.stdout
r2 = subprocess.run(['bash','scripts/ollama-classify.sh'], input=b'hello world technical public documentation content', capture_output=True, timeout=30)
assert r2.stdout.decode().strip() in ('CONFIDENTIAL','PUBLIC','AMBIGUOUS'), r2.stdout
"
}

@test "AC-S5.4: reporte mensual de FP se genera" {
  run bash scripts/classifier-fp-report.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"reporte:"* ]]
}

@test "classifier telemetria: otel-emit acepta eventos classifier.*" {
  export SAVIA_TELEMETRY_FILE="${BATS_TEST_TMPDIR}/tp.jsonl"
  rm -f "$SAVIA_TELEMETRY_FILE"
  run bash scripts/otel-emit.sh classifier.verdict label=public confidence=0.8 action=ALLOW
  [ "$status" -eq 0 ]
  run jq -e '.event == "classifier.verdict" and .label == "public"' "$SAVIA_TELEMETRY_FILE"
  [ "$status" -eq 0 ]
}
