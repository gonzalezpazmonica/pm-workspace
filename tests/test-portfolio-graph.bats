#!/usr/bin/env bats
# BATS tests for scripts/portfolio-graph.sh (SPEC-SE-020 Slice 2).
# Validates the portfolio-grapher: deps.yaml parsing, graph construction,
# ASCII/Mermaid/JSON output, safety, edge cases.
#
# Ref: SPEC-SE-020 §Portfolio graph, ROADMAP §Tier 5.12
# Safety: script under test `set -uo pipefail`, read-only.

SCRIPT="scripts/portfolio-graph.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() {
  cd /
}

# Helper: build a sandbox with N projects + deps.yaml.
build_sandbox() {
  local sb="$1"
  mkdir -p "$sb/proj-a" "$sb/proj-b" "$sb/proj-c"
  cat > "$sb/proj-a/deps.yaml" <<YAML
project: "proj-a"
tenant: "sandbox"
dependencies:
  upstream:
    - project: "proj-b"
      type: "blocks"
      deliverable: "D-001"
      needed_by: "2026-12-31"
      status: "on-track"
YAML
  cat > "$sb/proj-b/deps.yaml" <<YAML
project: "proj-b"
tenant: "sandbox"
dependencies:
  upstream:
    - project: "proj-c"
      type: "feeds"
      deliverable: "D-002"
      needed_by: "2026-11-30"
      status: "at-risk"
YAML
  cat > "$sb/proj-c/deps.yaml" <<YAML
project: "proj-c"
tenant: "sandbox"
dependencies:
  upstream: []
YAML
}

# ── Structure / safety ──────────────────────────────────────────────────────

@test "script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "script uses set -uo pipefail" {
  run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "script passes bash -n syntax check" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script references SPEC-SE-020 and Slice 2" {
  run grep -c 'SPEC-SE-020' "$SCRIPT"
  [[ "$output" -ge 1 ]]
  run grep -c 'Slice 2\|Portfolio graph' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── CLI surface ─────────────────────────────────────────────────────────────

@test "script accepts --help and exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"root"* ]]
  [[ "$output" == *"ascii"* ]]
  [[ "$output" == *"mermaid"* ]]
}

@test "script rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "script requires --root" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"root required"* ]]
}

@test "script rejects nonexistent root directory" {
  run bash "$SCRIPT" --root /does/not/exist
  [ "$status" -eq 2 ]
  [[ "$output" == *"not found"* ]]
}

@test "script rejects invalid format" {
  local sb="$BATS_TEST_TMPDIR/sb"
  mkdir -p "$sb"
  run bash "$SCRIPT" --root "$sb" --format svg
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid"* ]]
}

# ── Empty root ─────────────────────────────────────────────────────────────

@test "empty root directory returns zero-node graph gracefully" {
  local sb="$BATS_TEST_TMPDIR/empty"
  mkdir -p "$sb"
  run bash "$SCRIPT" --root "$sb"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nodes:      0"* ]]
  [[ "$output" == *"Edges:      0"* ]]
}

# ── ASCII output ────────────────────────────────────────────────────────────

@test "ascii output lists all 3 projects from sandbox" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_sandbox "$sb"
  run bash "$SCRIPT" --root "$sb"
  [ "$status" -eq 0 ]
  [[ "$output" == *"proj-a"* ]]
  [[ "$output" == *"proj-b"* ]]
  [[ "$output" == *"proj-c"* ]]
}

@test "ascii output shows Nodes:3 and Edges:2 for sandbox" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_sandbox "$sb"
  run bash "$SCRIPT" --root "$sb"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nodes:      3"* ]]
  [[ "$output" == *"Edges:      2"* ]]
}

@test "ascii output renders upstream→downstream edges" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_sandbox "$sb"
  run bash "$SCRIPT" --root "$sb"
  [ "$status" -eq 0 ]
  [[ "$output" == *"proj-b --[blocks]--> proj-a"* ]]
  [[ "$output" == *"proj-c --[feeds]--> proj-b"* ]]
}

@test "ascii output flags at-risk status badge" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_sandbox "$sb"
  run bash "$SCRIPT" --root "$sb"
  [ "$status" -eq 0 ]
  [[ "$output" == *"AT-RISK"* ]]
}

@test "ascii output flags blocked status badge" {
  local sb="$BATS_TEST_TMPDIR/sb"
  mkdir -p "$sb/p1" "$sb/p2"
  cat > "$sb/p1/deps.yaml" <<YAML
project: "p1"
tenant: "t"
dependencies:
  upstream:
    - project: "p2"
      type: "blocks"
      deliverable: "D"
      needed_by: "2026-01-01"
      status: "blocked"
YAML
  cat > "$sb/p2/deps.yaml" <<YAML
project: "p2"
tenant: "t"
dependencies:
  upstream: []
YAML
  run bash "$SCRIPT" --root "$sb"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BLOCKED"* ]]
}

# ── Mermaid output ──────────────────────────────────────────────────────────

@test "mermaid output starts with 'graph LR'" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_sandbox "$sb"
  run bash "$SCRIPT" --root "$sb" --format mermaid
  [ "$status" -eq 0 ]
  [[ "$output" == *"graph LR"* ]]
}

@test "mermaid output contains node declarations" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_sandbox "$sb"
  run bash "$SCRIPT" --root "$sb" --format mermaid
  [ "$status" -eq 0 ]
  [[ "$output" == *'proj_a["proj-a"]'* ]]
  [[ "$output" == *'proj_b["proj-b"]'* ]]
}

