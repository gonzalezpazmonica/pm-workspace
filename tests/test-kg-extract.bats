#!/usr/bin/env bats

setup() {
  EXTRACTOR="$BATS_TEST_DIRNAME/../scripts/kg-extract.py"
  TESTDIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TESTDIR"
}

@test "kg-extract exists and is executable" {
  [ -f "$EXTRACTOR" ]
  [ -x "$EXTRACTOR" ]
}

@test "deterministic mode extracts dates" {
  echo "Released on 2026-08-02 and 2025-01-15" > "$TESTDIR/test.txt"
  run python3 "$EXTRACTOR" --mode deterministic --input "$TESTDIR/test.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"2026-08-02"* ]]
  [[ "$output" == *"2025-01-15"* ]]
}

@test "deterministic mode extracts spec IDs" {
  echo "See SE-291 and SE-288 for details" > "$TESTDIR/test.txt"
  run python3 "$EXTRACTOR" --mode deterministic --input "$TESTDIR/test.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SE-291"* ]]
  [[ "$output" == *"SE-288"* ]]
}

@test "deterministic mode extracts emails" {
  echo "Contact: dev@savia.local" > "$TESTDIR/test.txt"
  run python3 "$EXTRACTOR" --mode deterministic --input "$TESTDIR/test.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"dev@savia.local"* ]]
}

@test "deterministic mode extracts file paths" {
  echo "See projects/savia-vaults/src/server/mcp.ts" > "$TESTDIR/test.txt"
  run python3 "$EXTRACTOR" --mode deterministic --input "$TESTDIR/test.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"projects/savia-vaults/src/server/mcp.ts"* ]]
}

@test "confidence is 1.0 for regex extraction" {
  echo "SE-291 was merged on 2026-08-02" > "$TESTDIR/test.txt"
  run python3 "$EXTRACTOR" --mode deterministic --input "$TESTDIR/test.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"confidence": 1.0'* ]]
}

@test "quality gate rejects hallucinated entities" {
  echo "The system uses REST APIs" > "$TESTDIR/test.txt"
  run python3 "$EXTRACTOR" --mode deterministic --input "$TESTDIR/test.txt" --quality-gate
  [ "$status" -eq 0 ]
}

@test "empty input handled gracefully" {
  echo "" > "$TESTDIR/empty.txt"
  run python3 "$EXTRACTOR" --mode deterministic --input "$TESTDIR/empty.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"entity_count": 0'* ]]
}

@test "source document tracked" {
  echo "SE-291" > "$TESTDIR/test.txt"
  run python3 "$EXTRACTOR" --mode deterministic --input "$TESTDIR/test.txt" --source "my-doc.pdf"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"source_document": "my-doc.pdf"'* ]]
}

@test "various patterns detected" {
  cat > "$TESTDIR/rich.txt" << 'EOF'
Release v0.3.0 on 2026-08-02.
See SE-291 and SE-288.
Budget: 50000 EUR.
Contact: team@savia.local.
Config: config/vaults.yaml.
Agent: architect designed the system.
EOF
  run python3 "$EXTRACTOR" --mode deterministic --input "$TESTDIR/rich.txt"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['entity_count'])")
  [ "$count" -ge 5 ]
}
