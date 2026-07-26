#!/usr/bin/env bats
# BATS tests for engagement-capacity-check.sh — SE-271 S4
# Tests capacity enforcement per engagement with deny-by-default

SCRIPT="scripts/engagement-capacity-check.sh"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export REPO_ROOT_ENV="$REPO_ROOT"
  FAKE_TMP=$(mktemp -d)
  export FAKE_TMP
  ENG_DIR="$FAKE_TMP/engagements"
  mkdir -p "$ENG_DIR"
}

teardown() {
  rm -rf "$FAKE_TMP"
  unset ENG_FILE_ENV ENG_TOOL ENG_DOMAIN ENG_ACTION
}

run_check() {
  run bash "$SCRIPT" "$@"
}

@test "script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "script has set -uo pipefail" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "script passes bash -n syntax check" {
  run bash -n "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "no engagement → unrestricted (operator mode)" {
  run_check --no-engagement --tool bash --domain code
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "unrestricted" ]]
}

@test "no engagement flag → all tools allowed" {
  run_check --no-engagement --tool write --action deploy --domain infra
  [[ "$status" -eq 0 ]]
}

@test "missing engagement file → unrestricted (default)" {
  run_check --tool bash --domain code
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "unrestricted" ]]
}

@test "nonexistent engagement file → exit 3" {
  run_check --engagement "$FAKE_TMP/nonexistent.yaml" --tool bash
  [[ "$status" -eq 3 ]]
}

@test "active engagement with in-scope tool → allowed" {
  cat > "$ENG_DIR/acme.yaml" << 'YAML'
engagement:
  id: "acme-001"
  client: "acme-corp"
  body: "acme-division"
  wall: "wall-acme"
  status: active
  scope:
    tools: [bash, python, read, write]
    domains: [code, docs]
    actions: [spec-generate, code-audit]
YAML
  run_check --engagement "$ENG_DIR/acme.yaml" --tool bash
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "in-scope" ]]
}

@test "active engagement with out-of-scope tool → denied" {
  cat > "$ENG_DIR/acme.yaml" << 'YAML'
engagement:
  id: "acme-001"
  client: "acme-corp"
  status: active
  scope:
    tools: [read]
    domains: [docs]
    actions: []
YAML
  run_check --engagement "$ENG_DIR/acme.yaml" --tool write
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "denied" ]]
}

@test "active engagement with in-scope domain → allowed" {
  cat > "$ENG_DIR/acme.yaml" << 'YAML'
engagement:
  id: "acme-001"
  client: "acme-corp"
  status: active
  scope:
    domains: [code, testing, docs]
    tools: []
    actions: []
YAML
  run_check --engagement "$ENG_DIR/acme.yaml" --domain code
  [[ "$status" -eq 0 ]]
}

@test "active engagement with out-of-scope domain → denied" {
  cat > "$ENG_DIR/acme.yaml" << 'YAML'
engagement:
  id: "acme-001"
  client: "acme-corp"
  status: active
  scope:
    domains: [docs]
    tools: []
    actions: []
YAML
  run_check --engagement "$ENG_DIR/acme.yaml" --domain infra
  [[ "$status" -eq 1 ]]
}

@test "active engagement with in-scope action → allowed" {
  cat > "$ENG_DIR/acme.yaml" << 'YAML'
engagement:
  id: "acme-001"
  client: "acme-corp"
  status: active
  scope:
    actions: [spec-generate, report-executive]
    tools: []
    domains: []
YAML
  run_check --engagement "$ENG_DIR/acme.yaml" --action spec-generate
  [[ "$status" -eq 0 ]]
}

@test "active engagement with out-of-scope action → denied" {
  cat > "$ENG_DIR/acme.yaml" << 'YAML'
engagement:
  id: "acme-001"
  client: "acme-corp"
  status: active
  scope:
    actions: [report-executive]
    tools: []
    domains: []
YAML
  run_check --engagement "$ENG_DIR/acme.yaml" --action deploy
  [[ "$status" -eq 1 ]]
}

@test "multiple checks: all must be in scope" {
  cat > "$ENG_DIR/acme.yaml" << 'YAML'
engagement:
  id: "acme-001"
  client: "acme-corp"
  status: active
  scope:
    tools: [bash, read]
    domains: [code]
    actions: [spec-generate]
YAML
  # All in scope
  run_check --engagement "$ENG_DIR/acme.yaml" --tool bash --domain code --action spec-generate
  [[ "$status" -eq 0 ]]
  # Domain out of scope
  run_check --engagement "$ENG_DIR/acme.yaml" --tool bash --domain infra --action spec-generate
  [[ "$status" -eq 1 ]]
}

@test "deny-by-default: empty scope denies all" {
  cat > "$ENG_DIR/acme.yaml" << 'YAML'
engagement:
  id: "acme-001"
  client: "acme-corp"
  status: active
  scope:
    domains: []
    tools: []
    actions: []
YAML
  run_check --engagement "$ENG_DIR/acme.yaml" --tool bash
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "empty-scope" ]]
}

@test "non-active engagement status → denied" {
  cat > "$ENG_DIR/acme.yaml" << 'YAML'
engagement:
  id: "acme-001"
  client: "acme-corp"
  status: suspended
  scope:
    tools: [bash]
YAML
  run_check --engagement "$ENG_DIR/acme.yaml" --tool bash
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "not-active" ]]
}

@test "terminated engagement → denied" {
  cat > "$ENG_DIR/acme.yaml" << 'YAML'
engagement:
  id: "acme-001"
  client: "acme-corp"
  status: terminated
  scope:
    tools: [bash]
YAML
  run_check --engagement "$ENG_DIR/acme.yaml" --tool bash
  [[ "$status" -eq 1 ]]
}

@test "no args → usage error exit 2" {
  run_check
  [[ "$status" -eq 2 ]]
}

@test "unknown argument → exit 2" {
  run_check --foobar
  [[ "$status" -eq 2 ]]
}

@test "output is valid JSON" {
  cat > "$ENG_DIR/acme.yaml" << 'YAML'
engagement:
  id: "acme-001"
  client: "acme-corp"
  status: active
  scope:
    tools: [bash]
    domains: [code]
    actions: [spec-generate]
YAML
  run_check --engagement "$ENG_DIR/acme.yaml" --tool bash --domain code
  python3 -c "import json; json.loads('''$output''')" 2>/dev/null
  [[ "$status" -eq 0 ]]
}

@test "JSON output includes engagement metadata" {
  cat > "$ENG_DIR/acme.yaml" << 'YAML'
engagement:
  id: "acme-001"
  client: "acme-corp"
  status: active
  scope:
    tools: [bash]
    domains: [code]
    actions: [spec-generate]
YAML
  run_check --engagement "$ENG_DIR/acme.yaml" --tool bash
  [[ "$output" =~ "acme-001" ]]
  [[ "$output" =~ "acme-corp" ]]
}

@test "JSON output includes scope when denied" {
  cat > "$ENG_DIR/acme.yaml" << 'YAML'
engagement:
  id: "acme-001"
  client: "acme-corp"
  status: active
  scope:
    tools: [read]
    domains: []
    actions: []
YAML
  run_check --engagement "$ENG_DIR/acme.yaml" --tool write
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "scope" ]]
}
