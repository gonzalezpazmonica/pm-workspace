#!/usr/bin/env bats
# test-se-020-crossdeps.bats — SE-020 Cross-Project Dependencies
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-020-cross-project-deps.md

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  DEP_GRAPH="${REPO_ROOT}/scripts/enterprise/dep-graph.sh"
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR REPO_ROOT
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

_create_deps_yaml() {
  local tenant="$1"
  local project="$2"
  local content="$3"
  local proj_dir="${TEST_TMPDIR}/tenants/${tenant}/projects/${project}"
  mkdir -p "$proj_dir"
  echo "$content" > "${proj_dir}/deps.yaml"
}

@test "SE-020: dep-graph.sh exists and is executable" {
  [[ -f "$DEP_GRAPH" ]]
  [[ -x "$DEP_GRAPH" ]]
}

@test "SE-020: dep-graph.sh fails without --tenant" {
  run bash "$DEP_GRAPH"
  [ "$status" -eq 2 ]
}

@test "SE-020: dep-graph.sh generates empty graph for tenant with no projects" {
  local tenant="empty-$$"
  mkdir -p "${TEST_TMPDIR}/tenants/${tenant}/projects"

  run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${DEP_GRAPH}' --tenant '${tenant}'"
  [ "$status" -eq 0 ]
  # Output file should exist
  [[ -f "${TEST_TMPDIR}/output/enterprise/dep-graph-${tenant}.json" ]]
}

@test "SE-020: dep-graph.sh generates JSON with nodes and edges" {
  local tenant="graph-$$"

  _create_deps_yaml "$tenant" "project-a" "$(cat <<'YAML'
project: project-a
tenant: acme
dependencies:
  upstream: []
  downstream:
    - project: project-b
      type: feeds
      status: on-track
shared_resources: []
YAML
)"

  _create_deps_yaml "$tenant" "project-b" "$(cat <<'YAML'
project: project-b
tenant: acme
dependencies:
  upstream:
    - project: project-a
      type: feeds
      status: on-track
  downstream: []
shared_resources: []
YAML
)"

  run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${DEP_GRAPH}' --tenant '${tenant}'"
  [ "$status" -eq 0 ]

  local output_file="${TEST_TMPDIR}/output/enterprise/dep-graph-${tenant}.json"
  [[ -f "$output_file" ]]
  grep -q '"nodes"' "$output_file"
  grep -q '"edges"' "$output_file"
  grep -q '"tenant"' "$output_file"
}

@test "SE-020: dep-graph.sh detects nodes from deps.yaml files" {
  local tenant="nodes-$$"

  for proj in alpha beta gamma; do
    _create_deps_yaml "$tenant" "$proj" "project: ${proj}"$'\n'"tenant: test"
  done

  run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${DEP_GRAPH}' --tenant '${tenant}'"
  [ "$status" -eq 0 ]

  local output_file="${TEST_TMPDIR}/output/enterprise/dep-graph-${tenant}.json"
  # Should have 3 nodes
  node_count=$(grep -o '"id"' "$output_file" | wc -l)
  [[ "$node_count" -ge 3 ]]
}

@test "SE-020: dep-graph.sh writes to custom --output path" {
  local tenant="custom-$$"
  local output_path="${TEST_TMPDIR}/custom-graph.json"
  mkdir -p "${TEST_TMPDIR}/tenants/${tenant}/projects"

  run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${DEP_GRAPH}' \
    --tenant '${tenant}' --output '${output_path}'"
  [ "$status" -eq 0 ]
  [[ -f "$output_path" ]]
}

@test "SE-020: dep-graph.sh output has required JSON keys" {
  local tenant="keys-$$"
  mkdir -p "${TEST_TMPDIR}/tenants/${tenant}/projects"

  bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${DEP_GRAPH}' --tenant '${tenant}'" >/dev/null 2>&1

  local output_file="${TEST_TMPDIR}/output/enterprise/dep-graph-${tenant}.json"
  grep -q '"nodes"' "$output_file"
  grep -q '"edges"' "$output_file"
  grep -q '"cycles"' "$output_file"
  grep -q '"blocked"' "$output_file"
  grep -q '"generated_at"' "$output_file"
}
