#!/usr/bin/env bats
# BATS tests for scripts/portfolio-deps-status.sh (SPEC-SE-020 Slice 5).
# Validates per-project status dashboard: upstream/downstream/shared,
# implicit downstream discovery, health verdict, exit codes.
#
# Ref: SPEC-SE-020 §6, docs/rules/domain/portfolio-as-graph.md
# Safety: script under test `set -uo pipefail`, read-only.

SCRIPT="scripts/portfolio-deps-status.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() { cd /; }

build_portfolio() {
  local root="$1"
  mkdir -p "$root/alpha" "$root/beta" "$root/gamma"
  cat > "$root/alpha/deps.yaml" <<YAML
project: "alpha"
tenant: "t"
dependencies:
  upstream:
    - project: "beta"
      type: "blocks"
      deliverable: "auth-service"
      needed_by: "2026-06-01"
      status: "at-risk"
  downstream:
    - project: "gamma"
      type: "feeds"
      deliverable: "alpha-api"
      needed_by: "2026-09-01"
YAML
  cat > "$root/beta/deps.yaml" <<YAML
project: "beta"
tenant: "t"
dependencies:
  upstream: []
YAML
  cat > "$root/gamma/deps.yaml" <<YAML
project: "gamma"
tenant: "t"
dependencies:
  upstream:
    - project: "alpha"
      type: "feeds"
      deliverable: "alpha-api"
      needed_by: "2026-09-01"
      status: "on-track"
YAML
}

@test "script exists and executable" { [[ -x "$SCRIPT" ]]; }

@test "uses set -uo pipefail" {
  run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "passes bash -n" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }

@test "references SPEC-SE-020" {
  run grep -c 'SPEC-SE-020' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"project"* ]]
}

@test "rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "requires --project" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "rejects nonexistent project" {
  run bash "$SCRIPT" --project /nope
  [ "$status" -eq 2 ]
}

@test "rejects project without deps.yaml" {
  local p="$BATS_TEST_TMPDIR/noDeps"
  mkdir -p "$p"
  run bash "$SCRIPT" --project "$p"
  [ "$status" -eq 2 ]
}

@test "at-risk upstream returns exit 1" {
  local root="$BATS_TEST_TMPDIR/root"
  build_portfolio "$root"
  run bash "$SCRIPT" --project "$root/alpha" --root "$root"
  [ "$status" -eq 1 ]
  [[ "$output" == *"AT-RISK"* ]]
}

@test "leaf project returns on-track" {
  local root="$BATS_TEST_TMPDIR/root"
  build_portfolio "$root"
  run bash "$SCRIPT" --project "$root/beta" --root "$root"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ON-TRACK"* ]]
}

@test "blocked upstream returns exit 2" {
  local root="$BATS_TEST_TMPDIR/root"
  mkdir -p "$root/p1" "$root/p2"
  cat > "$root/p1/deps.yaml" <<YAML
project: "p1"
tenant: "t"
dependencies:
  upstream:
    - project: "p2"
      type: "blocks"
      deliverable: "X"
      needed_by: "2026-01-01"
      status: "blocked"
YAML
  cat > "$root/p2/deps.yaml" <<YAML
project: "p2"
tenant: "t"
dependencies:
  upstream: []
YAML
  run bash "$SCRIPT" --project "$root/p1" --root "$root"
  [ "$status" -eq 2 ]
  [[ "$output" == *"BLOCKED"* ]]
}

@test "shows upstream list with deliverable and status" {
  local root="$BATS_TEST_TMPDIR/root"
  build_portfolio "$root"
  run bash "$SCRIPT" --project "$root/alpha" --root "$root"
  [[ "$output" == *"auth-service"* ]]
  [[ "$output" == *"2026-06-01"* ]]
  [[ "$output" == *"at-risk"* ]]
}

@test "shows declared downstream" {
  local root="$BATS_TEST_TMPDIR/root"
  build_portfolio "$root"
  run bash "$SCRIPT" --project "$root/alpha" --root "$root"
  [[ "$output" == *"Downstream declared"* ]]
  [[ "$output" == *"gamma"* ]]
}

@test "discovers implicit downstream" {
  local root="$BATS_TEST_TMPDIR/root"
  build_portfolio "$root"
  run bash "$SCRIPT" --project "$root/beta" --root "$root"
  [[ "$output" == *"implicit"* ]]
  [[ "$output" == *"alpha"* ]]
}

@test "shared_resources shown when present" {
  local root="$BATS_TEST_TMPDIR/root"
  mkdir -p "$root/p"
  cat > "$root/p/deps.yaml" <<YAML
project: "p"
tenant: "t"
dependencies:
  upstream: []
shared_resources:
  - person: "@devx"
    projects: ["p", "other"]
    allocation_pct: [70, 30]
    conflict: false
YAML
  run bash "$SCRIPT" --project "$root/p" --root "$root"
  [[ "$output" == *"@devx"* ]]
  [[ "$output" == *"100%"* ]]
}

@test "shared conflict=true shows marker" {
  local root="$BATS_TEST_TMPDIR/root"
  mkdir -p "$root/p"
  cat > "$root/p/deps.yaml" <<YAML
project: "p"
tenant: "t"
dependencies:
  upstream: []
shared_resources:
  - person: "@dba"
    projects: ["p", "other", "third"]
    allocation_pct: [50, 30, 20]
    conflict: true
YAML
  run bash "$SCRIPT" --project "$root/p" --root "$root"
  [[ "$output" == *"@dba"* ]]
  [[ "$output" == *"🔥"* ]]
}

@test "json output has expected keys" {
  local root="$BATS_TEST_TMPDIR/root"
  build_portfolio "$root"
  run bash -c 'bash '"$SCRIPT"' --project '"$root/alpha"' --root '"$root"' --json | python3 -c "
import json,sys
d = json.load(sys.stdin)
for k in [\"project\",\"health\",\"upstream\",\"downstream_declared\",\"downstream_implicit\",\"shared_resources\"]:
    assert k in d, f\"missing {k}\"
print(\"ok\")
"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "json health field matches verdict" {
  local root="$BATS_TEST_TMPDIR/root"
  build_portfolio "$root"
  run bash "$SCRIPT" --project "$root/alpha" --root "$root" --json
  [[ "$output" == *'"health": "AT-RISK"'* ]]
}

@test "auto-derives root from parent if not given" {
  local root="$BATS_TEST_TMPDIR/root"
  build_portfolio "$root"
  run bash "$SCRIPT" --project "$root/beta"
  [ "$status" -eq 0 ]
  [[ "$output" == *"alpha"* ]]
}

@test "isolation: does not modify deps.yaml" {
  local root="$BATS_TEST_TMPDIR/root"
  build_portfolio "$root"
  local h_before
  h_before=$(find "$root" -name 'deps.yaml' -exec md5sum {} \; | md5sum | awk '{print $1}')
  bash "$SCRIPT" --project "$root/alpha" --root "$root" >/dev/null 2>&1 || true
  local h_after
  h_after=$(find "$root" -name 'deps.yaml' -exec md5sum {} \; | md5sum | awk '{print $1}')
  [[ "$h_before" == "$h_after" ]]
}

@test "isolation: exit codes 0/1/2" {
  local root="$BATS_TEST_TMPDIR/root"
  build_portfolio "$root"
  run bash "$SCRIPT" --project "$root/beta" --root "$root"
  [[ "$status" -eq 0 ]]
  run bash "$SCRIPT" --project "$root/alpha" --root "$root"
  [[ "$status" -eq 1 ]]
  run bash "$SCRIPT" --bogus
  [[ "$status" -eq 2 ]]
}
