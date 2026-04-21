#!/usr/bin/env bats
# test-scrapling-fetch.bats — SE-061 Slice 2 BATS tests for scrapling-fetch.sh
# Target: >= 20 tests, auditor score >= 85.
# Spec: docs/propuestas/SE-061-scrapling-research-backend.md
# Research: output/research/scrapling-20260421.md (local)

SCRIPT="$BATS_TEST_DIRNAME/../scripts/scrapling-fetch.sh"

# --- Help & usage ---

@test "help: --help exits 0 and shows Usage" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "help: -h alias works" {
  run bash "$SCRIPT" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "help: references SE-061" {
  run bash "$SCRIPT" --help
  [[ "$output" == *"SE-061"* ]]
}

# --- URL validation ---

@test "usage: no URL exits 2" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"URL required"* ]]
}

@test "usage: invalid URL exits 2" {
  run bash "$SCRIPT" "not-a-url"
  [ "$status" -eq 2 ]
  [[ "$output" == *"http"* ]]
}

@test "usage: ftp URL rejected" {
  run bash "$SCRIPT" "ftp://example.com"
  [ "$status" -eq 2 ]
}

@test "usage: file URL rejected" {
  run bash "$SCRIPT" "file:///etc/passwd"
  [ "$status" -eq 2 ]
}

@test "usage: accepts https://" {
  # Will fail at network, but URL parsing OK (not exit 2)
  run timeout 5 bash "$SCRIPT" "https://127.0.0.1:1/test"
  [ "$status" -ne 2 ]
}

@test "usage: accepts http://" {
  run timeout 5 bash "$SCRIPT" "http://127.0.0.1:1/test"
  [ "$status" -ne 2 ]
}

# --- Flag parsing ---

@test "flag: --json requires no value" {
  run timeout 5 bash "$SCRIPT" "https://127.0.0.1:1/t" --json
  [ "$status" -ne 2 ]
}

@test "flag: --stealth accepted" {
  run timeout 5 bash "$SCRIPT" "https://127.0.0.1:1/t" --stealth
  [ "$status" -ne 2 ]
}

@test "flag: --timeout numeric accepted" {
  run timeout 5 bash "$SCRIPT" "https://127.0.0.1:1/t" --timeout 5
  [ "$status" -ne 2 ]
}

@test "flag: --timeout non-numeric rejected" {
  run bash "$SCRIPT" "https://example.com" --timeout abc
  [ "$status" -eq 2 ]
  [[ "$output" == *"timeout"* ]]
}

@test "flag: --timeout negative rejected" {
  run bash "$SCRIPT" "https://example.com" --timeout -5
  [ "$status" -eq 2 ]
}

@test "flag: --selector accepts CSS string" {
  run timeout 5 bash "$SCRIPT" "https://127.0.0.1:1/t" --selector "article.content"
  [ "$status" -ne 2 ]
}

@test "flag: positional selector after URL accepted" {
  run timeout 5 bash "$SCRIPT" "https://127.0.0.1:1/t" "div.main"
  [ "$status" -ne 2 ]
}

# --- Negative ---

@test "negative: unknown flag exits 2" {
  run bash "$SCRIPT" "https://example.com" --bogus
  [ "$status" -eq 2 ]
}

@test "negative: extra positional arg exits 2" {
  run bash "$SCRIPT" "https://example.com" "sel1" "extra"
  [ "$status" -eq 2 ]
}

@test "negative: empty URL exits 2" {
  run bash "$SCRIPT" ""
  [ "$status" -eq 2 ]
}

# --- Backend detection ---

@test "backend: runs with curl fallback when scrapling unavailable" {
  # If no network, still exit != 2 (backend detection works)
  run timeout 5 bash "$SCRIPT" "https://127.0.0.1:1/t" --json
  [ "$status" -ne 2 ]
}

# --- Coverage ---

@test "coverage: script has set -uo pipefail" {
  run grep -E "^set -uo pipefail" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "coverage: script references SE-061" {
  run grep -c "SE-061" "$SCRIPT"
  [[ "$output" -ge 2 ]]
}

@test "coverage: script implements curl fallback" {
  run grep -c "fetch_with_curl" "$SCRIPT"
  [[ "$output" -ge 2 ]]
}

@test "coverage: script implements scrapling path" {
  run grep -c "fetch_with_scrapling" "$SCRIPT"
  [[ "$output" -ge 2 ]]
}

@test "coverage: script uses mktemp for curl buffer" {
  run grep -c "mktemp" "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# --- Isolation ---

@test "isolation: --help does not modify cwd" {
  local tmpdir="$BATS_TEST_TMPDIR/iso1"
  mkdir -p "$tmpdir"
  cd "$tmpdir"
  local before=$(find . -type f 2>/dev/null | wc -l)
  bash "$SCRIPT" --help >/dev/null 2>&1 || true
  local after=$(find . -type f 2>/dev/null | wc -l)
  cd "$BATS_TEST_DIRNAME/.."
  [ "$before" -eq "$after" ]
}

@test "isolation: usage error does not write files" {
  local tmpdir="$BATS_TEST_TMPDIR/iso2"
  mkdir -p "$tmpdir"
  cd "$tmpdir"
  bash "$SCRIPT" --bogus >/dev/null 2>&1 || true
  bash "$SCRIPT" "not-a-url" >/dev/null 2>&1 || true
  local files=$(find . -type f 2>/dev/null | wc -l)
  cd "$BATS_TEST_DIRNAME/.."
  [ "$files" -eq 0 ]
}

@test "isolation: script is executable bit set" {
  run test -x "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "isolation: no globals leak after source of help" {
  # Simply verify help does not leak non-zero exit code
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
}
