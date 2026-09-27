#!/usr/bin/env bats
# BATS tests for SPEC-SE-012 Module 3 + Module 4 scripts.
# Consolida tests de 2 scripts porque ambos son signal-noise reduction
# tooling (ratio ruido/señal en CI+flujo PR).
#
# Scripts:
#   - scripts/pr-plan-queue-check.sh  (Module 4 — CHANGELOG version collision)
#   - scripts/pre-push-bats-critical.sh (Module 3 — selective BATS runner)
#
# Ref: SPEC-SE-012, ROADMAP.md §Tier 5
# Safety: ambos scripts con `set -uo pipefail`, read-only (no git mutations).

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

# Throwaway git repo with one commit on main and nothing changed: the runner
# must never be pointed at the working branch (it would run, and recurse into,
# whatever suites the branch touches).
clean_repo() {
  local repo="$BATS_TEST_TMPDIR/clean-repo"
  git init -q -b main "$repo"
  git -C "$repo" -c user.name=t -c user.email=t@example.invalid \
    commit -q --allow-empty -m init
  echo "$repo"
}

# Stub gh on PATH: never talk to the real GitHub from tests.
# $1 = JSON for `gh pr list`; $2 = CHANGELOG body served by `gh api`.
stub_gh() {
  local bin="$BATS_TEST_TMPDIR/stub-bin"
  mkdir -p "$bin"
  printf '%s' "$1" > "$bin/prs.json"
  printf '%s' "$2" | base64 -w0 > "$bin/changelog.b64"
  cat > "$bin/gh" <<STUB
#!/usr/bin/env bash
case "\$1" in
  pr)  cat "$bin/prs.json" ;;
  api) cat "$bin/changelog.b64" ;;
esac
STUB
  chmod +x "$bin/gh"
  export PATH="$bin:$PATH"
}

teardown() {
  cd /
}

# ── Structure / existence ──────────────────────────────────────────────────

@test "pr-plan-queue-check.sh exists and is executable" {
  [[ -x "scripts/pr-plan-queue-check.sh" ]]
}

@test "pre-push-bats-critical.sh exists and is executable" {
  [[ -x "scripts/pre-push-bats-critical.sh" ]]
}

# ── Safety ─────────────────────────────────────────────────────────────────

@test "queue-check uses set -uo pipefail" {
  run grep -cE '^set -[uo]+ pipefail' "scripts/pr-plan-queue-check.sh"
  [[ "$output" -ge 1 ]]
}

@test "pre-push-bats uses set -uo pipefail" {
  run grep -cE '^set -[uo]+ pipefail' "scripts/pre-push-bats-critical.sh"
  [[ "$output" -ge 1 ]]
}

@test "queue-check passes bash -n" {
  run bash -n scripts/pr-plan-queue-check.sh
  [ "$status" -eq 0 ]
}

@test "pre-push-bats passes bash -n" {
  run bash -n scripts/pre-push-bats-critical.sh
  [ "$status" -eq 0 ]
}

# ── CLI surface ────────────────────────────────────────────────────────────

@test "queue-check --help exits 0" {
  run bash scripts/pr-plan-queue-check.sh --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"local-version"* ]]
}

@test "pre-push-bats --help exits 0" {
  run bash scripts/pre-push-bats-critical.sh --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"base"* ]]
}

@test "queue-check rejects unknown arg" {
  run bash scripts/pr-plan-queue-check.sh --bogus
  [ "$status" -eq 2 ]
}

@test "pre-push-bats rejects unknown arg" {
  run bash scripts/pre-push-bats-critical.sh --bogus
  [ "$status" -eq 2 ]
}

# ── Graceful degradation ───────────────────────────────────────────────────

@test "queue-check skips when PR_PLAN_SKIP_QUEUE_CHECK=1" {
  run env PR_PLAN_SKIP_QUEUE_CHECK=1 bash scripts/pr-plan-queue-check.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipped"* ]]
}

@test "queue-check skips silently when gh missing (narrow PATH)" {
  # PATH with only what runs before the gh probe; gh may live in /usr/bin.
  local bin="$BATS_TEST_TMPDIR/no-gh-bin"
  mkdir -p "$bin"
  ln -s "$(command -v git)" "$bin/git"
  run env PATH="$bin" "$BASH" scripts/pr-plan-queue-check.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"gh CLI not installed"* ]]
}

@test "queue-check --quiet suppresses output" {
  run env PR_PLAN_SKIP_QUEUE_CHECK=1 bash scripts/pr-plan-queue-check.sh --quiet
  [ "$status" -eq 0 ]
  # Quiet mode should emit nothing
  [[ -z "$output" ]]
}

@test "pre-push-bats exits 0 when no changes" {
  cd "$(clean_repo)"
  run bash "$BATS_TEST_DIRNAME/../scripts/pre-push-bats-critical.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no changed files detected"* ]]
}

@test "pre-push-bats: nested invocation is a no-op (no recursion)" {
  run env SAVIA_PRE_PUSH_BATS_ACTIVE=1 bash scripts/pre-push-bats-critical.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"nested invocation skipped"* ]]
}

# ── Version detection ──────────────────────────────────────────────────────

@test "queue-check detects local version from CHANGELOG" {
  stub_gh '[]' ''
  run bash scripts/pr-plan-queue-check.sh --local-version 9.9.9
  [ "$status" -eq 0 ]
  [[ "$output" == *"local top version = 9.9.9"* ]]
  [[ "$output" == *"no open PRs"* ]]
}

