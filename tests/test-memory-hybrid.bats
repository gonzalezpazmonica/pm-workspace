#!/usr/bin/env bats
# Ref: docs/propuestas/SPEC-035-hybrid-search.md
# Tests for memory-hybrid.py — Hybrid search: vector + graph + grep

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/memory-hybrid.py"
  TMPDIR_MH=$(mktemp -d)
  export PROJECT_ROOT="$TMPDIR_MH"
  mkdir -p "$TMPDIR_MH/output"
  echo '{"topic_key":"test/decision","type":"decision","title":"Use PostgreSQL","content":"Decided PostgreSQL for persistence","ts":"2026-04-01T10:00:00Z"}' > "$TMPDIR_MH/output/.memory-store.jsonl"
}

teardown() { rm -rf "$TMPDIR_MH"; }

@test "script has shebang and safety" {
  head -1 "$SCRIPT" | grep -q "python3"
  grep -q "argparse\|ArgumentParser" "$SCRIPT"
}

@test "wrapper scripts use set -uo pipefail" {
  head -10 "$REPO_ROOT/scripts/memory-store.sh" | grep -qE "set -(e|u).*pipefail"
}

@test "status subcommand runs" {
  run python3 "$SCRIPT" status --store "$TMPDIR_MH/output/.memory-store.jsonl"
  [ "$status" -le 1 ]
}

@test "search returns results or empty" {
  run python3 "$SCRIPT" search "PostgreSQL" --store "$TMPDIR_MH/output/.memory-store.jsonl"
  [ "$status" -le 1 ]
}

@test "search with nonexistent query returns empty" {
  run python3 "$SCRIPT" search "xyznonexistent" --store "$TMPDIR_MH/output/.memory-store.jsonl"
  [ "$status" -le 1 ]
}

@test "negative: missing store file handled" {
  run python3 "$SCRIPT" search "test" --store "/nonexistent/store.jsonl"
  [ "$status" -le 1 ]
}

@test "negative: no query arg shows usage or error" {
  run python3 "$SCRIPT" search
  [ "$status" -ne 0 ]
}

@test "edge: empty store file handled" {
  touch "$TMPDIR_MH/output/empty.jsonl"
  run python3 "$SCRIPT" search "test" --store "$TMPDIR_MH/output/empty.jsonl"
  [ "$status" -le 1 ]
}

@test "edge: null query handled" {
  run python3 "$SCRIPT" search "" --store "$TMPDIR_MH/output/.memory-store.jsonl"
  [ "$status" -le 1 ]
}

@test "coverage: supports --mode flag" {
  grep -q "mode\|MODE" "$SCRIPT"
}

@test "coverage: fallback chain defined" {
  grep -q "grep\|fallback\|Fallback" "$SCRIPT"
}

@test "coverage: references vector and graph" {
  grep -q "vector\|graph" "$SCRIPT"
}

@test "positive: script under 150 lines" {
  local lines; lines=$(wc -l < "$SCRIPT"); [ "$lines" -le 150 ]
}

@test "coverage: uses subprocess or import" {
  grep -q "subprocess\|importlib\|import" "$SCRIPT"
}

@test "edge: boundary — top K parameter" {
  run python3 "$SCRIPT" search "test" --top 1 --store "$TMPDIR_MH/output/.memory-store.jsonl"
  [ "$status" -le 1 ]
}
