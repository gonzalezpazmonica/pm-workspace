#!/usr/bin/env bats
# BATS tests for scripts/portfolio-contention.sh (SPEC-SE-020 Slice 4).
# Validates over-allocation, critical-path collision, bus-factor risk detection.
#
# Ref: SPEC-SE-020 §Resource contention detection
# Safety: script under test `set -uo pipefail`, read-only.

SCRIPT="scripts/portfolio-contention.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() {
  cd /
}

# Helper: sandbox with over-allocated person.
build_overalloc_sandbox() {
  local sb="$1"
  mkdir -p "$sb/alpha" "$sb/beta" "$sb/gamma"
  cat > "$sb/alpha/deps.yaml" <<YAML
project: "alpha"
tenant: "t"
dependencies:
  upstream: []
shared_resources:
  - person: "@dba-lead"
    projects: ["alpha", "beta", "gamma"]
    allocation_pct: [50, 40, 30]
    conflict: true
YAML
  cat > "$sb/beta/deps.yaml" <<YAML
project: "beta"
tenant: "t"
dependencies:
  upstream: []
YAML
  cat > "$sb/gamma/deps.yaml" <<YAML
project: "gamma"
tenant: "t"
dependencies:
  upstream: []
YAML
}

# Helper: healthy sandbox (no contention).
build_healthy_sandbox() {
  local sb="$1"
  mkdir -p "$sb/alpha" "$sb/beta"
  cat > "$sb/alpha/deps.yaml" <<YAML
project: "alpha"
tenant: "t"
dependencies:
  upstream: []
shared_resources:
  - person: "@dev1"
    projects: ["alpha", "beta"]
    allocation_pct: [60, 40]
    conflict: false
YAML
  cat > "$sb/beta/deps.yaml" <<YAML
project: "beta"
tenant: "t"
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

@test "script references SPEC-SE-020 Slice 4" {
  run grep -c 'SPEC-SE-020' "$SCRIPT"
  [[ "$output" -ge 1 ]]
  run grep -cE 'Slice 4|Resource contention' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── CLI ────────────────────────────────────────────────────────────────────

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"root"* ]]
  [[ "$output" == *"contention"* ]]
}

@test "rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "requires --root" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "rejects nonexistent root" {
  run bash "$SCRIPT" --root /does/not/exist
  [ "$status" -eq 2 ]
}

@test "rejects nonexistent critical-path file" {
  local sb="$BATS_TEST_TMPDIR/sb"
  mkdir -p "$sb"
  run bash "$SCRIPT" --root "$sb" --critical-path /not/here.json
  [ "$status" -eq 2 ]
}

# ── Over-allocation ─────────────────────────────────────────────────────────

@test "detects over-allocation (>100%)" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_overalloc_sandbox "$sb"
  run bash "$SCRIPT" --root "$sb"
  [ "$status" -eq 1 ]
  [[ "$output" == *"over-allocation"* ]]
  [[ "$output" == *"@dba-lead"* ]]
  [[ "$output" == *"120"* ]]
}

@test "healthy allocation (<=100%) passes" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_healthy_sandbox "$sb"
  run bash "$SCRIPT" --root "$sb"
  [ "$status" -eq 0 ]
  [[ "$output" == *"healthy"* || "$output" == *"No contention"* ]]
}

# ── Bus-factor risk ────────────────────────────────────────────────────────

@test "detects bus-factor risk (3+ projects ≥80%)" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_overalloc_sandbox "$sb"
  run bash "$SCRIPT" --root "$sb"
  [ "$status" -eq 1 ]
  [[ "$output" == *"bus-factor"* ]]
}

@test "no bus-factor risk for 2 projects" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_healthy_sandbox "$sb"
  run bash "$SCRIPT" --root "$sb"
  [ "$status" -eq 0 ]
  [[ "$output" != *"bus-factor"* ]]
}

# ── Critical-path collision ─────────────────────────────────────────────────

@test "detects critical-path collision when 2+ critical projects overlap" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_overalloc_sandbox "$sb"
  cat > "$sb/cp.json" <<EOF
{"critical_path":[{"project":"alpha","slack_days":0},{"project":"beta","slack_days":2}]}
EOF
  run bash "$SCRIPT" --root "$sb" --critical-path "$sb/cp.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"critical-path-collision"* ]]
  [[ "$output" == *"@dba-lead"* ]]
}

