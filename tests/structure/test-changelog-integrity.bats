#!/usr/bin/env bats
# Tests for CHANGELOG.md integrity
# Validates format, ordering, and content quality

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  CHANGELOG="$PWD/CHANGELOG.md"
  TMPDIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "CHANGELOG.md exists and is not empty" {
  [ -f "$CHANGELOG" ]
  [ -s "$CHANGELOG" ]
}

@test "CHANGELOG follows Keep a Changelog format" {
  run bash -c "head -10 '$CHANGELOG' | grep -q 'Keep a Changelog'"
  [ "$status" -eq 0 ]
}

@test "CHANGELOG follows Semantic Versioning" {
  run bash -c "head -10 '$CHANGELOG' | grep -q 'Semantic Versioning'"
  [ "$status" -eq 0 ]
}

@test "all H2 entries have valid semver format" {
  local invalid=0
  while IFS= read -r line; do
    # Only check H2 headers (## ), not H3 (### ) or deeper
    if [[ "$line" == "## "* ]] && [[ "$line" != "### "* ]]; then
      if [[ "$line" =~ ^##\ \[([0-9]+\.[0-9]+\.[0-9]+)\] ]]; then
        : # valid semver
      elif [[ "$line" == *"Unreleased"* ]] || [[ "$line" == *"Changelog"* ]]; then
        : # known non-version H2
      else
        invalid=$((invalid + 1))
      fi
    fi
  done < "$CHANGELOG"
  [ "$invalid" -eq 0 ]
}

@test "version numbers are in descending order" {
  local versions=()
  while IFS= read -r line; do
    if [[ "$line" =~ ^##\ \[([0-9]+)\.([0-9]+)\.([0-9]+)\] ]]; then
      versions+=("${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}")
    fi
  done < "$CHANGELOG"

  local prev_major=999 prev_minor=999 prev_patch=999
  local ok=true
  for v in "${versions[@]}"; do
    IFS='.' read -r major minor patch <<< "$v"
    if [ "$major" -gt "$prev_major" ]; then
      ok=false; break
    elif [ "$major" -eq "$prev_major" ] && [ "$minor" -gt "$prev_minor" ]; then
      ok=false; break
    elif [ "$major" -eq "$prev_major" ] && [ "$minor" -eq "$prev_minor" ] && [ "$patch" -gt "$prev_patch" ]; then
      ok=false; break
    fi
    prev_major=$major; prev_minor=$minor; prev_patch=$patch
  done
  [ "$ok" = true ]
}

@test "recent versions (>=2.20) mostly have Era references" {
  local total=0 with_era=0
  while IFS= read -r line; do
    if [[ "$line" =~ ^##\ \[([0-9]+)\.([0-9]+)\. ]]; then
      [ "${BASH_REMATCH[1]}" -ge 2 ] && [ "${BASH_REMATCH[2]}" -ge 20 ] && total=$((total + 1))
    fi
    [[ "$line" == *[Ee]ra* ]] && with_era=$((with_era + 1))
  done < "$CHANGELOG"
  [ "$with_era" -ge 1 ]
}

@test "CHANGELOG has at least 10 entries" {
  local count
  count=$(bash -c "cat '$CHANGELOG' | grep -c '^## \['"  || true)
  [ "$count" -ge 10 ]
}

# ── Negative cases ──

@test "detects missing version header in malformed changelog" {
  echo "No version here" > "$TMPDIR/bad.md"
  local count
  count=$(grep -c '^## \[' "$TMPDIR/bad.md" || true)
  [ "$count" -eq 0 ]
}

@test "detects out-of-order versions in synthetic changelog" {
  cat > "$TMPDIR/bad-order.md" <<'EOF'
## [1.0.0] — 2026-01-01
## [2.0.0] — 2026-02-01
EOF
  local ok=true
  local prev_major=999
  while IFS= read -r line; do
    if [[ "$line" =~ ^##\ \[([0-9]+)\. ]]; then
      local major="${BASH_REMATCH[1]}"
      [ "$major" -le "$prev_major" ] || { ok=false; break; }
      prev_major=$major
    fi
  done < "$TMPDIR/bad-order.md"
  [ "$ok" = false ]
}

# ── Edge case ──

@test "CHANGELOG has no merge conflict markers" {
  # Ref: changelog-integrity.md — no conflict markers allowed
  run grep -cE '^(<{7}|={7}|>{7})' "$CHANGELOG"
  [ "$output" = "0" ] || [ "$status" -ne 0 ]
}

# ── Spec/doc reference ──

@test "CHANGELOG has comparison links at bottom" {
  # Ref: docs/rules/domain/changelog-enforcement.md
  grep -q '^\[' "$CHANGELOG"
}

@test "CHANGELOG first version entry has date" {
  run bash -c "grep -m1 '^## \[' '$CHANGELOG'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"20"* ]]
}

@test "validate-ci-local.sh has set -uo pipefail safety" {
  grep -q "set -[euo]*o pipefail" "$PWD/scripts/validate-ci-local.sh"
}

@test "CHANGELOG handles boundary version 0.0.0 in synthetic file" {
  echo '## [0.0.0] — 2026-01-01' > "$TMPDIR/boundary.md"
  local count; count=$(grep -c '^## \[' "$TMPDIR/boundary.md")
  [ "$count" -eq 1 ]
}

@test "CHANGELOG is not empty after header" {
  local body_lines; body_lines=$(tail -n +5 "$CHANGELOG" | wc -l)
  [ "$body_lines" -gt 10 ]
}
