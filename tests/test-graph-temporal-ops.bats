#!/usr/bin/env bats
# Tests for SPEC-123 — graph-temporal-ops (Graphiti-inspired temporal edges)
# Ref: docs/propuestas/SPEC-123-graphiti-temporal-pattern.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/graph-temporal-ops.sh"
  TMPDIR_GT="$(mktemp -d)"
  export TMPDIR_GT
  export GRAPH="$TMPDIR_GT/edges.jsonl"
}

teardown() {
  rm -rf "$TMPDIR_GT" 2>/dev/null || true
}

# ── Safety / integrity ───────────────────────────────────────────────────────

@test "safety: script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "safety: script has set -uo pipefail" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "safety: script references SPEC-123" {
  grep -q "SPEC-123" "$SCRIPT"
}

# ── Positive: add_edge ──────────────────────────────────────────────────────

@test "positive: add_edge creates edge with valid_from timestamp" {
  run bash "$SCRIPT" add_edge --from "p:laura" --to "pbi:001" --rel "owns" --graph "$GRAPH"
  [ "$status" -eq 0 ]
  [ -f "$GRAPH" ]
  grep -q "valid_from" "$GRAPH"
  grep -q "invalid_at" "$GRAPH"
}

@test "positive: multiple add_edge calls append lines" {
  bash "$SCRIPT" add_edge --from "p:laura" --to "pbi:001" --rel "owns" --graph "$GRAPH" >/dev/null
  bash "$SCRIPT" add_edge --from "p:diego" --to "pbi:002" --rel "owns" --graph "$GRAPH" >/dev/null
  [ "$(wc -l < "$GRAPH")" -eq 2 ]
}

@test "positive: query_at_time finds active edges" {
  bash "$SCRIPT" add_edge --from "p:laura" --to "pbi:001" --rel "owns" --graph "$GRAPH" >/dev/null
  sleep 1
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  run bash "$SCRIPT" query_at_time --when "$now" --entity "pbi:001" --graph "$GRAPH"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "p:laura"
}

@test "positive: invalidate_edge sets invalid_at" {
  bash "$SCRIPT" add_edge --from "p:laura" --to "pbi:001" --rel "owns" --graph "$GRAPH" >/dev/null
  run bash "$SCRIPT" invalidate_edge --from "p:laura" --to "pbi:001" --rel "owns" --graph "$GRAPH"
  [ "$status" -eq 0 ]
  # After invalidate, the edge has non-null invalid_at
  python3 -c "
import json
with open('$GRAPH') as f:
    for line in f:
        e=json.loads(line.strip())
        assert e.get('invalid_at') is not None, 'expected invalid_at set'
"
}

@test "positive: --help returns exit 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
}

# ── Negative cases ───────────────────────────────────────────────────────────

@test "negative: add_edge without required args fails with exit 2" {
  run bash "$SCRIPT" add_edge --graph "$GRAPH"
  [ "$status" -eq 2 ]
}

@test "negative: query_at_time without --when fails with exit 2" {
  run bash "$SCRIPT" query_at_time --graph "$GRAPH"
  [ "$status" -eq 2 ]
}

@test "negative: unknown command fails with exit 2" {
  run bash "$SCRIPT" bogus_command
  [ "$status" -eq 2 ]
}

@test "negative: invalidate non-existent edge warns with exit 1" {
  : > "$GRAPH"
  run bash "$SCRIPT" invalidate_edge --from "p:nobody" --to "pbi:0" --rel "owns" --graph "$GRAPH"
  [ "$status" -eq 1 ]
  echo "$output" | grep -qE "WARN|no active edge"
}

# ── Edge cases ───────────────────────────────────────────────────────────────

@test "edge: query on empty graph returns zero results cleanly" {
  : > "$GRAPH"
  run bash "$SCRIPT" query_at_time --when "2026-04-17T00:00:00Z" --graph "$GRAPH"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE "^# 0 edge\(s\) active"
}

@test "edge: temporal — query BEFORE valid_from returns no results" {
  bash "$SCRIPT" add_edge --from "p:laura" --to "pbi:001" --rel "owns" --graph "$GRAPH" >/dev/null
  run bash "$SCRIPT" query_at_time --when "2020-01-01T00:00:00Z" --entity "pbi:001" --graph "$GRAPH"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE "^# 0 edge"
}

@test "edge: temporal — query AFTER invalid_at returns no results" {
  bash "$SCRIPT" add_edge --from "p:laura" --to "pbi:001" --rel "owns" --graph "$GRAPH" >/dev/null
  bash "$SCRIPT" invalidate_edge --from "p:laura" --to "pbi:001" --rel "owns" --graph "$GRAPH" >/dev/null
  sleep 1
  future=$(date -u -d '+1 hour' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
  run bash "$SCRIPT" query_at_time --when "$future" --entity "pbi:001" --graph "$GRAPH"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE "^# 0 edge"
}

@test "edge: relation filter works" {
  bash "$SCRIPT" add_edge --from "p:laura" --to "pbi:001" --rel "owns" --graph "$GRAPH" >/dev/null
  bash "$SCRIPT" add_edge --from "p:laura" --to "pbi:001" --rel "reviewed" --graph "$GRAPH" >/dev/null
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  run bash "$SCRIPT" query_at_time --when "$now" --entity "pbi:001" --rel "owns" --graph "$GRAPH"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE "^# 1 edge"
}

# ── Isolation ────────────────────────────────────────────────────────────────

@test "isolation: graph file lives in tmp and is disposable" {
  bash "$SCRIPT" add_edge --from "x" --to "y" --rel "r" --graph "$GRAPH" >/dev/null
  [[ "$GRAPH" == /tmp/* ]] || [[ "$GRAPH" == /var/folders/* ]]
  [ -f "$GRAPH" ]
}

@test "isolation: does not write outside --graph path" {
  bash "$SCRIPT" add_edge --from "x" --to "y" --rel "r" --graph "$GRAPH" >/dev/null
  # Only $GRAPH should be modified in tmpdir
  [ "$(find "$TMPDIR_GT" -name 'edges.jsonl' | wc -l)" -eq 1 ]
}
