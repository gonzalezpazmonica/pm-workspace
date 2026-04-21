#!/usr/bin/env bats
# BATS tests for scripts/permissions-wildcard-audit.sh (SE-059 Slice 1).
# Ref: SE-059
SCRIPT="scripts/permissions-wildcard-audit.sh"

setup() { export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"; cd "$BATS_TEST_DIRNAME/.."; }
teardown() { cd /; }

@test "exists + executable" { [[ -x "$SCRIPT" ]]; }
@test "uses set -uo pipefail" { run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "passes bash -n" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }
@test "references SE-059" { run grep -c 'SE-059' "$SCRIPT"; [[ "$output" -ge 1 ]]; }

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"level"* ]]
  [[ "$output" == *"suggest"* ]]
}

@test "rejects unknown arg" { run bash "$SCRIPT" --bogus; [ "$status" -eq 2 ]; }
@test "rejects invalid --level" { run bash "$SCRIPT" --level invalid; [ "$status" -eq 2 ]; }

@test "default audit runs" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  [[ "$output" == *"VERDICT"* ]]
}

@test "--suggest prints recommendation" {
  run bash "$SCRIPT" --suggest
  [ "$status" -eq 0 ]
  [[ "$output" == *"deny"* ]]
}

@test "--json valid" {
  run bash -c 'bash scripts/permissions-wildcard-audit.sh --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
for k in [\"verdict\",\"level\",\"files_audited\",\"findings_count\",\"critical\",\"high\",\"medium\",\"findings\"]:
    assert k in d, f\"missing {k}\"
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

# ── Rule detection (synthetic) ─────────────────────────

@test "PERM-01 detects Bash(*) without deny list" {
  local root="$BATS_TEST_TMPDIR/perm01"
  mkdir -p "$root/.claude" "$root/scripts"
  cat > "$root/.claude/settings.json" <<'JSON'
{"permissions": {"allow": ["Bash(*)"]}}
JSON
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash scripts/permissions-wildcard-audit.sh --level repo --json
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 1 ]
  [[ "$output" == *"PERM-01"* ]]
}

@test "PERM-02 detects Write(*) without restrictions" {
  local root="$BATS_TEST_TMPDIR/perm02"
  mkdir -p "$root/.claude" "$root/scripts"
  cat > "$root/.claude/settings.json" <<'JSON'
{"permissions": {"allow": ["Write(*)"]}}
JSON
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash scripts/permissions-wildcard-audit.sh --level repo --json
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *"PERM-02"* ]]
}

@test "PERM-03 detects WebFetch(*)" {
  local root="$BATS_TEST_TMPDIR/perm03"
  mkdir -p "$root/.claude" "$root/scripts"
  cat > "$root/.claude/settings.json" <<'JSON'
{"permissions": {"allow": ["WebFetch(*)"], "deny": ["Bash(rm)"]}}
JSON
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash scripts/permissions-wildcard-audit.sh --level repo --json
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *"PERM-03"* ]]
}

@test "PERM-04 detects auto mode with skip prompts" {
  local root="$BATS_TEST_TMPDIR/perm04"
  mkdir -p "$root/.claude" "$root/scripts"
  cat > "$root/.claude/settings.json" <<'JSON'
{"permissions": {"defaultMode": "auto"}, "skipAutoPermissionPrompt": true}
JSON
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash scripts/permissions-wildcard-audit.sh --level repo --json
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *"PERM-04"* ]]
}

@test "PERM-08 detects malformed JSON" {
  local root="$BATS_TEST_TMPDIR/perm08"
  mkdir -p "$root/.claude" "$root/scripts"
  echo '{invalid json' > "$root/.claude/settings.json"
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash scripts/permissions-wildcard-audit.sh --level repo --json
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *"PERM-08"* ]]
}

@test "clean settings = PASS" {
  local root="$BATS_TEST_TMPDIR/clean"
  mkdir -p "$root/.claude" "$root/scripts"
  cat > "$root/.claude/settings.json" <<'JSON'
{"permissions": {"allow": ["Read(*)"], "deny": ["Bash(rm -rf)"]}}
JSON
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash scripts/permissions-wildcard-audit.sh --level repo --json
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *'"findings_count":0'* ]]
}

# ── Edge cases ────────────────────────────────────────

@test "edge: empty settings (no permissions block) = PASS" {
  local root="$BATS_TEST_TMPDIR/empty"
  mkdir -p "$root/.claude" "$root/scripts"
  echo '{}' > "$root/.claude/settings.json"
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash scripts/permissions-wildcard-audit.sh --level repo --json
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *'"findings_count":0'* ]]
}

@test "edge: --level user works" { run bash "$SCRIPT" --level user; [[ "$status" -eq 0 || "$status" -eq 1 ]]; }
@test "edge: --level local works" { run bash "$SCRIPT" --level local; [[ "$status" -eq 0 || "$status" -eq 1 ]]; }
@test "edge: nonexistent settings file is skipped" {
  local root="$BATS_TEST_TMPDIR/none"
  mkdir -p "$root/scripts"
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash scripts/permissions-wildcard-audit.sh --level repo --json
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *'"files_audited":0'* ]]
}

# ── Coverage ──────────────────────────────────────────

@test "coverage: audit_settings function" { run grep -c 'audit_settings' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "coverage: add_finding function" { run grep -c 'add_finding' "$SCRIPT"; [[ "$output" -ge 2 ]]; }
@test "coverage: 8 rules referenced" {
  for r in PERM-01 PERM-02 PERM-03 PERM-04 PERM-05 PERM-06 PERM-07 PERM-08; do
    grep -q "$r" "$SCRIPT" || fail "Missing rule $r"
  done
}

# ── Isolation ─────────────────────────────────────────

@test "isolation: does not modify settings.json" {
  local h_before
  h_before=$(md5sum .claude/settings.json 2>/dev/null | awk '{print $1}' || echo "")
  bash "$SCRIPT" >/dev/null 2>&1 || true
  local h_after
  h_after=$(md5sum .claude/settings.json 2>/dev/null | awk '{print $1}' || echo "")
  [[ "$h_before" == "$h_after" ]]
}

@test "isolation: exit codes 0/1/2" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}
