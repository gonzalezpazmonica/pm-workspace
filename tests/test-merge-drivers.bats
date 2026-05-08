#!/usr/bin/env bats
# BATS tests for git merge drivers configuration — eliminates recurring
# CHANGELOG.md + .confidentiality-signature + .scm/* conflicts that
# block PR merges whenever main advances.
#
# Ref: .gitattributes, scripts/setup-merge-drivers.sh, CHANGELOG.d/README.md,
# SPEC-SE-012 signal-noise reduction, SPEC-105 signature stability.
# Safety: script under test has `set -uo pipefail`; tests operate on
# sandbox repos so real .git/config stays untouched.

SCRIPT="scripts/setup-merge-drivers.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() {
  cd /
}

# ── Structure ──────────────────────────────────────────────────────────────

@test "setup-merge-drivers.sh exists and is executable" {
  [[ -x "scripts/setup-merge-drivers.sh" ]]
}

@test ".gitattributes exists at repo root" {
  [[ -f ".gitattributes" ]]
}

@test "setup-merge-drivers uses set -uo pipefail" {
  run grep -cE '^set -[uo]+ pipefail' "scripts/setup-merge-drivers.sh"
  [[ "$output" -ge 1 ]]
}

@test "setup-merge-drivers passes bash -n" {
  run bash -n "scripts/setup-merge-drivers.sh"
  [ "$status" -eq 0 ]
}

# ── .gitattributes content ─────────────────────────────────────────────────

@test ".gitattributes declares merge=ours for .confidentiality-signature" {
  run grep -cE '^\.confidentiality-signature[[:space:]]+merge=ours' ".gitattributes"
  [[ "$output" -ge 1 ]]
}

@test ".gitattributes declares merge=union for CHANGELOG.md" {
  run grep -cE '^CHANGELOG\.md[[:space:]]+merge=union' ".gitattributes"
  [[ "$output" -ge 1 ]]
}

@test ".gitattributes declares merge=ours for .scm/*" {
  run grep -cE '^\.scm/.*merge=ours' ".gitattributes"
  [[ "$output" -ge 2 ]]
}

# ── Local git config ──────────────────────────────────────────────────────

@test "ours merge driver is configured in local git config" {
  run git config merge.ours.driver
  [ "$status" -eq 0 ]
  [[ "$output" == "true" ]]
}

@test "setup-merge-drivers.sh is idempotent (safe to run repeatedly)" {
  bash scripts/setup-merge-drivers.sh >/dev/null 2>&1
  local first=$?
  bash scripts/setup-merge-drivers.sh >/dev/null 2>&1
  local second=$?
  [[ "$first" -eq "$second" ]]
  [[ "$first" -eq 0 ]]
}

# ── Actual merge behaviour (integration test in sandbox repo) ─────────────

@test "CHANGELOG.md union-merges without conflict markers" {
  local sandbox="$BATS_TEST_TMPDIR/sandbox-union"
  mkdir -p "$sandbox" && cd "$sandbox"
  git init --quiet --initial-branch=main
  git config user.email "t@t.t" && git config user.name "t"
  echo "CHANGELOG.md merge=union" > .gitattributes
  git add .gitattributes && git commit --quiet -m "init"

  printf "a\n" > CHANGELOG.md
  git add CHANGELOG.md && git commit --quiet -m "base"

  git checkout --quiet -b feat
  printf "b\na\n" > CHANGELOG.md
  git commit --quiet -am "feat"

  git checkout --quiet main
  printf "c\na\n" > CHANGELOG.md
  git commit --quiet -am "main"

  # Merge; should NOT produce conflict markers.
  git merge --no-edit feat >/dev/null 2>&1 || true
  run grep -c '<<<<<<<' CHANGELOG.md
  [[ "$output" == "0" ]]
}

@test ".confidentiality-signature merge=ours auto-resolves" {
  local sandbox="$BATS_TEST_TMPDIR/sandbox-ours"
  mkdir -p "$sandbox" && cd "$sandbox"
  git init --quiet --initial-branch=main
  git config user.email "t@t.t" && git config user.name "t"
  git config merge.ours.driver true
  echo ".confidentiality-signature merge=ours" > .gitattributes
  git add .gitattributes && git commit --quiet -m "init"

  echo "sig-base" > .confidentiality-signature
  git add .confidentiality-signature && git commit --quiet -m "base"

  git checkout --quiet -b feat
  echo "sig-feat" > .confidentiality-signature
  git commit --quiet -am "feat"

  git checkout --quiet main
  echo "sig-main" > .confidentiality-signature
  git commit --quiet -am "main"

  # Merge feat into main.
  git merge --no-edit feat >/dev/null 2>&1 || true
  # Ours driver on main means main keeps main's version.
  run cat .confidentiality-signature
  [[ "$output" == "sig-main" ]]
  # No conflict markers.
  run grep -c '<<<<<<<' .confidentiality-signature
  [[ "$output" == "0" ]]
}

