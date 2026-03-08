#!/usr/bin/env bats
# Tests for script safety standards (Era 88)

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
}

@test "all hook scripts have set -euo pipefail" {
  missing=0
  for f in .claude/hooks/*.sh; do
    [ -f "$f" ] || continue
    if [ "$(head -5 "$f" | grep -c 'set -euo pipefail')" -eq 0 ]; then
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

@test "no eval usage in test scripts" {
  found=0
  for f in scripts/test-*.sh; do
    [ -f "$f" ] || continue
    if grep -n "eval " "$f" | grep -v "^[0-9]*:#" | grep -v "grep.*eval" | head -1 | grep -q .; then
      echo "EVAL FOUND: $f" >&2
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
