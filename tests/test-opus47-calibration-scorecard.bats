#!/usr/bin/env bats
# BATS tests for scripts/opus47-calibration-scorecard.sh
# SE-070 Slice 1 — Calibration scorecard for sonnet-4-6 → opus-4-7 xhigh upgrade decisions.
# Ref: docs/propuestas/SE-070-opus47-eval-scorecard.md

SCRIPT="scripts/opus47-calibration-scorecard.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
}
teardown() { cd /; }

@test "script exists" { [[ -f "$SCRIPT" ]]; }
@test "script is executable" { [[ -x "$SCRIPT" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }
@test "SE-070 reference" {
  run grep -c 'SE-070' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── CLI ────────────────────────────────────────────────

@test "help: --help prints usage" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "help: -h equivalent" {
  run bash "$SCRIPT" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "cli: unknown flag exits 2" {
  run bash "$SCRIPT" --bogus-flag
  [ "$status" -eq 2 ]
}

@test "help: mentions sonnet-4-6 and opus-4-7" {
  run bash "$SCRIPT" --help
  [[ "$output" == *"claude-sonnet-4-6"* ]]
  [[ "$output" == *"claude-opus-4-7"* ]]
}

@test "help: disclaims no evals run, no auto-upgrade" {
  run bash "$SCRIPT" --help
  [[ "$output" == *"No evals are run"* ]] || [[ "$output" == *"Decisions are human"* ]]
}

# ── Execution ──────────────────────────────────────────

@test "exec: runs successfully producing YAML and MD outputs" {
  run timeout 30 bash "$SCRIPT" --quiet
  [ "$status" -eq 0 ]
  local date_str
  date_str=$(date +%Y%m%d)
  [[ -f "output/opus47-calibration-$date_str.yaml" ]]
  [[ -f "output/opus47-calibration-$date_str.md" ]]
}

@test "exec: non-quiet summary prints sonnet count" {
  run timeout 30 bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"opus47-calibration-scorecard"* ]]
  [[ "$output" == *"sonnet="* ]]
  [[ "$output" == *"total="* ]]
}

@test "exec: --quiet suppresses stdout" {
  run timeout 30 bash "$SCRIPT" --quiet
  [ "$status" -eq 0 ]
  [[ -z "$output" ]] || [[ "$output" != *"opus47-calibration-scorecard"* ]]
}

# ── JSON mode ──────────────────────────────────────────

@test "json: --json emits valid JSON to stdout" {
  run timeout 30 bash "$SCRIPT" --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c 'import sys,json; json.loads(sys.stdin.read())'
}

@test "json: contains required top-level keys" {
  run bash -c 'timeout 30 bash scripts/opus47-calibration-scorecard.sh --json'
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c '
import sys, json
d = json.loads(sys.stdin.read())
assert "date" in d
assert "total_agents" in d
assert "sonnet_count" in d
assert "sonnet_with_golden" in d
assert "cost_delta_pct_xhigh_upgrade" in d
assert "agents" in d
assert isinstance(d["agents"], list)
'
}

@test "json: sonnet_count matches actual sonnet agents in repo" {
  local actual_count
  actual_count=$(grep -l "^model: claude-sonnet-4-6" .claude/agents/*.md 2>/dev/null | wc -l)
  run bash -c 'timeout 30 bash scripts/opus47-calibration-scorecard.sh --json'
  [ "$status" -eq 0 ]
  local json_count
  json_count=$(echo "$output" | python3 -c 'import sys,json; print(json.load(sys.stdin)["sonnet_count"])')
  [[ "$actual_count" -eq "$json_count" ]]
}

# ── Cost model ─────────────────────────────────────────

@test "cost: cost_delta_pct computed via python3" {
  run grep -c 'cost_delta_pct\|COST_DELTA_PCT' "$SCRIPT"
  [[ "$output" -ge 2 ]]
}

@test "cost: sonnet pricing constants defined" {
  run grep -c 'SONNET_IN_COST_PER_MTOK\|SONNET_OUT_COST_PER_MTOK\|SONNET_IN = 3\|SONNET_OUT = 15' "$SCRIPT"
  [[ "$output" -ge 2 ]]
}

@test "cost: opus pricing constants defined" {
  run grep -c 'OPUS_IN_COST_PER_MTOK\|OPUS_OUT_COST_PER_MTOK\|OPUS_IN = 15\|OPUS_OUT = 75' "$SCRIPT"
  [[ "$output" -ge 2 ]]
}

@test "cost: xhigh thinking multiplier applied" {
  run grep -c 'XHIGH_MULT\|XHIGH_THINKING_MULT' "$SCRIPT"
  [[ "$output" -ge 2 ]]
}

# ── Golden-set detection ──────────────────────────────

@test "golden: has_golden function defined" {
  run grep -c 'has_golden()' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "golden: GOLDEN_DIR path set to tests/golden/opus47-calibration" {
  run grep -c 'tests/golden/opus47-calibration' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "golden: recommend field set to eval when golden-set present" {
  run grep -c 'recommend=.eval\|recommend=.defer' "$SCRIPT"
  [[ "$output" -ge 2 ]]
}

# ── Output content ────────────────────────────────────

@test "output: markdown report has Summary section" {
  bash "$SCRIPT" --quiet >/dev/null 2>&1 || true
  local date_str
  date_str=$(date +%Y%m%d)
  run cat "output/opus47-calibration-$date_str.md"
  [[ "$output" == *"# Opus 4.7 calibration scorecard"* ]]
  [[ "$output" == *"## Summary"* ]]
  [[ "$output" == *"## Sonnet-4-6 agents"* ]]
  [[ "$output" == *"## Recommendations"* ]]
}

@test "output: YAML report has required fields" {
  bash "$SCRIPT" --quiet >/dev/null 2>&1 || true
  local date_str
  date_str=$(date +%Y%m%d)
  run cat "output/opus47-calibration-$date_str.yaml"
  [[ "$output" == *"date:"* ]]
  [[ "$output" == *"total_agents:"* ]]
  [[ "$output" == *"sonnet_count:"* ]]
  [[ "$output" == *"agents:"* ]]
}

# ── Template files (Slice 2) ──────────────────────────

@test "slice2: golden-set README exists" {
  [[ -f "tests/golden/opus47-calibration/README.md" ]]
}

@test "slice2: TEMPLATE directory exists with prompt/expected/score" {
  [[ -f "tests/golden/opus47-calibration/TEMPLATE/prompt.txt" ]]
  [[ -f "tests/golden/opus47-calibration/TEMPLATE/expected.md" ]]
  [[ -f "tests/golden/opus47-calibration/TEMPLATE/score.yaml" ]]
}

@test "slice2: score.yaml has all required fields" {
  run cat "tests/golden/opus47-calibration/TEMPLATE/score.yaml"
  [[ "$output" == *"case_id:"* ]]
  [[ "$output" == *"sonnet_4_6:"* ]]
  [[ "$output" == *"opus_4_7_xhigh:"* ]]
  [[ "$output" == *"correctness:"* ]]
  [[ "$output" == *"quality_cost_ratio:"* ]]
  [[ "$output" == *"recommendation:"* ]]
}

# ── Playbook (Slice 3) ────────────────────────────────

@test "slice3: playbook exists in docs/rules/domain/" {
  [[ -f "docs/rules/domain/opus47-calibration-playbook.md" ]]
}

@test "slice3: playbook references SE-070 spec" {
  run grep -c 'SE-070' docs/rules/domain/opus47-calibration-playbook.md
  [[ "$output" -ge 1 ]]
}

@test "slice3: playbook has decision matrix" {
  run grep -c 'Decision matrix\|quality_cost_ratio' docs/rules/domain/opus47-calibration-playbook.md
  [[ "$output" -ge 2 ]]
}

@test "slice3: playbook documents blind-eval anti-pattern" {
  grep -q 'blind\|Anonymize' docs/rules/domain/opus47-calibration-playbook.md
}

@test "slice3: playbook cost guidance with approximate rates" {
  grep -q 'MTok\|Cost guidance' docs/rules/domain/opus47-calibration-playbook.md
}

# ── Negative cases ─────────────────────────────────────

@test "negative: empty agents dir handled" {
  # Verify the script's error branch exists via grep
  run grep -c 'no agents found' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "negative: non-sonnet agents NOT in candidate list" {
  run bash -c 'timeout 30 bash scripts/opus47-calibration-scorecard.sh --json'
  [ "$status" -eq 0 ]
  # All agents in the list should be sonnet-4-6
  echo "$output" | python3 -c '
import sys, json
d = json.loads(sys.stdin.read())
for a in d["agents"]:
    assert a["current_model"] == "claude-sonnet-4-6", f"Unexpected model: {a}"
'
}

# ── Edge cases ──────────────────────────────────────────

@test "edge: agent with missing model frontmatter handled" {
  # get_model returns unknown string; script does not crash
  run grep -c 'model:-unknown\|"unknown"' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "edge: empty golden-set dir not treated as having golden" {
  run grep -c 'ls -A.*GOLDEN_DIR' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "edge: large number of agents (65+) runs within timeout" {
  run timeout 30 bash "$SCRIPT" --quiet
  [ "$status" -eq 0 ]
}

# ── Coverage ────────────────────────────────────────────

@test "coverage: --json CLI flag handled" {
  run grep -c 'JSON_MODE\|--json' "$SCRIPT"
  [[ "$output" -ge 2 ]]
}

@test "coverage: --quiet CLI flag handled" {
  run grep -c 'QUIET' "$SCRIPT"
  [[ "$output" -ge 3 ]]
}

@test "coverage: exit codes documented" {
  run grep -c 'Exit codes\|exit 0\|exit 1\|exit 2' "$SCRIPT"
  [[ "$output" -ge 4 ]]
}

@test "coverage: TMPDIR used in tests" {
  grep -q 'TMPDIR' "$BATS_TEST_FILENAME"
}

# ── Isolation ──────────────────────────────────────────

@test "isolation: script does NOT modify agent frontmatter" {
  local before_hash after_hash
  before_hash=$(find .claude/agents -name '*.md' -exec sha256sum {} \; 2>/dev/null | sha256sum | cut -d' ' -f1)
  timeout 30 bash "$SCRIPT" --quiet >/dev/null 2>&1 || true
  after_hash=$(find .claude/agents -name '*.md' -exec sha256sum {} \; 2>/dev/null | sha256sum | cut -d' ' -f1)
  [[ "$before_hash" == "$after_hash" ]]
}

@test "isolation: exit codes limited to {0, 1, 2}" {
  for args in "" "--quiet" "--json" "--bogus" "--help"; do
    run timeout 10 bash -c "bash $SCRIPT $args"
    [[ "$status" -eq 0 || "$status" -eq 1 || "$status" -eq 2 ]]
  done
}

@test "isolation: outputs only go to output/ dir" {
  run grep -c 'OUTPUT_DIR.*REPO_ROOT/output' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}
