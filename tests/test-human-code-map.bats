#!/usr/bin/env bats
# Ref: .claude/skills/human-code-map/SKILL.md
# Ref: docs/propuestas/SPEC-107-ai-cognitive-debt-mitigation.md
# Ref: docs/cognitive-debt-guide.md
#
# Calibración SE-376 de human-code-map. La skill es prosa (genera .hcm a mano
# con el LLM); su único ejecutable asociado es scripts/cognitive-debt.sh, la
# medición opt-in de deuda cognitiva (SPEC-107). Estos tests ejercitan su
# comportamiento real sobre settings.json y telemetría sintéticos en mktemp -d.

SCRIPT="scripts/cognitive-debt.sh"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  CD="$REPO_ROOT/$SCRIPT"
  TMP="$(mktemp -d)"
  export SAVIA_COGNITIVE_DIR="$TMP/cog dir"
  export USER="tester"
  LOG="$SAVIA_COGNITIVE_DIR/tester.jsonl"
  SET="$TMP/settings con espacios.json"
  export SAVIA_SETTINGS_OVERRIDE="$SET"
  mkdir -p "$SAVIA_COGNITIVE_DIR"
}

teardown() {
  rm -rf "$TMP"
}

# settings.json con los tres hooks de SPEC-107 tal y como están registrados
# en el workspace real, más un hook ajeno y texto no ASCII.
write_wired_settings() {
  cat > "$SET" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.opencode/hooks/cognitive-debt-hypothesis-first.sh",
            "name": "cognitive-debt-hypothesis-first"
          },
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.opencode/hooks/otro.sh",
            "statusMessage": "Validando sesión…"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write|Task",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.opencode/hooks/cognitive-debt-telemetry.sh",
            "name": "cognitive-debt-telemetry"
          }
        ]
      },
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/cognitive-debt-check.sh"
          }
        ]
      }
    ]
  }
}
JSON
}

utc_days_ago() { date -u -d "-$1 days" +%Y-%m-%dT12:00:00Z; }

# ── Contrato del script ─────────────────────────────────────────────────────

@test "script: set -uo pipefail and valid bash syntax" {
  run grep -c '^set -uo pipefail' "$CD"
  [ "$output" -ge 1 ]
  run bash -n "$CD"
  [ "$status" -eq 0 ]
}

@test "usage: --help exits 2 and does not leak shell code into the help text" {
  run bash "$CD" --help
  [ "$status" -eq 2 ]
  [[ "$output" == *"enable"* ]]
  [[ "$output" != *"set -uo pipefail"* ]]
}

@test "dispatch: unknown subcommand is rejected with exit 2" {
  run bash "$CD" bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown subcommand"* ]]
}

# ── status ──────────────────────────────────────────────────────────────────

@test "status: zero events today prints a single number, not '0\\n0'" {
  write_wired_settings
  printf '%s\n' '{"ts":"2020-01-01T00:00:00Z","tool":"Edit"}' > "$LOG"
  run bash "$CD" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Today:        0 events"* ]]
  [[ "$output" == *"Total events: 1"* ]]
}

@test "status: counts today's events by UTC date, matching the hook's UTC timestamps" {
  write_wired_settings
  local today; today=$(date -u +%Y-%m-%d)
  printf '{"ts":"%sT00:30:00Z","tool":"Edit"}\n{"ts":"%sT23:30:00Z","tool":"Write"}\n' \
    "$today" "$today" > "$LOG"
  run bash "$CD" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Today:        2 events"* ]]
}

@test "status: settings with the telemetry hook wired reports ENABLED" {
  write_wired_settings
  run bash "$CD" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"State:        ENABLED"* ]]
  [[ "$output" != *"DISABLED"* ]]
}

@test "status: empty settings without hook reports DISABLED (opt-in)" {
  echo '{"hooks":{}}' > "$SET"
  run bash "$CD" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"DISABLED"* ]]
}

# ── disable ─────────────────────────────────────────────────────────────────

@test "disable: removes only telemetry and hypothesis-first, keeps cognitive-debt-check.sh" {
  write_wired_settings
  run bash "$CD" disable
  [ "$status" -eq 0 ]
  run grep -c 'cognitive-debt-check.sh' "$SET"
  [ "$output" -eq 1 ]
  run grep -c 'cognitive-debt-telemetry.sh\|cognitive-debt-hypothesis-first.sh' "$SET"
  [ "$output" -eq 0 ]
  run grep -c 'otro.sh' "$SET"
  [ "$output" -eq 1 ]
}

