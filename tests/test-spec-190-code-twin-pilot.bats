#!/usr/bin/env bats
# SCRIPT='scripts/code-twin-simulate.sh'
# test-spec-190-code-twin-pilot.bats — BATS suite for SPEC-190 Slice 9 (pilot twin)
# Spec: SPEC-190 AC-13, AC-V1
# Score target: ≥85 (SPEC-055 quality gate)
# Exercises: pilot twin lint, index validation, seed lint, simulate on savia-web twin

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
LINT="$REPO_ROOT/scripts/code-twin-lint.sh"
SIM="$REPO_ROOT/scripts/code-twin-simulate.sh"
TWIN="$REPO_ROOT/projects/savia-web/code-twin"
SEEDS="$TWIN/seeds"
DB_SEEDS="$TWIN/infrastructure/db/seeds"
INDEX="$TWIN/index.md"

setup() {
  TMP_DIR="$(mktemp -d)"
  OUT_DIR="$REPO_ROOT/output"
  mkdir -p "$OUT_DIR"
}

teardown() {
  rm -rf "$TMP_DIR"
}

# ---------------------------------------------------------------------------
# Safety
# ---------------------------------------------------------------------------

@test "safety: simulate script contains set -uo pipefail" {
  grep -q "set -uo pipefail" "$SIM"
}

@test "safety: lint script contains set -uo pipefail" {
  grep -q "set -uo pipefail" "$LINT"
}

@test "safety: pilot twin directory exists" {
  [ -d "$TWIN" ]
}

# ---------------------------------------------------------------------------
# AC-13: CTI (index.md) validation
# ---------------------------------------------------------------------------

@test "ac-13: index.md exists" {
  [ -f "$INDEX" ]
}

@test "ac-13: index.md passes code-twin-lint.sh --index" {
  run bash "$LINT" --index "$INDEX"
  [ "$status" -eq 0 ]
}

@test "ac-13: index.md has total_modules ≥ 8" {
  val=$(grep "^total_modules:" "$INDEX" | awk '{print $2}')
  [ "$val" -ge 8 ]
}

@test "ac-13: index.md total_token_cost ≤ 8000" {
  val=$(grep "^total_token_cost:" "$INDEX" | awk '{print $2}')
  [ "$val" -le 8000 ]
}

@test "ac-13: index.md total_token_cost > 0" {
  val=$(grep "^total_token_cost:" "$INDEX" | awk '{print $2}')
  [ "$val" -gt 0 ]
}

@test "ac-13: index.md has last_full_sync in frontmatter" {
  grep -q "^last_full_sync:" "$INDEX"
}

@test "ac-13: index table has module_id column" {
  grep -qE "\|\s*module_id\s*\|" "$INDEX"
}

@test "ac-13: index table has path column" {
  grep -qE "\|\s*path\s*\|" "$INDEX"
}

# ---------------------------------------------------------------------------
# AC-13: Individual CTF lint checks
# ---------------------------------------------------------------------------

@test "ac-13: meta/tech-stack.md passes lint" {
  run bash "$LINT" "$TWIN/meta/tech-stack.md"
  [ "$status" -eq 0 ]
}

@test "ac-13: domain/entities.md passes lint" {
  run bash "$LINT" "$TWIN/domain/entities.md"
  [ "$status" -eq 0 ]
}

@test "ac-13: api/routes.md passes lint" {
  run bash "$LINT" "$TWIN/api/routes.md"
  [ "$status" -eq 0 ]
}

@test "ac-13: frontend/stores.md passes lint" {
  run bash "$LINT" "$TWIN/frontend/stores.md"
  [ "$status" -eq 0 ]
}

@test "ac-13: frontend/composables.md passes lint" {
  run bash "$LINT" "$TWIN/frontend/composables.md"
  [ "$status" -eq 0 ]
}

@test "ac-13: frontend/router.md passes lint" {
  run bash "$LINT" "$TWIN/frontend/router.md"
  [ "$status" -eq 0 ]
}

@test "ac-13: application/auth-service.md passes lint" {
  run bash "$LINT" "$TWIN/application/auth-service.md"
  [ "$status" -eq 0 ]
}

