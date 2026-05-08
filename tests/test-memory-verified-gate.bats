#!/usr/bin/env bats
# BATS tests for .opencode/hooks/memory-verified-gate.sh
# SE-072 Verified Memory axiom: blocks Write to auto-memory without citation.
# Ref: docs/propuestas/SE-072-verified-memory-axiom.md

HOOK=".opencode/hooks/memory-verified-gate.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  TEST_DIR=$(mktemp -d "$TMPDIR/mvg-XXXXXX")
}
teardown() {
  rm -rf "$TEST_DIR" 2>/dev/null || true
  cd /
}

# ── Structural ────────────────────────────────────

@test "hook file exists" { [[ -f "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }
@test "header: SE-072 reference" {
  run grep -c 'SE-072' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "header: PreToolUse event documented" {
  run grep -c 'PreToolUse' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Profile gate ──────────────────────────────────

@test "profile gate: standard tier sourced" {
  run grep -c 'profile_gate "standard"' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Pass-through (non-matching tools/paths) ───────

@test "pass-through: empty stdin exits 0" {
  run bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
}

@test "pass-through: non-Write tool exits 0" {
  cat > "$TEST_DIR/in.json" <<'EOF'
{"tool_name":"Read","tool_input":{"file_path":"/some/path.md"}}
EOF
  run bash "$HOOK" < "$TEST_DIR/in.json"
  [ "$status" -eq 0 ]
}

@test "pass-through: Write outside auto-memory exits 0" {
  cat > "$TEST_DIR/in.json" <<'EOF'
{"tool_name":"Write","tool_input":{"file_path":"/tmp/foo.md","content":"random"}}
EOF
  run bash "$HOOK" < "$TEST_DIR/in.json"
  [ "$status" -eq 0 ]
}

# ── Skip ephemeral / index files ──────────────────

@test "skip: MEMORY.md index file passes silently" {
  cat > "$TEST_DIR/in.json" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"/home/monica/.claude/projects/-home-monica-claude/memory/MEMORY.md","content":"no citations"}}
EOF
  run bash "$HOOK" < "$TEST_DIR/in.json"
  [ "$status" -eq 0 ]
}

@test "skip: session-journal.md ephemeral passes silently" {
  cat > "$TEST_DIR/in.json" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"/home/monica/.claude/projects/-home-monica-claude/memory/session-journal.md","content":"draft notes"}}
EOF
  run bash "$HOOK" < "$TEST_DIR/in.json"
  [ "$status" -eq 0 ]
}

@test "skip: session-hot.md ephemeral passes silently" {
  cat > "$TEST_DIR/in.json" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"/home/monica/.claude/projects/-home-monica-claude/memory/session-hot.md","content":"hot scratchpad"}}
EOF
  run bash "$HOOK" < "$TEST_DIR/in.json"
  [ "$status" -eq 0 ]
}

# ── Block on missing citation ─────────────────────

@test "block: write without citation exits 2" {
  cat > "$TEST_DIR/in.json" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"/home/monica/.claude/projects/-home-monica-claude/memory/test-feedback.md","content":"random thoughts about something"}}
EOF
  run bash "$HOOK" < "$TEST_DIR/in.json"
  [ "$status" -eq 2 ]
}

@test "block: error message references SE-072" {
  cat > "$TEST_DIR/in.json" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"/home/monica/.claude/projects/-home-monica-claude/memory/no-cite.md","content":"empty content"}}
EOF
  run bash "$HOOK" < "$TEST_DIR/in.json"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"SE-072"* || "$output" == *"SE-072"* ]]
}

@test "block: error message lists 5 citation options" {
  cat > "$TEST_DIR/in.json" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"/home/monica/.claude/projects/-home-monica-claude/memory/x.md","content":"nothing"}}
EOF
  run bash "$HOOK" < "$TEST_DIR/in.json"
  [[ "$stderr" == *"File reference"* || "$output" == *"File reference"* ]]
}

# ── Pass on citation patterns ─────────────────────

@test "pass: file:path:line reference" {
  cat > "$TEST_DIR/in.json" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"/home/monica/.claude/projects/-home-monica-claude/memory/x.md","content":"Pattern from scripts/foo.sh:42 was applied"}}
EOF
  run bash "$HOOK" < "$TEST_DIR/in.json"
  [ "$status" -eq 0 ]
}

@test "pass: markdown link to repo file" {
  cat > "$TEST_DIR/in.json" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"/home/monica/.claude/projects/-home-monica-claude/memory/x.md","content":"See [config](docs/rules/pm-config.md)"}}
EOF
  run bash "$HOOK" < "$TEST_DIR/in.json"
  [ "$status" -eq 0 ]
}

@test "pass: explicit Source: keyword" {
  cat > "$TEST_DIR/in.json" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"/home/monica/.claude/projects/-home-monica-claude/memory/x.md","content":"Note about a thing\nSource: bash session 2026-04-25"}}
EOF
  run bash "$HOOK" < "$TEST_DIR/in.json"
  [ "$status" -eq 0 ]
}

