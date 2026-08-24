#!/usr/bin/env bats
# BATS tests for scripts/savia-catalog.py (SE-342 S1 / Labs L17)
# Ref: SE-342 S1, hypothesis l17-data-catalog.md, CRIT-001

SCRIPT="scripts/savia-catalog.py"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  TMP_DB="$(mktemp -t catalog.XXXXXX.db)"
  rm -f "$TMP_DB" "$TMP_DB-wal" "$TMP_DB-shm"
  export SAVIA_CATALOG_DB="$TMP_DB"
  export KG_DB="$TMP_DB"
}

teardown() {
  [[ -n "$TMP_DB" ]] && rm -f "$TMP_DB" "$TMP_DB-wal" "$TMP_DB-shm"
  cd /
}

@test "script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "passes py_compile" {
  run python3 -m py_compile "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "--version prints semver" {
  run python3 "$SCRIPT" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

# ── registro ────────────────────────────────────────────────────────────

@test "register dataset requires level; list shows it" {
  run python3 "$SCRIPT" register --type dataset --name customers --level N2
  [ "$status" -eq 0 ]
  run python3 "$SCRIPT" list --type dataset
  [ "$status" -eq 0 ]
  [[ "$output" == *"customers"* ]]
}

@test "register invalid level rejected (exit 2)" {
  run python3 "$SCRIPT" register --type dataset --name x --level N9
  [ "$status" -eq 2 ]
}

@test "register invalid type rejected (exit 2)" {
  run python3 "$SCRIPT" register --type bogus --name x --level N1
  [ "$status" -eq 2 ]
}

@test "asset without declared level is refused by required flag (argparse)" {
  run python3 "$SCRIPT" register --type dataset --name orphan
  [ "$status" -ne 0 ]
}

# ── lineage ─────────────────────────────────────────────────────────────

@test "lineage: dataset -> feature -> model 3 nodes with level guard" {
  python3 "$SCRIPT" register --type dataset --name raw_crops --level N2
  python3 "$SCRIPT" register --type feature --name yield_moisture --level N2 \
    --from-name raw_crops --from-type dataset --relation feeds
  python3 "$SCRIPT" register --type model --name yield_model --level N2 \
    --from-name yield_moisture --from-type feature --relation trained_on
  run python3 "$SCRIPT" lineage --name yield_model
  [ "$status" -eq 0 ]
  [[ "$output" == *"feeds"* ]]
  [[ "$output" == *"raw_crops"* ]]
}

@test "strict level guard rejects N1 -> N3 chain (exit 3)" {
  python3 "$SCRIPT" register --type dataset --name public_map --level N1
  run python3 "$SCRIPT" register --type model --name risky --level N3 \
    --from-name public_map --from-type dataset --relation trained_on
  [ "$status" -eq 3 ]
}

@test "lineage source not found -> exit 1" {
  python3 "$SCRIPT" register --type feature --name f1 --level N2
  run python3 "$SCRIPT" register --type model --name m1 --level N2 \
    --from-name missing --from-type dataset --relation trained_on
  [ "$status" -eq 1 ]
}

@test "show returns 1 for unknown asset" {
  run python3 "$SCRIPT" show --name nope
  [ "$status" -eq 1 ]
}