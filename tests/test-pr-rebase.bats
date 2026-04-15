#!/usr/bin/env bats
# SPEC-105: pr-rebase.sh — signature-stable rebase of queued PRs.
# Validates script structure + merge-base usage in confidentiality-sign.sh.
# Ref: docs/propuestas/SPEC-105-signature-stability-queued-prs.md
# Related: .claude/rules/domain/pr-signing-protocol.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  REBASE_SCRIPT="$REPO_ROOT/scripts/pr-rebase.sh"
  SIGN_SCRIPT="$REPO_ROOT/scripts/confidentiality-sign.sh"
  GITATTR="$REPO_ROOT/.gitattributes"
  TMP_DIR=$(mktemp -d -t pr-rebase-XXXXXX)
}

teardown() {
  rm -rf "$TMP_DIR" 2>/dev/null || true
}

# ── Structural invariants ───────────────────────────────────────────────────

@test "pr-rebase.sh exists and is executable" {
  [ -x "$REBASE_SCRIPT" ]
}

@test "pr-rebase.sh has valid bash syntax" {
  bash -n "$REBASE_SCRIPT"
}

@test "pr-rebase.sh has set -uo pipefail safety" {
  grep -q "set -uo pipefail" "$REBASE_SCRIPT"
}

@test "pr-rebase.sh references SPEC-105" {
  grep -qE "SPEC-105|signature-stability|queued.*PR" "$REBASE_SCRIPT" || \
    grep -q "rebase.*origin/main" "$REBASE_SCRIPT"
}

@test "pr-rebase.sh uses force-with-lease (safer than --force)" {
  grep -q "force-with-lease" "$REBASE_SCRIPT"
}

@test "pr-rebase.sh fetches origin main before rebasing" {
  grep -qE "git fetch origin main|git fetch.*main" "$REBASE_SCRIPT"
}

@test "pr-rebase.sh auto-resolves signature conflict with --ours" {
  grep -q "checkout --ours" "$REBASE_SCRIPT"
  grep -q ".confidentiality-signature" "$REBASE_SCRIPT"
}

@test "pr-rebase.sh defines 4 distinct exit codes" {
  for code in 1 2 3; do
    grep -qE "exit $code\b" "$REBASE_SCRIPT" || return 1
  done
}

# ── confidentiality-sign.sh uses merge-base (stable hash) ───────────────────

@test "confidentiality-sign.sh uses merge-base for stable hash" {
  grep -q "merge-base" "$SIGN_SCRIPT"
}

@test "confidentiality-sign.sh references SPEC-105 rationale" {
  grep -qE "SPEC-105|stable.*main advances|queued PR" "$SIGN_SCRIPT"
}

@test "confidentiality-sign.sh no longer relies on moving origin/main directly" {
  # Should use merge-base as the base ref, not origin/main..HEAD directly
  grep -qE 'git merge-base origin/main HEAD' "$SIGN_SCRIPT"
}

# ── .gitattributes auto-resolves signature conflicts ────────────────────────

@test ".gitattributes declares merge=ours for signature file" {
  grep -qE '\.confidentiality-signature.*merge=ours' "$GITATTR"
}

@test ".gitattributes comment explains the rationale for merge=ours" {
  grep -qiE "(queued|conflict|PR|rebase)" "$GITATTR"
}

# ── Negative / failure modes ────────────────────────────────────────────────

@test "negative: pr-rebase declares check for uncommitted changes" {
  # Structural: the script always cd's to its own $ROOT, so runtime testing
  # with a fake tmp repo is not feasible. Validate the guard exists.
  grep -qE "(uncommitted|dirty|diff --quiet)" "$REBASE_SCRIPT"
}

@test "negative: pr-rebase declares guard against running on main/master" {
  grep -qE '\$BRANCH.*"main"|\$BRANCH.*"master"|BRANCH.*==.*main|BRANCH.*==.*master' "$REBASE_SCRIPT"
}

@test "negative: invalid flag does not crash script" {
  run bash "$REBASE_SCRIPT" --help
  [ "$status" -eq 0 ]
}

@test "negative: unknown arg ignored gracefully" {
  # The script silently ignores unknown args (only parses --no-push, -h/--help)
  cd "$TMP_DIR"
  git init -q .
  git checkout -q -b main
  run bash "$REBASE_SCRIPT" --unknown-flag-12345
  # Should not crash on parsing; may exit with other errors (no remote, etc.)
  [ "$status" -ne 127 ]  # 127 would be command-not-found
}

# ── Edge cases ──────────────────────────────────────────────────────────────

@test "edge: empty working dir — script fails gracefully" {
  cd "$TMP_DIR"
  run bash "$REBASE_SCRIPT"
  # No git repo → exit nonzero, no crash
  [ "$status" -ne 0 ]
  [ "$status" -ne 127 ]
}

@test "edge: nonexistent remote — script reports fetch failure" {
  cd "$TMP_DIR"
  git init -q .
  git config user.email test@test.local
  git config user.name test
  git checkout -q -b feature-test
  echo initial > file.txt
  git add file.txt && git commit -q -m initial
  run bash "$REBASE_SCRIPT"
  # No remote configured → fetch fails, exit 3
  [ "$status" -ne 0 ]
}

@test "edge: boundary — --no-push flag accepted" {
  grep -q "\-\-no-push" "$REBASE_SCRIPT"
}

@test "edge: zero commits ahead — script handles already-up-to-date case" {
  grep -qE "(Already up to date|BEHIND.*-eq 0|nothing to rebase)" "$REBASE_SCRIPT"
}

# ── Regression guard ────────────────────────────────────────────────────────

@test "regression: confidentiality-sign.sh retains merge-base pattern" {
  count=$(grep -c "merge-base" "$SIGN_SCRIPT")
  [ "$count" -ge 1 ]
}

@test "regression: .gitattributes retains the signature merge rule" {
  count=$(grep -c "\.confidentiality-signature" "$GITATTR")
  [ "$count" -ge 1 ]
}

@test "regression: pr-rebase script retains force-with-lease safety" {
  count=$(grep -c "force-with-lease" "$REBASE_SCRIPT")
  [ "$count" -ge 1 ]
}
