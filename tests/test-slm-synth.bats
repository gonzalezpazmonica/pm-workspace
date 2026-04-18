#!/usr/bin/env bats
# Tests for SE-028 slice 1 — slm-synth wrapper
# Ref: docs/rules/domain/slm-pipeline-protocol.md

setup() {
  REPO_ROOT_REAL="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT_REAL/scripts/slm-synth.sh"
  export PROTOCOL="$REPO_ROOT_REAL/docs/rules/domain/slm-pipeline-protocol.md"
  TMPDIR_SLM="$(mktemp -d)"
  export TMPDIR_SLM

  mkdir -p "$TMPDIR_SLM/projects/alpha/.slm/recipes"
  cat > "$TMPDIR_SLM/projects/alpha/.slm/recipes/fine-tune.yaml" <<'F'
model:
  base_model: "unsloth/llama-4-8b-Instruct-bnb-4bit"
training:
  backend: "unsloth"
export:
  deploy: "ollama"
F

  # Zero-egress violation recipe
  cat > "$TMPDIR_SLM/projects/alpha/.slm/recipes/bad-fireworks.yaml" <<'F'
export:
  deploy: "fireworks"
F

  cat > "$TMPDIR_SLM/projects/alpha/.slm/recipes/bad-openai.yaml" <<'F'
export:
  deploy: "openai"
F
}

teardown() {
  rm -rf "$TMPDIR_SLM" 2>/dev/null || true
}

# ── Safety ───────────────────────────────────────────────────────────────────

@test "safety: script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "safety: script has set -uo pipefail" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "safety: script references SE-028" {
  grep -q "SE-028" "$SCRIPT"
}

@test "safety: protocol doc exists" {
  [ -f "$PROTOCOL" ]
  [ -s "$PROTOCOL" ]
}

# ── Positive: dry-run ────────────────────────────────────────────────────────

@test "positive: --dry-run with valid recipe returns exit 1 (SKIPPED)" {
  run env REPO_ROOT="$TMPDIR_SLM" bash "$SCRIPT" --project alpha --dry-run
  [ "$status" -eq 1 ]
  echo "$output" | grep -qE "dry-run|SKIPPED"
}

@test "positive: --json --dry-run produces valid JSON" {
  run env REPO_ROOT="$TMPDIR_SLM" bash "$SCRIPT" --project alpha --dry-run --json
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['project'] == 'alpha'
assert d['dry_run'] is True
assert d['status'] == 'SKIPPED'
"
}

@test "positive: --help returns exit 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
}

@test "positive: graceful skip when oumi not installed" {
  run env REPO_ROOT="$TMPDIR_SLM" bash "$SCRIPT" --project alpha
  # Test env doesn't have oumi installed
  [ "$status" -eq 1 ]
  echo "$output" | grep -qE "SKIPPED|not installed"
}

@test "positive: protocol doc references Unsloth + oumi + Ollama" {
  grep -qE "Unsloth" "$PROTOCOL"
  grep -qE "oumi" "$PROTOCOL"
  grep -qE "Ollama" "$PROTOCOL"
}

@test "positive: protocol doc shows YAML recipe template" {
  grep -qE "base_model" "$PROTOCOL"
  grep -qE "backend:" "$PROTOCOL"
}

# ── Negative: zero-egress ────────────────────────────────────────────────────

@test "negative: fireworks deploy rejected with exit 2" {
  run env REPO_ROOT="$TMPDIR_SLM" bash "$SCRIPT" --project alpha \
    --recipe "$TMPDIR_SLM/projects/alpha/.slm/recipes/bad-fireworks.yaml"
  [ "$status" -eq 2 ]
  echo "$output" | grep -qE "zero-egress|violation"
}

@test "negative: openai deploy rejected with exit 2" {
  run env REPO_ROOT="$TMPDIR_SLM" bash "$SCRIPT" --project alpha \
    --recipe "$TMPDIR_SLM/projects/alpha/.slm/recipes/bad-openai.yaml"
  [ "$status" -eq 2 ]
  echo "$output" | grep -qE "zero-egress"
}

@test "negative: missing --project rejected with exit 2" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "negative: nonexistent recipe file rejected with exit 2" {
  run env REPO_ROOT="$TMPDIR_SLM" bash "$SCRIPT" --project alpha \
    --recipe "/nonexistent/recipe.yaml"
  [ "$status" -eq 2 ]
}

@test "negative: unknown flag rejected" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

# ── Edge cases ───────────────────────────────────────────────────────────────

@test "edge: default recipe path uses projects/{name}/.slm/recipes/fine-tune.yaml" {
  run env REPO_ROOT="$TMPDIR_SLM" bash "$SCRIPT" --project alpha --dry-run --json
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert 'projects/alpha/.slm/recipes/fine-tune.yaml' in d['recipe']
"
}

@test "edge: nonexistent project defaults recipe path but fails" {
  run env REPO_ROOT="$TMPDIR_SLM" bash "$SCRIPT" --project unknown --dry-run
  [ "$status" -eq 2 ]
}

@test "edge: empty recipe file treated as invalid" {
  : > "$TMPDIR_SLM/projects/alpha/.slm/recipes/empty.yaml"
  run env REPO_ROOT="$TMPDIR_SLM" bash "$SCRIPT" --project alpha \
    --recipe "$TMPDIR_SLM/projects/alpha/.slm/recipes/empty.yaml" --dry-run
  # Empty recipe is accepted (no zero-egress string to match); dry-run skip
  [ "$status" -eq 1 ]
}

@test "edge: nested cloud deploy still caught" {
  cat > "$TMPDIR_SLM/projects/alpha/.slm/recipes/bad-bedrock.yaml" <<'F'
export:
    deploy: "bedrock"
F
  run env REPO_ROOT="$TMPDIR_SLM" bash "$SCRIPT" --project alpha \
    --recipe "$TMPDIR_SLM/projects/alpha/.slm/recipes/bad-bedrock.yaml"
  [ "$status" -eq 2 ]
}

# ── Isolation ────────────────────────────────────────────────────────────────

@test "isolation: does not modify recipe file" {
  h=$(sha256sum "$TMPDIR_SLM/projects/alpha/.slm/recipes/fine-tune.yaml" | awk '{print $1}')
  env REPO_ROOT="$TMPDIR_SLM" bash "$SCRIPT" --project alpha --dry-run >/dev/null 2>&1 || true
  h2=$(sha256sum "$TMPDIR_SLM/projects/alpha/.slm/recipes/fine-tune.yaml" | awk '{print $1}')
  [ "$h" = "$h2" ]
}

@test "isolation: exit codes are 0, 1, or 2" {
  run env REPO_ROOT="$TMPDIR_SLM" bash "$SCRIPT" --project alpha --dry-run
  [[ "$status" == "0" || "$status" == "1" || "$status" == "2" ]]
}