@test "pass: explicit Ref: keyword" {
  cat > "$TEST_DIR/in.json" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"/home/monica/.claude/projects/-home-monica-claude/memory/x.md","content":"Some text\nRef: SPEC-NNN"}}
EOF
  run bash "$HOOK" < "$TEST_DIR/in.json"
  [ "$status" -eq 0 ]
}

@test "pass: URL reference" {
  cat > "$TEST_DIR/in.json" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"/home/monica/.claude/projects/-home-monica-claude/memory/x.md","content":"Discovered at https://github.com/foo/bar"}}
EOF
  run bash "$HOOK" < "$TEST_DIR/in.json"
  [ "$status" -eq 0 ]
}

@test "pass: frontmatter type:reference implicit provenance" {
  cat > "$TEST_DIR/in.json" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"/home/monica/.claude/projects/-home-monica-claude/memory/x.md","content":"---\ntype: reference\n---\nNo other refs needed"}}
EOF
  run bash "$HOOK" < "$TEST_DIR/in.json"
  [ "$status" -eq 0 ]
}

# ── Escape hatch ──────────────────────────────────

@test "escape hatch: SAVIA_VERIFIED_MEMORY_DISABLED=true bypasses gate" {
  cat > "$TEST_DIR/in.json" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"/home/monica/.claude/projects/-home-monica-claude/memory/x.md","content":"no citation pattern"}}
EOF
  SAVIA_VERIFIED_MEMORY_DISABLED=true run bash "$HOOK" < "$TEST_DIR/in.json"
  [ "$status" -eq 0 ]
}

# ── Negative cases ────────────────────────────────

@test "negative: invalid JSON stdin exits 0 graceful" {
  echo "not-json" > "$TEST_DIR/in.txt"
  run bash "$HOOK" < "$TEST_DIR/in.txt"
  [ "$status" -eq 0 ]
}

@test "negative: empty file_path exits 0 silent" {
  cat > "$TEST_DIR/in.json" <<'EOF'
{"tool_name":"Write","tool_input":{"content":"x"}}
EOF
  run bash "$HOOK" < "$TEST_DIR/in.json"
  [ "$status" -eq 0 ]
}

@test "negative: unknown tool exits 0 silent" {
  cat > "$TEST_DIR/in.json" <<'EOF'
{"tool_name":"WeirdTool","tool_input":{"file_path":"/x.md"}}
EOF
  run bash "$HOOK" < "$TEST_DIR/in.json"
  [ "$status" -eq 0 ]
}

# ── Edge cases ────────────────────────────────────

@test "edge: empty content blocks (no citation possible)" {
  cat > "$TEST_DIR/in.json" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"/home/monica/.claude/projects/-home-monica-claude/memory/x.md","content":""}}
EOF
  run bash "$HOOK" < "$TEST_DIR/in.json"
  [ "$status" -eq 2 ]
}

@test "edge: large content with citation passes" {
  local big
  big=$(printf 'word %.0s' {1..200})
  cat > "$TEST_DIR/in.json" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"/home/monica/.claude/projects/-home-monica-claude/memory/x.md","content":"$big scripts/foo.sh:1"}}
EOF
  run bash "$HOOK" < "$TEST_DIR/in.json"
  [ "$status" -eq 0 ]
}

@test "edge: zero-length stdin handled" {
  run timeout 3 bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
}

@test "edge: nonexistent path pattern still evaluates citation" {
  cat > "$TEST_DIR/in.json" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"/home/monica/.claude/projects/-home-monica-claude/memory/sub/dir/x.md","content":"Includes path/to/file.py:1"}}
EOF
  run bash "$HOOK" < "$TEST_DIR/in.json"
  [ "$status" -eq 0 ]
}

# ── Isolation ─────────────────────────────────────

@test "isolation: hook does not modify input file" {
  cat > "$TEST_DIR/in.json" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"/home/monica/.claude/projects/-home-monica-claude/memory/x.md","content":"with [link](docs/x.md)"}}
EOF
  before_sha=$(sha256sum "$TEST_DIR/in.json" | awk '{print $1}')
  bash "$HOOK" < "$TEST_DIR/in.json" || true
  after_sha=$(sha256sum "$TEST_DIR/in.json" | awk '{print $1}')
  [[ "$before_sha" == "$after_sha" ]]
}

@test "isolation: read-only — never writes anywhere" {
  before=$(find "$TEST_DIR" -type f | wc -l)
  cat > "$TEST_DIR/in.json" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"/home/monica/.claude/projects/-home-monica-claude/memory/x.md","content":"text"}}
EOF
  bash "$HOOK" < "$TEST_DIR/in.json" || true
  after=$(find "$TEST_DIR" -type f | wc -l)
  [[ "$after" -eq $((before + 1)) ]]  # only the in.json we created
}

@test "coverage: 5 citation patterns documented in source" {
  run grep -c 'has_citation=1' "$HOOK"
  [[ "$output" -ge 5 ]]
}

@test "coverage: SAVIA_VERIFIED_MEMORY_DISABLED escape hatch present" {
  run grep -c 'SAVIA_VERIFIED_MEMORY_DISABLED' "$HOOK"
  [[ "$output" -ge 1 ]]
}
