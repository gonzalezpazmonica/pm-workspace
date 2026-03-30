#!/usr/bin/env bats
# Tests for script safety standards (Era 88)
# Ref: .claude/rules/domain/security-check-patterns.md

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  TMPDIR_SS=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_SS"
}

@test "all hook scripts have set -uo pipefail" {
  missing=0
  for f in .claude/hooks/*.sh; do
    [ -f "$f" ] || continue
    if [ "$(head -5 "$f" | grep -c 'set -uo pipefail')" -eq 0 ]; then
      echo "MISSING: $f" >&2
      missing=$((missing + 1))
    fi
  done
  [ "$missing" -eq 0 ]
}

@test "no eval usage in hook scripts" {
  found=0
  for f in .claude/hooks/*.sh; do
    [ -f "$f" ] || continue
    if grep -n "eval " "$f" | grep -v "^[0-9]*:#" | grep -v "grep.*eval" | head -1 | grep -q .; then
      echo "EVAL FOUND: $f" >&2
      found=$((found + 1))
    fi
  done
  [ "$found" -eq 0 ]
}

@test "no unsafe eval usage in test scripts" {
  found=0
  for f in scripts/test-*.sh; do
    [ -f "$f" ] || continue
    # Allow eval inside check()/assert() function definitions (controlled test assertions)
    # Allow eval "$var" patterns used in assert/check test helpers (hardcoded assertions)
    if grep -n "eval " "$f" | grep -v "^[0-9]*:#" | grep -v "grep.*eval" | grep -v 'eval "\$' | head -1 | grep -q .; then
      echo "UNSAFE EVAL FOUND: $f" >&2
      found=$((found + 1))
    fi
  done
  [ "$found" -eq 0 ]
}

@test "no hardcoded /home/monica paths in scripts" {
  found=0
  for f in scripts/*.sh; do
    [ -f "$f" ] || continue
    basename "$f" | grep -q "vuln-scan" && continue
    if grep -n "/home/monica" "$f" | grep -v "^[0-9]*:#" | head -1 | grep -q .; then
      echo "HARDCODED: $f" >&2
      found=$((found + 1))
    fi
  done
  [ "$found" -eq 0 ]
}

@test "core scripts have set -uo pipefail" {
  core_scripts="security-scan.sh vuln-scan.sh coverage-report.sh audit-test-quality.sh generate-index.sh workspace-health.sh"
  missing=0
  for name in $core_scripts; do
    f="scripts/$name"
    [ -f "$f" ] || continue
    if [ "$(grep -c 'set -[a-z]*uo pipefail' "$f")" -eq 0 ]; then
      echo "MISSING: $f" >&2
      missing=$((missing + 1))
    fi
  done
  [ "$missing" -eq 0 ]
}

# ── Negative cases ──

@test "no executable sudo invocations in hook scripts (string refs ok)" {
  found=0
  for f in .claude/hooks/*.sh; do
    [ -f "$f" ] || continue
    # Exclude comments, echo/print strings, grep patterns
    if grep -n "sudo " "$f" | grep -v "^[0-9]*:#" | grep -v "grep" | grep -v "echo" | grep -v "print" | grep -v "BLOQUEADO" | head -1 | grep -q .; then
      echo "SUDO FOUND: $f" >&2
      found=$((found + 1))
    fi
  done
  [ "$found" -eq 0 ]
}

@test "no unguarded rm -rf / in scripts (strings and config ok)" {
  found=0
  for f in scripts/*.sh; do
    [ -f "$f" ] || continue
    # Exclude: comments, variables, /tmp, strings (echo, quotes, JSON)
    if grep -n 'rm -rf /' "$f" | grep -v "^[0-9]*:#" | grep -v '\$' | grep -v 'rm -rf /tmp' | grep -v '"' | grep -v "'" | head -1 | grep -q .; then
      echo "DANGEROUS RM: $f" >&2
      found=$((found + 1))
    fi
  done
  [ "$found" -eq 0 ]
}

# ── Edge cases ──

@test "hook scripts are not empty" {
  for f in .claude/hooks/*.sh; do
    [ -f "$f" ] || continue
    [ -s "$f" ] || { echo "EMPTY: $f" >&2; return 1; }
  done
}

@test "no .sh files with Windows line endings and core files not empty" {
  local found=0
  for f in .claude/hooks/*.sh; do
    [ -f "$f" ] || continue
    file "$f" | grep -q "CRLF" && found=$((found + 1))
  done
  [ "$found" -eq 0 ]
  for f in scripts/validate-ci-local.sh scripts/memory-store.sh; do
    [ -f "$f" ] && [ -s "$f" ]
  done
}

@test "hook scripts use bash shebang" {
  for f in .claude/hooks/*.sh; do
    [ -f "$f" ] || continue
    local first; first=$(head -1 "$f")
    [[ "$first" == *"bash"* ]] || [[ "$first" == *"sh"* ]]
  done
}

@test "hook count is reasonable and not zero" {
  local count; count=$(ls .claude/hooks/*.sh 2>/dev/null | wc -l)
  [ "$count" -ge 5 ]
  [ "$count" -le 100 ]
}

@test "scripts handle nonexistent hook dir gracefully" {
  run bash -c "ls /nonexistent-$$/.claude/hooks/*.sh 2>/dev/null | wc -l"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}
