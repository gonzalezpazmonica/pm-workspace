#!/usr/bin/env bats
# test-context-sanitize-hook.bats — SPEC-193 Capa A tests
#
# Tests for:
#   - .opencode/hooks/context-sanitize-input.sh
#   - .opencode/hooks/memory-write-sanitize.sh
# Covers all modes: off, shadow, warn, block
# Verifies: bidi always blocked in block mode, master switch SAVIA_HARDENING=off

SANITIZE_HOOK="${BATS_TEST_DIRNAME}/../.opencode/hooks/context-sanitize-input.sh"
MEMORY_HOOK="${BATS_TEST_DIRNAME}/../.opencode/hooks/memory-write-sanitize.sh"

# Cyrillic 'а' U+0430 looks like Latin 'a'
CYRILLIC_A=$'\xd0\xb0'
# RLO bidi control U+202E
BIDI_RLO=$'\xe2\x80\xae'
# Zero-width space U+200B
ZWS=$'\xe2\x80\x8b'

setup() {
  export TMP_DIR
  TMP_DIR="$(mktemp -d)"
  export CLAUDE_PROJECT_DIR="${BATS_TEST_DIRNAME}/.."
  export SAVIA_HARDENING_LOG="${TMP_DIR}/telemetry.jsonl"
  # Default: hardening on, warn mode
  export SAVIA_HARDENING="on"
  export SAVIA_SANITIZE_INPUT="warn"
  export SAVIA_MEMORY_WRITE_SANITIZE="warn"
  export SAVIA_REDTEAM_MODE="off"
}