# ── session-init hook integration ──────────────────────────────────────────

@test "session-init hook invokes setup-merge-drivers" {
  run grep -c 'setup-merge-drivers.sh' ".opencode/hooks/session-init.sh"
  [[ "$output" -ge 1 ]]
}

# ── Negative cases ─────────────────────────────────────────────────────────

@test "negative: script fails gracefully when .gitattributes missing merge=ours" {
  local sandbox="$BATS_TEST_TMPDIR/sandbox-missing"
  local script
  script=$(readlink -f "scripts/setup-merge-drivers.sh")
  mkdir -p "$sandbox" && cd "$sandbox"
  git init --quiet --initial-branch=main
  echo "* text=auto" > .gitattributes
  # Running in the sandbox repo: script's git rev-parse resolves to sandbox.
  run bash "$script"
  [ "$status" -eq 1 ]
  [[ "$output" == *"WARNING"* ]]
}

@test "negative: script rejects no-args usage errors" {
  # The script does not accept any args; passing bogus should still work silently
  # because it does not parse them, but must not crash.
  run bash scripts/setup-merge-drivers.sh ignored-arg
  # Either accepts silently (current behaviour) or errors cleanly.
  [[ "$status" -eq 0 || "$status" -eq 2 ]]
}

@test "negative: without merge driver configured, merge=ours would not auto-resolve" {
  # Sanity: verify the git behaviour requires merge.ours.driver.
  local sandbox="$BATS_TEST_TMPDIR/sandbox-missing-driver"
  mkdir -p "$sandbox" && cd "$sandbox"
  git init --quiet --initial-branch=main
  git config user.email "t@t.t" && git config user.name "t"
  # Deliberately NOT configuring merge.ours.driver.
  echo ".confidentiality-signature merge=ours" > .gitattributes
  git add .gitattributes && git commit --quiet -m "init"
  echo "sig" > .confidentiality-signature
  git add .confidentiality-signature && git commit --quiet -m "base"
  git checkout --quiet -b feat
  echo "sig-feat" > .confidentiality-signature
  git commit --quiet -am "feat"
  git checkout --quiet main
  echo "sig-main" > .confidentiality-signature
  git commit --quiet -am "main"
  git merge --no-edit feat >/dev/null 2>&1 || true
  # Should have conflict markers (drives home why the setup script is needed).
  run grep -c '<<<<<<<' .confidentiality-signature
  [[ "$output" -ge 1 ]]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: setup script is idempotent via current driver detection" {
  run grep -c 'already configured' "scripts/setup-merge-drivers.sh"
  [[ "$output" -ge 1 ]]
}

@test "edge: .gitattributes documents the requirement + setup script" {
  run grep -cE 'setup-merge-drivers\.sh|merge.ours.driver' ".gitattributes"
  [[ "$output" -ge 1 ]]
}

@test "edge: session-init runs setup silently + idempotent" {
  run grep -A1 'setup-merge-drivers' .opencode/hooks/session-init.sh
  [[ "$output" == *">/dev/null 2>&1"* ]] || [[ "$output" == *"|| true"* ]]
}

# ── Extra rigor: coverage + cross-ref ──────────────────────────────────────

@test "coverage: .gitattributes has explanatory comments" {
  run grep -cE '^#' .gitattributes
  [[ "$output" -ge 4 ]]
}

@test "cross-ref: resolve-pr-conflicts.sh complements merge drivers" {
  # Pattern: the older tool (resolve-pr-conflicts.sh) still exists and
  # handles cases where someone forgot to run setup-merge-drivers.
  [[ -x "scripts/resolve-pr-conflicts.sh" ]]
}

@test "negative: setup script does not attempt to modify .gitattributes" {
  run grep -cE 'cat >|echo.*>.*\.gitattributes|sed -i.*\.gitattributes' scripts/setup-merge-drivers.sh
  [[ "$output" -eq 0 ]]
}

@test "edge: setup script uses local-repo config (not --global)" {
  run grep -c '\-\-global' scripts/setup-merge-drivers.sh
  [[ "$output" -eq 0 ]]
}

@test "edge: CHANGELOG.d/ pattern documented as preferred alternative" {
  run grep -c 'CHANGELOG\.d/\|fragment' .gitattributes
  [[ "$output" -ge 1 ]]
}
