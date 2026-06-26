#!/usr/bin/env bats
# tests/bats/test-se-075-kokoro.bats — SE-075 Slice 3
# BATS tests for Kokoro CPU TTS integration.
# >= 5 tests required.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
KOKORO_PY="$REPO_ROOT/scripts/savia-kokoro.py"
SPEAK_SH="$REPO_ROOT/scripts/savia-voice-speak.sh"
PROTOCOL_MD="$REPO_ROOT/docs/rules/domain/kokoro-voice-protocol.md"
TELEMETRY_FILE="$REPO_ROOT/output/kokoro-telemetry.jsonl"

# ── Test 1: savia-kokoro.py exists and produces JSON ─────────────────────────
@test "SE-075 AC-09: savia-kokoro.py exists and produces valid JSON" {
  python3 -c "import kokoro" 2>/dev/null || skip "kokoro not installed in CI"
  [ -f "$KOKORO_PY" ]
  local out
  out="$(mktemp /tmp/bats-kokoro-XXXXXX.wav)"
  run python3 "$KOKORO_PY" --text "Hola" --output "$out" --json
  [ "$status" -eq 0 ]
  # stdout must contain a JSON object (last JSON line)
  local json_line
  json_line="$(echo "$output" | grep -E '^\{' | tail -1)"
  [ -n "$json_line" ]
  # parse JSON and check required fields
  echo "$json_line" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert 'file' in d, 'missing file'
assert 'duration_s' in d, 'missing duration_s'
assert 'voice' in d, 'missing voice'
assert 'lang' in d, 'missing lang'
assert d['duration_s'] > 0, 'duration_s must be > 0'
"
  rm -f "$out"
}

# ── Test 2: savia-voice-speak.sh exists and is executable ────────────────────
@test "SE-075 AC-10: savia-voice-speak.sh exists and is executable" {
  [ -f "$SPEAK_SH" ]
  [ -x "$SPEAK_SH" ]
}

# ── Test 3: SAVIA_VOICE=off → no reproduction, exit 0 ───────────────────────
@test "SE-075 AC-11: SAVIA_VOICE=off exits 0 without synthesizing" {
  run env SAVIA_VOICE=off bash "$SPEAK_SH" "Texto de prueba"
  [ "$status" -eq 0 ]
  # Should print the disabled message, NOT a wav path
  echo "$output" | grep -qi "off\|disabled"
  # No wav should have been written to /tmp with this specific text
  local hash
  hash="$(printf '%s' "Texto de pruebaef_doraes" | sha256sum | cut -c1-12)"
  [ ! -f "/tmp/savia-voice-${hash}.wav" ]
}

# ── Test 4: protocol.md exists and has required sections ─────────────────────
@test "SE-075 AC-12: kokoro-voice-protocol.md exists with required sections" {
  [ -f "$PROTOCOL_MD" ]
  grep -q "ef_dora"   "$PROTOCOL_MD"
  grep -q "em_alex"   "$PROTOCOL_MD"
  grep -q "af_heart"  "$PROTOCOL_MD"
  grep -q "SAVIA_VOICE" "$PROTOCOL_MD"
  grep -q "local"     "$PROTOCOL_MD"
}

# ── Test 5: telemetry JSONL is valid after synthesis ─────────────────────────
@test "SE-075: telemetry JSONL written and parseable after synthesis" {
  python3 -c "import kokoro" 2>/dev/null || skip "kokoro not installed in CI"
  local out tel_tmp
  out="$(mktemp /tmp/bats-kokoro-tel-XXXXXX.wav)"

  # Run synthesis (appends to real telemetry or a temp copy)
  run python3 "$KOKORO_PY" --text "Prueba telemetría" --output "$out"
  [ "$status" -eq 0 ]

  # Telemetry file must exist and last line must be valid JSON with ok=true
  [ -f "$TELEMETRY_FILE" ]
  local last_line
  last_line="$(tail -1 "$TELEMETRY_FILE")"
  [ -n "$last_line" ]
  echo "$last_line" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert 'ts' in d,       'missing ts'
assert 'voice' in d,    'missing voice'
assert 'lang' in d,     'missing lang'
assert 'duration_s' in d, 'missing duration_s'
assert 'chars' in d,    'missing chars'
assert 'ok' in d,       'missing ok'
assert d['ok'] == True, 'ok must be True'
"
  rm -f "$out"
}

# ── Test 6: savia-voice-chunk.sh uses kokoro when available ──────────────────
@test "SE-075: savia-voice-chunk.sh includes kokoro fallback logic" {
  local chunk_sh="$REPO_ROOT/scripts/savia-voice-chunk.sh"
  [ -f "$chunk_sh" ]
  grep -q "kokoro" "$chunk_sh"
  grep -q "savia-kokoro.py" "$chunk_sh"
}