@test "no collision alert without critical-path file" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_overalloc_sandbox "$sb"
  run bash "$SCRIPT" --root "$sb"
  [[ "$output" != *"critical-path-collision"* ]]
}

@test "no collision when only 1 critical project" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_overalloc_sandbox "$sb"
  cat > "$sb/cp.json" <<EOF
{"critical_path":[{"project":"alpha","slack_days":0}]}
EOF
  run bash "$SCRIPT" --root "$sb" --critical-path "$sb/cp.json"
  [[ "$output" != *"critical-path-collision"* ]]
}

# ── JSON output ────────────────────────────────────────────────────────────

@test "json output has expected top-level keys" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_overalloc_sandbox "$sb"
  run bash -c 'bash '"$SCRIPT"' --root '"$sb"' --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert \"alerts\" in d; assert \"n_shared_entries\" in d; assert \"healthy\" in d; print(\"ok\")"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "json alerts is a list of structured dicts" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_overalloc_sandbox "$sb"
  run bash -c 'bash '"$SCRIPT"' --root '"$sb"' --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert isinstance(d[\"alerts\"], list); assert all(\"type\" in a and \"person\" in a for a in d[\"alerts\"]); print(\"ok\")"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "json healthy:true when no alerts" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_healthy_sandbox "$sb"
  run bash "$SCRIPT" --root "$sb" --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"healthy": true'* ]]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: empty portfolio returns healthy" {
  local sb="$BATS_TEST_TMPDIR/empty"
  mkdir -p "$sb"
  run bash "$SCRIPT" --root "$sb"
  [ "$status" -eq 0 ]
}

@test "edge: projects without shared_resources return healthy" {
  local sb="$BATS_TEST_TMPDIR/sb"
  mkdir -p "$sb/p1" "$sb/p2"
  cat > "$sb/p1/deps.yaml" <<YAML
project: "p1"
tenant: "t"
dependencies:
  upstream: []
YAML
  cat > "$sb/p2/deps.yaml" <<YAML
project: "p2"
tenant: "t"
dependencies:
  upstream: []
YAML
  run bash "$SCRIPT" --root "$sb"
  [ "$status" -eq 0 ]
}

@test "edge: exactly 100% allocation is not over-allocation" {
  local sb="$BATS_TEST_TMPDIR/sb"
  mkdir -p "$sb/a" "$sb/b"
  cat > "$sb/a/deps.yaml" <<YAML
project: "a"
tenant: "t"
dependencies:
  upstream: []
shared_resources:
  - person: "@dev"
    projects: ["a", "b"]
    allocation_pct: [60, 40]
    conflict: false
YAML
  cat > "$sb/b/deps.yaml" <<YAML
project: "b"
tenant: "t"
dependencies:
  upstream: []
YAML
  run bash "$SCRIPT" --root "$sb"
  [ "$status" -eq 0 ]
  [[ "$output" != *"over-allocation"* ]]
}

# ── Isolation ──────────────────────────────────────────────────────────────

@test "isolation: script does not modify deps.yaml" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_overalloc_sandbox "$sb"
  local h_before
  h_before=$(find "$sb" -name 'deps.yaml' -exec md5sum {} \; | md5sum | awk '{print $1}')
  bash "$SCRIPT" --root "$sb" >/dev/null 2>&1 || true
  bash "$SCRIPT" --root "$sb" --json >/dev/null 2>&1 || true
  local h_after
  h_after=$(find "$sb" -name 'deps.yaml' -exec md5sum {} \; | md5sum | awk '{print $1}')
  [[ "$h_before" == "$h_after" ]]
}

@test "isolation: exit codes are 0/1/2" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_healthy_sandbox "$sb"
  run bash "$SCRIPT" --root "$sb"
  [[ "$status" -eq 0 ]]
  build_overalloc_sandbox "$BATS_TEST_TMPDIR/bad"
  run bash "$SCRIPT" --root "$BATS_TEST_TMPDIR/bad"
  [[ "$status" -eq 1 ]]
  run bash "$SCRIPT" --bogus
  [[ "$status" -eq 2 ]]
}
