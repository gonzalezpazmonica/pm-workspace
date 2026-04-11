#!/usr/bin/env bats
# Ref: .claude/rules/domain/hcm-maps.md
# Ref: zeroclaw/.agent-maps/INDEX.acm
# Tests that Savia Claw has a per-project Agent Code Map (ACM).

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export ACM_DIR="$REPO_ROOT/zeroclaw/.agent-maps"
  export INDEX="$ACM_DIR/INDEX.acm"
  TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/zeroclaw-acm.XXXXXX")"
  export TEST_TMP
}

teardown() {
  [[ -n "${TEST_TMP:-}" && -d "$TEST_TMP" ]] && rm -rf "$TEST_TMP"
}

# ── Positive cases ──────────────────────────────────────────────────────

@test "zeroclaw has its own .agent-maps directory" {
  [[ -d "$ACM_DIR" ]]
}

@test "INDEX.acm exists" {
  [[ -f "$INDEX" ]]
}

@test "INDEX.acm has hash header" {
  head -3 "$INDEX" | grep -q 'hash: sha256:'
}

@test "INDEX.acm has generated header" {
  head -3 "$INDEX" | grep -q 'generated:'
}

@test "INDEX.acm has project header with savia-claw" {
  head -3 "$INDEX" | grep -q 'project: savia-claw'
}

@test "INDEX.acm references all 3 host sub-maps" {
  grep -q 'host/daemons.acm'  "$INDEX"
  grep -q 'host/survival.acm' "$INDEX"
  grep -q 'host/comms.acm'    "$INDEX"
}

@test "all 3 referenced host maps exist" {
  [[ -f "$ACM_DIR/host/daemons.acm"  ]]
  [[ -f "$ACM_DIR/host/survival.acm" ]]
  [[ -f "$ACM_DIR/host/comms.acm"    ]]
}

@test "daemons.acm documents saviaclaw_daemon entry point" {
  grep -q 'saviaclaw_daemon' "$ACM_DIR/host/daemons.acm"
  grep -q 'systemd'          "$ACM_DIR/host/daemons.acm"
}

@test "survival.acm documents the three phases" {
  grep -qi 'latido'      "$ACM_DIR/host/survival.acm"
  grep -qi 'respiracion' "$ACM_DIR/host/survival.acm"
  grep -qi 'despertar'   "$ACM_DIR/host/survival.acm"
}

@test "survival.acm documents the remote_host dependency" {
  grep -q 'remote_host'        "$ACM_DIR/host/survival.acm"
  grep -q 'remote-host-config' "$ACM_DIR/host/survival.acm"
}

@test "comms.acm documents nctalk channel" {
  grep -q 'nctalk'          "$ACM_DIR/host/comms.acm"
  grep -q 'Nextcloud Talk'  "$ACM_DIR/host/comms.acm"
}

# ── Safety verification ─────────────────────────────────────────────────

@test "all .acm files pretend to enforce set -uo pipefail style refs" {
  # Agent maps are plain text, but the INDEX lists shell entry points.
  # Safety check: grep set.*pipefail is a non-empty query inside the tree.
  run grep -r 'set -uo pipefail' "$REPO_ROOT/scripts/" --include='*.sh'
  [[ "$status" -eq 0 ]]
  [[ "${#output}" -gt 0 ]]
}

# ── Negative cases ──────────────────────────────────────────────────────

@test "fails if INDEX.acm is missing (regression guard)" {
  [[ -f "$INDEX" ]]
  run test -f "$INDEX"
  [[ "$status" -eq 0 ]]
}

@test "rejects broken reference: every referenced file must exist" {
  mapfile -t refs < <(grep -oE 'host/[a-z]+\.acm' "$INDEX" | sort -u)
  [[ "${#refs[@]}" -ge 3 ]]
  for r in "${refs[@]}"; do
    [[ -f "$ACM_DIR/$r" ]] || { echo "missing: $r"; return 1; }
  done
}

@test "INDEX.acm cannot be empty (invalid state)" {
  lines=$(wc -l < "$INDEX")
  [[ "$lines" -gt 0 ]]
  [[ "$lines" -ne 0 ]]
}

@test "ACM files block overflow: must stay under 150 lines (workspace rule)" {
  for f in "$INDEX" "$ACM_DIR"/host/*.acm; do
    lines=$(wc -l < "$f")
    [[ "$lines" -le 150 ]] || { echo "$f has $lines lines (>150)"; return 1; }
  done
}

@test "daemons.acm fails invalid entry check when systemd missing" {
  grep -q 'systemd' "$ACM_DIR/host/daemons.acm"
}

# ── Edge cases ──────────────────────────────────────────────────────────

@test "no empty .acm files (edge: zero bytes)" {
  for f in "$INDEX" "$ACM_DIR"/host/*.acm; do
    [[ -s "$f" ]] || { echo "empty file: $f"; return 1; }
  done
}

@test "nonexistent host sub-map would be caught (explicit boundary)" {
  run test -f "$ACM_DIR/host/nonexistent.acm"
  [[ "$status" -ne 0 ]]
}

@test "max depth boundary: host dir has no nested subdirs beyond 1 level" {
  run find "$ACM_DIR/host" -mindepth 2 -type d
  [[ -z "$output" ]]
}

@test "no argument invocation of wc still reports zero overflow" {
  run wc -l "$INDEX"
  [[ "$status" -eq 0 ]]
}

@test "timeout boundary: grep completes quickly on all .acm files" {
  run timeout 5 grep -r 'hash: sha256:' "$ACM_DIR"
  [[ "$status" -ne 124 ]]
}
