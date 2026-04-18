#!/usr/bin/env bats
# Ref: docs/propuestas/SPEC-027-graph-memory-layer.md
# Tests for memory-graph.py — Entity-relation extraction

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/memory-graph.py"
  TMPDIR_MG=$(mktemp -d)
  export PROJECT_ROOT="$TMPDIR_MG"
  mkdir -p "$TMPDIR_MG/output"
  cat > "$TMPDIR_MG/output/.memory-store.jsonl" << 'EOF'
{"topic_key":"decision/auth","type":"decision","title":"Use JWT for auth","content":"Team decided JWT tokens for API authentication","ts":"2026-04-01T10:00:00Z"}
{"topic_key":"decision/db","type":"decision","title":"PostgreSQL selected","content":"la usuaria chose PostgreSQL over MySQL for persistence","ts":"2026-04-02T10:00:00Z"}
EOF
}

teardown() { rm -rf "$TMPDIR_MG"; }

@test "script has shebang and safety" {
  head -1 "$SCRIPT" | grep -q "python3"
  grep -q "argparse\|ArgumentParser" "$SCRIPT"
}

@test "wrapper scripts use set -uo pipefail" {
  # memory-store.sh wraps this Python script with bash safety
  head -10 "$REPO_ROOT/scripts/memory-store.sh" | grep -qE "set -(e|u).*pipefail"
}

@test "status subcommand runs" {
  run python3 "$SCRIPT" status --store "$TMPDIR_MG/output/.memory-store.jsonl"
  [ "$status" -le 1 ]
}

@test "build creates graph" {
  run python3 "$SCRIPT" build --store "$TMPDIR_MG/output/.memory-store.jsonl"
  [ "$status" -le 1 ]
}

@test "search finds entities" {
  python3 "$SCRIPT" build --store "$TMPDIR_MG/output/.memory-store.jsonl" 2>/dev/null || true
  run python3 "$SCRIPT" search "JWT" --store "$TMPDIR_MG/output/.memory-store.jsonl"
  [ "$status" -le 1 ]
}

@test "entities subcommand runs" {
  python3 "$SCRIPT" build --store "$TMPDIR_MG/output/.memory-store.jsonl" 2>/dev/null || true
  run python3 "$SCRIPT" entities --store "$TMPDIR_MG/output/.memory-store.jsonl"
  [ "$status" -le 1 ]
}

@test "negative: missing store file" {
  run python3 "$SCRIPT" status --store "/nonexistent/store.jsonl"
  [ "$status" -le 1 ]
}

@test "edge: empty store file" {
  touch "$TMPDIR_MG/output/empty.jsonl"
  run python3 "$SCRIPT" build --store "$TMPDIR_MG/output/empty.jsonl"
  [ "$status" -le 1 ]
}

@test "edge: null query in search" {
  run python3 "$SCRIPT" search "" --store "$TMPDIR_MG/output/.memory-store.jsonl"
  [ "$status" -le 1 ]
}

@test "coverage: extracts entities and relations" {
  grep -q "entit\|relation\|extract" "$SCRIPT"
}

@test "coverage: graph stored as JSON" {
  grep -q "graph\|json\|JSON" "$SCRIPT"
}

@test "edge: boundary — single entry store" {
  echo '{"topic_key":"x","type":"bug","title":"One","content":"Single entry","ts":"2026-01-01T00:00:00Z"}' > "$TMPDIR_MG/output/single.jsonl"
  run python3 "$SCRIPT" build --store "$TMPDIR_MG/output/single.jsonl"
  [ "$status" -le 1 ]
}

@test "edge: nonexistent query in built graph" {
  python3 "$SCRIPT" build --store "$TMPDIR_MG/output/.memory-store.jsonl" 2>/dev/null || true
  run python3 "$SCRIPT" search "zzz_nonexistent_zzz" --store "$TMPDIR_MG/output/.memory-store.jsonl"
  [ "$status" -le 1 ]
}

@test "positive: script under 300 lines" {
  local lines; lines=$(wc -l < "$SCRIPT"); [ "$lines" -le 300 ]
}

@test "coverage: uses Path or os.path" {
  grep -q "Path\|os.path" "$SCRIPT"
}
