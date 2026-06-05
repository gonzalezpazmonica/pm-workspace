#!/usr/bin/env bats
# SCRIPT='scripts/code-twin-lint.sh'
# test-spec-190-code-twin-lint.bats — BATS suite for SPEC-190 Slice 1
# Spec: SPEC-190 AC-1, AC-2, AC-9
# Score target: ≥85 (SPEC-055 quality gate)
# Exercises: frontmatter fm_field fm_has_key token_approx

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
LINT="$REPO_ROOT/scripts/code-twin-lint.sh"
FX="$REPO_ROOT/tests/fixtures/code-twin"

setup() {
  TMP_DIR="$(mktemp -d)"
  [[ -f "$LINT" ]] || { echo "linter not found: $LINT" >&2; return 1; }
}

teardown() {
  rm -rf "$TMP_DIR"
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

make_ctf() {
  # make_ctf <filename> — write a valid CTF to TMP_DIR
  local out="$TMP_DIR/${1:-ctf.md}"
  local now; now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  cat > "$out" << CTF
---
module_id: TestService
layer: application
version: "1.0.0"
last_sync: "${now}"
token_budget: 400
stale_after_days: 14
depends_on:
  - SomeRepo
provides:
  - doSomething
status: STABLE
---
# TestService

A test service with logic.
CTF
  echo "$out"
}

make_cti() {
  # make_cti — write a valid CTI (index.md) to TMP_DIR
  local out="$TMP_DIR/index.md"
  cat > "$out" << CTI
---
total_modules: 2
total_token_cost: 500
last_full_sync: "2026-06-01T00:00:00Z"
---
# Code Twin Index

| module_id | layer | path | provides | tokens |
|-----------|-------|------|----------|--------|
| TestService | application | application/test-service.md | doSomething | 250 |
| TestEntity | domain | domain/test-entity.md | - | 150 |
CTI
  echo "$out"
}

make_seeds_dir() {
  # make_seeds_dir — create a valid seeds dir with 5 valid JSON lines each
  local dir="$TMP_DIR/seeds"
  mkdir -p "$dir"
  printf '%s\n%s\n%s\n%s\n%s\n' \
    '{"id":"u1","email":"a@t.com","name":"Alice"}' \
    '{"id":"u2","email":"b@t.com","name":"Bob"}' \
    '{"id":"u3","email":"c@t.com","name":"Charlie"}' \
    '{"id":"u4","email":"d@t.com","name":"Diana"}' \
    '{"id":"u5","email":"e@t.com","name":"Eve"}' \
    > "$dir/users.jsonl"
  echo "$dir"
}

# ---------------------------------------------------------------------------
# AC-1: CTI (--index) validation
# ---------------------------------------------------------------------------

@test "AC-1: valid CTI → exit 0" {
  cti=$(make_cti)
  run bash "$LINT" --index "$cti"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK (index)"* ]]
}

@test "AC-1: valid fixture CTI → exit 0" {
  run bash "$LINT" --index "$FX/index.md"
  [ "$status" -eq 0 ]
}

@test "AC-1: CTI missing total_modules → exit 2" {
  cti=$(make_cti)
  sed -i '/^total_modules:/d' "$cti"
  run bash "$LINT" --index "$cti"
  [ "$status" -eq 2 ]
  [[ "$output" == *"total_modules"* ]]
}

@test "AC-1: CTI missing total_token_cost → exit 2" {
  cti=$(make_cti)
  sed -i '/^total_token_cost:/d' "$cti"
  run bash "$LINT" --index "$cti"
  [ "$status" -eq 2 ]
  [[ "$output" == *"total_token_cost"* ]]
}

@test "AC-1: CTI no table at all → exit 2 (missing columns)" {
  local out="$TMP_DIR/no-table.md"
  cat > "$out" << EOF
---
total_modules: 1
total_token_cost: 100
---
# No table here
EOF
  run bash "$LINT" --index "$out"
  [ "$status" -eq 2 ]
  [[ "$output" == *"table missing column"* ]]
}

@test "AC-1: CTI table missing 'tokens' column → exit 2" {
  local out="$TMP_DIR/missing-col.md"
  cat > "$out" << EOF
---
total_modules: 1
total_token_cost: 100
---
# CTI
| module_id | layer | path | provides |
|-----------|-------|------|----------|
| Foo | domain | domain/foo.md | - |
EOF
  run bash "$LINT" --index "$out"
  [ "$status" -eq 2 ]
  [[ "$output" == *"tokens"* ]]
}

@test "AC-1: CTI token count > 300 → exit 2" {
  local out="$TMP_DIR/huge-cti.md"
  # Create a CTI with > 300 tokens (~1200+ chars)
  {
    echo "---"
    echo "total_modules: 50"
    echo "total_token_cost: 20000"
    echo "---"
    echo "# Huge CTI"
    echo ""
    echo "| module_id | layer | path | provides | tokens |"
    echo "|-----------|-------|------|----------|--------|"
    # Add 40 rows to push past token limit
    for i in $(seq 1 40); do
      echo "| VeryLongServiceNameModule${i} | application | application/very-long-service-name-module-${i}.md | methodA,methodB,methodC,methodD | $((i*10)) |"
    done
  } > "$out"
  run bash "$LINT" --index "$out"
  [ "$status" -eq 2 ]
  [[ "$output" == *"token count"* ]]
}

@test "AC-1: --index file not found → exit 2" {
  run bash "$LINT" --index "$TMP_DIR/nonexistent.md"
  [ "$status" -eq 2 ]
  [[ "$output" == *"not found"* ]]
}

# ---------------------------------------------------------------------------
# AC-2: CTF validation
# ---------------------------------------------------------------------------

@test "AC-2: valid CTF → exit 0" {
  ctf=$(make_ctf)
  run bash "$LINT" "$ctf"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK:"* ]]
}

@test "AC-2: valid fixture CTF → exit 0" {
  run bash "$LINT" "$FX/application/auth-service.md"
  [ "$status" -eq 0 ]
}

@test "AC-2: CTF missing module_id → exit 2" {
  ctf=$(make_ctf)
  sed -i '/^module_id:/d' "$ctf"
  run bash "$LINT" "$ctf"
  [ "$status" -eq 2 ]
  [[ "$output" == *"module_id"* ]]
}

@test "AC-2: CTF missing layer → exit 2" {
  ctf=$(make_ctf)
  sed -i '/^layer:/d' "$ctf"
  run bash "$LINT" "$ctf"
  [ "$status" -eq 2 ]
  [[ "$output" == *"layer"* ]]
}

@test "AC-2: CTF missing version → exit 2" {
  ctf=$(make_ctf)
  sed -i '/^version:/d' "$ctf"
  run bash "$LINT" "$ctf"
  [ "$status" -eq 2 ]
  [[ "$output" == *"version"* ]]
}

@test "AC-2: CTF missing last_sync → exit 2" {
  ctf=$(make_ctf)
  sed -i '/^last_sync:/d' "$ctf"
  run bash "$LINT" "$ctf"
  [ "$status" -eq 2 ]
  [[ "$output" == *"last_sync"* ]]
}

@test "AC-2: CTF missing token_budget → exit 2" {
  ctf=$(make_ctf)
  sed -i '/^token_budget:/d' "$ctf"
  run bash "$LINT" "$ctf"
  [ "$status" -eq 2 ]
  [[ "$output" == *"token_budget"* ]]
}

@test "AC-2: CTF missing depends_on → exit 2" {
  ctf=$(make_ctf)
  sed -i '/^depends_on:/d; /^  - SomeRepo/d' "$ctf"
  run bash "$LINT" "$ctf"
  [ "$status" -eq 2 ]
  [[ "$output" == *"depends_on"* ]]
}

@test "AC-2: CTF missing provides → exit 2" {
  ctf=$(make_ctf)
  sed -i '/^provides:/d; /^  - doSomething/d' "$ctf"
  run bash "$LINT" "$ctf"
  [ "$status" -eq 2 ]
  [[ "$output" == *"provides"* ]]
}

@test "AC-2: CTF missing stale_after_days → exit 2" {
  ctf=$(make_ctf)
  sed -i '/^stale_after_days:/d' "$ctf"
  run bash "$LINT" "$ctf"
  [ "$status" -eq 2 ]
  [[ "$output" == *"stale_after_days"* ]]
}

@test "AC-2: CTF with invalid layer → exit 2" {
  local out="$TMP_DIR/bad-layer.md"
  local now; now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  cat > "$out" << CTF
---
module_id: BadService
layer: presentation
version: "1.0.0"
last_sync: "${now}"
token_budget: 200
stale_after_days: 14
depends_on: []
provides:
  - serve
---
CTF
  run bash "$LINT" "$out"
  [ "$status" -eq 2 ]
  [[ "$output" == *"presentation"* ]]
}

@test "AC-2: CTF with token_budget exactly 800 → exit 0" {
  ctf=$(make_ctf)
  sed -i 's/^token_budget: .*/token_budget: 800/' "$ctf"
  run bash "$LINT" "$ctf"
  [ "$status" -eq 0 ]
}

@test "AC-2: CTF with token_budget 801 → exit 2" {
  ctf=$(make_ctf)
  sed -i 's/^token_budget: .*/token_budget: 801/' "$ctf"
  run bash "$LINT" "$ctf"
  [ "$status" -eq 2 ]
  [[ "$output" == *"801"* ]]
}

@test "AC-2: CTF with status=DRAFT → exit 2" {
  ctf=$(make_ctf)
  sed -i 's/^status: STABLE/status: DRAFT/' "$ctf"
  run bash "$LINT" "$ctf"
  [ "$status" -eq 2 ]
  [[ "$output" == *"DRAFT"* ]]
}

@test "AC-2: CTF without status field → exit 0 (defaults to STABLE)" {
  ctf=$(make_ctf)
  sed -i '/^status:/d' "$ctf"
  run bash "$LINT" "$ctf"
  [ "$status" -eq 0 ]
}

@test "AC-2: all 6 valid layers accepted (domain)" {
  ctf=$(make_ctf)
  sed -i 's/^layer: application/layer: domain/' "$ctf"
  run bash "$LINT" "$ctf"
  [ "$status" -eq 0 ]
}

@test "AC-2: all 6 valid layers accepted (infrastructure)" {
  ctf=$(make_ctf)
  sed -i 's/^layer: application/layer: infrastructure/' "$ctf"
  run bash "$LINT" "$ctf"
  [ "$status" -eq 0 ]
}

@test "AC-2: all 6 valid layers accepted (api)" {
  ctf=$(make_ctf)
  sed -i 's/^layer: application/layer: api/' "$ctf"
  run bash "$LINT" "$ctf"
  [ "$status" -eq 0 ]
}

@test "AC-2: all 6 valid layers accepted (frontend)" {
  ctf=$(make_ctf)
  sed -i 's/^layer: application/layer: frontend/' "$ctf"
  run bash "$LINT" "$ctf"
  [ "$status" -eq 0 ]
}

@test "AC-2: all 6 valid layers accepted (cross-cutting)" {
  ctf=$(make_ctf)
  sed -i 's/^layer: application/layer: cross-cutting/' "$ctf"
  run bash "$LINT" "$ctf"
  [ "$status" -eq 0 ]
}

@test "AC-2: CTF file not found → exit 2" {
  run bash "$LINT" "$TMP_DIR/nonexistent.md"
  [ "$status" -eq 2 ]
  [[ "$output" == *"not found"* ]]
}

# ---------------------------------------------------------------------------
# AC-9: Seeds JSONL validation
# ---------------------------------------------------------------------------

@test "AC-9: valid seeds dir → exit 0" {
  seeds=$(make_seeds_dir)
  run bash "$LINT" --seeds "$seeds"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK (seeds)"* ]]
}

@test "AC-9: valid fixture seeds dir → exit 0" {
  run bash "$LINT" --seeds "$FX/db/seeds"
  [ "$status" -eq 0 ]
}

@test "AC-9: seeds file with < 5 lines → exit 2 with table name and count" {
  seeds=$(make_seeds_dir)
  # Replace users.jsonl with only 3 lines
  printf '%s\n%s\n%s\n' \
    '{"id":"u1","email":"a@t.com"}' \
    '{"id":"u2","email":"b@t.com"}' \
    '{"id":"u3","email":"c@t.com"}' \
    > "$seeds/users.jsonl"
  run bash "$LINT" --seeds "$seeds"
  [ "$status" -eq 2 ]
  [[ "$output" == *"users.jsonl"* ]]
  [[ "$output" == *"3"* ]]
}

@test "AC-9: seeds file with invalid JSON line → exit 2 with line number" {
  seeds=$(make_seeds_dir)
  # Replace line 3 with invalid JSON
  python3 -c "
lines = open('$seeds/users.jsonl').readlines()
lines[2] = 'not valid json\n'
open('$seeds/users.jsonl','w').writelines(lines)
"
  run bash "$LINT" --seeds "$seeds"
  [ "$status" -eq 2 ]
  # Line number 3 appears in error
  [[ "$output" == *"3"* ]]
}

@test "AC-9: seeds with non-nullable field missing (schema.md present) → exit 2" {
  # Create seeds dir adjacent to schema.md so linter can find it
  local db_dir="$TMP_DIR/db"
  mkdir -p "$db_dir/seeds"
  cat > "$db_dir/schema.md" << 'SCHEMA'
# Schema
## Table: products
| column | type | nullable |
|--------|------|----------|
| id | uuid | false |
| name | varchar | false |
| price | decimal | false |
| description | text | true |
SCHEMA
  # seeds missing 'price' (non-nullable)
  printf '%s\n%s\n%s\n%s\n%s\n' \
    '{"id":"p1","name":"Alpha"}' \
    '{"id":"p2","name":"Beta"}' \
    '{"id":"p3","name":"Gamma"}' \
    '{"id":"p4","name":"Delta"}' \
    '{"id":"p5","name":"Epsilon"}' \
    > "$db_dir/seeds/products.jsonl"
  run bash "$LINT" --seeds "$db_dir/seeds"
  [ "$status" -eq 2 ]
  # Error message must include field name and table
  [[ "$output" == *"price"* ]]
}

@test "AC-9: seeds with all non-nullable fields present → exit 0" {
  local db_dir="$TMP_DIR/db2"
  mkdir -p "$db_dir/seeds"
  cat > "$db_dir/schema.md" << 'SCHEMA'
# Schema
## Table: items
| column | type | nullable |
|--------|------|----------|
| id | uuid | false |
| name | varchar | false |
| qty | int | false |
SCHEMA
  printf '%s\n%s\n%s\n%s\n%s\n' \
    '{"id":"i1","name":"A","qty":1}' \
    '{"id":"i2","name":"B","qty":2}' \
    '{"id":"i3","name":"C","qty":3}' \
    '{"id":"i4","name":"D","qty":4}' \
    '{"id":"i5","name":"E","qty":5}' \
    > "$db_dir/seeds/items.jsonl"
  run bash "$LINT" --seeds "$db_dir/seeds"
  [ "$status" -eq 0 ]
}

@test "AC-9: seeds dir with no .jsonl files → exit 2" {
  local empty_dir="$TMP_DIR/empty-seeds"
  mkdir -p "$empty_dir"
  run bash "$LINT" --seeds "$empty_dir"
  [ "$status" -eq 2 ]
  [[ "$output" == *"no .jsonl"* ]]
}

@test "AC-9: --seeds dir not found → exit 2" {
  run bash "$LINT" --seeds "$TMP_DIR/no-such-dir"
  [ "$status" -eq 2 ]
  [[ "$output" == *"not found"* ]]
}

# ---------------------------------------------------------------------------
# Edge cases & guards
# ---------------------------------------------------------------------------

@test "no arguments → exit 2 with usage message" {
  run bash "$LINT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage"* ]]
}

