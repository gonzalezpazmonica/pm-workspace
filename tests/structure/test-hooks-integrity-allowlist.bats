#!/usr/bin/env bats
# SE-094 closure — validates the hooks-allowlist contract.
# Every entry MUST: (a) point to an existing .sh, (b) have justification ≥10 chars,
# (c) reference a spec (SE-NNN, SPEC-NNN, or named rule).

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  ALLOWLIST="$REPO_ROOT/.claude/hooks-allowlist.tsv"
  HOOKS_DIR="$REPO_ROOT/.opencode/hooks"
}

@test "allowlist file exists" {
  [ -f "$ALLOWLIST" ]
}

@test "every allowlist entry points to an existing hook file" {
  while IFS=$'\t' read -r fname _just; do
    [[ -z "$fname" || "$fname" =~ ^# ]] && continue
    [ -f "$HOOKS_DIR/$fname" ] || { echo "missing: $fname"; return 1; }
  done < "$ALLOWLIST"
}

@test "every allowlist entry has justification of at least 10 chars" {
  while IFS=$'\t' read -r fname just; do
    [[ -z "$fname" || "$fname" =~ ^# ]] && continue
    [ "${#just}" -ge 10 ] || { echo "short justification: $fname ($just)"; return 1; }
  done < "$ALLOWLIST"
}

@test "every allowlist entry cites a spec or named rule" {
  while IFS=$'\t' read -r fname just; do
    [[ -z "$fname" || "$fname" =~ ^# ]] && continue
    if ! echo "$just" | grep -qE "(SE-[0-9]+|SPEC-[0-9]+|Rule #[0-9]+|autonomous-safety|governance)"; then
      echo "no spec/rule citation: $fname ($just)"
      return 1
    fi
  done < "$ALLOWLIST"
}

@test "hooks-integrity-check passes with allowlist applied" {
  run bash "$REPO_ROOT/scripts/hooks-integrity-check.sh"
  [ "$status" -eq 0 ]
}
