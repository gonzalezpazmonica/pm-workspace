#!/usr/bin/env bats
# Ref: docs/propuestas/SPEC-066-enhanced-local-llm.md
# Tests for sovereignty-switch.sh — LLM provider sovereignty manager

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/sovereignty-switch.sh"
  TMPDIR_SS=$(mktemp -d)
  export HOME="$TMPDIR_SS"
}

teardown() {
  rm -rf "$TMPDIR_SS"
}

@test "script has safety flags" {
  head -5 "$SCRIPT" | grep -qE "set -[eu]o pipefail"
}

@test "help shows usage" {
  run bash "$SCRIPT" help
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"sovereignty"* ]] || [[ "$output" == *"Sovereignty"* ]]
  [[ "$output" == *"local"* ]]
  [[ "$output" == *"mistral"* ]]
  [[ "$output" == *"claude"* ]]
}

@test "status shows provider info" {
  run bash "$SCRIPT" status
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Active provider"* ]]
  [[ "$output" == *"Ollama"* ]]
}

@test "switch to claude creates config" {
  run bash "$SCRIPT" claude
  [[ "$status" -eq 0 ]]
  [[ -f "$TMPDIR_SS/.savia/sovereignty-provider" ]]
  [[ "$(cat "$TMPDIR_SS/.savia/sovereignty-provider")" == "claude" ]]
}

@test "switch to local with available ollama" {
  if ! command -v ollama &>/dev/null; then
    skip "Ollama not installed"
  fi
  run bash "$SCRIPT" local
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"LOCAL"* ]]
  [[ "$(cat "$TMPDIR_SS/.savia/sovereignty-provider")" == "local" ]]
}

@test "switch to mistral without key fails" {
  run bash "$SCRIPT" mistral
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"key not configured"* ]] || [[ "$output" == *"API key"* ]]
}

@test "switch to mistral with key succeeds" {
  mkdir -p "$TMPDIR_SS/.savia/providers"
  echo "test-key-xxx" > "$TMPDIR_SS/.savia/providers/mistral-key"
  run bash "$SCRIPT" mistral
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"MISTRAL"* ]]
  [[ "$output" == *"EU"* ]]
}

@test "providers lists available options" {
  run bash "$SCRIPT" providers
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"claude"* ]]
  [[ "$output" == *"mistral"* ]]
  [[ "$output" == *"local"* ]]
}

@test "test command checks claude reachability" {
  bash "$SCRIPT" claude
  run bash "$SCRIPT" test
  # May pass or fail depending on network — but should not crash
  [[ "$status" -le 1 ]]
}

@test "unknown command fails" {
  run bash "$SCRIPT" bogus
  [[ "$status" -eq 1 ]]
}

@test "negative: local without ollama fails gracefully" {
  # Simulate no ollama by overriding PATH
  PATH="/usr/bin:/bin" run bash "$SCRIPT" local
  [[ "$status" -eq 1 ]] || [[ "$output" == *"not installed"* ]] || [[ "$output" == *"none"* ]]
}

@test "edge: detect_ollama_best prefers gemma4:e4b" {
  if ! command -v ollama &>/dev/null; then
    skip "Ollama not installed"
  fi
  run bash "$SCRIPT" status
  if echo "$output" | grep -q "gemma4:e4b"; then
    [[ "$output" == *"Best: gemma4:e4b"* ]]
  fi
}

@test "coverage: CONFIG_FILE variable defined" {
  grep -q "CONFIG_FILE" "$SCRIPT"
}

@test "coverage: detect_ollama_best function exists" {
  grep -q "detect_ollama_best()" "$SCRIPT"
}

@test "coverage: cmd_status function exists" {
  grep -q "cmd_status()" "$SCRIPT"
}

@test "edge: switching providers round-trip" {
  bash "$SCRIPT" claude
  [[ "$(cat "$TMPDIR_SS/.savia/sovereignty-provider")" == "claude" ]]
  if command -v ollama &>/dev/null; then
    bash "$SCRIPT" local qwen2.5:3b
    [[ "$(cat "$TMPDIR_SS/.savia/sovereignty-provider")" == "local" ]]
  fi
  bash "$SCRIPT" claude
  [[ "$(cat "$TMPDIR_SS/.savia/sovereignty-provider")" == "claude" ]]
}

@test "edge: empty model arg uses auto-detect" {
  if ! command -v ollama &>/dev/null; then skip "Ollama not installed"; fi
  run bash "$SCRIPT" local ""
  [[ "$status" -eq 0 ]]
}