@test "queue-check blocks when an open PR claims the same version" {
  stub_gh '[{"number":7,"headRefName":"agent/other"}]' $'# Changelog\n\n## [9.9.9] - 2026-01-01\n'
  run bash scripts/pr-plan-queue-check.sh --local-version 9.9.9
  [ "$status" -eq 1 ]
  [[ "$output" == *"COLLISION"*"#7"* ]]
}

@test "queue-check passes when open PRs claim other versions" {
  stub_gh '[{"number":7,"headRefName":"agent/other"}]' $'# Changelog\n\n## [9.9.8] - 2026-01-01\n'
  run bash scripts/pr-plan-queue-check.sh --local-version 9.9.9
  [ "$status" -eq 0 ]
  [[ "$output" != *"COLLISION"* ]]
}

@test "queue-check --local-version override is accepted" {
  run env PR_PLAN_SKIP_QUEUE_CHECK=1 bash scripts/pr-plan-queue-check.sh --local-version 9.9.9
  [ "$status" -eq 0 ]
}

# ── Mapping (pre-push-bats) ────────────────────────────────────────────────

@test "pre-push-bats maps hook files to their tests" {
  run grep -cE '\.opencode/hooks|\.claude/hooks' "scripts/pre-push-bats-critical.sh"
  [[ "$output" -ge 2 ]]
}

@test "pre-push-bats maps script files to their tests" {
  run grep -cE 'scripts/\*\.sh|scripts/\*\.py' "scripts/pre-push-bats-critical.sh"
  [[ "$output" -ge 1 ]]
}

@test "pre-push-bats maps skill files to their tests" {
  run grep -c 'SKILL.md\|DOMAIN.md' "scripts/pre-push-bats-critical.sh"
  [[ "$output" -ge 1 ]]
}

@test "pre-push-bats deduplicates test paths" {
  run grep -c 'sort -u' "scripts/pre-push-bats-critical.sh"
  [[ "$output" -ge 1 ]]
}

# ── Negative cases ─────────────────────────────────────────────────────────

@test "negative: queue-check invalid arg value still rejected" {
  run bash scripts/pr-plan-queue-check.sh --local-version
  # Missing value — should fail
  [ "$status" -ne 0 ]
}

@test "negative: pre-push-bats invalid --base value does not crash" {
  cd "$(clean_repo)"
  run bash "$BATS_TEST_DIRNAME/../scripts/pre-push-bats-critical.sh" --base nonexistent-branch-xyz --quiet
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "negative: queue-check handles missing CHANGELOG gracefully" {
  local fake="$BATS_TEST_TMPDIR/no-changelog"
  mkdir -p "$fake"
  cd "$fake"
  # Don't skip — let it detect missing CHANGELOG
  run bash "$BATS_TEST_DIRNAME/../scripts/pr-plan-queue-check.sh"
  [ "$status" -eq 0 ]
}

@test "negative: network timeout in gh call does not hang" {
  # The timeout commands in the script bound gh calls to 10s + 8s.
  # Verify they're present.
  run grep -cE 'timeout [0-9]+ gh' "scripts/pr-plan-queue-check.sh"
  [[ "$output" -ge 2 ]]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: queue-check excludes current branch from comparison" {
  run grep -c 'current_branch' "scripts/pr-plan-queue-check.sh"
  [[ "$output" -ge 2 ]]
}

@test "edge: pre-push-bats test mapping is in a function (testable)" {
  run grep -c 'map_file_to_test' "scripts/pre-push-bats-critical.sh"
  [[ "$output" -ge 2 ]]
}

@test "edge: both scripts reference SPEC-SE-012" {
  run grep -l 'SPEC-SE-012' scripts/pr-plan-queue-check.sh scripts/pre-push-bats-critical.sh
  local n
  n=$(echo "$output" | wc -l)
  [[ "$n" -ge 2 ]]
}

@test "edge: queue-check suggestion bumps minor version" {
  run grep -cE 'next_minor|bump to' "scripts/pr-plan-queue-check.sh"
  [[ "$output" -ge 1 ]]
}

@test "edge: pre-push-bats reports count of related tests before running" {
  run grep -cE 'related .bats test file|running.*related' "scripts/pre-push-bats-critical.sh"
  [[ "$output" -ge 1 ]]
}

# ── Read-only invariant ────────────────────────────────────────────────────

@test "queue-check does NOT mutate git state" {
  local before_hash after_hash
  before_hash=$(git rev-parse HEAD 2>/dev/null)
  env PR_PLAN_SKIP_QUEUE_CHECK=1 bash scripts/pr-plan-queue-check.sh --quiet >/dev/null 2>&1
  after_hash=$(git rev-parse HEAD 2>/dev/null)
  [[ "$before_hash" == "$after_hash" ]]
}

@test "pre-push-bats does NOT mutate git state" {
  local before_hash after_hash
  cd "$(clean_repo)"
  before_hash=$(git rev-parse HEAD 2>/dev/null)
  bash "$BATS_TEST_DIRNAME/../scripts/pre-push-bats-critical.sh" --quiet >/dev/null 2>&1 || true
  after_hash=$(git rev-parse HEAD 2>/dev/null)
  [[ "$before_hash" == "$after_hash" ]]
}
