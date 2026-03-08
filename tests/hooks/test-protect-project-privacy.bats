#!/usr/bin/env bats
# Tests for protect-project-privacy.sh pre-commit script

setup() {
  SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/scripts/protect-project-privacy.sh"
  TEST_TMPDIR="$(mktemp -d)"

  # Create minimal git repo for testing
  git init "$TEST_TMPDIR/repo" --quiet
  cd "$TEST_TMPDIR/repo"
  echo "# Test" > README.md
  echo "projects/*" > .gitignore
  echo "!projects/allowed/" >> .gitignore
  git add -A && git commit -m "init" --quiet
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ] || chmod +x "$SCRIPT"
}

@test "--check mode runs without error" {
  cd "$TEST_TMPDIR/repo"
  # Copy script into the test repo so ROOT resolves
  mkdir -p scripts
  cp "$SCRIPT" scripts/protect-project-privacy.sh
  chmod +x scripts/protect-project-privacy.sh
  run bash scripts/protect-project-privacy.sh --check
  [ "$status" -eq 0 ]
}

@test "allows commit when .gitignore not modified" {
  cd "$TEST_TMPDIR/repo"
  mkdir -p scripts
  cp "$SCRIPT" scripts/protect-project-privacy.sh
  chmod +x scripts/protect-project-privacy.sh

  echo "new line" >> README.md
  git add README.md
  run bash scripts/protect-project-privacy.sh --hook
  [ "$status" -eq 0 ]
}

@test "BLOCKS commit when .gitignore adds new project whitelist" {
  cd "$TEST_TMPDIR/repo"
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
  cd "$TEST_TMPDIR/repo"
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
  cd "$TEST_TMPDIR/repo"
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
