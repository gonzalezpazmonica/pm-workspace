#!/usr/bin/env bats
# Fixture test para el test de ejecución real de mutation-audit (SE-035 Slice 2).

@test "add 2 3 equals 5" {
  run bash "$BATS_TEST_DIRNAME/target.sh" 2 3
  [ "$status" -eq 0 ]
  [ "$output" = "5" ]
}
