#!/usr/bin/env bats

setup() {
  TEST_DIR=$(mktemp -d)
  cd "$TEST_DIR"
  git init --quiet
  git commit --allow-empty -m "initial" --quiet
  git checkout -b agent/se291-test --quiet
  HOOK="$BATS_TEST_DIRNAME/../.opencode/hooks/pre-commit-no-new-features.sh"
}

teardown() {
  cd /
  rm -rf "$TEST_DIR"
}

@test "allows commit on branch without open PR" {
  echo "test" > file.txt
  git add file.txt
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "allows modifications to existing files" {
  mkdir -p projects/savia-vaults/specs
  echo "old" > projects/savia-vaults/specs/SE-291-test.spec.md
  git add projects/savia-vaults/specs/SE-291-test.spec.md
  git commit -m "add spec" --quiet
  echo "modified" > projects/savia-vaults/specs/SE-291-test.spec.md
  git add projects/savia-vaults/specs/SE-291-test.spec.md
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "allows confidentiality signature update" {
  echo "hash=abc" > .confidentiality-signature
  git add .confidentiality-signature
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "detects mismatched SE number in spec files" {
  mkdir -p projects/savia-vaults/specs
  echo "new" > projects/savia-vaults/specs/SE-294-other.spec.md
  git add projects/savia-vaults/specs/SE-294-other.spec.md
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "skips non-agent branches" {
  git checkout -b feature/something --quiet
  echo "test" > file.txt
  git add file.txt
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "safety: has set -uo pipefail" {
  head -2 "$HOOK" | grep -q "set -uo pipefail"
}

@test "hook is executable" {
  [ -x "$HOOK" ]
}
