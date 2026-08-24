#!/usr/bin/env bats
# BATS tests for tabular-profile.py monitor (SE-342 S3 / Labs L19)
# Ref: SE-342 S3, hypothesis l19-data-quality-feature-store.md, CRIT-001

SCRIPT="scripts/tabular-profile.py"
FIX="$(mktemp -d -t dq.XXXXXX)"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  python3 - "$FIX" <<'PY'
import csv, sys, os
p = os.path.join(sys.argv[1], "ok.csv")
with open(p, "w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=["id", "t", "x"]); w.writeheader()
    for i in range(60):
        w.writerow({"id": i, "t": i % 3, "x": round(i * 0.5, 2)})
PY
  export SAVIA_DQ_DIR="$(mktemp -d -t dqbase.XXXXXX)"
  export SAVIA_CATALOG_DB="$(mktemp -t cat.XXXXXX.db)"
  rm -f "$SAVIA_CATALOG_DB"
}

teardown() {
  rm -rf "$FIX" "$SAVIA_DQ_DIR"
  [[ -n "${SAVIA_CATALOG_DB:-}" ]] && rm -f "$SAVIA_CATALOG_DB"
  cd /
}

@test "monitor init saves baseline (exit 0)" {
  run python3 "$SCRIPT" monitor init "$FIX/ok.csv"
  [ "$status" -eq 0 ]
  [[ "$output" == *"baseline_saved"* ]]
}

@test "monitor check on unchanged data verdict PASS" {
  python3 "$SCRIPT" monitor init "$FIX/ok.csv" >/dev/null
  run python3 "$SCRIPT" monitor check "$FIX/ok.csv"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"verdict": "PASS"'* ]]
}

@test "monitor check detects completeness drop (missing values in column)" {
  python3 "$SCRIPT" monitor init "$FIX/ok.csv" >/dev/null
  # mutate the SAME file (same logical key) with 50% missing 'x'
  python3 - "$FIX/ok.csv" <<'PY'
import csv, sys
rows = []
with open(sys.argv[1], newline="") as fh:
    for r in csv.DictReader(fh):
        if int(r["id"]) % 2 == 0:
            r["x"] = ""   # 50% missing in x
        rows.append(r)
with open(sys.argv[1], "w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=rows[0].keys()); w.writeheader(); w.writerows(rows)
PY
  run python3 "$SCRIPT" monitor check "$FIX/ok.csv"
  [ "$status" -eq 1 ]
  [[ "$output" == *'"verdict": "FAIL"'* ]]
  [[ "$output" == *"completeness"* ]]
}

@test "monitor check rejects when no baseline" {
  run python3 "$SCRIPT" monitor check "$FIX/ok.csv"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no baseline"* ]]
}

@test "monitor detects schema drift (new column)" {
  python3 "$SCRIPT" monitor init "$FIX/ok.csv" >/dev/null
  python3 - "$FIX/ok.csv" <<'PY'
import csv, sys
rows = []
with open(sys.argv[1], newline="") as fh:
    for r in csv.DictReader(fh):
        r["y"] = int(r["id"])   # add new column
        rows.append(r)
with open(sys.argv[1], "w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=rows[0].keys()); w.writeheader(); w.writerows(rows)
PY
  run python3 "$SCRIPT" monitor check "$FIX/ok.csv"
  [ "$status" -eq 1 ]
  [[ "$output" == *"new column"* ]]
}

@test "feature store: revertible feature registered in catalog (L17 integration)" {
  python3 scripts/savia-catalog.py register --type dataset --name raw --level N2 >/dev/null
  run python3 scripts/savia-catalog.py register --type feature --name f_yield --level N2 \
    --from-name raw --from-type dataset --relation feeds
  [ "$status" -eq 0 ]
  run python3 scripts/savia-catalog.py lineage --name f_yield
  [ "$status" -eq 0 ]
  [[ "$output" == *"raw"* ]]
}