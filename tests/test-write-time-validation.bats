#!/usr/bin/env bats
# Ref: SPEC-184 / docs/propuestas/SPEC-184-writetime-validator-nonblocking.md
# Tests for write-time non-blocking validators (PostToolUse Edit|Write).

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  HOOK="$PWD/.opencode/hooks/post-write-validate.sh"
  VDIR="$PWD/.opencode/hooks/validators"
  TMPDIR_TEST="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

# ── AC1: hook always exits 0 (warn-only, never blocks) ──────────────────────

@test "AC1: hook exits 0 even when validators emit warnings" {
  local f="$TMPDIR_TEST/banned.md"
  printf 'em-dash \xe2\x80\x94 here\n' > "$f"
  run bash "$HOOK" <<<"{\"tool_input\":{\"file_path\":\"$f\"}}"
  [ "$status" -eq 0 ]
}

@test "AC1: hook exits 0 with malformed input" {
  run bash "$HOOK" <<<"not json"
  [ "$status" -eq 0 ]
}

@test "AC1: hook exits 0 with empty input" {
  run bash "$HOOK" <<<""
  [ "$status" -eq 0 ]
}

# ── AC2: em-dash detection ──────────────────────────────────────────────────

@test "AC2: em-dash triggers warning with U+2014 codepoint and ASCII suggestion" {
  local f="$TMPDIR_TEST/dash.md"
  printf 'foo \xe2\x80\x94 bar\n' > "$f"
  run bash "$VDIR/validate-banned-unicode.sh" "$f"
  [ "$status" -eq 0 ]
  [[ "$output" == *"U+2014"* ]]
  [[ "$output" == *"--"* ]]
  [[ "$output" == *"EM DASH"* ]]
}

@test "AC2: NBSP triggers warning with U+00A0 codepoint" {
  local f="$TMPDIR_TEST/nbsp.md"
  printf 'foo\xc2\xa0bar\n' > "$f"
  run bash "$VDIR/validate-banned-unicode.sh" "$f"
  [[ "$output" == *"U+00A0"* ]]
}

@test "AC2: ellipsis triggers warning with U+2026 codepoint" {
  local f="$TMPDIR_TEST/ell.md"
  printf 'wait\xe2\x80\xa6done\n' > "$f"
  run bash "$VDIR/validate-banned-unicode.sh" "$f"
  [[ "$output" == *"U+2026"* ]]
  [[ "$output" == *"..."* ]]
}

@test "AC2: clean ASCII file produces no warnings" {
  local f="$TMPDIR_TEST/clean.md"
  echo "all ascii here -- no problem..." > "$f"
  run bash "$VDIR/validate-banned-unicode.sh" "$f"
  [ "$status" -eq 0 ]
  [[ "$output" != *"WARN"* ]]
}

# ── AC3: missing frontmatter on SPEC docs ───────────────────────────────────

@test "AC3: SPEC doc without frontmatter triggers warning" {
  mkdir -p "$TMPDIR_TEST/docs/propuestas"
  local f="$TMPDIR_TEST/docs/propuestas/SPEC-999-x.md"
  echo "no frontmatter" > "$f"
  run bash "$VDIR/validate-frontmatter.sh" "$f"
  [[ "$output" == *"missing YAML frontmatter"* ]]
}

@test "AC3: SPEC doc missing 'status:' field triggers warning" {
  mkdir -p "$TMPDIR_TEST/docs/propuestas"
  local f="$TMPDIR_TEST/docs/propuestas/SPEC-998-x.md"
  cat > "$f" <<'EOF'
---
spec_id: SPEC-998
title: Test
---
EOF
  run bash "$VDIR/validate-frontmatter.sh" "$f"
  [[ "$output" == *"status"* ]]
}

@test "AC3: SPEC doc with all required fields produces no warning" {
  mkdir -p "$TMPDIR_TEST/docs/propuestas"
  local f="$TMPDIR_TEST/docs/propuestas/SPEC-997-x.md"
  cat > "$f" <<'EOF'
---
spec_id: SPEC-997
title: Test
status: PROPOSED
---
body
EOF
  run bash "$VDIR/validate-frontmatter.sh" "$f"
  [[ "$output" != *"WARN"* ]]
}

# ── AC4: bypass directories ─────────────────────────────────────────────────

@test "AC4: file under output/ is bypassed (no warnings)" {
  mkdir -p "$TMPDIR_TEST/output"
  local f="$TMPDIR_TEST/output/dirty.md"
  printf 'em-dash \xe2\x80\x94 here\n' > "$f"
  run bash "$HOOK" <<<"{\"tool_input\":{\"file_path\":\"$f\"}}"
  [ "$status" -eq 0 ]
  [[ "$output" != *"WARN"* ]]
}

@test "AC4: file under .git/ is bypassed" {
  mkdir -p "$TMPDIR_TEST/.git"
  local f="$TMPDIR_TEST/.git/dirty.md"
  printf 'em-dash \xe2\x80\x94 here\n' > "$f"
  run bash "$HOOK" <<<"{\"tool_input\":{\"file_path\":\"$f\"}}"
  [[ "$output" != *"WARN"* ]]
}

@test "AC4: file under node_modules/ is bypassed" {
  mkdir -p "$TMPDIR_TEST/node_modules"
  local f="$TMPDIR_TEST/node_modules/x.md"
  printf 'em-dash \xe2\x80\x94 here\n' > "$f"
  run bash "$HOOK" <<<"{\"tool_input\":{\"file_path\":\"$f\"}}"
  [[ "$output" != *"WARN"* ]]
}

# ── AC5: global toggle ──────────────────────────────────────────────────────