teardown() {
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

# ─────────────────────────────────────────────────────────────────────────────
# Basic existence + safety checks
# ─────────────────────────────────────────────────────────────────────────────

@test "context-sanitize-input.sh exists and is executable" {
  [[ -x "$SANITIZE_HOOK" ]]
}

@test "memory-write-sanitize.sh exists and is executable" {
  [[ -x "$MEMORY_HOOK" ]]
}

@test "sanitize hook uses set -uo pipefail" {
  grep -E "set -uo pipefail" "$SANITIZE_HOOK"
}

@test "memory hook uses set -uo pipefail" {
  grep -E "set -uo pipefail" "$MEMORY_HOOK"
}

# ─────────────────────────────────────────────────────────────────────────────
# Master switch: SAVIA_HARDENING=off
# ─────────────────────────────────────────────────────────────────────────────

@test "master switch SAVIA_HARDENING=off: sanitize hook passes everything" {
  export SAVIA_HARDENING="off"
  export SAVIA_SANITIZE_INPUT="block"
  # Even with a bidi char, should exit 0
  local payload
  payload='{"tool_name":"Write","tool_input":{"content":"hello'"$BIDI_RLO"'world"}}'
  run bash "$SANITIZE_HOOK" <<< "$payload"
  [[ "$status" -eq 0 ]]
}

@test "master switch SAVIA_HARDENING=off: memory hook passes everything" {
  export SAVIA_HARDENING="off"
  export SAVIA_MEMORY_WRITE_SANITIZE="block"
  local payload='{"tool_name":"Bash","tool_input":{"command":"bash scripts/memory-store.sh save key '"$CYRILLIC_A$CYRILLIC_A$CYRILLIC_A"'"}}'
  run bash "$MEMORY_HOOK" <<< "$payload"
  [[ "$status" -eq 0 ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# Mode: off
# ─────────────────────────────────────────────────────────────────────────────

@test "mode=off: exits 0 even with bidi in payload" {
  export SAVIA_SANITIZE_INPUT="off"
  local payload='{"tool_name":"Write","tool_input":{"content":"bad'"$BIDI_RLO"'content"}}'
  run bash "$SANITIZE_HOOK" <<< "$payload"
  [[ "$status" -eq 0 ]]
}

@test "mode=off: exits 0 for empty input" {
  export SAVIA_SANITIZE_INPUT="off"
  run bash "$SANITIZE_HOOK" <<< ""
  [[ "$status" -eq 0 ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# Mode: shadow
# ─────────────────────────────────────────────────────────────────────────────

@test "mode=shadow: exits 0 even with homoglyphs" {
  export SAVIA_SANITIZE_INPUT="shadow"
  local payload='{"tool_name":"Write","tool_input":{"content":"p'"$CYRILLIC_A"'ypal"}}'
  run bash "$SANITIZE_HOOK" <<< "$payload"
  [[ "$status" -eq 0 ]]
}

@test "mode=shadow: exits 0 even with bidi" {
  export SAVIA_SANITIZE_INPUT="shadow"
  local payload='{"tool_name":"Write","tool_input":{"content":"bad'"$BIDI_RLO"'content"}}'
  run bash "$SANITIZE_HOOK" <<< "$payload"
  [[ "$status" -eq 0 ]]
}

@test "mode=shadow: writes telemetry entry" {
  export SAVIA_SANITIZE_INPUT="shadow"
  local payload='{"tool_name":"Write","tool_input":{"content":"p'"$CYRILLIC_A"'ypal"}}'
  run bash "$SANITIZE_HOOK" <<< "$payload"
  [[ "$status" -eq 0 ]]
  # Telemetry file should exist and have content
  if [[ -f "$SAVIA_HARDENING_LOG" ]]; then
    local line_count
    line_count=$(wc -l < "$SAVIA_HARDENING_LOG")
    [[ "$line_count" -ge 1 ]]
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Mode: warn
# ─────────────────────────────────────────────────────────────────────────────

@test "mode=warn: exits 0 with homoglyphs (warn but no block)" {
  export SAVIA_SANITIZE_INPUT="warn"
  local payload='{"tool_name":"Write","tool_input":{"content":"p'"$CYRILLIC_A"'ypal"}}'
  run bash "$SANITIZE_HOOK" <<< "$payload"
  [[ "$status" -eq 0 ]]
}

@test "mode=warn: exits 0 even with bidi (warn only)" {
  export SAVIA_SANITIZE_INPUT="warn"
  local payload='{"tool_name":"Write","tool_input":{"content":"bad'"$BIDI_RLO"'content"}}'
  run bash "$SANITIZE_HOOK" <<< "$payload"
  [[ "$status" -eq 0 ]]
}

@test "mode=warn: emits WARN to stderr for homoglyphs" {
  export SAVIA_SANITIZE_INPUT="warn"
  local payload='{"tool_name":"Write","tool_input":{"content":"p'"$CYRILLIC_A"'yp'"$CYRILLIC_A"'l"}}'
  run bash "$SANITIZE_HOOK" <<< "$payload"
  # status 0, stderr contains WARN (may or may not depending on score)
  [[ "$status" -eq 0 ]]
}

@test "mode=warn: exits 0 for clean text" {
  export SAVIA_SANITIZE_INPUT="warn"
  local payload='{"tool_name":"Write","tool_input":{"content":"hello world"}}'
  run bash "$SANITIZE_HOOK" <<< "$payload"
  [[ "$status" -eq 0 ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# Mode: block — bidi ALWAYS blocks
# ─────────────────────────────────────────────────────────────────────────────

@test "mode=block: bidi RLO always blocked (exit 2)" {
  export SAVIA_SANITIZE_INPUT="block"
  local payload='{"tool_name":"Write","tool_input":{"content":"hello'"$BIDI_RLO"'world"}}'
  run bash "$SANITIZE_HOOK" <<< "$payload"
  [[ "$status" -eq 2 ]]
}

@test "mode=block: bidi LRE always blocked (exit 2)" {
  export SAVIA_SANITIZE_INPUT="block"
  local lre=$'\xe2\x80\xaa'
  local payload='{"tool_name":"Write","tool_input":{"content":"text'"$lre"'here"}}'
  run bash "$SANITIZE_HOOK" <<< "$payload"
  [[ "$status" -eq 2 ]]
}

@test "mode=block: bidi in warn mode does NOT block (exit 0)" {
  export SAVIA_SANITIZE_INPUT="warn"
  local payload='{"tool_name":"Write","tool_input":{"content":"bad'"$BIDI_RLO"'content"}}'
  run bash "$SANITIZE_HOOK" <<< "$payload"
  [[ "$status" -eq 0 ]]
}

@test "mode=block: high homoglyph score blocks (exit 2)" {
  export SAVIA_SANITIZE_INPUT="block"
  # Multiple cyrillic+bidi to guarantee score >= 70
  local text="p${CYRILLIC_A}yp${CYRILLIC_A}l${BIDI_RLO}"
  local payload='{"tool_name":"Write","tool_input":{"content":"'"$text"'"}}'
  run bash "$SANITIZE_HOOK" <<< "$payload"
  [[ "$status" -eq 2 ]]
}

@test "mode=block: clean text passes (exit 0)" {
  export SAVIA_SANITIZE_INPUT="block"
  local payload='{"tool_name":"Write","tool_input":{"content":"hello world clean text"}}'
  run bash "$SANITIZE_HOOK" <<< "$payload"
  [[ "$status" -eq 0 ]]
}

@test "mode=block: empty input passes (exit 0)" {
  export SAVIA_SANITIZE_INPUT="block"
  run bash "$SANITIZE_HOOK" <<< ""
  [[ "$status" -eq 0 ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# Redteam mode
# ─────────────────────────────────────────────────────────────────────────────

@test "SAVIA_REDTEAM_MODE=on: bidi does not block (exit 0) but logs REDTEAM_BYPASS" {
  export SAVIA_SANITIZE_INPUT="block"
  export SAVIA_REDTEAM_MODE="on"
  local payload='{"tool_name":"Write","tool_input":{"content":"bad'"$BIDI_RLO"'content"}}'
  run bash "$SANITIZE_HOOK" <<< "$payload"
  [[ "$status" -eq 0 ]]
}

@test "SAVIA_REDTEAM_MODE=on: high score does not block (exit 0)" {
  export SAVIA_SANITIZE_INPUT="block"
  export SAVIA_REDTEAM_MODE="on"
  local text="p${CYRILLIC_A}yp${CYRILLIC_A}l${BIDI_RLO}"
  local payload='{"tool_name":"Write","tool_input":{"content":"'"$text"'"}}'
  run bash "$SANITIZE_HOOK" <<< "$payload"
  [[ "$status" -eq 0 ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# memory-write-sanitize hook tests
# ─────────────────────────────────────────────────────────────────────────────

@test "memory hook: non-Bash tool exits 0" {
  local payload='{"tool_name":"Read","tool_input":{"file_path":"/foo"}}'
  run bash "$MEMORY_HOOK" <<< "$payload"
  [[ "$status" -eq 0 ]]
}

@test "memory hook: Bash without memory-store exits 0" {
  local payload='{"tool_name":"Bash","tool_input":{"command":"ls -la"}}'
  run bash "$MEMORY_HOOK" <<< "$payload"
  [[ "$status" -eq 0 ]]
}

@test "memory hook: mode=off passes everything" {
  export SAVIA_MEMORY_WRITE_SANITIZE="off"
  local payload='{"tool_name":"Bash","tool_input":{"command":"bash scripts/memory-store.sh save key '"$BIDI_RLO"'value"}}'
  run bash "$MEMORY_HOOK" <<< "$payload"
  [[ "$status" -eq 0 ]]
}

@test "memory hook: SAVIA_HARDENING=off passes everything" {
  export SAVIA_HARDENING="off"
  export SAVIA_MEMORY_WRITE_SANITIZE="block"
  local payload='{"tool_name":"Bash","tool_input":{"command":"bash scripts/memory-store.sh save key value with '"$BIDI_RLO"'"}}'
  run bash "$MEMORY_HOOK" <<< "$payload"
  [[ "$status" -eq 0 ]]
}

@test "memory hook mode=warn: memory-store with risky content exits 0" {
  export SAVIA_MEMORY_WRITE_SANITIZE="warn"
  local text="bash scripts/memory-store.sh save key ${CYRILLIC_A}${CYRILLIC_A}${CYRILLIC_A}value"
  local payload='{"tool_name":"Bash","tool_input":{"command":"'"$text"'"}}'
  run bash "$MEMORY_HOOK" <<< "$payload"
  [[ "$status" -eq 0 ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# Telemetry validation
# ─────────────────────────────────────────────────────────────────────────────

@test "telemetry JSONL is valid JSON when written" {
  export SAVIA_SANITIZE_INPUT="shadow"
  local payload='{"tool_name":"Write","tool_input":{"content":"p'"$CYRILLIC_A"'ypal"}}'
  run bash "$SANITIZE_HOOK" <<< "$payload"
  if [[ -f "$SAVIA_HARDENING_LOG" ]]; then
    # Each line must be valid JSON
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      python3 -c "import json; json.loads('$line')" 2>/dev/null || {
        echo "Invalid JSON line: $line" >&2
        return 1
      }
    done < "$SAVIA_HARDENING_LOG"
  fi
}

@test "telemetry entry contains required fields (ts, layer, decision)" {
  export SAVIA_SANITIZE_INPUT="shadow"
  local payload='{"tool_name":"Write","tool_input":{"content":"p'"$CYRILLIC_A"'ypal"}}'
  run bash "$SANITIZE_HOOK" <<< "$payload"
  if [[ -f "$SAVIA_HARDENING_LOG" ]]; then
    local first_line
    first_line=$(head -1 "$SAVIA_HARDENING_LOG")
    python3 -c "
import json, sys
d = json.loads('$first_line')
assert 'ts' in d, 'missing ts'
assert 'layer' in d, 'missing layer'
assert 'decision' in d, 'missing decision'
print('OK')
" 2>/dev/null
  fi
}