@test "AC-9: fixture seeds with schema.md non-nullable cross-check → exit 0" {
  # Fixture db/seeds has users.jsonl with all non-nullable fields from db/schema.md
  run bash "$LINT" --seeds "$FX/db/seeds"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Safety & structure checks
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Slice 2 fixtures: domain CTFs
# ---------------------------------------------------------------------------

@test "Slice2: fixture domain/entities.md → exit 0" {
  run bash "$LINT" "$FX/domain/entities.md"
  [ "$status" -eq 0 ]
}

@test "Slice2: fixture domain/value-objects.md → exit 0" {
  run bash "$LINT" "$FX/domain/value-objects.md"
  [ "$status" -eq 0 ]
}

@test "Slice2: fixture domain/business-rules.md → exit 0" {
  run bash "$LINT" "$FX/domain/business-rules.md"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Slice 2 fixtures: application CTFs
# ---------------------------------------------------------------------------

@test "Slice2: fixture application/use-cases.md → exit 0" {
  run bash "$LINT" "$FX/application/use-cases.md"
  [ "$status" -eq 0 ]
}

@test "Slice2: fixture application/commands.md → exit 0" {
  run bash "$LINT" "$FX/application/commands.md"
  [ "$status" -eq 0 ]
}

@test "Slice2: fixture application/queries.md → exit 0" {
  run bash "$LINT" "$FX/application/queries.md"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Safety & structure checks
# ---------------------------------------------------------------------------

@test "script has set -uo pipefail" {
  grep -q "set -uo pipefail" "$LINT"
}

@test "lint is executable" {
  [ -x "$LINT" ]
}
