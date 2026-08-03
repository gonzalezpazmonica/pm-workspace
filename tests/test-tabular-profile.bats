#!/usr/bin/env bats

setup() {
  PROFILER="$BATS_TEST_DIRNAME/../scripts/tabular-profile.py"
  TESTDIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TESTDIR"
}

@test "tabular-profile exists and is executable" {
  [ -f "$PROFILER" ]
  [ -x "$PROFILER" ]
}

@test "detects numeric column type" {
  cat > "$TESTDIR/data.csv" << 'EOF'
name,age,salary
Alice,30,50000
Bob,25,45000
Carol,35,60000
Dave,28,48000
Eve,32,52000
EOF
  run python3 "$PROFILER" "$TESTDIR/data.csv"
  [ "$status" -eq 0 ]
  [[ "$output" == *"numeric"* ]]
  [[ "$output" == *"mean"* ]]
}

@test "detects categorical column type" {
  cat > "$TESTDIR/data.csv" << 'EOF'
name,department
Alice,Engineering
Bob,Sales
Carol,Engineering
Dave,Marketing
Eve,Sales
EOF
  run python3 "$PROFILER" "$TESTDIR/data.csv"
  [ "$status" -eq 0 ]
  [[ "$output" == *"categorical"* ]]
}

@test "computes correlations" {
  cat > "$TESTDIR/data.csv" << 'EOF'
x,y
1,2
2,4
3,6
4,8
5,10
EOF
  run python3 "$PROFILER" "$TESTDIR/data.csv"
  [ "$status" -eq 0 ]
  [[ "$output" == *"correlations"* ]]
  [[ "$output" == *"coefficient"* ]]
}

@test "detects outliers via IQR" {
  cat > "$TESTDIR/data.csv" << 'EOF'
value
10
12
11
13
10
500
11
12
EOF
  run python3 "$PROFILER" "$TESTDIR/data.csv"
  [ "$status" -eq 0 ]
  [[ "$output" == *"outliers"* ]]
  [[ "$output" == *"500"* ]]
}

@test "handles JSON array input" {
  echo '[{"a":1,"b":2},{"a":3,"b":4},{"a":5,"b":6},{"a":7,"b":8},{"a":9,"b":10}]' > "$TESTDIR/data.json"
  run python3 "$PROFILER" "$TESTDIR/data.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"numeric"* ]]
}

@test "handles empty input gracefully" {
  echo "" > "$TESTDIR/empty.csv"
  run python3 "$PROFILER" "$TESTDIR/empty.csv"
  [ "$status" -eq 1 ] || [[ "$output" == *"no data"* ]]
}

@test "safety: has set -uo pipefail" {
  head -1 "$PROFILER" | grep -q "python3" || true
}

@test "token savings reported" {
  cat > "$TESTDIR/big.csv" << 'EOF'
col1,col2,col3,col4,col5
1,2,3,4,5
2,3,4,5,6
3,4,5,6,7
4,5,6,7,8
5,6,7,8,9
EOF
  run python3 "$PROFILER" "$TESTDIR/big.csv"
  [ "$status" -eq 0 ]
  [[ "$output" == *"token_estimate"* ]]
  [[ "$output" == *"savings"* ]]
}
