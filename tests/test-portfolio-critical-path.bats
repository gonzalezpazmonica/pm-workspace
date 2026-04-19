#!/usr/bin/env bats
# BATS tests for scripts/portfolio-critical-path.sh (SPEC-SE-020 Slice 3).
# Validates critical path computation, slack calculation, bottleneck detection,
# JSON output, CLI surface, edge cases.
#
# Ref: SPEC-SE-020 §Cross-project critical path
# Safety: script under test `set -uo pipefail`, read-only.

SCRIPT="scripts/portfolio-critical-path.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() {
  cd /
}

# Helper: build a 3-project sandbox where erp-migration is critical + at-risk.
build_critical_sandbox() {
  local sb="$1"
  mkdir -p "$sb/sso-integration" "$sb/erp-migration" "$sb/mobile-app"
  cat > "$sb/sso-integration/deps.yaml" <<YAML
project: "sso-integration"
tenant: "test"
dependencies:
  upstream: []
YAML
  cat > "$sb/erp-migration/deps.yaml" <<YAML
project: "erp-migration"
tenant: "test"
dependencies:
  upstream:
    - project: "sso-integration"
      type: "blocks"
      deliverable: "D-003"
      needed_by: "2026-07-15"
      status: "at-risk"
YAML
  cat > "$sb/mobile-app/deps.yaml" <<YAML
project: "mobile-app"
tenant: "test"
dependencies:
  upstream:
    - project: "erp-migration"
      type: "feeds"
      deliverable: "API spec"
      needed_by: "2026-09-01"
      status: "on-track"
YAML
}

# Helper: sandbox where nothing is critical (all on-track, far-future dates).
build_healthy_sandbox() {
  local sb="$1"
  mkdir -p "$sb/a" "$sb/b"
  cat > "$sb/a/deps.yaml" <<YAML
project: "a"
tenant: "test"
dependencies:
  upstream: []
YAML
  cat > "$sb/b/deps.yaml" <<YAML
project: "b"
tenant: "test"
dependencies:
  upstream:
    - project: "a"
      type: "feeds"
      deliverable: "D"
      needed_by: "2027-01-01"
      status: "on-track"
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

@test "script references SPEC-SE-020 Slice 3" {
  run grep -c 'SPEC-SE-020' "$SCRIPT"
  [[ "$output" -ge 1 ]]
  run grep -c 'Slice 3\|critical path' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── CLI ────────────────────────────────────────────────────────────────────

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"root"* ]]
  [[ "$output" == *"critical"* ]]
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

# ── Empty root ─────────────────────────────────────────────────────────────

@test "empty root returns gracefully with zero projects" {
  local sb="$BATS_TEST_TMPDIR/empty"
  mkdir -p "$sb"
  run bash "$SCRIPT" --root "$sb"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no projects"* || "$output" == *"0"* ]]
}

# ── Critical path detection ────────────────────────────────────────────────

@test "detects critical path in 3-project sandbox" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_critical_sandbox "$sb"
  run bash "$SCRIPT" --root "$sb"
  # Bottleneck at-risk returns exit 1.
  [ "$status" -eq 1 ]
  [[ "$output" == *"erp-migration"* ]]
  [[ "$output" == *"0 days"* ]]
}

@test "bottleneck is detected when upstream is at-risk" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_critical_sandbox "$sb"
  run bash "$SCRIPT" --root "$sb"
  [ "$status" -eq 1 ]
  [[ "$output" == *"BOTTLENECK"* ]]
  [[ "$output" == *"at-risk"* ]]
}

@test "earliest deadline is reported" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_critical_sandbox "$sb"
  run bash "$SCRIPT" --root "$sb"
  [[ "$output" == *"2026-07-15"* ]]
}

@test "healthy portfolio (all on-track) returns exit 0 with no bottleneck" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_healthy_sandbox "$sb"
  run bash "$SCRIPT" --root "$sb"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No bottleneck"* ]]
}

# ── Slack computation ──────────────────────────────────────────────────────

