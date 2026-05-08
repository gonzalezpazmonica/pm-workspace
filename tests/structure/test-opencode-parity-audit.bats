#!/usr/bin/env bats
# Ref: SE-077 Slice 2 — opencode-parity-audit.sh

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SCRIPT="$ROOT_DIR/scripts/opencode-parity-audit.sh"
  TMP=$(mktemp -d)
  HOOKS_DIR="$TMP/hooks"
  SETTINGS="$TMP/settings.json"
  MANIFEST="$TMP/manifest.json"
  BASELINE_DIR="$TMP/.ci-baseline"
  mkdir -p "$HOOKS_DIR" "$BASELINE_DIR"
  export HOOKS_DIR SETTINGS
  export OPENCODE_MANIFEST="$MANIFEST"
  export PROJECT_ROOT="$TMP"
  export ROOT="$TMP"
  # Move the baseline file into the temp tree by overriding via PROJECT_ROOT
  cat > "$SETTINGS" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {"matcher":"Bash","hooks":[{"type":"command","command":"\"$CLAUDE_PROJECT_DIR\"/.opencode/hooks/block-credential-leak.sh"}]}
    ],
    "PostToolUse": [
      {"matcher":"Read","hooks":[{"type":"command","command":"\"$CLAUDE_PROJECT_DIR\"/.opencode/hooks/acm-turn-marker.sh"}]}
    ],
    "Stop": [
      {"hooks":[{"type":"command","command":"\"$CLAUDE_PROJECT_DIR\"/.opencode/hooks/session-end-snapshot.sh"}]}
    ]
  }
}
JSON
  echo "#!/bin/bash" > "$HOOKS_DIR/block-credential-leak.sh"
  echo "#!/bin/bash" > "$HOOKS_DIR/acm-turn-marker.sh"
  echo "#!/bin/bash" > "$HOOKS_DIR/session-end-snapshot.sh"
}

teardown() { rm -rf "$TMP"; }

write_manifest() {
  # $@ = "<event>:<hook.sh>" pairs
  python3 - "$MANIFEST" "$@" <<'PY'
import json, sys
out = {"bindings": []}
for pair in sys.argv[2:]:
    ev, hk = pair.split(":", 1)
    out["bindings"].append({"event": ev, "claudeHook": hk, "matcher": None, "handler": "x"})
json.dump(out, open(sys.argv[1], "w"), indent=2)
PY
}

# ── Default (text) mode ─────────────────────────────────────────────────────

@test "parity: default text reports total/matched/justified/gap" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"total Claude Code bindings"* ]]
  [[ "$output" == *"matched in OpenCode plugin"* ]]
  [[ "$output" == *"unjustified gap"* ]]
}

@test "parity: gap == total when manifest missing" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"unjustified gap            : 3"* ]]
}

@test "parity: matched count rises with manifest entries" {
  write_manifest "PreToolUse:block-credential-leak.sh" "PostToolUse:acm-turn-marker.sh"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"matched in OpenCode plugin : 2"* ]]
  [[ "$output" == *"unjustified gap            : 1"* ]]
}

# ── Justification headers ───────────────────────────────────────────────────

@test "parity: hook with NOT_EXPOSED justification is excluded from gap" {
  cat > "$HOOKS_DIR/session-end-snapshot.sh" <<'EOF'
#!/bin/bash
# opencode-binding: NOT_EXPOSED — Stop hook category not in OpenCode plugin SDK
EOF
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"justified (NOT_EXPOSED)    : 1"* ]]
  [[ "$output" == *"unjustified gap            : 2"* ]]
}

@test "parity: hook with explicit handler justification is excluded" {
  cat > "$HOOKS_DIR/acm-turn-marker.sh" <<'EOF'
#!/bin/bash
# opencode-binding: tool.execute.after — bound via savia-gates
EOF
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"justified (NOT_EXPOSED)    : 1"* ]]
}

# ── --json ──────────────────────────────────────────────────────────────────

@test "parity: --json emits valid JSON" {
  run bash "$SCRIPT" --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'gap' in d and 'missing' in d"
}

# ── --baseline ──────────────────────────────────────────────────────────────

@test "parity: --baseline writes integer to .ci-baseline/opencode-parity-gap.count" {
  run bash "$SCRIPT" --baseline
  [ "$status" -eq 0 ]
  [ -f "$TMP/.ci-baseline/opencode-parity-gap.count" ]
  count=$(cat "$TMP/.ci-baseline/opencode-parity-gap.count")
  [ "$count" -eq 3 ]
}

# ── --check ─────────────────────────────────────────────────────────────────

@test "parity: --check exits 2 when baseline missing" {
  write_manifest
  run bash "$SCRIPT" --check
  [ "$status" -eq 2 ]
}

@test "parity: --check exits 3 when manifest missing" {
  echo 3 > "$TMP/.ci-baseline/opencode-parity-gap.count"
  run bash "$SCRIPT" --check
  [ "$status" -eq 3 ]
}

@test "parity: --check passes when gap == baseline" {
  write_manifest
  bash "$SCRIPT" --baseline >/dev/null
  run bash "$SCRIPT" --check
  [ "$status" -eq 0 ]
}

@test "parity: --check fails with exit 1 when gap regressed" {
  write_manifest "PreToolUse:block-credential-leak.sh" "PostToolUse:acm-turn-marker.sh" "Stop:session-end-snapshot.sh"
  bash "$SCRIPT" --baseline >/dev/null
  # Now drop a manifest entry, simulating regression
  write_manifest "PreToolUse:block-credential-leak.sh"
  run bash "$SCRIPT" --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"regression"* ]]
}

# ── Edge cases ──────────────────────────────────────────────────────────────

@test "edge: empty hooks section reports zero total bindings" {
  echo '{"hooks":{}}' > "$SETTINGS"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"total Claude Code bindings : 0"* ]]
}

@test "edge: --baseline overwrites previous baseline" {
  write_manifest
  bash "$SCRIPT" --baseline >/dev/null
  echo "stale" > "$TMP/.ci-baseline/opencode-parity-gap.count"
  run bash "$SCRIPT" --baseline
  [ "$status" -eq 0 ]
  count=$(cat "$TMP/.ci-baseline/opencode-parity-gap.count")
  [ "$count" -eq 3 ]
}

# ── Static / safety / spec ref ──────────────────────────────────────────────

@test "spec ref: SE-077 Slice 2 cited in script header" {
  grep -q "SE-077 Slice 2" "$SCRIPT"
}

@test "safety: parity-audit has set -uo pipefail" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "safety: parity-audit never invokes git push or merge" {
  ! grep -E '^[^#]*git\s+(push|merge)' "$SCRIPT"
}
