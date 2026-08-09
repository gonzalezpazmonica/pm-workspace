#!/usr/bin/env bats
# BATS tests for scripts/sovereignty-classify.sh + sovereignty-decide.sh
# SE-314 S1-S4 — determinismo, umbrales, regex/LLM, caché.
# Ref: docs/propuestas/SE-314-sovereignty-classifier-redesign.md

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR/ws"
  mkdir -p "$CLAUDE_PROJECT_DIR" "$CLAUDE_PROJECT_DIR/config/classifier"
  cp config/classifier/prompt-v2.txt "$CLAUDE_PROJECT_DIR/config/classifier/" 2>/dev/null || true
  cp config/sovereignty-thresholds.yaml "$CLAUDE_PROJECT_DIR/config/" 2>/dev/null || true
  rm -rf "$CLAUDE_PROJECT_DIR/output/classifier-cache" 2>/dev/null || true
  export TEST_INPUT="$CLAUDE_PROJECT_DIR/input.txt"
}

@test "sovereignty-classify.sh existe y es ejecutable" {
  [[ -f scripts/sovereignty-classify.sh ]]
  [[ -x scripts/sovereignty-classify.sh ]]
}

@test "sovereignty-decide.sh existe y es ejecutable" {
  [[ -f scripts/sovereignty-decide.sh ]]
  [[ -x scripts/sovereignty-decide.sh ]]
}

@test "prompt-v2.txt versionado existe" {
  [[ -f config/classifier/prompt-v2.txt ]]
}

@test "sovereignty-thresholds.yaml existe y es YAML válido" {
  [[ -f config/sovereignty-thresholds.yaml ]]
  run python3 -c "import yaml; yaml.safe_load(open('config/sovereignty-thresholds.yaml'))"
  [ "$status" -eq 0 ]
}

@test "AC-S1.3: salida JSON válida con jq, hash = sha256 del input" {
  printf '%s' "hello world public content" > "$TEST_INPUT"
  run bash scripts/sovereignty-classify.sh < "$TEST_INPUT"
  [ "$status" -eq 0 ]
  HASH=$(printf '%s' "hello world public content" | sha256sum | cut -d' ' -f1)
  run jq -e --arg h "sha256:$HASH" '.schema == "savia.classify/2.0" and .hash == $h' <<< "$output"
  [ "$status" -eq 0 ]
}

@test "AC-S1.1: determinismo byte-idéntico (mismo input → misma salida)" {
  echo "hello world this is public technical documentation content" > "$TEST_INPUT"
  R1=$(bash scripts/sovereignty-classify.sh --no-cache < "$TEST_INPUT" 2>/dev/null)
  R2=$(bash scripts/sovereignty-classify.sh --no-cache < "$TEST_INPUT" 2>/dev/null)
  [[ "$R1" == "$R2" ]]
  run jq -e '.label == "public"' <<< "$R1"
  [ "$status" -eq 0 ]
}

@test "AC-S3.2: secreto real (IP interna) bloquea sin depender del LLM" {
  echo "host at 10.0.0.1 internal" > "$TEST_INPUT"
  OUT=$(bash scripts/sovereignty-classify.sh < "$TEST_INPUT" 2>/dev/null)
  run jq -e '.label == "confidential" and (.deterministic_matches | index("internal_ip"))' <<< "$OUT"
  [ "$status" -eq 0 ]
}

@test "AC-S3.3: deterministic_matches presente en salida" {
  echo "plain public content here" > "$TEST_INPUT"
  OUT=$(bash scripts/sovereignty-classify.sh --no-cache < "$TEST_INPUT" 2>/dev/null)
  run jq -e '.deterministic_matches | type == "array"' <<< "$OUT"
  [ "$status" -eq 0 ]
}

@test "AC-S4.1: 2ª clasificación del mismo contenido es cache_hit" {
  head -c 1200 scripts/savia-env.sh > "$TEST_INPUT"
  R1=$(bash scripts/sovereignty-classify.sh < "$TEST_INPUT" 2>/dev/null)
  R2=$(bash scripts/sovereignty-classify.sh < "$TEST_INPUT" 2>/dev/null)
  run jq -e '.cache_hit == false' <<< "$R1"
  [ "$status" -eq 0 ]
  run jq -e '.cache_hit == true' <<< "$R2"
  [ "$status" -eq 0 ]
}

@test "AC-S2.3: confidence < 0.70 en N1 → ALLOW (decide)" {
  echo "hello world public short" > "$TEST_INPUT"
  OUT=$(bash scripts/sovereignty-classify.sh < "$TEST_INPUT" 2>/dev/null)
  DEC=$(printf '%s' "$OUT" | bash scripts/sovereignty-decide.sh --dest n1)
  run jq -e '.action == "ALLOW" and .reason == "below_threshold"' <<< "$DEC"
  [ "$status" -eq 0 ]
}

@test "AC-S2.1: confidential confidence alta en N1 → BLOCK (decide)" {
  echo "host at 10.0.0.1 internal network" > "$TEST_INPUT"
  OUT=$(bash scripts/sovereignty-classify.sh < "$TEST_INPUT" 2>/dev/null)
  DEC=$(printf '%s' "$OUT" | bash scripts/sovereignty-decide.sh --dest n1 2>/dev/null || true)
  run jq -e '.action == "BLOCK" and .label == "confidential"' <<< "$DEC"
  [ "$status" -eq 0 ]
}

@test "usage inválido falla (exit 2)" {
  run bash scripts/sovereignty-classify.sh --bogus-flag
  [ "$status" -eq 2 ]
}
