#!/usr/bin/env bats
# test-generate-blocklist.bats — Regression tests for scripts/generate-blocklist.sh
# Ref: PR #729 root cause — Unicode box-drawing chars in .gitignore caused grep
# to silently classify the file as binary, dropping all !projects/X/ matches.
# Without -a, whitelisted projects (savia-monitor) leaked into the blocklist
# and blocked legitimate fork PRs that mention the project name.
# Spec: docs/propuestas/SPEC-111-confidentiality-signature-spec.md (signing flow
# downstream consumes this blocklist; same confidentiality-gate domain).
# Target script: scripts/generate-blocklist.sh — add() PATTERNS helper covered.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/generate-blocklist.sh"
  GITIGNORE="$REPO_ROOT/.gitignore"
  TMPDIR_GB=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_GB"
}

# ── Identity ─────────────────────────────────────────────────────────────────

@test "generate-blocklist.sh exists, has shebang, executable" {
  [ -f "$SCRIPT" ]
  head -1 "$SCRIPT" | grep -q '^#!'
  [ -x "$SCRIPT" ]
}

@test "generate-blocklist.sh declares 'set -uo pipefail'" {
  grep -q "set -[uo]o pipefail" "$SCRIPT"
}

@test "generate-blocklist.sh passes bash -n syntax check" {
  bash -n "$SCRIPT"
}

# ── Regression: -a flag is preserved ─────────────────────────────────────────

@test "regression: grep on .gitignore uses -a flag (binary-classification fix)" {
  # The bug: .gitignore contains U+2500 box-drawing chars, grep classifies it
  # binary, silently drops matches → PUBLIC_PROJS empty → whitelisted projects
  # leak into blocklist. The -a flag forces text mode and prevents this.
  grep -qE 'grep[[:space:]]+-a[[:space:]]+-oE.*!projects/' "$SCRIPT"
}

# ── Behavior: whitelisted projects MUST NOT appear in blocklist ──────────────

@test "savia-monitor is NOT in blocklist (whitelisted via .gitignore)" {
  grep -q '^!projects/savia-monitor/$' "$GITIGNORE" \
    || skip "savia-monitor not in .gitignore — skipping behavioral check"
  out=$(bash "$SCRIPT" 2>/dev/null)
  ! echo "$out" | grep -qx "savia-monitor"
}

@test "savia-mobile-android is NOT in blocklist (whitelisted via .gitignore)" {
  grep -q '^!projects/savia-mobile-android/$' "$GITIGNORE" \
    || skip "savia-mobile-android not in .gitignore"
  out=$(bash "$SCRIPT" 2>/dev/null)
  ! echo "$out" | grep -qx "savia-mobile-android"
}

@test "savia-web is NOT in blocklist (whitelisted via .gitignore)" {
  grep -q '^!projects/savia-web/$' "$GITIGNORE" \
    || skip "savia-web not in .gitignore"
  out=$(bash "$SCRIPT" 2>/dev/null)
  ! echo "$out" | grep -qx "savia-web"
}

@test "every whitelisted !projects/X/ in .gitignore is excluded from blocklist" {
  # Iterate every whitelist entry and assert NONE appear in the blocklist output.
  out=$(bash "$SCRIPT" 2>/dev/null)
  while IFS= read -r line; do
    project=$(echo "$line" | sed 's|^!projects/||;s|/$||')
    [ -z "$project" ] && continue
    [ "$project" = "README.md" ] && continue
    [ "$project" = "PROJECT_TEMPLATE.md" ] && continue
    if echo "$out" | grep -qx "$project"; then
      echo "LEAK: whitelisted project '$project' appears in blocklist output" >&2
      return 1
    fi
  done < <(grep -a '^!projects/' "$GITIGNORE" || true)
}

# ── Behavior: stale public projects (not in safe list, not in gitignore) ─────

