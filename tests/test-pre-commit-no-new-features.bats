#!/usr/bin/env bats
# Ref: SE-291 — pre-commit-no-new-features: no new features in branches with an open PR

setup() {
  # Test-local git identity: fixture commits must not depend on a global
  # user.name/user.email (absent on some machines, present in CI).
  export GIT_AUTHOR_NAME="bats" GIT_AUTHOR_EMAIL="bats@example.invalid"
  export GIT_COMMITTER_NAME="bats" GIT_COMMITTER_EMAIL="bats@example.invalid"
  TEST_DIR=$(mktemp -d)
  cd "$TEST_DIR"
  git init --quiet
  git commit --allow-empty -m "initial" --quiet
  git checkout -b agent/se291-test --quiet
  HOOK="$BATS_TEST_DIRNAME/../.opencode/hooks/pre-commit-no-new-features.sh"
  # gh stub: STUB_PR set => the branch has that open PR; empty => no PR.
  mkdir -p "$TEST_DIR/.bin"
  printf '#!/usr/bin/env bash\necho "${STUB_PR:-}"\n' > "$TEST_DIR/.bin/gh"
  chmod +x "$TEST_DIR/.bin/gh"
  export PATH="$TEST_DIR/.bin:$PATH"
  export STUB_PR=""
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

@test "allows a mismatched spec number when the branch has no open PR" {
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

@test "reject: open PR blocks a new spec with a different SE number" {
  export STUB_PR=42
  mkdir -p projects/savia-vaults/specs
  echo "new" > projects/savia-vaults/specs/SE-294-other.spec.md
  git add projects/savia-vaults/specs/SE-294-other.spec.md
  run bash "$HOOK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"SE-294"*"SE-291"* ]]
  [[ "$output" == *"#42"* ]]
}

@test "open PR allows a spec with the branch SE number" {
  export STUB_PR=42
  mkdir -p projects/savia-vaults/specs
  echo "new" > projects/savia-vaults/specs/SE-291-same.spec.md
  git add projects/savia-vaults/specs/SE-291-same.spec.md
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "reject: open PR blocks a new source directory not present in main" {
  export STUB_PR=42
  mkdir -p src/newmod
  echo "x" > src/newmod/a.py
  git add src/newmod/a.py
  run bash "$HOOK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"New directory: src/newmod/"* ]]
}

@test "empty: open PR with nothing staged is allowed" {
  export STUB_PR=42
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}
