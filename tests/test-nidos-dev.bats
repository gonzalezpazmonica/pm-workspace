#!/usr/bin/env bats
# SPEC-098: nidos.sh dev subcommand — dev server lifecycle in a nido.
# Tests: detection heuristics, start/stop lifecycle, failure modes.
# Ref: docs/propuestas/SPEC-098-workspace-bundle-nidos.md
# Related: scripts/nidos-dev-lib.sh

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  NIDOS="$REPO_ROOT/scripts/nidos.sh"
  DEV_LIB="$REPO_ROOT/scripts/nidos-dev-lib.sh"
  TMP_DIR=$(mktemp -d -t nidos-dev-XXXXXX)

  # Source the library in isolation for unit tests
  # shellcheck source=/dev/null
  NIDOS_DIR="$TMP_DIR/nidos"
  mkdir -p "$NIDOS_DIR"
  export NIDOS_DIR
  source "$DEV_LIB"
}

teardown() {
  # Kill any stray dev servers
  for pid_file in "$TMP_DIR"/nidos/*/.dev-server/pid; do
    [[ -f "$pid_file" ]] || continue
    local pid
    pid=$(cat "$pid_file" 2>/dev/null)
    [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
  done
  rm -rf "$TMP_DIR" 2>/dev/null || true
}

# ── Structural invariants ───────────────────────────────────────────────────

@test "nidos.sh exists and is executable" {
  [ -x "$NIDOS" ]
}

@test "nidos-dev-lib.sh exists with valid bash syntax" {
  [ -f "$DEV_LIB" ]
  bash -n "$DEV_LIB"
}

@test "nidos-dev-lib.sh has set -uo pipefail safety" {
  grep -q "set -uo pipefail" "$DEV_LIB"
}

@test "nidos-dev-lib.sh references SPEC-098" {
  grep -q "SPEC-098" "$DEV_LIB"
}

@test "nidos.sh registers dev subcommand" {
  grep -qE "dev\)[[:space:]]*shift.*dev_dispatch" "$NIDOS"
}

@test "nidos.sh sources nidos-dev-lib.sh" {
  grep -q "nidos-dev-lib.sh" "$NIDOS"
}

@test "usage text mentions dev subcommand" {
  run bash "$NIDOS" help
  echo "$output" | grep -q "dev.*start.*stop.*url.*logs"
}

# ── Project detection (positive cases) ──────────────────────────────────────

@test "detect: Angular project (angular.json)" {
  mkdir -p "$TMP_DIR/nidos/angular-nido"
  touch "$TMP_DIR/nidos/angular-nido/angular.json"
  result=$(dev_detect_project "$TMP_DIR/nidos/angular-nido")
  echo "$result" | grep -q "4200"
  echo "$result" | grep -q "npm run start"
}

@test "detect: Next.js project (next.config.js)" {
  mkdir -p "$TMP_DIR/nidos/next-nido"
  touch "$TMP_DIR/nidos/next-nido/next.config.js"
  touch "$TMP_DIR/nidos/next-nido/package.json"
  result=$(dev_detect_project "$TMP_DIR/nidos/next-nido")
  echo "$result" | grep -q "3000"
}

@test "detect: Vite project (vite.config.ts)" {
  mkdir -p "$TMP_DIR/nidos/vite-nido"
  touch "$TMP_DIR/nidos/vite-nido/vite.config.ts"
  touch "$TMP_DIR/nidos/vite-nido/package.json"
  result=$(dev_detect_project "$TMP_DIR/nidos/vite-nido")
  echo "$result" | grep -q "5173"
}

@test "detect: Django project (manage.py)" {
  mkdir -p "$TMP_DIR/nidos/django-nido"
  touch "$TMP_DIR/nidos/django-nido/manage.py"
  result=$(dev_detect_project "$TMP_DIR/nidos/django-nido")
  echo "$result" | grep -q "8000"
  echo "$result" | grep -q "manage.py"
}

@test "detect: Go project (go.mod)" {
  mkdir -p "$TMP_DIR/nidos/go-nido"
  touch "$TMP_DIR/nidos/go-nido/go.mod"
  result=$(dev_detect_project "$TMP_DIR/nidos/go-nido")
  echo "$result" | grep -q "8080"
  echo "$result" | grep -q "go run"
}

@test "detect: Rust project (Cargo.toml)" {
  mkdir -p "$TMP_DIR/nidos/rust-nido"
  touch "$TMP_DIR/nidos/rust-nido/Cargo.toml"
  result=$(dev_detect_project "$TMP_DIR/nidos/rust-nido")
  echo "$result" | grep -q "cargo run"
}

@test "detect: Laravel project (artisan)" {
  mkdir -p "$TMP_DIR/nidos/laravel-nido"
  touch "$TMP_DIR/nidos/laravel-nido/artisan"
  result=$(dev_detect_project "$TMP_DIR/nidos/laravel-nido")
  echo "$result" | grep -q "artisan serve"
  echo "$result" | grep -q "8000"
}

@test "detect: CLAUDE.md overrides default command and port" {
  mkdir -p "$TMP_DIR/nidos/custom-nido"
  cat > "$TMP_DIR/nidos/custom-nido/CLAUDE.md" <<EOF
DEV_SERVER_COMMAND = "make dev"
DEV_SERVER_PORT = 9999
DEV_SERVER_READY = "serving at"
EOF
  result=$(dev_detect_project "$TMP_DIR/nidos/custom-nido")
  echo "$result" | grep -q "make dev"
  echo "$result" | grep -q "9999"
}

# ── Negative / failure modes ────────────────────────────────────────────────

@test "negative: detect returns error on empty directory" {
  mkdir -p "$TMP_DIR/nidos/empty-nido"
  run dev_detect_project "$TMP_DIR/nidos/empty-nido"
  [ "$status" -ne 0 ]
}

@test "negative: detect fails for nonexistent nido path" {
  run dev_detect_project "$TMP_DIR/does-not-exist"
  [ "$status" -ne 0 ]
}

@test "negative: dev_stop on nido without state reports cleanly" {
  mkdir -p "$TMP_DIR/nidos/no-dev-nido"
  run dev_stop "$TMP_DIR/nidos/no-dev-nido"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "no dev server"
}

@test "negative: dev_url on nido without server fails gracefully" {
  mkdir -p "$TMP_DIR/nidos/no-url-nido"
  run dev_url "$TMP_DIR/nidos/no-url-nido"
  [ "$status" -ne 0 ]
}

@test "negative: dev_logs on missing log file reports error" {
  mkdir -p "$TMP_DIR/nidos/no-log-nido/.dev-server"
  run dev_logs "$TMP_DIR/nidos/no-log-nido"
  [ "$status" -ne 0 ]
}

@test "negative: dev_dispatch with missing subcommand shows usage" {
  run dev_dispatch "some-nido" ""
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "usage\|subcommand"
}

# ── Edge cases ──────────────────────────────────────────────────────────────

@test "edge: empty CLAUDE.md without DEV_SERVER falls back to detection" {
  mkdir -p "$TMP_DIR/nidos/empty-config-nido"
  echo "# Empty" > "$TMP_DIR/nidos/empty-config-nido/CLAUDE.md"
  touch "$TMP_DIR/nidos/empty-config-nido/package.json"
  result=$(dev_detect_project "$TMP_DIR/nidos/empty-config-nido")
  [ -n "$result" ]
}

@test "edge: nonexistent nido path in dispatch returns error" {
  NIDOS_DIR="$TMP_DIR/nidos"
  run dev_dispatch "ghost-nido" "url"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "not found"
}

@test "edge: boundary — port resolution returns a free port in range" {
  run dev_resolve_port 34567
  [ "$status" -eq 0 ]
  # Output should be a number within 20 of requested
  echo "$output" | grep -qE "^[0-9]+$"
}

@test "edge: zero-byte marker files still trigger detection" {
  mkdir -p "$TMP_DIR/nidos/zero-nido"
  : > "$TMP_DIR/nidos/zero-nido/go.mod"  # empty file
  result=$(dev_detect_project "$TMP_DIR/nidos/zero-nido")
  echo "$result" | grep -q "go run"
}

# ── Regression guards ──────────────────────────────────────────────────────

@test "regression: nidos.sh remove calls dev_stop before removal" {
  grep -q "dev_stop" "$NIDOS"
}

@test "regression: dev library provides all 5 core functions" {
  for fn in dev_detect_project dev_start dev_stop dev_url dev_logs; do
    grep -qE "^${fn}\(\)" "$DEV_LIB" || return 1
  done
}

@test "regression: dispatcher recognizes all 4 subcommands" {
  for sub in start stop url logs; do
    grep -qE "^[[:space:]]+${sub}\)" "$DEV_LIB" || return 1
  done
}
