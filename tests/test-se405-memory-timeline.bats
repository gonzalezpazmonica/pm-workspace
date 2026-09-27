#!/usr/bin/env bats
# Ref: docs/specs/SE-405-harness-observability-increments.spec.md (Slice 3, AC7-AC8)
# Store temporal en PROJECT_ROOT: nunca toca la memoria real.

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-$(mktemp -d)}"
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/memory-store.sh"
  export PROJECT_ROOT="$TMPDIR/ws"
  mkdir -p "$PROJECT_ROOT/output"
  STORE="$PROJECT_ROOT/output/.memory-store.jsonl"
  export SAVIA_EMBED_AUTOSTART=false SAVIA_VERIFIED_MEMORY_DISABLED=true
  for i in 1 2 3 4 5 6 7; do
    printf '{"ts":"2026-09-2%sT10:00:00Z","type":"decision","title":"t%s","content":"c%s","topic_key":"k%s","project":"%s","hash":"h%s000000"}\n' \
      "$i" "$i" "$i" "$i" "$([ "$i" -eq 4 ] && echo other || echo alpha)" "$i" >> "$STORE"
  done
}

teardown() { cd /; }

@test "safety: memory-store.sh keeps strict mode" {
  head -8 "$SCRIPT" | grep -qE 'set -e?uo pipefail'
}

@test "AC7: timeline by topic_key returns anchor plus N before and after in time order" {
  run bash "$SCRIPT" timeline k5 --window 2
  [ "$status" -eq 0 ]
  titles=$(grep -oE '\bt[0-9]\b' <<<"$output" | tr '\n' ' ')
  [ "$titles" = "t2 t3 t5 t6 t7 " ]
  [[ "$output" == *"▶"*"t5"* ]]
}

@test "AC7: entries from another project are excluded when the anchor has a project" {
  run bash "$SCRIPT" timeline k5 --window 3
  [[ "$output" != *"t4"* ]]
}

@test "AC7: anchor resolvable by hash prefix" {
  run bash "$SCRIPT" timeline h3000 --window 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"▶"*"t3"* ]]
}

@test "boundary: window at the start of the store returns only later entries" {
  run bash "$SCRIPT" timeline k1 --window 2
  [ "$status" -eq 0 ]
  [ "$(grep -oE '\bt[0-9]\b' <<<"$output" | tr '\n' ' ')" = "t1 t2 t3 " ]
}

@test "AC8: nonexistent anchor exits 1 with a message" {
  run bash "$SCRIPT" timeline no-such-key
  [ "$status" -eq 1 ]
  [[ "$output" == *"no-such-key"* ]]
}

@test "AC8: non-numeric --window exits 2" {
  run bash "$SCRIPT" timeline k5 --window abc
  [ "$status" -eq 2 ]
}

@test "empty: missing anchor argument exits 2 with usage" {
  run bash "$SCRIPT" timeline
  [ "$status" -eq 2 ]
  [[ "$output" == *"timeline"* ]]
}

@test "empty store file exits 1 without crashing" {
  : > "$STORE"
  run bash "$SCRIPT" timeline k5
  [ "$status" -eq 1 ]
}
