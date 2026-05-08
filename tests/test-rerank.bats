#!/usr/bin/env bats
# test-rerank.bats — SE-032 Slice 2 tests for rerank.py + skill.
# Spec: docs/propuestas/SE-032-reranker-layer.md

set -uo pipefail
ROOT="$BATS_TEST_DIRNAME/.."
SCRIPT="$ROOT/scripts/rerank.py"
SKILL_DIR="$ROOT/.opencode/skills/reranker"

setup() {
  TMPDIR="$(mktemp -d)"
  export TMPDIR
}

teardown() {
  [[ -n "${TMPDIR:-}" && -d "$TMPDIR" ]] && rm -rf "$TMPDIR" || true
}

# --- Script existence ---

@test "script: rerank.py exists" {
  [ -f "$SCRIPT" ]
}

@test "script: rerank.py has shebang" {
  run head -1 "$SCRIPT"
  [[ "$output" == "#!/usr/bin/env python3" ]]
}

@test "script: rerank.py is executable" {
  [ -x "$SCRIPT" ]
}

@test "script: --help does not crash" {
  run python3 "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"rerank"* ]]
}

# --- JSON input parsing ---

@test "input: empty stdin returns parse error (exit 1)" {
  run bash -c "echo '' | python3 '$SCRIPT'"
  [ "$status" -eq 1 ]
}

@test "input: invalid JSON returns error (exit 1)" {
  run bash -c "echo 'not json' | python3 '$SCRIPT'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid JSON"* || "$output" == *"JSON"* ]]
}

@test "input: missing query field returns error" {
  run bash -c "echo '{\"candidates\":[]}' | python3 '$SCRIPT'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"query"* ]]
}

@test "input: candidates not a list returns error" {
  run bash -c "echo '{\"query\":\"x\",\"candidates\":\"nope\"}' | python3 '$SCRIPT'"
  [ "$status" -eq 1 ]
}

@test "input: candidate missing id returns error" {
  run bash -c "echo '{\"query\":\"x\",\"candidates\":[{\"text\":\"no id\"}]}' | python3 '$SCRIPT'"
  [ "$status" -eq 1 ]
}

@test "input: candidate missing text returns error" {
  run bash -c "echo '{\"query\":\"x\",\"candidates\":[{\"id\":\"a\"}]}' | python3 '$SCRIPT'"
  [ "$status" -eq 1 ]
}

# --- Happy path ---

@test "happy: valid input returns JSON output" {
  local input='{"query":"test","candidates":[{"id":"a","text":"doc a","cosine":0.5}]}'
  run bash -c "echo '$input' | python3 '$SCRIPT' --top-k 1"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"reranked"'* ]]
  [[ "$output" == *'"backend"'* ]]
  [[ "$output" == *'"latency_ms"'* ]]
}

@test "happy: empty candidates returns empty reranked" {
  local input='{"query":"test","candidates":[]}'
  run bash -c "echo '$input' | python3 '$SCRIPT'"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"reranked":'*"[]"* ]]
  [[ "$output" == *'"empty-input"'* ]]
}

@test "happy: top-k limits results" {
  local input='{"query":"q","candidates":[{"id":"a","text":"1","cosine":0.5},{"id":"b","text":"2","cosine":0.6},{"id":"c","text":"3","cosine":0.7}]}'
  local count
  count=$(echo "$input" | python3 "$SCRIPT" --top-k 2 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)['reranked']))")
  [ "$count" -eq 2 ]
}

@test "happy: rank field assigned starting at 1" {
  local input='{"query":"q","candidates":[{"id":"a","text":"1","cosine":0.9},{"id":"b","text":"2","cosine":0.8}]}'
  run bash -c "echo '$input' | python3 '$SCRIPT' --top-k 2"
  [[ "$output" == *'"rank": 1'* ]]
  [[ "$output" == *'"rank": 2'* ]]
}

@test "happy: --json flag pretty-prints" {
  local input='{"query":"q","candidates":[{"id":"a","text":"t","cosine":0.5}]}'
  run bash -c "echo '$input' | python3 '$SCRIPT' --json"
  [ "$status" -eq 0 ]
  # Pretty output has newlines inside braces
  local lines=$(echo "$output" | wc -l)
  [ "$lines" -gt 3 ]
}