@test "disable: preserves non-ASCII text verbatim (no \\u escapes)" {
  write_wired_settings
  run bash "$CD" disable
  [ "$status" -eq 0 ]
  run grep -c 'Validando sesión…' "$SET"
  [ "$output" -eq 1 ]
  run grep -c '\\u00f3' "$SET"
  [ "$output" -eq 0 ]
}

@test "disable: invalid JSON fails with error and leaves settings untouched" {
  printf '%s\n' '{"hooks": cognitive-debt-telemetry.sh' > "$SET"
  cp "$SET" "$TMP/orig"
  run bash "$CD" disable
  [ "$status" -ne 0 ]
  [[ "$output" == *"ERROR"* ]]
  [[ "$output" != *"Cognitive Debt disabled"* ]]
  cmp "$SET" "$TMP/orig"
}

# ── enable ──────────────────────────────────────────────────────────────────

@test "enable: invalid JSON is rejected, no false success and no backup left" {
  printf '%s\n' '{bad' > "$SET"
  run bash "$CD" enable
  [ "$status" -ne 0 ]
  [[ "$output" == *"ERROR"* ]]
  [[ "$output" != *"Cognitive Debt enabled"* ]]
  run bash -c "ls \"$TMP\" | grep -c '\.bak\.'"
  [ "$output" -eq 0 ]
}

@test "enable: wires hooks with the workspace shape (quoted path, non-blocking, timeout)" {
  echo '{"hooks":{}}' > "$SET"
  run bash "$CD" enable
  [ "$status" -eq 0 ]
  run python3 - "$SET" <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1]))
want = {
    "PostToolUse": ("Edit|Write|Task", "cognitive-debt-telemetry"),
    "PreToolUse": ("Edit|Write", "cognitive-debt-hypothesis-first"),
}
for event, (matcher, name) in want.items():
    entry = [e for e in cfg["hooks"][event] if e["matcher"] == matcher][0]
    h = [h for h in entry["hooks"] if h.get("name") == name][0]
    assert h["command"] == f'bash "$CLAUDE_PROJECT_DIR"/.opencode/hooks/{name}.sh', h
    assert h["blocking"] is False and 0 < h["timeout"] <= 3, h
print("shape-ok")
PY
  [ "$status" -eq 0 ]
  [[ "$output" == *"shape-ok"* ]]
}

@test "enable: settings symlink is followed — target updated, link kept" {
  echo '{"hooks":{}}' > "$TMP/real.json"
  ln -s "$TMP/real.json" "$TMP/link.json"
  SAVIA_SETTINGS_OVERRIDE="$TMP/link.json" run bash "$CD" enable
  [ "$status" -eq 0 ]
  [ -L "$TMP/link.json" ]
  run grep -c 'cognitive-debt-telemetry.sh' "$TMP/real.json"
  [ "$output" -eq 1 ]
}

@test "enable: preserves the settings file mode (0644, not mkstemp 0600)" {
  echo '{"hooks":{}}' > "$SET"
  chmod 644 "$SET"
  run bash "$CD" enable
  [ "$status" -eq 0 ]
  [ "$(stat -c %a "$SET")" = "644" ]
}

@test "enable: missing settings file errors out with exit 5" {
  run bash "$CD" enable
  [ "$status" -eq 5 ]
  [[ "$output" == *"not found"* ]]
}

@test "enable then disable: round trip wires both hooks and keeps other content byte-identical" {
  write_wired_settings
  bash "$CD" disable >/dev/null
  cp "$SET" "$TMP/after-disable"
  run bash "$CD" enable
  [ "$status" -eq 0 ]
  run grep -c 'cognitive-debt-telemetry.sh' "$SET"
  [ "$output" -eq 1 ]
  run grep -c 'cognitive-debt-hypothesis-first.sh' "$SET"
  [ "$output" -eq 1 ]
  run bash "$CD" enable
  [[ "$output" == *"Already enabled"* ]]
  bash "$CD" disable >/dev/null
  cmp "$SET" "$TMP/after-disable"
}

# ── summary ─────────────────────────────────────────────────────────────────

@test "summary: events without duration are excluded from the fast-accept ratio (null and missing)" {
  printf '{"ts":"%s","tool":"Edit"}\n{"ts":"%s","tool":"Edit","duration_ms":null}\n' \
    "$(utc_days_ago 0)" "$(utc_days_ago 0)" > "$LOG"
  run bash "$CD" summary
  [ "$status" -eq 0 ]
  [[ "$output" == *"Total events (last 7d):  2"* ]]
  [[ "$output" == *"Fast-accept ratio:       n/a"* ]]
}