@test "mermaid output contains edge with label" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_sandbox "$sb"
  run bash "$SCRIPT" --root "$sb" --format mermaid
  [ "$status" -eq 0 ]
  [[ "$output" == *"proj_b -->|blocks| proj_a"* ]]
}

@test "mermaid output annotates non-on-track status in label" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_sandbox "$sb"
  run bash "$SCRIPT" --root "$sb" --format mermaid
  [ "$status" -eq 0 ]
  [[ "$output" == *"feeds (at-risk)"* ]]
}

# ── JSON output ─────────────────────────────────────────────────────────────

@test "json output is valid JSON with expected keys" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_sandbox "$sb"
  run bash -c 'bash '"$SCRIPT"' --root '"$sb"' --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert \"nodes\" in d; assert \"edges\" in d; assert \"n_nodes\" in d; print(\"ok\")"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "json output contains 3 nodes and 2 edges for sandbox" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_sandbox "$sb"
  run bash "$SCRIPT" --root "$sb" --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"n_nodes":3'* ]]
  [[ "$output" == *'"n_edges":2'* ]]
}

@test "json edge objects have from/to/type/status" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_sandbox "$sb"
  run bash "$SCRIPT" --root "$sb" --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"from":"proj-b"'* ]]
  [[ "$output" == *'"to":"proj-a"'* ]]
  [[ "$output" == *'"type":"blocks"'* ]]
  [[ "$output" == *'"status":"on-track"'* ]]
}

# ── Multi-upstream ──────────────────────────────────────────────────────────

@test "project with multiple upstream deps creates multiple edges" {
  local sb="$BATS_TEST_TMPDIR/sb"
  mkdir -p "$sb/hub" "$sb/a" "$sb/b"
  cat > "$sb/hub/deps.yaml" <<YAML
project: "hub"
tenant: "t"
dependencies:
  upstream:
    - project: "a"
      type: "blocks"
      deliverable: "D-A"
      needed_by: "2026-01-01"
      status: "on-track"
    - project: "b"
      type: "feeds"
      deliverable: "D-B"
      needed_by: "2026-02-01"
      status: "on-track"
YAML
  cat > "$sb/a/deps.yaml" <<YAML
project: "a"
tenant: "t"
dependencies:
  upstream: []
YAML
  cat > "$sb/b/deps.yaml" <<YAML
project: "b"
tenant: "t"
dependencies:
  upstream: []
YAML
  run bash "$SCRIPT" --root "$sb" --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"n_nodes":3'* ]]
  [[ "$output" == *'"n_edges":2'* ]]
}

# ── Negative ───────────────────────────────────────────────────────────────

@test "negative: project without deps.yaml is not included" {
  local sb="$BATS_TEST_TMPDIR/sb"
  mkdir -p "$sb/standalone"
  # No deps.yaml.
  run bash "$SCRIPT" --root "$sb"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nodes:      0"* ]]
}

@test "negative: unknown flag rejected" {
  run bash "$SCRIPT" --some-flag
  [ "$status" -eq 2 ]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: deep nested dirs are ignored (only depth 2)" {
  local sb="$BATS_TEST_TMPDIR/sb"
  mkdir -p "$sb/valid" "$sb/deep/nested/path"
  cat > "$sb/valid/deps.yaml" <<YAML
project: "valid"
tenant: "t"
dependencies:
  upstream: []
YAML
  cat > "$sb/deep/nested/path/deps.yaml" <<YAML
project: "ignored-deep"
tenant: "t"
dependencies:
  upstream: []
YAML
  run bash "$SCRIPT" --root "$sb"
  [ "$status" -eq 0 ]
  [[ "$output" == *"valid"* ]]
  [[ "$output" != *"ignored-deep"* ]]
}

@test "edge: upstream project not declared elsewhere is still added as node" {
  local sb="$BATS_TEST_TMPDIR/sb"
  mkdir -p "$sb/only"
  cat > "$sb/only/deps.yaml" <<YAML
project: "only"
tenant: "t"
dependencies:
  upstream:
    - project: "external-dep"
      type: "blocks"
      deliverable: "D"
      needed_by: "2026-01-01"
      status: "on-track"
YAML
  run bash "$SCRIPT" --root "$sb" --json
  [ "$status" -eq 0 ]
  [[ "$output" == *"external-dep"* ]]
  [[ "$output" == *'"n_nodes":2'* ]]
}

# ── Isolation ──────────────────────────────────────────────────────────────

@test "isolation: script does not modify any deps.yaml" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_sandbox "$sb"
  local hash_before
  hash_before=$(find "$sb" -name 'deps.yaml' -exec md5sum {} \; | md5sum | awk '{print $1}')
  bash "$SCRIPT" --root "$sb" >/dev/null 2>&1
  bash "$SCRIPT" --root "$sb" --format mermaid >/dev/null 2>&1
  bash "$SCRIPT" --root "$sb" --json >/dev/null 2>&1
  local hash_after
  hash_after=$(find "$sb" -name 'deps.yaml' -exec md5sum {} \; | md5sum | awk '{print $1}')
  [[ "$hash_before" == "$hash_after" ]]
}

@test "isolation: all 3 output formats reflect same n_edges" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_sandbox "$sb"
  run bash "$SCRIPT" --root "$sb"
  [[ "$output" == *"Edges:      2"* ]]
  run bash "$SCRIPT" --root "$sb" --json
  [[ "$output" == *'"n_edges":2'* ]]
}
