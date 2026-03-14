#!/usr/bin/env bats
# Tests for Era 100 — Context Window Adaptive per Model

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  ROOT="$PWD"
}

@test "config/model-capabilities.yaml exists" {
  [ -f "$ROOT/config/model-capabilities.yaml" ]
}

@test "model-capabilities.yaml is valid YAML (basic structure)" {
  run grep -c "^models:" "$ROOT/config/model-capabilities.yaml"
  [ "$output" = "1" ]
  run grep -c "^default:" "$ROOT/config/model-capabilities.yaml"
  [ "$output" = "1" ]
}

@test "model-capabilities.yaml contains opus, sonnet, haiku" {
  grep -q "claude-opus-4-6:" "$ROOT/config/model-capabilities.yaml"
  grep -q "claude-sonnet-4-6:" "$ROOT/config/model-capabilities.yaml"
  grep -q "claude-haiku-4-5-20251001:" "$ROOT/config/model-capabilities.yaml"
}

@test "model-capability-resolver.sh exists and is executable" {
  [ -x "$ROOT/scripts/model-capability-resolver.sh" ]
}

@test "resolver outputs correct vars for opus (1M, max)" {
  run bash -c "echo '' | $ROOT/scripts/model-capability-resolver.sh --model claude-opus-4-6"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "SAVIA_CONTEXT_WINDOW=1000000"
  echo "$output" | grep -q "SAVIA_MODEL_TIER=max"
  echo "$output" | grep -q "SAVIA_COMPACT_THRESHOLD=70"
  echo "$output" | grep -q "SAVIA_SUPPORTS_THINKING=true"
}

@test "resolver outputs correct vars for haiku (200K, fast)" {
  run bash -c "echo '' | $ROOT/scripts/model-capability-resolver.sh --model claude-haiku-4-5-20251001"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "SAVIA_CONTEXT_WINDOW=200000"
  echo "$output" | grep -q "SAVIA_MODEL_TIER=fast"
  echo "$output" | grep -q "SAVIA_COMPACT_THRESHOLD=45"
  echo "$output" | grep -q "SAVIA_SUPPORTS_THINKING=false"
}

@test "resolver outputs correct vars for sonnet (1M, high)" {
  run bash -c "echo '' | $ROOT/scripts/model-capability-resolver.sh --model claude-sonnet-4-6"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "SAVIA_CONTEXT_WINDOW=1000000"
  echo "$output" | grep -q "SAVIA_MODEL_TIER=high"
  echo "$output" | grep -q "SAVIA_COMPACT_THRESHOLD=65"
}

@test "resolver falls back to default for unknown model" {
  run bash -c "echo '' | $ROOT/scripts/model-capability-resolver.sh --model unknown-model-xyz"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "SAVIA_CONTEXT_WINDOW=200000"
  echo "$output" | grep -q "SAVIA_MODEL_TIER=fast"
  echo "$output" | grep -q "SAVIA_COMPACT_THRESHOLD=50"
}

@test "adaptive-strategy-selector.sh exists and is executable" {
  [ -x "$ROOT/scripts/adaptive-strategy-selector.sh" ]
}

@test "strategy selector returns valid JSON for tier max" {
  run bash -c "echo '' | $ROOT/scripts/adaptive-strategy-selector.sh max"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)"
  echo "$output" | grep -q '"agent_budget":5000'
  echo "$output" | grep -q '"load_full_sprint":true'
}

@test "strategy selector returns valid JSON for tier high" {
  run bash -c "echo '' | $ROOT/scripts/adaptive-strategy-selector.sh high"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)"
  echo "$output" | grep -q '"agent_budget":3000'
}

@test "strategy selector returns valid JSON for tier fast" {
  run bash -c "echo '' | $ROOT/scripts/adaptive-strategy-selector.sh fast"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)"
  echo "$output" | grep -q '"agent_budget":1000'
}

@test "strategy selector fails gracefully for unknown tier" {
  run bash -c "echo '' | $ROOT/scripts/adaptive-strategy-selector.sh banana 2>&1"
  [ "$status" -eq 1 ]
  echo "$output" | grep -qi "unknown tier"
}
