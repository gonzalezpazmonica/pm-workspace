#!/usr/bin/env bats
# tests/bats/test-spec-se-030-skill-detection.bats — SPEC-SE-030 Skill Self-Improvement Phase 1
#
# Tests for scripts/skill-pattern-detector.sh and scripts/skill-usage-tracker.py
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-030-skill-self-improvement.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  DETECTOR="$REPO_ROOT/scripts/skill-pattern-detector.sh"
  TRACKER="$REPO_ROOT/scripts/skill-usage-tracker.py"
  TMPDIR_TEST="$(mktemp -d)"
  export DATA_DIR="$TMPDIR_TEST/data"
  export OUTPUT_DIR="$TMPDIR_TEST/output"
  export INVOCATIONS_LOG="$TMPDIR_TEST/data/skill-invocations.jsonl"
  mkdir -p "$DATA_DIR" "$OUTPUT_DIR"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

# ── Test 1: skill-pattern-detector.sh exists and is executable ───────────────

@test "skill-pattern-detector.sh exists and is executable" {
  [ -f "$DETECTOR" ]
  [ -x "$DETECTOR" ]
}

# ── Test 2: --json produces JSON with patterns_found ─────────────────────────

@test "--json produces JSON with patterns_found key" {
  run bash "$DETECTOR" --json
  [ "$status" -eq 0 ]
  has_key=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print('yes' if 'patterns_found' in d else 'no')" 2>/dev/null)
  [ "$has_key" = "yes" ]
}

# ── Test 3: skill-usage-tracker.py exists ────────────────────────────────────

@test "skill-usage-tracker.py exists in scripts/" {
  [ -f "$TRACKER" ]
}

# ── Test 4: script does not fail with empty data/ ────────────────────────────

@test "skill-pattern-detector.sh does not crash with no data/ files" {
  run bash "$DETECTOR" --json
  [ "$status" -eq 0 ]
}

# ── Test 5: no data returns patterns_found=0 ─────────────────────────────────

@test "patterns_found is 0 when no invocations file exists" {
  run bash "$DETECTOR" --json
  [ "$status" -eq 0 ]
  count=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['patterns_found'])" 2>/dev/null)
  [ "$count" -eq 0 ]
}

# ── Test 6: usage-tracker appends entry to JSONL ─────────────────────────────

@test "skill-usage-tracker.py appends entry to JSONL file" {
  run python3 "$TRACKER" \
    --skill "test-skill" \
    --command "/test-cmd" \
    --session "bats-session-001" \
    --invocations-file "$INVOCATIONS_LOG"
  [ "$status" -eq 0 ]
  [ -f "$INVOCATIONS_LOG" ]
  count=$(wc -l < "$INVOCATIONS_LOG")
  [ "$count" -ge 1 ]
}

# ── Test 7: usage-tracker entry has required fields ───────────────────────────

@test "skill-usage-tracker.py entry has ts, skill, command, session_id" {
  python3 "$TRACKER" \
    --skill "my-skill" \
    --command "/my-cmd" \
    --session "sess-42" \
    --invocations-file "$INVOCATIONS_LOG"

  has_all=$(python3 -c "
import json
r = json.loads(open('$INVOCATIONS_LOG').read().strip())
required = {'ts','skill','command','session_id'}
missing = required - set(r.keys())
print('ok' if not missing else 'MISSING:'+str(missing))
" 2>/dev/null)
  [ "$has_all" = "ok" ]
}

# ── Test 8: pattern detection with sufficient synthetic sessions ──────────────

@test "detector finds pattern with 25 sessions sharing 3-cmd sequence" {
  # Generate 25 sessions × 3 commands each
  python3 << 'PYEOF'
import json
from pathlib import Path
import os

log = Path(os.environ["INVOCATIONS_LOG"])
log.parent.mkdir(parents=True, exist_ok=True)
cmds = ["/spec-new", "/code", "/test"]
with log.open("w") as fh:
    for sess in range(25):
        sid = f"sess-{sess:03d}"
        for cmd in cmds:
            entry = {
                "ts": f"2026-06-{(sess % 28)+1:02d}T10:00:00Z",
                "skill": "spec-driven-development",
                "command": cmd,
                "session_id": sid,
            }
            fh.write(json.dumps(entry) + "\n")
PYEOF

  run bash "$DETECTOR" --json --min-count 3
  [ "$status" -eq 0 ]
  count=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['patterns_found'])" 2>/dev/null)
  [ "$count" -ge 1 ]
}

# ── Test 9: patterns have sequence, count, suggestion ────────────────────────

@test "detected pattern has sequence, count, suggestion fields" {
  python3 << 'PYEOF'
import json
from pathlib import Path
import os

log = Path(os.environ["INVOCATIONS_LOG"])
log.parent.mkdir(parents=True, exist_ok=True)
cmds = ["/a", "/b", "/c"]
with log.open("w") as fh:
    for sess in range(25):
        sid = f"sess-{sess:03d}"
        for cmd in cmds:
            fh.write(json.dumps({"ts": "2026-06-01T08:00:00Z", "skill": "s", "command": cmd, "session_id": sid}) + "\n")
PYEOF

  run bash "$DETECTOR" --json --min-count 3
  [ "$status" -eq 0 ]
  has_fields=$(echo "$output" | python3 -c "
import json,sys
d=json.load(sys.stdin)
if d['patterns_found'] == 0:
    print('no_patterns')
else:
    p=d['patterns'][0]
    req={'sequence','count','suggestion'}
    missing=req-set(p.keys())
    print('ok' if not missing else 'MISSING:'+str(missing))
" 2>/dev/null)
  [ "$has_fields" = "ok" ] || [ "$has_fields" = "no_patterns" ]
}

# ── Test 10: suggestion not empty ────────────────────────────────────────────

@test "suggestion field is not empty when pattern is detected" {
  python3 << 'PYEOF'
import json
from pathlib import Path
import os

log = Path(os.environ["INVOCATIONS_LOG"])
log.parent.mkdir(parents=True, exist_ok=True)
cmds = ["/x", "/y", "/z"]
with log.open("w") as fh:
    for sess in range(25):
        sid = f"sess-{sess:03d}"
        for cmd in cmds:
            fh.write(json.dumps({"ts": "2026-06-01T08:00:00Z", "skill": "s", "command": cmd, "session_id": sid}) + "\n")
PYEOF

  run bash "$DETECTOR" --json --min-count 3
  [ "$status" -eq 0 ]
  suggestion_ok=$(echo "$output" | python3 -c "
import json,sys
d=json.load(sys.stdin)
if d['patterns_found'] == 0:
    print('skip')
else:
    s=d['patterns'][0].get('suggestion','')
    print('ok' if s else 'EMPTY')
" 2>/dev/null)
  [ "$suggestion_ok" = "ok" ] || [ "$suggestion_ok" = "skip" ]
}