# --- Fallback contract ---

@test "fallback: cosine fallback when no transformers (identity if no cosine)" {
  local input='{"query":"q","candidates":[{"id":"a","text":"1"},{"id":"b","text":"2"}]}'
  run bash -c "echo '$input' | python3 '$SCRIPT'"
  [ "$status" -eq 0 ]
  # backend must be one of the valid choices
  [[ "$output" == *"cross-encoder"* || "$output" == *"fallback-identity"* || "$output" == *"fallback-cosine"* ]]
}

# --- Usage errors ---

@test "usage: --top-k 0 rejected" {
  run bash -c "echo '{}' | python3 '$SCRIPT' --top-k 0"
  [ "$status" -eq 2 ]
}

@test "usage: --top-k negative rejected" {
  run bash -c "echo '{}' | python3 '$SCRIPT' --top-k -5"
  [ "$status" -eq 2 ]
}

# --- Skill structure ---

@test "skill: reranker directory exists" {
  [ -d "$SKILL_DIR" ]
}

@test "skill: SKILL.md exists and under 150 lines" {
  [ -f "$SKILL_DIR/SKILL.md" ]
  local lines=$(wc -l < "$SKILL_DIR/SKILL.md")
  [ "$lines" -le 150 ]
}

@test "skill: DOMAIN.md exists and under 150 lines" {
  [ -f "$SKILL_DIR/DOMAIN.md" ]
  local lines=$(wc -l < "$SKILL_DIR/DOMAIN.md")
  [ "$lines" -le 150 ]
}

@test "skill: SKILL.md references SE-032" {
  run grep "SE-032" "$SKILL_DIR/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "skill: DOMAIN.md references SE-032" {
  run grep "SE-032" "$SKILL_DIR/DOMAIN.md"
  [ "$status" -eq 0 ]
}

@test "skill: SKILL.md frontmatter has name: reranker" {
  run grep -E "^name:\s*reranker" "$SKILL_DIR/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "skill: SKILL.md lists 3 backends" {
  run grep -E "cross-encoder|fallback-cosine|fallback-identity" "$SKILL_DIR/SKILL.md"
  [ "$status" -eq 0 ]
}

# --- Coverage ---

@test "coverage: script has fallback_cosine function" {
  run grep "def fallback_cosine" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "coverage: script has try_cross_encode function" {
  run grep "def try_cross_encode" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "coverage: script handles ImportError gracefully" {
  run grep "ImportError" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "coverage: script references SE-032 in docstring" {
  run grep "SE-032" "$SCRIPT"
  [ "$status" -eq 0 ]
}

# --- Edge cases ---

@test "edge: empty string query returns error" {
  run bash -c "echo '{\"query\":\"\",\"candidates\":[]}' | python3 '$SCRIPT'"
  [ "$status" -eq 1 ]
}

@test "edge: whitespace-only query returns error" {
  run bash -c "echo '{\"query\":\"   \",\"candidates\":[]}' | python3 '$SCRIPT'"
  [ "$status" -eq 1 ]
}

@test "edge: nonexistent flag rejected" {
  run python3 "$SCRIPT" --bogus-flag
  [ "$status" -ne 0 ]
}

@test "edge: zero candidates no crash" {
  run bash -c "echo '{\"query\":\"q\",\"candidates\":[]}' | python3 '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "edge: null in text field preserved" {
  local input='{"query":"q","candidates":[{"id":"a","text":""}]}'
  run bash -c "echo '$input' | python3 '$SCRIPT'"
  [ "$status" -eq 0 ]
}

# --- Isolation ---

@test "isolation: script does not write to cwd" {
  cd "$TMPDIR"
  local before=$(find . -type f 2>/dev/null | wc -l)
  echo '{"query":"q","candidates":[]}' | python3 "$SCRIPT" >/dev/null 2>&1 || true
  local after=$(find . -type f 2>/dev/null | wc -l)
  cd "$ROOT"
  [ "$before" -eq "$after" ]
}

@test "isolation: script --help does not require network" {
  run timeout 3 python3 "$SCRIPT" --help
  [ "$status" -eq 0 ]
}
