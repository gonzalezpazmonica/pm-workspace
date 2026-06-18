#!/usr/bin/env bats
# Tests for scripts/content-fingerprint.sh
# SE-151: Content fingerprint consolidation

setup() {
  CF="${BATS_TEST_DIRNAME}/../../scripts/content-fingerprint.sh"
  FIXTURES="${BATS_TEST_DIRNAME}/../fixtures/fingerprint"
  [[ -x "$CF" ]] || skip "content-fingerprint.sh not executable"
}

# AC-1: len validation
@test "len=8 produces 8-char hex" {
  result=$(echo "test" | "$CF" 8)
  [ ${#result} -eq 8 ]
  [[ "$result" =~ ^[0-9a-f]+$ ]]
}

@test "len=16 produces 16-char hex" {
  result=$(echo "test" | "$CF" 16)
  [ ${#result} -eq 16 ]
}

@test "len=32 produces 32-char hex" {
  result=$(echo "test" | "$CF" 32)
  [ ${#result} -eq 32 ]
}

@test "len=64 produces 64-char hex" {
  result=$(echo "test" | "$CF" 64)
  [ ${#result} -eq 64 ]
}

@test "len=99 rejected with exit 2" {
  run bash -c "echo test | '$CF' 99"
  [ "$status" -eq 2 ]
}

@test "len=foo rejected with exit 2" {
  run bash -c "echo test | '$CF' foo"
  [ "$status" -eq 2 ]
}

# AC-1: determinismo
@test "same input produces same output" {
  a=$(echo "hello world" | "$CF" 16)
  b=$(echo "hello world" | "$CF" 16)
  [ "$a" = "$b" ]
}

# AC-1: avalanche (1 byte change → totally different output)
@test "1-char difference produces different fingerprint" {
  a=$(echo "hello world" | "$CF" 16)
  b=$(echo "hello worle" | "$CF" 16)
  [ "$a" != "$b" ]
}

# Empty stdin is treated as empty content (valid, deterministic)
@test "empty stdin produces sha256 of empty string" {
  result=$(echo -n "" | "$CF" 16)
  # sha256("") = e3b0c44298fc1c14...
  [ "$result" = "e3b0c44298fc1c14" ]
}

# AC-4: dataset etiquetado — identicos
@test "AC-4 identicos: same fingerprint for all 5 identical pairs" {
  for i in 1 2 3 4 5; do
    a=$("$CF" 16 < "$FIXTURES/identical-${i}-a.txt")
    b=$("$CF" 16 < "$FIXTURES/identical-${i}-b.txt")
    [ "$a" = "$b" ] || { echo "pair $i differs: $a vs $b"; return 1; }
  done
}

# AC-4: dataset — near-duplicates (deben diferir)
@test "AC-4 near-dup: different fingerprint for all 5 near-duplicate pairs" {
  for i in 1 2 3 4 5; do
    a=$("$CF" 16 < "$FIXTURES/near-${i}-a.txt")
    b=$("$CF" 16 < "$FIXTURES/near-${i}-b.txt")
    [ "$a" != "$b" ] || { echo "pair $i collides: $a"; return 1; }
  done
}

# AC-4: dataset — distintos
@test "AC-4 distintos: different fingerprint for all 5 distinct pairs" {
  for i in 1 2 3 4 5; do
    a=$("$CF" 16 < "$FIXTURES/distinct-${i}-a.txt")
    b=$("$CF" 16 < "$FIXTURES/distinct-${i}-b.txt")
    [ "$a" != "$b" ] || { echo "pair $i collides: $a"; return 1; }
  done
}

# AC-5: latencia (100 invocaciones <50ms p95 → no test estricto, sanity check)
@test "AC-5 latencia: 100 invocaciones <5s total" {
  start=$(date +%s%N)
  for i in $(seq 1 100); do
    echo "test-$i" | "$CF" 16 >/dev/null
  done
  end=$(date +%s%N)
  elapsed_ms=$(( (end - start) / 1000000 ))
  echo "100 invocations took ${elapsed_ms}ms"
  [ "$elapsed_ms" -lt 5000 ]
}

# Self-test
@test "--self-test exits 0" {
  run "$CF" --self-test
  [ "$status" -eq 0 ]
}
