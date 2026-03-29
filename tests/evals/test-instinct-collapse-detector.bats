#!/usr/bin/env bats
# Tests for SPEC-045 instinct-collapse-detector

SCRIPT="scripts/instinct-collapse-detector.sh"

setup() {
  TMPDIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "instinct-collapse-detector.sh exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "instinct-collapse-detector.sh has set -uo pipefail" {
  head -5 "$SCRIPT" | grep -q "set -uo pipefail"
}

@test "handles empty registry" {
  echo '{"version":"1.0.0","entries":[]}' > "$TMPDIR/reg.json"
  run bash "$SCRIPT" --registry "$TMPDIR/reg.json"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['total']==0"
}

@test "handles missing registry gracefully" {
  run bash "$SCRIPT" --registry "/nonexistent/reg.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "detects healthy instinct" {
  cat > "$TMPDIR/reg.json" << 'JSON'
{"version":"1.0.0","entries":[{
  "id":"test-1","pattern":"Monday = sprint","category":"workflow",
  "confidence":80,"activations":20,"enabled":true,
  "last_used":"2026-03-29T10:00:00Z","alternatives_observed":["a","b","c"],
  "silent_overrides":2,"context_at_creation":{},"context_current":{}
}]}
JSON
  run bash "$SCRIPT" --registry "$TMPDIR/reg.json"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['instincts'][0]['status'] == 'healthy', d['instincts'][0]['status']
"
}

@test "detects collapsed instinct (high AMI + CDS + PAR)" {
  cat > "$TMPDIR/reg.json" << 'JSON'
{"version":"1.0.0","entries":[{
  "id":"collapsed-1","pattern":"always X","category":"workflow",
  "confidence":93,"activations":100,"enabled":true,
  "last_used":"2026-03-29T10:00:00Z","alternatives_observed":[],
  "silent_overrides":40,
  "context_at_creation":{"role":"PM","project":"alpha","primary_mode":"daily","capability_group":"sprint","sprint_phase":"mid","team_size":"small"},
  "context_current":{"role":"PO","project":"beta","primary_mode":"reporting","capability_group":"sprint","sprint_phase":"mid","team_size":"small"}
}]}
JSON
  run bash "$SCRIPT" --registry "$TMPDIR/reg.json"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['instincts'][0]['status'] == 'collapsed', d['instincts'][0]['status']
assert d['collapsed'] == 1
"
}

@test "detects drifted instinct (high AMI + CDS, low PAR)" {
  cat > "$TMPDIR/reg.json" << 'JSON'
{"version":"1.0.0","entries":[{
  "id":"drifted-1","pattern":"always Y","category":"workflow",
  "confidence":90,"activations":50,"enabled":true,
  "last_used":"2026-03-29T10:00:00Z","alternatives_observed":[],
  "silent_overrides":5,
  "context_at_creation":{"role":"PM","project":"alpha","primary_mode":"daily","capability_group":"sprint","sprint_phase":"start","team_size":"small"},
  "context_current":{"role":"TL","project":"beta","primary_mode":"code","capability_group":"sdd","sprint_phase":"start","team_size":"small"}
}]}
JSON
  run bash "$SCRIPT" --registry "$TMPDIR/reg.json"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['instincts'][0]['status'] == 'drifted', d['instincts'][0]['status']
"
}

@test "table format works" {
  echo '{"version":"1.0.0","entries":[]}' > "$TMPDIR/reg.json"
  run bash "$SCRIPT" --registry "$TMPDIR/reg.json" --format table
  [ "$status" -eq 0 ]
  [[ "$output" == *"No instincts"* ]]
}

@test "skips disabled instincts" {
  cat > "$TMPDIR/reg.json" << 'JSON'
{"version":"1.0.0","entries":[{
  "id":"disabled-1","pattern":"X","category":"workflow",
  "confidence":90,"activations":50,"enabled":false
}]}
JSON
  run bash "$SCRIPT" --registry "$TMPDIR/reg.json"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['total']==0"
}

@test "SPEC-045 document exists" {
  [ -f "docs/propuestas/SPEC-045-exploration-collapse-detection.md" ]
}
