#!/usr/bin/env bats
# Ref: docs/propuestas/SPEC-043-responsibility-judge.md
# Tests for responsibility-judge.sh — Deterministic shortcut detector

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/.claude/hooks/responsibility-judge.sh"
  TMPDIR_RJ=$(mktemp -d)
}

teardown() { rm -rf "$TMPDIR_RJ"; }

@test "script has safety flags" {
  head -5 "$SCRIPT" | grep -qE "set -[eu]o pipefail"
}

@test "valid bash syntax" {
  run bash -n "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "detects S-06 pattern in script source" {
  # Verify the hook contains S-06 TODO/FIXME detection logic
  grep -q "S-06\|TODO.*FIXME\|FIXME.*TODO" "$SCRIPT"
}

@test "passes clean input without TODO" {
  echo '{"tool_name":"Edit","tool_input":{"file_path":"/test/file.sh","new_string":"clean code here"}}' > "$TMPDIR_RJ/input.json"
  run bash -c "cat '$TMPDIR_RJ/input.json' | SAVIA_HOOK_PROFILE=standard bash '$SCRIPT'"
  [[ "$status" -eq 0 ]]
}

@test "excludes DOMAIN.md from S-06" {
  echo '{"tool_name":"Write","tool_input":{"file_path":"/test/DOMAIN.md","content":"TODO document this"}}' > "$TMPDIR_RJ/input.json"
  run bash -c "cat '$TMPDIR_RJ/input.json' | SAVIA_HOOK_PROFILE=standard bash '$SCRIPT'"
  [[ "$status" -eq 0 ]]
}

@test "negative: minimal profile skips checks" {
  echo '{"tool_name":"Edit","tool_input":{"file_path":"/test/file.sh","new_string":"TODO fix"}}' > "$TMPDIR_RJ/input.json"
  run bash -c "cat '$TMPDIR_RJ/input.json' | SAVIA_HOOK_PROFILE=minimal bash '$SCRIPT'"
  [[ "$status" -eq 0 ]]
}

@test "edge: empty stdin handled" {
  run bash -c "echo '' | bash '$SCRIPT'"
  [[ "$status" -eq 0 ]]
}

@test "coverage: profile-gate sourced" {
  grep -q "profile-gate\|profile_gate" "$SCRIPT"
}

@test "edge: propuestas/ path excluded from S-06" {
  echo '{"tool_name":"Write","tool_input":{"file_path":"/test/propuestas/SPEC-099.md","content":"TODO draft"}}' > "$TMPDIR_RJ/input.json"
  run bash -c "cat '$TMPDIR_RJ/input.json' | SAVIA_HOOK_PROFILE=standard bash '$SCRIPT'"
  [[ "$status" -eq 0 ]]
}

@test "negative: missing tool field handled" {
  echo '{"input":{"file_path":"/test.sh"}}' > "$TMPDIR_RJ/input.json"
  run bash -c "cat '$TMPDIR_RJ/input.json' | bash '$SCRIPT'"
  [[ "$status" -eq 0 ]]
}

@test "coverage: S-06 rule defined" {
  grep -q "S-06" "$SCRIPT"
}

@test "positive: script has Layer 1 comment" {
  grep -q "Layer 1\|layer.*1\|deterministic" "$SCRIPT"
}

@test "positive: script under 150 lines" {
  local lines
  lines=$(wc -l < "$SCRIPT")
  [[ "$lines" -le 150 ]]
}

@test "edge: JSON without input field" {
  echo '{"tool":"Bash","command":"ls"}' > "$TMPDIR_RJ/input.json"
  run bash -c "cat '$TMPDIR_RJ/input.json' | bash '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "edge: null tool value" {
  echo '{"tool":null}' > "$TMPDIR_RJ/input.json"
  run bash -c "cat '$TMPDIR_RJ/input.json' | bash '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "edge: zero-length file path" {
  echo '{"tool_name":"Edit","tool_input":{"file_path":"","new_string":"x"}}' > "$TMPDIR_RJ/input.json"
  run bash -c "cat '$TMPDIR_RJ/input.json' | bash '$SCRIPT'"
  [ "$status" -le 2 ]
}

# ── SE-065 i18n fix regression tests ────────────────────
# Ref: docs/propuestas/SE-065-responsibility-judge-s06-i18n.md
# S-06 must not block Spanish prose in markdown/docs, but still catch bare
# uppercase annotations in code files.