@test "AC5: SAVIA_WRITE_VALIDATORS_ENABLED=false silences hook completely" {
  local f="$TMPDIR_TEST/banned.md"
  printf 'em-dash \xe2\x80\x94 here\n' > "$f"
  SAVIA_WRITE_VALIDATORS_ENABLED=false run bash "$HOOK" <<<"{\"tool_input\":{\"file_path\":\"$f\"}}"
  [ "$status" -eq 0 ]
  [[ "$output" != *"WARN"* ]]
}

# ── Spec status validator ───────────────────────────────────────────────────

@test "spec-status: invalid status enum triggers warning" {
  mkdir -p "$TMPDIR_TEST/docs/propuestas"
  local f="$TMPDIR_TEST/docs/propuestas/SPEC-996-x.md"
  cat > "$f" <<'EOF'
---
spec_id: SPEC-996
title: Test
status: BANANA
---
EOF
  run bash "$VDIR/validate-spec-status.sh" "$f"
  [[ "$output" == *"BANANA"* ]]
  [[ "$output" == *"PROPOSED"* ]]
}

@test "spec-status: valid PROPOSED status produces no warning" {
  mkdir -p "$TMPDIR_TEST/docs/propuestas"
  local f="$TMPDIR_TEST/docs/propuestas/SPEC-995-x.md"
  cat > "$f" <<'EOF'
---
spec_id: SPEC-995
title: Test
status: PROPOSED
---
EOF
  run bash "$VDIR/validate-spec-status.sh" "$f"
  [[ "$output" != *"WARN"* ]]
}

@test "spec-status: non-SPEC file is ignored" {
  local f="$TMPDIR_TEST/random.md"
  echo "status: BANANA" > "$f"
  run bash "$VDIR/validate-spec-status.sh" "$f"
  [[ "$output" != *"WARN"* ]]
}

# ── Memory entry length validator ───────────────────────────────────────────

@test "memory-length: entry >150 chars triggers warning" {
  mkdir -p "$TMPDIR_TEST/external-memory/auto"
  local f="$TMPDIR_TEST/external-memory/auto/MEMORY.md"
  printf -- '- decision: %s\n' "$(printf 'x%.0s' {1..200})" > "$f"
  run bash "$VDIR/validate-memory-entry-length.sh" "$f"
  [[ "$output" == *"cap=150"* ]]
}

@test "memory-length: entry <=150 chars produces no warning" {
  mkdir -p "$TMPDIR_TEST/external-memory/auto"
  local f="$TMPDIR_TEST/external-memory/auto/MEMORY.md"
  echo "- short entry under cap" > "$f"
  run bash "$VDIR/validate-memory-entry-length.sh" "$f"
  [[ "$output" != *"WARN"* ]]
}

@test "memory-length: non-memory file is ignored" {
  local f="$TMPDIR_TEST/random.md"
  printf -- '- %s\n' "$(printf 'x%.0s' {1..300})" > "$f"
  run bash "$VDIR/validate-memory-entry-length.sh" "$f"
  [[ "$output" != *"WARN"* ]]
}

# ── AC7: latency ────────────────────────────────────────────────────────────

@test "AC7: hook completes under 200ms on a small file" {
  local f="$TMPDIR_TEST/small.md"
  echo "small file ascii content" > "$f"
  local start end ms
  start=$(date +%s%N)
  bash "$HOOK" <<<"{\"tool_input\":{\"file_path\":\"$f\"}}" >/dev/null 2>&1
  end=$(date +%s%N)
  ms=$(( (end - start) / 1000000 ))
  [ "$ms" -lt 200 ]
}

# ── Negative cases ──────────────────────────────────────────────────────────

@test "neg: hook with non-md file extension is no-op" {
  local f="$TMPDIR_TEST/test.txt"
  printf 'em-dash \xe2\x80\x94 here\n' > "$f"
  run bash "$HOOK" <<<"{\"tool_input\":{\"file_path\":\"$f\"}}"
  [[ "$output" != *"WARN"* ]]
}

@test "neg: hook with nonexistent file is no-op" {
  run bash "$HOOK" <<<"{\"tool_input\":{\"file_path\":\"$TMPDIR_TEST/nope.md\"}}"
  [ "$status" -eq 0 ]
  [[ "$output" != *"WARN"* ]]
}

@test "neg: validators bad-path arg returns 0 silently" {
  run bash "$VDIR/validate-banned-unicode.sh" "$TMPDIR_TEST/missing.md"
  [ "$status" -eq 0 ]
  [[ "$output" != *"WARN"* ]]
}

# ── Edge cases ──────────────────────────────────────────────────────────────

@test "edge: empty markdown file produces no warnings" {
  local f="$TMPDIR_TEST/empty.md"
  : > "$f"
  run bash "$HOOK" <<<"{\"tool_input\":{\"file_path\":\"$f\"}}"
  [ "$status" -eq 0 ]
  [[ "$output" != *"WARN"* ]]
}

@test "edge: large file (1000 lines) completes" {
  local f="$TMPDIR_TEST/big.md"
  for i in $(seq 1 1000); do echo "line $i ascii"; done > "$f"
  run bash "$HOOK" <<<"{\"tool_input\":{\"file_path\":\"$f\"}}"
  [ "$status" -eq 0 ]
}

# ── Safety verification ─────────────────────────────────────────────────────

@test "safety: hook script uses set -uo pipefail" {
  grep -q "set -uo pipefail" "$HOOK"
}

@test "safety: settings.json registers post-write-validate hook" {
  grep -q "post-write-validate" .claude/settings.json
}

@test "safety: doc rule exists" {
  [ -f "docs/rules/domain/write-time-validation.md" ]
}