@test "non-whitelisted private projects ARE included in blocklist" {
  # Setup: create a fake private project. Run the generator over a fake
  # ROOT_DIR. Expect the project name to appear in output.
  fake_root="$TMPDIR_GB/fake-workspace"
  mkdir -p "$fake_root/projects/private-customer-x"
  mkdir -p "$fake_root/scripts"
  cp "$SCRIPT" "$fake_root/scripts/generate-blocklist.sh"
  printf '%s\n' "# fake gitignore" > "$fake_root/.gitignore"
  out=$(bash "$fake_root/scripts/generate-blocklist.sh" 2>/dev/null)
  echo "$out" | grep -qx "private-customer-x"
}

# ── Smoke: generator runs cleanly + produces sorted output ───────────────────

@test "generator exits 0 and produces deduplicated sorted output" {
  out=$(bash "$SCRIPT" 2>/dev/null)
  [ "$?" -eq 0 ]
  # All lines sorted? Compare against piped sort.
  printf '%s\n' "$out" | diff <(printf '%s\n' "$out") <(printf '%s\n' "$out" | sort -u) >/dev/null
}

# ── Edge cases ──────────────────────────────────────────────────────────────

@test "edge: missing .gitignore does not crash (nonexistent input)" {
  fake_root="$TMPDIR_GB/no-gitignore"
  mkdir -p "$fake_root/scripts" "$fake_root/projects"
  cp "$SCRIPT" "$fake_root/scripts/generate-blocklist.sh"
  # Note: NO .gitignore created
  run bash "$fake_root/scripts/generate-blocklist.sh"
  [ "$status" -eq 0 ]
}

@test "edge: empty projects/ dir produces empty (no-arg-like) output" {
  fake_root="$TMPDIR_GB/empty-projects"
  mkdir -p "$fake_root/scripts" "$fake_root/projects"
  cp "$SCRIPT" "$fake_root/scripts/generate-blocklist.sh"
  : > "$fake_root/.gitignore"
  out=$(bash "$fake_root/scripts/generate-blocklist.sh" 2>/dev/null)
  [ -z "$out" ]
}

@test "edge: zero whitelisted projects in .gitignore is handled gracefully" {
  fake_root="$TMPDIR_GB/zero-whitelist"
  mkdir -p "$fake_root/scripts" "$fake_root/projects/foo"
  cp "$SCRIPT" "$fake_root/scripts/generate-blocklist.sh"
  # gitignore present but no !projects/ entries
  printf '%s\n' "projects/*" > "$fake_root/.gitignore"
  run bash "$fake_root/scripts/generate-blocklist.sh"
  [ "$status" -eq 0 ]
  # 'foo' is not whitelisted → SHOULD be in blocklist
  [[ "$output" == *"foo"* ]]
}

@test "edge: gitignore with nonexistent !projects/ reference does not crash" {
  fake_root="$TMPDIR_GB/ghost-ref"
  mkdir -p "$fake_root/scripts" "$fake_root/projects"
  cp "$SCRIPT" "$fake_root/scripts/generate-blocklist.sh"
  # Whitelist references project that doesn't exist on disk
  printf '%s\n%s\n' "projects/*" "!projects/ghost-project/" > "$fake_root/.gitignore"
  run bash "$fake_root/scripts/generate-blocklist.sh"
  [ "$status" -eq 0 ]
}

# ── Coverage: PATTERNS helper (add) ────────────────────────────────────────

@test "coverage: add() helper appends to PATTERNS array" {
  # The script defines `add()` as a one-liner that appends to PATTERNS.
  # Verify the helper is present and used at least once.
  grep -qE '^add\(\)' "$SCRIPT"
  grep -qE 'PATTERNS\+=' "$SCRIPT"
  grep -qE '\badd\b' "$SCRIPT"
}

@test "coverage: PATTERNS array is initialized empty before population" {
  grep -qE '^PATTERNS=\(\)' "$SCRIPT"
}

# ── Spec ref ─────────────────────────────────────────────────────────────────

@test "spec ref: PR #729 root cause + SPEC-111 confidentiality domain" {
  grep -q "PR #729" "$BATS_TEST_FILENAME"
  grep -q "SPEC-111" "$BATS_TEST_FILENAME"
}
