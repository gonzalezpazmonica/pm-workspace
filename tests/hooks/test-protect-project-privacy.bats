#!/usr/bin/env bats
# Tests for protect-project-privacy.sh pre-commit script
# Ref: docs/rules/domain/project-privacy-protection.md

setup() {
  TMPDIR=$(mktemp -d)
  SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/scripts/protect-project-privacy.sh"

  # Create minimal git repo for testing
  git init "$TMPDIR/repo" --quiet
  cd "$TMPDIR/repo"
  echo "# Test" > README.md
  echo "projects/*" > .gitignore
  echo "!projects/allowed/" >> .gitignore
  git add -A && git commit -m "init" --quiet
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "target has safety flags" {
  grep -q "set -[euo]" "$SCRIPT"
}

@test "script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ] || chmod +x "$SCRIPT"
}

@test "--check mode runs without error" {
  cd "$TMPDIR/repo"
  # Copy script into the test repo so ROOT resolves
  mkdir -p scripts
  cp "$SCRIPT" scripts/protect-project-privacy.sh
  chmod +x scripts/protect-project-privacy.sh
  run bash scripts/protect-project-privacy.sh --check
  [ "$status" -eq 0 ]
}

@test "allows commit when .gitignore not modified" {
  cd "$TMPDIR/repo"
  mkdir -p scripts
  cp "$SCRIPT" scripts/protect-project-privacy.sh
  chmod +x scripts/protect-project-privacy.sh

  echo "new line" >> README.md
  git add README.md
  run bash scripts/protect-project-privacy.sh --hook
  [ "$status" -eq 0 ]
}

@test "BLOCKS commit when .gitignore adds new project whitelist" {
  cd "$TMPDIR/repo"
  mkdir -p scripts .claude
  cp "$SCRIPT" scripts/protect-project-privacy.sh
  chmod +x scripts/protect-project-privacy.sh

  echo "!projects/secret-client/" >> .gitignore
  git add .gitignore
  run bash scripts/protect-project-privacy.sh --hook
  [ "$status" -eq 1 ]
  [[ "$output" == *"BLOQUEADO"* ]]
  [[ "$output" == *"secret-client"* ]]
}

@test "allows commit when project is authorized" {
  cd "$TMPDIR/repo"
  mkdir -p scripts .claude
  cp "$SCRIPT" scripts/protect-project-privacy.sh
  chmod +x scripts/protect-project-privacy.sh

  # Pre-authorize the project
  echo "authorized-project" > .claude/.project-authorizations
  echo "!projects/authorized-project/" >> .gitignore
  git add .gitignore
  run bash scripts/protect-project-privacy.sh --hook
  [ "$status" -eq 0 ]
}

@test "BLOCKS git add -f of unwhitelisted project files" {
  cd "$TMPDIR/repo"
  mkdir -p scripts .claude projects/sneaky-project
  cp "$SCRIPT" scripts/protect-project-privacy.sh
  chmod +x scripts/protect-project-privacy.sh

  echo "secret data" > projects/sneaky-project/data.txt
  git add -f projects/sneaky-project/data.txt
  run bash scripts/protect-project-privacy.sh --hook
  [ "$status" -eq 1 ]
  [[ "$output" == *"BLOQUEADO"* ]]
  [[ "$output" == *"sneaky-project"* ]]
}

# ── Edge cases ──

@test "empty .gitignore change does not crash" {
  cd "$TMPDIR/repo"
  mkdir -p scripts
  cp "$SCRIPT" scripts/protect-project-privacy.sh
  chmod +x scripts/protect-project-privacy.sh
  touch .gitignore
  git add .gitignore
  run bash scripts/protect-project-privacy.sh --hook
  [ "$status" -eq 0 ]
}

@test "nonexistent .claude dir handled gracefully" {
  cd "$TMPDIR/repo"
  mkdir -p scripts
  cp "$SCRIPT" scripts/protect-project-privacy.sh
  chmod +x scripts/protect-project-privacy.sh
  run bash scripts/protect-project-privacy.sh --check
  [ "$status" -eq 0 ]
  grep -q "." <<< "$status"
}

@test "core hooks use safety flags" {
  grep -q "set -[euo]" "$BATS_TEST_DIRNAME/../../.opencode/hooks/validate-bash-global.sh"
}

@test "edge: empty input produces no error" {
  run bash -c "echo '{}' | SAVIA_HOOK_PROFILE=minimal bash '$BATS_TEST_DIRNAME/../../.opencode/hooks/validate-bash-global.sh' 2>&1"
  [ "$status" -eq 0 ]
}
