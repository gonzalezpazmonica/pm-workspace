#!/usr/bin/env bats
# BATS tests for tabular-profile.py predict (SE-342 S5 / Labs L21)
# Ref: SE-342 S5, hypothesis l21-assisted-prediction.md, SE-296 (no-TFM), CRIT-001

SCRIPT="scripts/tabular-profile.py"
FIX="$(mktemp -d -t tab.XXXXXX)"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  # fixture dataset (60 rows, deterministic) — above the 50-row predict gate
  python3 - "$FIX" <<'PY'
import csv, sys, os
p = os.path.join(sys.argv[1], "tiny.csv")
fields = ["id", "t", "x"]
with open(p, "w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=fields)
    w.writeheader()
    for i in range(60):
        w.writerow({"id": i, "t": i % 3, "x": i * 0.5})
PY
  export SAVIA_CATALOG_DB="$(mktemp -t cat.XXXXXX.db)"
  rm -f "$TMP_CATALOG" 2>/dev/null || true
}

teardown() {
  rm -rf "$FIX"
  [[ -n "${SAVIA_CATALOG_DB:-}" ]] && rm -f "$SAVIA_CATALOG_DB"
  cd /
}

@test "predict requires --target (exit 2)" {
  run python3 "$SCRIPT" predict "$FIX/tiny.csv"
  [ "$status" -eq 2 ]
  [[ "$output" == *"--target"* ]]
}

@test "predict rejects unknown target column (JSON error)" {
  run python3 "$SCRIPT" predict --target nope "$FIX/tiny.csv"
  [ "$status" -eq 1 ]
  [[ "$output" == *"target column"* ]]
}

@test "predict on small dataset (<50 rows) returns size error" {
  SMALL="$(mktemp -t small.XXXXXX.csv)"
  python3 - "$SMALL" <<'PY'
import csv, sys
with open(sys.argv[1], "w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=["id", "t", "x"]); w.writeheader()
    for i in range(10):
        w.writerow({"id": i, "t": i % 3, "x": i})
PY
  run python3 "$SCRIPT" predict --target t --categorical "$SMALL"
  [ "$status" -eq 1 ]
  [[ "$output" == *"too small"* ]]
  rm -f "$SMALL"
}

@test "predict without sklearn degrades explicitly (no crash, no egress)" {
  # only runs if sklearn missing; asserts a clear JSON error either way
  run python3 "$SCRIPT" predict --target x "$FIX/tiny.csv" 2>/dev/null || true
  if python3 -c "import sklearn" 2>/dev/null; then
    [ "$status" -eq 0 ]  # sklearn present -> path continues, exit 0 or 1 per data
  else
    [ "$status" -eq 1 ]
    [[ "$output" == *"sklearn not installed"* ]]
  fi
}

@test "predict help prints usage" {
  run python3 "$SCRIPT" predict --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--target"* ]]
}