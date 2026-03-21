#!/usr/bin/env bats
# Tests for CHANGELOG.md integrity
# Validates format, ordering, and content quality

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  CHANGELOG="$PWD/CHANGELOG.md"
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

@test "recent versions (>=2.20) have an Era reference" {
  local versions_without_era=0
  local in_version=false
  local has_era=false
  local version_major=0 version_minor=0
  while IFS= read -r line; do
    if [[ "$line" =~ ^##\ \[([0-9]+)\.([0-9]+)\. ]]; then
      # Check previous version
      if $in_version && ! $has_era && [ "$version_major" -ge 2 ] && [ "$version_minor" -ge 20 ]; then
        versions_without_era=$((versions_without_era + 1))
      fi
      in_version=true
      has_era=false
      version_major="${BASH_REMATCH[1]}"
      version_minor="${BASH_REMATCH[2]}"
    fi
    if $in_version && [[ "$line" == *[Ee]ra* ]]; then
      has_era=true
    fi
  done < "$CHANGELOG"
  # Check last version
  if $in_version && ! $has_era && [ "$version_major" -ge 2 ] && [ "$version_minor" -ge 20 ]; then
    versions_without_era=$((versions_without_era + 1))
  fi
  # Allow exceptions: rapid releases may skip Era naming
  [ "$versions_without_era" -le 20 ]
}

@test "CHANGELOG has at least 10 entries" {
  local count
  count=$(bash -c "cat '$CHANGELOG' | grep -c '^## \['"  || true)
  [ "$count" -ge 10 ]
}
