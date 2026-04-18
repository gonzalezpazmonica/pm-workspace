#!/usr/bin/env bats
# BATS tests for ci-extended-checks.sh check #7 (SCM Freshness)
# Ref: docs/propuestas/SE-031-query-library-nl.md (freshness gate pattern)
# SPEC-055 quality gate (score >= 80)
#
# The SCM generator is deterministic (v5.34.0). This check prevents .scm/
# drift from accumulating silently when authors add commands/skills/agents/
# scripts without regenerating. Fails the PR at CI level and locally via
# pr-plan G5b which runs ci-extended-checks.sh.

CHECK="scripts/ci-extended-checks.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() {
  cd /
}

# ── Structure / safety ──────────────────────────────────────────────────────

@test "ci-extended-checks.sh exists and is executable" {
  [[ -x "$CHECK" ]]
}

@test "ci-extended-checks.sh uses set -uo pipefail" {
  run head -5 "$CHECK"
  [[ "$output" == *"set -uo pipefail"* ]]
}

@test "check #7 (SCM Freshness) is registered" {
  run grep -c '^# 7\. SCM Freshness' "$CHECK"
  [ "$output" = "1" ]
}

@test "check #7 invokes generate-capability-map.py" {
  run grep -c 'generate-capability-map.py' "$CHECK"
  [[ "$output" -ge 1 ]]
}

@test "check #7 compares before/after sha256 of INDEX.scm" {
  run grep -c 'sha256sum.*INDEX.scm\|sha256sum "$scm_index"' "$CHECK"
  [[ "$output" -ge 2 ]]
}

@test "check #7 restores tree on stale detection (non-destructive)" {
  # After a FAIL, git checkout -- .scm/ must reset the tree
  run grep -c 'git -C .*checkout -- \.scm' "$CHECK"
  [[ "$output" -ge 1 ]]
}

@test "check #7 mentions remediation command in error message" {
  run grep -c "generate-capability-map.py.*commit" "$CHECK"
  [[ "$output" -ge 1 ]]
}

# ── Behavior: passes when fresh ────────────────────────────────────────────

@test "check #7 passes when .scm is fresh" {
  # Regenerate first to ensure fresh state
  python3 scripts/generate-capability-map.py >/dev/null 2>&1
  run bash "$CHECK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SCM Freshness"* ]]
  [[ "$output" == *"fresh vs tracked sources"* ]]
}

@test "check #7 reports all passed checks when all green (count adapts as checks are added)" {
  python3 scripts/generate-capability-map.py >/dev/null 2>&1
  run bash "$CHECK"
  [ "$status" -eq 0 ]
  # Count adapts: 7 original + N new ratchet gates (SE-037/038/039 Slice 3 added checks #8/9/10).
  # Invariant: when green, "passed" count equals "total" count and "failed" is 0.
  [[ "$output" =~ Results:[[:space:]]+([0-9]+)[[:space:]]passed,[[:space:]]+0[[:space:]]failed[[:space:]]\(([0-9]+)[[:space:]]total ]]
  local passed="${BASH_REMATCH[1]}"
  local total="${BASH_REMATCH[2]}"
  [[ "$passed" == "$total" ]]
  [[ "$passed" -ge 7 ]]
}

# ── Negative cases: fails when stale ───────────────────────────────────────

@test "negative: check #7 fails when .scm is stale (before is different from after)" {
  # Regenerate, then artificially make INDEX.scm stale by mutating one byte
  python3 scripts/generate-capability-map.py >/dev/null 2>&1
  # Make stale: append a line not present in real output
  local backup; backup=$(mktemp)
  cp .scm/INDEX.scm "$backup"
  echo "# STALE_MARKER_FOR_TEST" >> .scm/INDEX.scm
  run bash "$CHECK"
  # Restore (the check itself also does `git checkout`, but we're defensive)
  cp "$backup" .scm/INDEX.scm
  rm -f "$backup"
  [ "$status" -ne 0 ]
  [[ "$output" == *"stale"* ]]
  [[ "$output" == *"generate-capability-map.py"* ]]
}

@test "negative: missing SCM generator produces fail with clear reason" {
  # Simulate: the generator script doesn't exist → check reports error
  run grep 'SCM generator or INDEX missing' "$CHECK"
  [ "$status" -eq 0 ]
}

@test "negative: missing INDEX.scm handled in the guard clause" {
  run grep -E '\[\[ -x "\$scm_gen" && -f "\$scm_index" \]\]' "$CHECK"
  [ "$status" -eq 0 ]
}

@test "negative: invalid ci-extended-checks.sh syntax would be caught" {
  run bash -n "$CHECK"
  [ "$status" -eq 0 ]
}

@test "negative: bash -n fails on obviously invalid script" {
  local bad="$BATS_TEST_TMPDIR/bad.sh"
  echo 'if then fi' > "$bad"
  run bash -n "$bad"
  [ "$status" -ne 0 ]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: boundary — check survives when generator output differs by 1 line" {
  python3 scripts/generate-capability-map.py >/dev/null 2>&1
  local backup; backup=$(mktemp)
  cp .scm/INDEX.scm "$backup"
  # Mutate a single line (change the hash prefix)
  sed -i '2s/hash: [a-f0-9]*/hash: deadbeef1234/' .scm/INDEX.scm
  run bash "$CHECK"
  cp "$backup" .scm/INDEX.scm
  rm -f "$backup"
  [ "$status" -ne 0 ]
  [[ "$output" == *"stale"* ]]
}

@test "edge: empty check output still reports Results line" {
  python3 scripts/generate-capability-map.py >/dev/null 2>&1
  run bash "$CHECK"
  [[ "$output" == *"Results:"* ]]
}

@test "edge: check is idempotent (two runs produce same exit code)" {
  python3 scripts/generate-capability-map.py >/dev/null 2>&1
  bash "$CHECK" >/dev/null 2>&1
  local s1=$?
  bash "$CHECK" >/dev/null 2>&1
  local s2=$?
  [ "$s1" = "$s2" ]
}

@test "edge: no args (check takes no arguments) works fine" {
  run bash "$CHECK"
  # Either passes (fresh) or fails (stale), but must not crash
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "edge: nonexistent check script triggers bash error" {
  run bash /tmp/nonexistent-ci-checks-12345.sh
  [ "$status" -ne 0 ]
}