@test "summary: ratio uses only timed events (1 fast of 2 timed = 50%)" {
  printf '{"ts":"%s","duration_ms":1200}\n{"ts":"%s","duration_ms":9000}\n{"ts":"%s"}\n' \
    "$(utc_days_ago 0)" "$(utc_days_ago 1)" "$(utc_days_ago 2)" > "$LOG"
  run bash "$CD" summary
  [ "$status" -eq 0 ]
  [[ "$output" == *"Total events (last 7d):  3"* ]]
  [[ "$output" == *"Fast-accept ratio:       50%"* ]]
  [[ "$output" == *"timed events: 2"* ]]
}

@test "summary: boundary — 4999 ms is fast, 5000 ms is not, boolean is not a duration" {
  printf '{"ts":"%s","duration_ms":4999}\n{"ts":"%s","duration_ms":5000}\n{"ts":"%s","duration_ms":true}\n' \
    "$(utc_days_ago 0)" "$(utc_days_ago 0)" "$(utc_days_ago 0)" > "$LOG"
  run bash "$CD" summary
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fast-accept ratio:       50%"* ]]
  [[ "$output" == *"timed events: 2"* ]]
}

@test "summary: boundary — window is 7 days including today, day -7 excluded" {
  printf '{"ts":"%s","duration_ms":9000}\n{"ts":"%s","duration_ms":9000}\n' \
    "$(utc_days_ago 6)" "$(utc_days_ago 7)" > "$LOG"
  run bash "$CD" summary
  [ "$status" -eq 0 ]
  [[ "$output" == *"Total events (last 7d):  1"* ]]
}

@test "summary: malformed and non-object lines are skipped, not fatal" {
  printf '%s\n' 'not-json{' '[]' '42' "{\"ts\":\"$(utc_days_ago 0)\",\"duration_ms\":\"abc\"}" > "$LOG"
  run bash "$CD" summary
  [ "$status" -eq 0 ]
  [[ "$output" == *"Total events (last 7d):  1"* ]]
  [[ "$output" == *"n/a"* ]]
}

@test "summary: missing log exits 0 with a no-data message (null input)" {
  run bash "$CD" summary
  [ "$status" -eq 0 ]
  [[ "$output" == *"No telemetry data yet"* ]]
}

@test "summary: empty log reports zero events" {
  : > "$LOG"
  run bash "$CD" summary
  [ "$status" -eq 0 ]
  [[ "$output" == *"Total events (last 7d):  0"* ]]
}

@test "summary: large log (5000 events) aggregates exactly" {
  local ts; ts=$(utc_days_ago 0)
  for i in $(seq 1 5000); do printf '{"ts":"%s","duration_ms":100}\n' "$ts"; done > "$LOG"
  run bash "$CD" summary
  [ "$status" -eq 0 ]
  [[ "$output" == *"Total events (last 7d):  5000"* ]]
  [[ "$output" == *"Fast-accept ratio:       100%"* ]]
}

@test "summary: es_ES locale does not change the integer percentage output" {
  printf '{"ts":"%s","duration_ms":100}\n{"ts":"%s","duration_ms":9000}\n{"ts":"%s","duration_ms":9000}\n' \
    "$(utc_days_ago 0)" "$(utc_days_ago 0)" "$(utc_days_ago 0)" > "$LOG"
  LC_ALL=es_ES.UTF-8 run bash "$CD" summary
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fast-accept ratio:       33%"* ]]
}

# ── forget ──────────────────────────────────────────────────────────────────

@test "forget: refuses without --confirm and keeps the log" {
  printf '%s\n' '{"ts":"2026-01-01T00:00:00Z"}' > "$LOG"
  run bash "$CD" forget
  [ "$status" -eq 2 ]
  [ -f "$LOG" ]
}

@test "forget: --confirm wipes the log in a path with spaces" {
  printf '%s\n' '{"ts":"2026-01-01T00:00:00Z"}' > "$LOG"
  run bash "$CD" forget --confirm
  [ "$status" -eq 0 ]
  [ ! -f "$LOG" ]
}

@test "forget: unknown flag is rejected (invalid arg)" {
  run bash "$CD" forget --yes
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown arg"* ]]
}
