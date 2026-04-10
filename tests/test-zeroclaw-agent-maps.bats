#!/usr/bin/env bats
# Ref: zeroclaw/.agent-maps/INDEX.acm
# Tests that Savia Claw has a per-project Agent Code Map (ACM).

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export ACM_DIR="$REPO_ROOT/zeroclaw/.agent-maps"
}

@test "zeroclaw has its own .agent-maps directory" {
  [[ -d "$ACM_DIR" ]]
}

@test "INDEX.acm exists" {
  [[ -f "$ACM_DIR/INDEX.acm" ]]
}

@test "INDEX.acm has hash + generated + project header" {
  head -3 "$ACM_DIR/INDEX.acm" | grep -q 'hash: sha256:'
  head -3 "$ACM_DIR/INDEX.acm" | grep -q 'generated:'
  head -3 "$ACM_DIR/INDEX.acm" | grep -q 'project: savia-claw'
}

@test "INDEX.acm references all 3 host sub-maps" {
  grep -q 'host/daemons.acm' "$ACM_DIR/INDEX.acm"
  grep -q 'host/survival.acm' "$ACM_DIR/INDEX.acm"
  grep -q 'host/comms.acm' "$ACM_DIR/INDEX.acm"
}

@test "all 3 referenced host maps exist" {
  [[ -f "$ACM_DIR/host/daemons.acm" ]]
  [[ -f "$ACM_DIR/host/survival.acm" ]]
  [[ -f "$ACM_DIR/host/comms.acm" ]]
}

@test "daemons.acm documents saviaclaw_daemon entry point" {
  grep -q 'saviaclaw_daemon' "$ACM_DIR/host/daemons.acm"
  grep -q 'systemd' "$ACM_DIR/host/daemons.acm"
}

@test "survival.acm documents the three phases" {
  grep -qi 'latido' "$ACM_DIR/host/survival.acm"
  grep -qi 'respiracion' "$ACM_DIR/host/survival.acm"
  grep -qi 'despertar' "$ACM_DIR/host/survival.acm"
}

@test "survival.acm documents the remote_host dependency" {
  grep -q 'remote_host' "$ACM_DIR/host/survival.acm"
  grep -q 'remote-host-config' "$ACM_DIR/host/survival.acm"
}

@test "comms.acm documents nctalk channel" {
  grep -q 'nctalk' "$ACM_DIR/host/comms.acm"
  grep -q 'Nextcloud Talk' "$ACM_DIR/host/comms.acm"
}

@test "ACM files stay under 150 lines (workspace rule)" {
  for f in "$ACM_DIR/INDEX.acm" "$ACM_DIR"/host/*.acm; do
    lines=$(wc -l < "$f")
    [[ "$lines" -le 150 ]] || { echo "$f has $lines lines (>150)"; return 1; }
  done
}