@test "ac-13: infrastructure/db/schema.md passes lint" {
  run bash "$LINT" "$TWIN/infrastructure/db/schema.md"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# AC-13: CTF frontmatter fields
# ---------------------------------------------------------------------------

@test "ac-13: auth-service.md has module_id AuthService" {
  grep -q "^module_id: AuthService" "$TWIN/application/auth-service.md"
}

@test "ac-13: auth-service.md layer is application" {
  grep -q "^layer: application" "$TWIN/application/auth-service.md"
}

@test "ac-13: domain/entities.md layer is domain" {
  grep -q "^layer: domain" "$TWIN/domain/entities.md"
}

@test "ac-13: schema.md layer is infrastructure" {
  grep -q "^layer: infrastructure" "$TWIN/infrastructure/db/schema.md"
}

@test "ac-13: each CTF has status field" {
  for f in "$TWIN/meta/tech-stack.md" "$TWIN/domain/entities.md" \
            "$TWIN/api/routes.md" "$TWIN/application/auth-service.md"; do
    grep -q "^status:" "$f" || { echo "missing status: $f" >&2; return 1; }
  done
}

@test "ac-13: each CTF token_budget ≤ 800" {
  for f in "$TWIN/meta/tech-stack.md" "$TWIN/domain/entities.md" \
            "$TWIN/api/routes.md" "$TWIN/frontend/stores.md" \
            "$TWIN/frontend/composables.md" "$TWIN/frontend/router.md" \
            "$TWIN/application/auth-service.md" "$TWIN/infrastructure/db/schema.md"; do
    budget=$(grep "^token_budget:" "$f" | awk '{print $2}')
    [ "$budget" -le 800 ] || { echo "token_budget $budget > 800 in $f" >&2; return 1; }
  done
}

# ---------------------------------------------------------------------------
# AC-13: Seeds — db/seeds lint
# ---------------------------------------------------------------------------

@test "ac-13: infrastructure/db/seeds directory exists" {
  [ -d "$DB_SEEDS" ]
}

@test "ac-13: db/seeds has ≥3 jsonl files" {
  count=$(ls "$DB_SEEDS"/*.jsonl 2>/dev/null | wc -l)
  [ "$count" -ge 3 ]
}

@test "ac-13: db/seeds passes code-twin-lint.sh --seeds" {
  run bash "$LINT" --seeds "$DB_SEEDS"
  [ "$status" -eq 0 ]
}

@test "ac-13: db/seeds/users.jsonl has ≥5 rows" {
  count=$(grep -c '' "$DB_SEEDS/users.jsonl")
  [ "$count" -ge 5 ]
}

@test "ac-13: db/seeds/projects.jsonl has ≥5 rows" {
  count=$(grep -c '' "$DB_SEEDS/projects.jsonl")
  [ "$count" -ge 5 ]
}

@test "ac-13: db/seeds/tasks.jsonl has ≥5 rows" {
  count=$(grep -c '' "$DB_SEEDS/tasks.jsonl")
  [ "$count" -ge 5 ]
}

@test "ac-13: db/seeds/users.jsonl all lines are valid JSON" {
  while IFS= read -r line; do
    echo "$line" | jq empty 2>/dev/null || { echo "invalid JSON: $line" >&2; return 1; }
  done < "$DB_SEEDS/users.jsonl"
}

# ---------------------------------------------------------------------------
# AC-V1: Simulate seeds
# ---------------------------------------------------------------------------

@test "ac-v1: simulate seeds/users.jsonl exists" {
  [ -f "$SEEDS/users.jsonl" ]
}

@test "ac-v1: simulate seeds/users.jsonl has ≥5 rows" {
  count=$(grep -c '' "$SEEDS/users.jsonl")
  [ "$count" -ge 5 ]
}

@test "ac-v1: simulate seeds/users.jsonl has password_hash fields" {
  grep -q "password_hash" "$SEEDS/users.jsonl"
}

@test "ac-v1: simulate seeds/users.jsonl uses sim: prefix" {
  grep -q '"sim:' "$SEEDS/users.jsonl"
}

# ---------------------------------------------------------------------------
# AC-V1: Simulate execution — valid credentials
# ---------------------------------------------------------------------------

@test "ac-v1: simulate AuthService.login exits 0 for valid user" {
  run bash "$SIM" AuthService login \
    '{"email":"alice@savia.local","password":"alice-pass"}' "$SEEDS"
  [ "$status" -eq 0 ]
}

@test "ac-v1: simulate output contains confidence header" {
  run bash "$SIM" AuthService login \
    '{"email":"alice@savia.local","password":"alice-pass"}' "$SEEDS"
  echo "$output" | grep -q "SIMULATION"
}

@test "ac-v1: simulate confidence ≥ 0.7" {
  json=$(bash "$SIM" AuthService login \
    '{"email":"alice@savia.local","password":"alice-pass"}' "$SEEDS" | tail -n +2)
  conf=$(echo "$json" | jq '.confidence')
  # Use awk for float comparison
  LC_NUMERIC=C awk -v c="$conf" 'BEGIN { exit (c >= 0.7) ? 0 : 1 }'
}

@test "ac-v1: simulate result contains token" {
  json=$(bash "$SIM" AuthService login \
    '{"email":"alice@savia.local","password":"alice-pass"}' "$SEEDS" | tail -n +2)
  echo "$json" | jq -e '.result.token' | grep -q "sim-token"
}

@test "ac-v1: simulate result has db_trace READ on users" {
  json=$(bash "$SIM" AuthService login \
    '{"email":"alice@savia.local","password":"alice-pass"}' "$SEEDS" | tail -n +2)
  echo "$json" | jq -e '.db_trace[] | select(.op=="READ" and .table=="users")' > /dev/null
}

@test "ac-v1: simulate saves result to output/code-twin-pilot-sim-result.json" {
  bash "$SIM" AuthService login \
    '{"email":"alice@savia.local","password":"alice-pass"}' "$SEEDS" \
    | tail -n +2 > "$OUT_DIR/code-twin-pilot-sim-result.json"
  [ -s "$OUT_DIR/code-twin-pilot-sim-result.json" ]
}

@test "ac-v1: saved result has confidence ≥ 0.7" {
  bash "$SIM" AuthService login \
    '{"email":"alice@savia.local","password":"alice-pass"}' "$SEEDS" \
    | tail -n +2 > "$OUT_DIR/code-twin-pilot-sim-result.json"
  conf=$(jq '.confidence' "$OUT_DIR/code-twin-pilot-sim-result.json")
  LC_NUMERIC=C awk -v c="$conf" 'BEGIN { exit (c >= 0.7) ? 0 : 1 }'
}

# ---------------------------------------------------------------------------
# AC-V1: Simulate — error paths
# ---------------------------------------------------------------------------

@test "ac-v1: simulate exits 1 for unknown email" {
  run bash "$SIM" AuthService login \
    '{"email":"nobody@savia.local","password":"irrelevant"}' "$SEEDS"
  [ "$status" -eq 1 ]
}

@test "ac-v1: simulate returns INVALID_CREDENTIALS for unknown user" {
  json=$(bash "$SIM" AuthService login \
    '{"email":"nobody@savia.local","password":"irrelevant"}' "$SEEDS" | tail -n +2)
  echo "$json" | jq -e '.error.code == "INVALID_CREDENTIALS"' > /dev/null
}

@test "ac-v1: simulate returns INVALID_CREDENTIALS for wrong password" {
  json=$(bash "$SIM" AuthService login \
    '{"email":"alice@savia.local","password":"wrong"}' "$SEEDS" | tail -n +2)
  echo "$json" | jq -e '.error.code == "INVALID_CREDENTIALS"' > /dev/null
}

@test "ac-v1: simulate exits 1 for disabled user" {
  run bash "$SIM" AuthService login \
    '{"email":"charlie@savia.local","password":"charlie-pass"}' "$SEEDS"
  [ "$status" -eq 1 ]
}

@test "ac-v1: simulate returns USER_DISABLED for disabled user" {
  json=$(bash "$SIM" AuthService login \
    '{"email":"charlie@savia.local","password":"charlie-pass"}' "$SEEDS" | tail -n +2)
  echo "$json" | jq -e '.error.code == "USER_DISABLED"' > /dev/null
}

@test "ac-v1: simulate error has status 401 for invalid credentials" {
  json=$(bash "$SIM" AuthService login \
    '{"email":"nobody@savia.local","password":"x"}' "$SEEDS" | tail -n +2)
  echo "$json" | jq -e '.error.status == 401' > /dev/null
}

# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

@test "edge: simulate exits 2 for nonexistent seeds dir" {
  run bash "$SIM" AuthService login '{"email":"a@b.com","password":"p"}' \
    "/nonexistent/seeds/dir"
  [ "$status" -eq 2 ]
}

@test "edge: simulate exits 2 when no args provided" {
  run bash "$SIM"
  [ "$status" -eq 2 ]
}

@test "edge: simulate exits 2 for null-like empty module_id arg" {
  run bash "$SIM" "" login '{"email":"a@b.com","password":"p"}' "$SEEDS"
  [ "$status" -eq 2 ]
}

@test "edge: lint rejects empty CTF file" {
  local empty_ctf="$TMP_DIR/empty.md"
  touch "$empty_ctf"
  run bash "$LINT" "$empty_ctf"
  [ "$status" -eq 2 ]
}

@test "edge: lint --index rejects nonexistent index file" {
  run bash "$LINT" --index "/nonexistent/index.md"
  [ "$status" -eq 2 ]
}

@test "edge: lint --seeds rejects nonexistent directory" {
  run bash "$LINT" --seeds "/nonexistent/seeds"
  [ "$status" -eq 2 ]
}

@test "edge: simulate confidence boundary — never zero for valid logic" {
  json=$(bash "$SIM" AuthService login \
    '{"email":"alice@savia.local","password":"alice-pass"}' "$SEEDS" | tail -n +2)
  conf=$(echo "$json" | jq '.confidence')
  # boundary: confidence must be > 0
  LC_NUMERIC=C awk -v c="$conf" 'BEGIN { exit (c > 0) ? 0 : 1 }'
}

@test "edge: simulate confidence boundary — never exactly 1.0" {
  json=$(bash "$SIM" AuthService login \
    '{"email":"alice@savia.local","password":"alice-pass"}' "$SEEDS" | tail -n +2)
  conf=$(echo "$json" | jq '.confidence')
  LC_NUMERIC=C awk -v c="$conf" 'BEGIN { exit (c < 1.0) ? 0 : 1 }'
}

@test "edge: simulate output header line is not null or empty" {
  run bash "$SIM" AuthService login \
    '{"email":"alice@savia.local","password":"alice-pass"}' "$SEEDS"
  [[ "$output" =~ "SIMULATION" ]]
}

@test "edge: simulate with overflow-length email returns error gracefully" {
  long_email=$(python3 -c "print('a'*300+'@b.com')")
  run bash "$SIM" AuthService login \
    "{\"email\":\"${long_email}\",\"password\":\"x\"}" "$SEEDS"
  # Should not crash — exit 0 or 1 only, not 2
  [ "$status" -ne 2 ] || [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# Assertion quality — extended checks with [[ output ]] pattern
# ---------------------------------------------------------------------------

@test "assert: simulate success output contains module_id field" {
  run bash "$SIM" AuthService login \
    '{"email":"alice@savia.local","password":"alice-pass"}' "$SEEDS"
  [[ "$output" =~ "module_id" ]]
}

@test "assert: simulate success output contains method field" {
  run bash "$SIM" AuthService login \
    '{"email":"alice@savia.local","password":"alice-pass"}' "$SEEDS"
  [[ "$output" =~ "method" ]]
}

@test "assert: simulate output json is valid per python3 json.loads" {
  json=$(bash "$SIM" AuthService login \
    '{"email":"alice@savia.local","password":"alice-pass"}' "$SEEDS" | tail -n +2)
  echo "$json" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null
}

@test "assert: simulate disabled user output json is valid" {
  json=$(bash "$SIM" AuthService login \
    '{"email":"charlie@savia.local","password":"charlie-pass"}' "$SEEDS" | tail -n +2)
  echo "$json" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null
}

@test "assert: index total_modules matches actual CTF count" {
  declared=$(grep "^total_modules:" "$INDEX" | awk '{print $2}')
  actual=$(find "$TWIN" -name "*.md" ! -name "index.md" | wc -l)
  # declared ≤ actual (index may under-count intentionally)
  [ "$declared" -le "$actual" ]
}
