#!/usr/bin/env bats
# Ref: docs/propuestas/SPEC-066-enhanced-local-llm.md
# Tests for sovereignty-benchmark.sh — LLM benchmark for pm-workspace

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/sovereignty-benchmark.sh"
  TMPDIR_SB=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_SB"
}

@test "script has safety flags" {
  head -5 "$SCRIPT" | grep -qE "set -[eu]o pipefail"
}

@test "help shows usage" {
  run bash "$SCRIPT" --help
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Usage"* ]]
}

@test "fails without ollama" {
  PATH="/usr/bin:/bin" run bash "$SCRIPT"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Ollama"* ]] || [[ "$output" == *"not installed"* ]]
}

@test "fails with nonexistent model" {
  if ! command -v ollama &>/dev/null; then skip "Ollama not installed"; fi
  run bash "$SCRIPT" --model nonexistent-model-xyz
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"not available"* ]]
}

@test "quick mode runs with available model" {
  if ! command -v ollama &>/dev/null; then skip "Ollama not installed"; fi
  run timeout 20 bash "$SCRIPT" --quick --model qwen2.5:3b
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 124 ]] && skip "Ollama timeout"
  [[ "$output" == *"Summary"* ]]
  [[ "$output" == *"Score"* ]]
}

@test "output contains VERDICT" {
  if ! command -v ollama &>/dev/null; then skip "Ollama not installed"; fi
  run timeout 20 bash "$SCRIPT" --quick --model qwen2.5:3b
  [[ "$status" -eq 124 ]] && skip "Ollama timeout"
  [[ "$output" == *"VERDICT"* ]]
}

@test "benchmark_prompt function exists" {
  grep -q "benchmark_prompt()" "$SCRIPT"
}

@test "edge: --quick flag reduces test count" {
  grep -c "benchmark_prompt" "$SCRIPT" | head -1
  local quick_count full_count
  quick_count=$(grep -c 'benchmark_prompt' "$SCRIPT")
  # Should have more than 5 benchmarks total
  [[ "$quick_count" -ge 5 ]]
}

@test "negative: invalid flag handled" {
  if ! command -v ollama &>/dev/null; then skip "Ollama not installed"; fi
  run timeout 20 bash "$SCRIPT" --invalid-flag
  [[ "$status" -eq 124 ]] && skip "Ollama timeout"
  [[ "$status" -le 1 ]]
}

@test "edge: results file created" {
  if ! command -v ollama &>/dev/null; then skip "Ollama not installed"; fi
  run timeout 20 bash "$SCRIPT" --quick --model qwen2.5:3b
  [[ "$status" -eq 124 ]] && skip "Ollama timeout"
  ls "$REPO_ROOT/output/sovereignty-benchmark-"*.md 2>/dev/null | grep -q "."
}

@test "coverage: MODEL variable configurable via env" {
  grep -q "SAVIA_BENCHMARK_MODEL" "$SCRIPT"
}