@test "slack=0 for earliest-deadline project" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_critical_sandbox "$sb"
  run bash "$SCRIPT" --root "$sb" --json
  # Exit 1 because bottleneck detected (at-risk on critical path).
  [[ "$status" -eq 1 || "$status" -eq 0 ]]
  [[ "$output" == *'"erp-migration": 0'* ]]
}

@test "slack>0 for later-deadline project" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_critical_sandbox "$sb"
  run bash "$SCRIPT" --root "$sb" --json
  [[ "$status" -eq 1 || "$status" -eq 0 ]]
  [[ "$output" == *'"mobile-app":'* ]]
  # mobile-app has 2026-09-01 needed_by vs earliest 2026-07-15 → 48 days slack.
  [[ "$output" == *'"mobile-app": 48'* ]]
}

# ── JSON output ────────────────────────────────────────────────────────────

@test "json output has expected top-level keys" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_critical_sandbox "$sb"
  run bash -c 'bash '"$SCRIPT"' --root '"$sb"' --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert \"n_projects\" in d; assert \"critical_path\" in d; assert \"bottleneck\" in d; assert \"slack\" in d; print(\"ok\")"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "json critical_path is a list" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_critical_sandbox "$sb"
  run bash -c 'bash '"$SCRIPT"' --root '"$sb"' --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert isinstance(d[\"critical_path\"], list); print(\"ok\")"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "json bottleneck is null when healthy" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_healthy_sandbox "$sb"
  run bash "$SCRIPT" --root "$sb" --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"bottleneck": null'* ]]
}

@test "json bottleneck dict when at-risk" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_critical_sandbox "$sb"
  run bash "$SCRIPT" --root "$sb" --json
  [[ "$status" -eq 1 || "$status" -eq 0 ]]
  [[ "$output" == *'"status": "at-risk"'* ]]
  [[ "$output" == *'"slack_days": 0'* ]]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: single project without deps returns 0 with no critical path" {
  local sb="$BATS_TEST_TMPDIR/sb"
  mkdir -p "$sb/lonely"
  cat > "$sb/lonely/deps.yaml" <<YAML
project: "lonely"
tenant: "test"
dependencies:
  upstream: []
YAML
  run bash "$SCRIPT" --root "$sb"
  [ "$status" -eq 0 ]
}

@test "edge: project dir without deps.yaml is ignored" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_critical_sandbox "$sb"
  mkdir -p "$sb/no-deps-project"
  run bash "$SCRIPT" --root "$sb" --json
  [[ "$output" == *'"n_projects": 3'* ]]
  [[ "$output" != *"no-deps-project"* ]]
}

@test "edge: blocked status also triggers bottleneck" {
  local sb="$BATS_TEST_TMPDIR/sb"
  mkdir -p "$sb/p1" "$sb/p2"
  cat > "$sb/p1/deps.yaml" <<YAML
project: "p1"
tenant: "test"
dependencies:
  upstream: []
YAML
  cat > "$sb/p2/deps.yaml" <<YAML
project: "p2"
tenant: "test"
dependencies:
  upstream:
    - project: "p1"
      type: "blocks"
      deliverable: "D"
      needed_by: "2026-06-01"
      status: "blocked"
YAML
  run bash "$SCRIPT" --root "$sb"
  [ "$status" -eq 1 ]
  [[ "$output" == *"BOTTLENECK"* || "$output" == *"blocked"* ]]
}

# ── Isolation ──────────────────────────────────────────────────────────────

@test "isolation: script does not modify deps.yaml" {
  local sb="$BATS_TEST_TMPDIR/sb"
  build_critical_sandbox "$sb"
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
  build_critical_sandbox "$BATS_TEST_TMPDIR/critical"
  run bash "$SCRIPT" --root "$BATS_TEST_TMPDIR/critical"
  [[ "$status" -eq 1 ]]
  run bash "$SCRIPT" --bogus
  [[ "$status" -eq 2 ]]
}
