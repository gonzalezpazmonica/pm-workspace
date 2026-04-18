#!/usr/bin/env bats
# Tests for SE-029-M — context distortion metric
# Ref: docs/propuestas/SE-029-rate-distortion-context.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/context-distortion-measure.sh"
  TMPDIR_CD="$(mktemp -d)"
  export TMPDIR_CD

  # Identical: compacted = original → distortion near 0
  cat > "$TMPDIR_CD/identical-orig.md" <<'F'
The user wants SPEC-120 implementation with MediatR and FluentValidation.
Laura owns PBI-001. Target coverage is eighty percent.
F
  cp "$TMPDIR_CD/identical-orig.md" "$TMPDIR_CD/identical-comp.md"

  # Lossy: high compression, low recall
  cat > "$TMPDIR_CD/lossy-orig.md" <<'F'
Long original text with many important tokens: authentication,
authorization, validation, sanitization, encryption, persistence,
repository, mediator, handler, command, query, event, projection,
aggregate, entity, valueobject, domain, application, infrastructure.
F
  cat > "$TMPDIR_CD/lossy-comp.md" <<'F'
short.
F

  # Task-anchored: compacted preserves anchors
  cat > "$TMPDIR_CD/anchored-orig.md" <<'F'
Implement SPEC-120 spec-kit alignment. Laura owns PBI-001.
Uses MediatR handler. Target: eighty percent coverage.
F
  cat > "$TMPDIR_CD/anchored-comp.md" <<'F'
SPEC-120. Laura PBI-001. MediatR.
F
}

teardown() {
  rm -rf "$TMPDIR_CD" 2>/dev/null || true
}

# ── Safety ───────────────────────────────────────────────────────────────────

@test "safety: script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "safety: script has set -uo pipefail" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "safety: script references SE-029" {
  grep -q "SE-029" "$SCRIPT"
}

# ── Positive ─────────────────────────────────────────────────────────────────

@test "positive: --help returns exit 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
}

@test "positive: identical files produce very low distortion" {
  run bash "$SCRIPT" --original "$TMPDIR_CD/identical-orig.md" --compacted "$TMPDIR_CD/identical-comp.md" --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['token_recall'] > 0.9, f\"recall was {d['token_recall']}\"
assert d['distortion'] < 0.1, f\"distortion was {d['distortion']}\"
assert d['verdict'] == 'HIGH_QUALITY', f\"verdict was {d['verdict']}\"
"
}

@test "positive: JSON output contains all required fields" {
  run bash "$SCRIPT" --original "$TMPDIR_CD/identical-orig.md" --compacted "$TMPDIR_CD/identical-comp.md" --json
  echo "$output" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for k in ['ratio','distortion','token_recall','anchor_coverage','verdict','original_bytes','compacted_bytes']:
    assert k in d, f'missing field: {k}'
"
}

@test "positive: anchors preserved → anchor_coverage == 1.0" {
  run bash "$SCRIPT" --original "$TMPDIR_CD/anchored-orig.md" --compacted "$TMPDIR_CD/anchored-comp.md" --task-anchors "SPEC-120,PBI-001,MediatR" --json
  echo "$output" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['anchor_coverage'] == 1.0, f\"coverage was {d['anchor_coverage']}\"
"
}

@test "positive: compression ratio calculated correctly" {
  run bash "$SCRIPT" --original "$TMPDIR_CD/lossy-orig.md" --compacted "$TMPDIR_CD/lossy-comp.md" --json
  echo "$output" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['ratio'] > 5, f'expected high ratio, got {d[\"ratio\"]}'
"
}

# ── Negative ─────────────────────────────────────────────────────────────────

@test "negative: missing --original rejected with exit 2" {
  run bash "$SCRIPT" --compacted "$TMPDIR_CD/identical-comp.md"
  [ "$status" -eq 2 ]
}

@test "negative: missing --compacted rejected with exit 2" {
  run bash "$SCRIPT" --original "$TMPDIR_CD/identical-orig.md"
  [ "$status" -eq 2 ]
}

@test "negative: nonexistent --original rejected" {
  run bash "$SCRIPT" --original "/nonexistent/file.md" --compacted "$TMPDIR_CD/identical-comp.md"
  [ "$status" -eq 2 ]
}

@test "negative: nonexistent --compacted rejected" {
  run bash "$SCRIPT" --original "$TMPDIR_CD/identical-orig.md" --compacted "/nonexistent/file.md"
  [ "$status" -eq 2 ]
}

@test "negative: unknown flag rejected" {
  run bash "$SCRIPT" --bogus-flag
  [ "$status" -eq 2 ]
}

# ── Edge cases ───────────────────────────────────────────────────────────────

@test "edge: lossy compression produces HIGH distortion" {
  run bash "$SCRIPT" --original "$TMPDIR_CD/lossy-orig.md" --compacted "$TMPDIR_CD/lossy-comp.md" --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['distortion'] > 0.3, f\"expected high distortion, got {d['distortion']}\"
assert d['verdict'] == 'UNACCEPTABLE', f\"verdict was {d['verdict']}\"
"
}

@test "edge: distortion formula uses 0.4*recall + 0.6*anchor" {
  # With anchor_cov=1.0 and recall=0.5, D = 1 - (0.4*0.5 + 0.6*1.0) = 0.2
  # Use anchored fixtures
  run bash "$SCRIPT" --original "$TMPDIR_CD/anchored-orig.md" --compacted "$TMPDIR_CD/anchored-comp.md" --task-anchors "SPEC-120,PBI-001,MediatR" --json
  echo "$output" | python3 -c "
import json,sys
d=json.load(sys.stdin)
# recall * 0.4 + anchor * 0.6 should equal 1 - distortion
expected = d['token_recall'] * 0.4 + d['anchor_coverage'] * 0.6
delta = abs((1 - d['distortion']) - expected)
assert delta < 0.001, f\"formula mismatch: {delta}\"
"
}

@test "edge: empty anchors list → anchor_coverage = 1.0 (neutral)" {
  run bash "$SCRIPT" --original "$TMPDIR_CD/identical-orig.md" --compacted "$TMPDIR_CD/identical-comp.md" --json
  echo "$output" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['anchor_coverage'] == 1.0
"
}

@test "edge: verdict thresholds (0.15, 0.30) documented in script" {
  grep -q "0.15" "$SCRIPT"
  grep -q "0.30" "$SCRIPT"
}

# ── Isolation ────────────────────────────────────────────────────────────────

@test "isolation: does not modify input files" {
  h1=$(sha256sum "$TMPDIR_CD/identical-orig.md" | awk '{print $1}')
  bash "$SCRIPT" --original "$TMPDIR_CD/identical-orig.md" --compacted "$TMPDIR_CD/identical-comp.md" --json >/dev/null 2>&1
  h2=$(sha256sum "$TMPDIR_CD/identical-orig.md" | awk '{print $1}')
  [ "$h1" = "$h2" ]
}

@test "isolation: all exit codes well-defined" {
  run bash "$SCRIPT" --original "$TMPDIR_CD/identical-orig.md" --compacted "$TMPDIR_CD/identical-comp.md"
  [[ "$status" == "0" || "$status" == "2" ]]
}
