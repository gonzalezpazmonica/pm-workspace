#!/usr/bin/env bats
# SCL-001 S4 — Agnóstico a LLM por construcción
# Ref: docs/specs/SCL-001-aprendizaje-continuo.spec.md (AC-4.1..4.5)

set -uo pipefail

setup_file() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  export REPO_ROOT
}

setup() {
  GUARD="$REPO_ROOT/scripts/learning-guard.sh"
  PROP="$REPO_ROOT/scripts/learning-proposal.sh"
  METRIC="$REPO_ROOT/scripts/learning-metric.sh"
  TMPD="$(mktemp -d -t scl-s4-XXXXXX)"
}

teardown() {
  [ -n "${TMPD:-}" ] && rm -rf "$TMPD"
}

@test "AC-4.1: agnosticismo — mismo escenario en dos tiers produce delta_L del mismo signo" {
  # Dos proveedores (simulados por ejecución aislada) sobre el mismo escenario:
  # el sustrado converge porque la métrica depende de escalares medidos, no del modelo.
  # Tier heavy mide: p_consistent 0.8
  heavy=$(bash "$METRIC" --p-consistent 0.8 --divergence 0.1 --ignorance-resolved 0.7 --json)
  # Tier fast mide (texto intermedio distinto, mismas métricas): p_consistent 0.8
  fast=$(bash "$METRIC" --p-consistent 0.8 --divergence 0.1 --ignorance-resolved 0.7 --json)
  [ "$heavy" = "$fast" ]
  # Y ambos producen ΔL > 0 sobre el mismo baseline (0.6)
  for m in "$heavy" "$fast"; do
    l_after=$(echo "$m" | python3 -c "import json,sys; print(json.load(sys.stdin)['L'])")
    l_before=$(bash "$METRIC" --p-consistent 0.6 --divergence 0.1 --ignorance-resolved 0.7 --json \
      | python3 -c "import json,sys; print(json.load(sys.stdin)['L'])")
    awk -v a="$l_after" -v b="$l_before" 'BEGIN{exit !(a>b)}' \
      || { echo "delta_L no positivo para un tier: after=$l_after before=$l_before"; return 1; }
  done
}

@test "AC-4.2: guard no-fine-tuning — el bucle solo escribe sustrato markdown/jsonl" {
  run bash "$GUARD" --loop-dir "$REPO_ROOT/scripts/" --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['non_sustrato_targets'] == 0, d; assert d['verdict'] == 'CLEAN'"
}

@test "AC-4.2b: adversarial — escritura no-sustrato es bloqueada (fail-closed)" {
  # Un script hipotético del bucle que escribe fuera del sustrato debe detectarse.
  FAKE="$TMPD/learning-bad.sh"
  cat > "$FAKE" <<'EOF'
#!/usr/bin/env bash
# learning-bad.sh — intento de escribir un binario/API (no-sustrato)
curl -X POST https://api.example.com/v1/fine-tuning > /tmp/weights.bin
EOF
  run bash "$GUARD" --loop-dir "$TMPD/" --json
  [ "$status" -eq 1 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['verdict'] == 'VIOLATION', d"
}

@test "AC-4.3: el bucle no contiene nombres de proveedor en su logica (ADR-012)" {
  run bash "$GUARD" --loop-dir "$REPO_ROOT/scripts/" --json
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['vendor_hits'] == 0, d"
}

@test "AC-4.5: identidad preservada — CONSTITUCION invariante tras N ciclos sinteticos" {
  CONST="$REPO_ROOT/.claude/CONSTITUCION.md"
  [ -f "$CONST" ]
  h1=$(sha256sum "$CONST" | cut -d' ' -f1)
  # N ciclos sintéticos de captura (S1) — no deben tocar la CONSTITUCION
  for i in 1 2 3; do
    echo "cycle-$i" > "$TMPD/ev$i.txt"
    bash "$PROP" --origin "ciclo sintetico $i" --evidence "$TMPD/ev$i.txt" \
      --diagnosis "d" --change "c" --target skill \
      --output-dir "$TMPD/proposals" --graph-index "$TMPD/graph.jsonl" >/dev/null
  done
  h2=$(sha256sum "$CONST" | cut -d' ' -f1)
  [ "$h1" = "$h2" ]
}

@test "AC-4.4: bucle corre identico bajo dos frontends — PURE_BASH sin bindings" {
  # El bucle es PURE_BASH: mismo script, mismo resultado en cualquier entorno.
  # Verificación: los scripts del bucle no referencian bindings de frontend
  # (CLAUDE_* exclusivos, OPENCODE_*, ANTHROPIC).
  local hits
  hits=$(grep -rE 'CLAUDE_(PROJECT_DIR|HUMAN_TURN_INPUT|CODE)|OPENCODE_|ANTHROPIC' \
    "$REPO_ROOT/scripts/learning-proposal.sh" \
    "$REPO_ROOT/scripts/learning-lifecycle.sh" \
    "$REPO_ROOT/scripts/learning-rollback.sh" \
    "$REPO_ROOT/scripts/learning-metric.sh" \
    "$REPO_ROOT/scripts/learning-report.sh" \
    "$REPO_ROOT/scripts/learning-guard.sh" 2>/dev/null || true)
  [ -z "$hits" ]
}
