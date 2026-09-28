#!/usr/bin/env bats
# Ref: docs/specs/SE-405-harness-observability-increments.spec.md (Slice 2, AC4-AC6)
# HOME y directorio de snapshots temporales: nunca toca ~/.savia real.

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-$(mktemp -d)}"
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/config-snapshot.sh"
  HOOK="$BATS_TEST_DIRNAME/../.claude/hooks/config-snapshot-hook.sh"
  export SAVIA_CONFIG_SNAPSHOT_DIR="$TMPDIR/snaps"
  WS="$TMPDIR/ws"; mkdir -p "$WS/.claude"
  CFG="$WS/.claude/settings.json"
  echo '{"v":1}' > "$CFG"
}

teardown() { cd /; }

hook_payload() { printf '{"tool_name":"%s","tool_input":{"file_path":"%s"},"cwd":"%s"}' "$1" "$2" "$WS"; }

@test "safety: script declares set -uo pipefail" {
  head -3 "$SCRIPT" | grep -q 'set -uo pipefail'
}

@test "AC4: snapshot stores content identical to the file before the edit" {
  run bash "$SCRIPT" snapshot "$CFG"
  [ "$status" -eq 0 ]
  snap=$(ls "$SAVIA_CONFIG_SNAPSHOT_DIR/settings.json/" | head -1)
  cmp "$CFG" "$SAVIA_CONFIG_SNAPSHOT_DIR/settings.json/$snap"
}

@test "AC4: the PreToolUse hook snapshots a watched file and never blocks" {
  run bash -c "$(declare -f hook_payload); WS='$WS'; hook_payload Edit '$CFG' | bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ "$(ls "$SAVIA_CONFIG_SNAPSHOT_DIR/settings.json/" | grep -vc "\.path$")" -eq 1 ]
}

@test "negative: the hook ignores files that are not watched" {
  echo x > "$WS/other.json"
  run bash -c "$(declare -f hook_payload); WS='$WS'; hook_payload Write '$WS/other.json' | bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ ! -d "$SAVIA_CONFIG_SNAPSHOT_DIR" ] || [ -z "$(ls "$SAVIA_CONFIG_SNAPSHOT_DIR")" ]
}

@test "AC5: restore without --confirm exits 2 and changes nothing" {
  bash "$SCRIPT" snapshot "$CFG" >/dev/null
  id=$(bash "$SCRIPT" list "$CFG" | awk 'NR==1{print $1}')
  echo '{"v":2}' > "$CFG"
  run bash "$SCRIPT" restore "$id"
  [ "$status" -eq 2 ]
  grep -q '"v":2' "$CFG"
}

@test "AC5: restore --confirm restores and snapshots the replaced state first" {
  bash "$SCRIPT" snapshot "$CFG" >/dev/null
  id=$(bash "$SCRIPT" list "$CFG" | awk 'NR==1{print $1}')
  echo '{"v":2}' > "$CFG"
  run bash "$SCRIPT" restore "$id" --confirm
  [ "$status" -eq 0 ]
  grep -q '"v":1' "$CFG"
  grep -rq '"v":2' "$SAVIA_CONFIG_SNAPSHOT_DIR/settings.json/"
}

@test "AC6: retention keeps at most 30 snapshots per file" {
  for i in $(seq 1 33); do echo "{\"v\":$i}" > "$CFG"; bash "$SCRIPT" snapshot "$CFG" >/dev/null; done
  [ "$(ls "$SAVIA_CONFIG_SNAPSHOT_DIR/settings.json/" | grep -vc "\.path$")" -eq 30 ]
  grep -rq '"v":33' "$SAVIA_CONFIG_SNAPSHOT_DIR/settings.json/"
  ! grep -rq '"v":1}' "$SAVIA_CONFIG_SNAPSHOT_DIR/settings.json/"
}

@test "missing: snapshot of a nonexistent file exits 1" {
  run bash "$SCRIPT" snapshot "$WS/nope.json"
  [ "$status" -eq 1 ]
}

@test "invalid: restore of an unknown id exits 1" {
  run bash "$SCRIPT" restore "settings.json/does-not-exist" --confirm
  [ "$status" -eq 1 ]
}

@test "empty: no arguments prints usage and exits 2" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage"* ]]
}
