#!/usr/bin/env bats
# Ref: SE-077 Slice 2 — opencode-monthly-canary.sh

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SCRIPT="$ROOT_DIR/scripts/opencode-monthly-canary.sh"
  TMP=$(mktemp -d)
  SPECS_DIR="$TMP/specs"
  mkdir -p "$SPECS_DIR" "$TMP/output"
  export SPECS_DIR
  export PROJECT_ROOT="$TMP"
  export ROOT="$TMP"
  export OPENCODE_BIN="$TMP/missing-opencode"
  export CLAUDE_BIN="$TMP/missing-claude"
}

teardown() { rm -rf "$TMP"; }

make_spec() {
  local id="$1" canary="${2:-false}"
  cat > "$SPECS_DIR/${id}-test.md" <<EOF
---
id: ${id}
title: ${id}
canary_eligible: ${canary}
---

# ${id}
EOF
}

# ── Usage / dispatch ─────────────────────────────────────────────────────────

@test "canary: --help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "canary: rejects unknown flag with exit 5" {
  run bash "$SCRIPT" --frobnicate
  [ "$status" -eq 5 ]
}

# ── Spec selection ──────────────────────────────────────────────────────────

@test "canary: errors with exit 2 when no canary-eligible spec found" {
  make_spec "SE-100"  # not eligible
  run bash "$SCRIPT" --report-only
  [ "$status" -eq 2 ]
  [[ "$output" == *"no canary-eligible spec"* ]]
}

@test "canary: picks the first canary-eligible spec when no flag" {
  make_spec "SE-100" "false"
  make_spec "SE-200" "true"
  make_spec "SE-300" "true"
  run bash "$SCRIPT" --report-only
  [ "$status" -eq 0 ]
  ls "$TMP/output"/opencode-canary-*.md >/dev/null
}

@test "canary: --spec flag overrides default selection" {
  make_spec "SE-444" "true"
  run bash "$SCRIPT" --spec SE-444 --report-only
  [ "$status" -eq 0 ]
  grep -q "SE-444" "$TMP/output"/opencode-canary-*.md
}

@test "canary: rejects spec id that does not exist" {
  run bash "$SCRIPT" --spec SE-999 --report-only
  [ "$status" -eq 2 ]
  [[ "$output" == *"spec not found"* ]]
}

@test "canary: refuses spec with requires hardware" {
  cat > "$SPECS_DIR/SE-555-test.md" <<'EOF'
---
id: SE-555
canary_eligible: true
requires: hardware
---
EOF
  run bash "$SCRIPT" --spec SE-555 --report-only
  [ "$status" -eq 3 ]
  [[ "$output" == *"ineligible"* ]]
}

# ── Runtime presence ────────────────────────────────────────────────────────

@test "canary: exits 4 when OPENCODE_BIN missing" {
  make_spec "SE-100" "true"
  run bash "$SCRIPT"
  [ "$status" -eq 4 ]
  [[ "$output" == *"OPENCODE_BIN"* ]]
}

@test "canary: exits 4 when CLAUDE_BIN missing on PATH" {
  make_spec "SE-100" "true"
  # Make OPENCODE_BIN exist but CLAUDE_BIN absent
  : > "$TMP/fake-oc"; chmod +x "$TMP/fake-oc"
  OPENCODE_BIN="$TMP/fake-oc" CLAUDE_BIN="claude-not-on-path-XXX" run bash "$SCRIPT"
  [ "$status" -eq 4 ]
}

# ── Report file ─────────────────────────────────────────────────────────────

@test "canary: --report-only writes report under output/" {
  make_spec "SE-100" "true"
  run bash "$SCRIPT" --report-only
  [ "$status" -eq 0 ]
  ls "$TMP/output"/opencode-canary-*.md >/dev/null
}

@test "canary: report contains spec id and runtime paths" {
  make_spec "SE-100" "true"
  bash "$SCRIPT" --report-only >/dev/null
  rep=$(ls "$TMP/output"/opencode-canary-*.md | head -1)
  grep -q "SE-100" "$rep"
  grep -q "opencode" "$rep"
  grep -q "claude" "$rep"
}

# ── Edge cases ──────────────────────────────────────────────────────────────

@test "edge: empty SPECS_DIR exits 2" {
  rm -rf "$SPECS_DIR"
  mkdir -p "$SPECS_DIR"
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "edge: large set of 5 canary-eligible specs picks deterministic first" {
  for i in 1 2 3 4 5; do make_spec "SE-${i}00" "true"; done
  run bash "$SCRIPT" --report-only
  [ "$status" -eq 0 ]
  rep=$(ls "$TMP/output"/opencode-canary-*.md | head -1)
  # Spec id should be present in report — first lexically
  grep -q "SE-100" "$rep"
}

# ── Static / safety / spec ref ──────────────────────────────────────────────

@test "spec ref: SE-077 Slice 2 cited in script header" {
  grep -q "SE-077 Slice 2" "$SCRIPT"
}

@test "safety: canary has set -uo pipefail" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "safety: canary never invokes git push, merge, or pr merge" {
  ! grep -E '^[^#]*(git\s+push|git\s+merge\b|gh\s+pr\s+merge)' "$SCRIPT"
}