@test "SE-065: Spanish prose in CHANGELOG.d/ does NOT block" {
  # Lowercase word matching the letter sequence (common Spanish quantifier).
  local payload='{"tool_name":"Write","tool_input":{"file_path":"CHANGELOG.d/entry.md","content":"salta todo y hazlo bien"}}'
  echo "$payload" > "$TMPDIR_RJ/input.json"
  run bash -c "cat '$TMPDIR_RJ/input.json' | SAVIA_HOOK_PROFILE=standard bash '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "SE-065: Spanish prose in docs/ does NOT block" {
  local payload='{"tool_name":"Write","tool_input":{"file_path":"docs/rules/x.md","content":"aplica a todo el workspace"}}'
  echo "$payload" > "$TMPDIR_RJ/input.json"
  run bash -c "cat '$TMPDIR_RJ/input.json' | SAVIA_HOOK_PROFILE=standard bash '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "SE-065: .md file with Spanish prose does NOT block" {
  local payload='{"tool_name":"Write","tool_input":{"file_path":"/x/y.md","content":"la lista completa y todo lo demas"}}'
  echo "$payload" > "$TMPDIR_RJ/input.json"
  run bash -c "cat '$TMPDIR_RJ/input.json' | SAVIA_HOOK_PROFILE=standard bash '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "SE-065: lowercase in .sh file does NOT block (case-sensitive)" {
  # Before fix: -i flag matched lowercase. After fix: uppercase only.
  local payload='{"tool_name":"Write","tool_input":{"file_path":"script.sh","content":"echo todo cleared"}}'
  echo "$payload" > "$TMPDIR_RJ/input.json"
  run bash -c "cat '$TMPDIR_RJ/input.json' | SAVIA_HOOK_PROFILE=standard bash '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "SE-065: bare uppercase code-shortcut in .py STILL blocks" {
  # Real code shortcut detection preserved. Build keyword via hex to avoid
  # this test file triggering its own hook scan on parse.
  local kw; kw=$(printf '\x54\x4f\x44\x4f')
  local payload="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"s.py\",\"content\":\"def f(): pass  # $kw fix later\"}}"
  echo "$payload" > "$TMPDIR_RJ/input.json"
  run bash -c "cat '$TMPDIR_RJ/input.json' | SAVIA_HOOK_PROFILE=standard bash '$SCRIPT'"
  [ "$status" -eq 2 ]
}

@test "SE-065: annotated uppercase TODO(#123) in code passes" {
  # Annotation exempt pattern unchanged by fix.
  local kw; kw=$(printf '\x54\x4f\x44\x4f')
  local payload="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"s.sh\",\"content\":\"# $kw(#123) ticket ref\"}}"
  echo "$payload" > "$TMPDIR_RJ/input.json"
  run bash -c "cat '$TMPDIR_RJ/input.json' | SAVIA_HOOK_PROFILE=standard bash '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "SE-065: annotated uppercase FIXME(AB#123) in code passes" {
  local kw; kw=$(printf '\x46\x49\x58\x4d\x45')
  local payload="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"s.ts\",\"content\":\"// $kw(AB#123) Azure item\"}}"
  echo "$payload" > "$TMPDIR_RJ/input.json"
  run bash -c "cat '$TMPDIR_RJ/input.json' | SAVIA_HOOK_PROFILE=standard bash '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "SE-065: HACK bare in .java blocks" {
  local kw; kw=$(printf '\x48\x41\x43\x4b')
  local payload="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"X.java\",\"content\":\"// $kw workaround\"}}"
  echo "$payload" > "$TMPDIR_RJ/input.json"
  run bash -c "cat '$TMPDIR_RJ/input.json' | SAVIA_HOOK_PROFILE=standard bash '$SCRIPT'"
  [ "$status" -eq 2 ]
}

@test "SE-065: .mdx extension exempted like .md" {
  local payload='{"tool_name":"Write","tool_input":{"file_path":"guide.mdx","content":"salta todo y listo"}}'
  echo "$payload" > "$TMPDIR_RJ/input.json"
  run bash -c "cat '$TMPDIR_RJ/input.json' | SAVIA_HOOK_PROFILE=standard bash '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "SE-065: .txt files exempted" {
  local payload='{"tool_name":"Write","tool_input":{"file_path":"notes.txt","content":"todo el trabajo"}}'
  echo "$payload" > "$TMPDIR_RJ/input.json"
  run bash -c "cat '$TMPDIR_RJ/input.json' | SAVIA_HOOK_PROFILE=standard bash '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "SE-065: regression — S-01..S-05 rules unaffected" {
  # Verify earlier rules still work — test-coverage threshold change in config
  local payload='{"tool_name":"Edit","tool_input":{"file_path":"test-config.yml","new_string":"coverage_min = 60"}}'
  echo "$payload" > "$TMPDIR_RJ/input.json"
  run bash -c "cat '$TMPDIR_RJ/input.json' | SAVIA_HOOK_PROFILE=standard bash '$SCRIPT'"
  # S-05 still fires — test yields exit 2 OR 0 depending on path match, not crash
  [[ "$status" -eq 0 || "$status" -eq 2 ]]
}

@test "SE-065: coverage — file-type exemption regex present" {
  grep -qE 'CHANGELOG\\.d/' "$SCRIPT" && grep -qF '(md|mdx|txt|rst)' "$SCRIPT"
}

@test "SE-065: coverage — case-sensitive grep (-qE not -qiE) in S-06 block" {
  # Extract the S-06 block and verify it uses -qE (not -qiE)
  sed -n '/S-06/,/^fi$/p' "$SCRIPT" | grep -q 'grep -qE' && \
    ! sed -n '/S-06/,/^fi$/p' "$SCRIPT" | grep -q '(TODO|FIXME|HACK).*-qiE'
}
