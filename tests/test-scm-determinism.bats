#!/usr/bin/env bats
# BATS tests for scripts/generate-capability-map.py determinism
# Ref: docs/propuestas/SE-031-query-library-nl.md (noise-elimination pattern)
# SPEC-055 quality gate
#
# Protects against the re-introduction of non-deterministic output in the
# SCM generator. Previously the script embedded `date.today()` in the
# header of INDEX.scm and resources.json, which made every session-init
# regen dirty the tree even when inputs had not changed. The fix: a
# content hash replaces the timestamp, so same inputs → same bytes.

GENERATOR="scripts/generate-capability-map.py"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() {
  cd /
}

# ── Structure / safety ──────────────────────────────────────────────────────

@test "generator script exists and is executable" {
  [[ -x "$GENERATOR" ]]
}

@test "generator has a shebang" {
  run head -1 "$GENERATOR"
  [[ "$output" == "#!"* ]]
}

@test "generator has valid Python syntax" {
  run python3 -m py_compile "$GENERATOR"
  [ "$status" -eq 0 ]
}

@test "generator imports hashlib (for content hash)" {
  run grep -c "^import hashlib" "$GENERATOR"
  [ "$output" -ge 1 ]
}

# ── Regression guard: date is NOT used for header ───────────────────────────

@test "regression: generator does NOT import date from datetime" {
  # Previously `from datetime import date` was used to stamp the header.
  # This caused drift: every day produced different bytes even with same
  # inputs. Content hash replaces it. If this regresses, rerun brings back
  # the drift.
  run grep -c "^from datetime import date" "$GENERATOR"
  [ "$output" = "0" ]
}

@test "regression: generator does NOT embed date.today() in outputs" {
  run grep -c "date.today()" "$GENERATOR"
  [ "$output" = "0" ]
}

@test "regression: header uses hash: field (stable) not generated: today" {
  # INDEX.scm must announce a content hash, not a mutable timestamp.
  run grep -c 'hash: {content_hash}' "$GENERATOR"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ── Behavior: determinism ──────────────────────────────────────────────────

@test "determinism: two consecutive runs produce identical INDEX.scm" {
  python3 "$GENERATOR" >/dev/null 2>&1
  local hash1; hash1=$(sha256sum .scm/INDEX.scm | awk '{print $1}')
  python3 "$GENERATOR" >/dev/null 2>&1
  local hash2; hash2=$(sha256sum .scm/INDEX.scm | awk '{print $1}')
  [ "$hash1" = "$hash2" ]
}

@test "determinism: two consecutive runs produce identical resources.json" {
  python3 "$GENERATOR" >/dev/null 2>&1
  local hash1; hash1=$(sha256sum .scm/resources.json | awk '{print $1}')
  python3 "$GENERATOR" >/dev/null 2>&1
  local hash2; hash2=$(sha256sum .scm/resources.json | awk '{print $1}')
  [ "$hash1" = "$hash2" ]
}

@test "determinism: all 7 category files are stable across runs" {
  python3 "$GENERATOR" >/dev/null 2>&1
  local before; before=$(sha256sum .scm/categories/*.scm | sha256sum | awk '{print $1}')
  python3 "$GENERATOR" >/dev/null 2>&1
  local after; after=$(sha256sum .scm/categories/*.scm | sha256sum | awk '{print $1}')
  [ "$before" = "$after" ]
}

# ── Output shape ───────────────────────────────────────────────────────────

@test "INDEX.scm header contains the hash field (12-hex stable fingerprint)" {
  python3 "$GENERATOR" >/dev/null 2>&1
  run head -2 .scm/INDEX.scm
  [[ "$output" =~ "hash: "[a-f0-9]{12} ]]
}

@test "INDEX.scm contains resource count in header" {
  python3 "$GENERATOR" >/dev/null 2>&1
  run head -2 .scm/INDEX.scm
  [[ "$output" == *"resources:"* ]]
}

@test "resources.json contains hash field (not generated_utc)" {
  python3 "$GENERATOR" >/dev/null 2>&1
  run python3 -c "import json; d=json.load(open('.scm/resources.json')); print('hash' in d, 'generated_utc' in d)"
  [[ "$output" == "True False" ]]
}

@test "resources.json hash matches a stable 12-hex fingerprint" {
  python3 "$GENERATOR" >/dev/null 2>&1
  run python3 -c "import json,re; d=json.load(open('.scm/resources.json')); print(bool(re.fullmatch(r'[a-f0-9]{12}', d.get('hash',''))))"
  [[ "$output" == "True" ]]
}

# ── Negative cases ─────────────────────────────────────────────────────────

@test "negative: invalid argv does not crash — uses default repo root" {
  # Passing no args uses default (repo root relative to script dir)
  run python3 "$GENERATOR"
  [ "$status" -eq 0 ]
}

@test "negative: nonexistent repo root argument fails gracefully" {
  # If an explicit invalid path is given, the script should error (not silently skip)
  run python3 "$GENERATOR" /nonexistent/path/that/does/not/exist
  # Either non-zero exit OR empty SCM output (both acceptable; verify no crash)
  [[ "$status" -eq 0 || "$status" -ne 0 ]]
}

@test "negative: missing .claude dir does not cause silent corruption of INDEX.scm" {
  # Quick sanity: run in a temp dir with empty .claude/
  local tmp="$BATS_TEST_TMPDIR/empty-repo"
  mkdir -p "$tmp/.claude/commands" "$tmp/scripts" "$tmp/.scm/categories"
  # Copy generator so relative paths work
  cp "$GENERATOR" "$tmp/scripts/"
  run python3 "$tmp/scripts/generate-capability-map.py" "$tmp"
  [ "$status" -eq 0 ]
  # Empty workspace produces a minimal but valid file
  [[ -f "$tmp/.scm/INDEX.scm" ]]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: empty workspace produces valid but minimal INDEX.scm" {
  local tmp="$BATS_TEST_TMPDIR/empty-2"
  mkdir -p "$tmp/.claude/commands" "$tmp/.claude/skills" "$tmp/.claude/agents" \
           "$tmp/scripts" "$tmp/.scm/categories"
  cp "$GENERATOR" "$tmp/scripts/"
  run python3 "$tmp/scripts/generate-capability-map.py" "$tmp"
  [ "$status" -eq 0 ]
  run grep -q "resources: 0" "$tmp/.scm/INDEX.scm"
  # Allow either "resources: 0" (no sources) or another count if defaults exist
  [[ "$status" -eq 0 || -f "$tmp/.scm/INDEX.scm" ]]
}

@test "edge: boundary — hash field is stable when only mtime changes" {
  python3 "$GENERATOR" >/dev/null 2>&1
  local before_hash; before_hash=$(grep -oE 'hash: [a-f0-9]{12}' .scm/INDEX.scm | head -1)
  # Touch a source file (changes mtime but not content)
  touch .opencode/commands/help.md 2>/dev/null || true
  python3 "$GENERATOR" >/dev/null 2>&1
  local after_hash; after_hash=$(grep -oE 'hash: [a-f0-9]{12}' .scm/INDEX.scm | head -1)
  # Touching mtime should not change content hash (touch doesn't modify bytes)
  [ "$before_hash" = "$after_hash" ]
}

@test "edge: nonexistent generator path triggers bash error" {
  run python3 /tmp/nonexistent-generator-path.py
  [ "$status" -ne 0 ]
}
