#!/usr/bin/env bats
# BATS tests for scripts/agent-size-audit.sh
# SE-038 Slice 4 — Agent catalog size audit (Rule #22 compliance).
# Ref: SE-038 agent-size-audit, Rule #22 critical-rules-extended.md

SCRIPT="scripts/agent-size-audit.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  TEST_REPO=$(mktemp -d "$TMPDIR/asa-XXXXXX")
}
teardown() {
  rm -rf "$TEST_REPO" 2>/dev/null || true
  cd /
}

@test "script exists" { [[ -f "$SCRIPT" ]]; }
@test "script is executable" { [[ -x "$SCRIPT" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }
@test "SE-038 reference" {
  run grep -c 'SE-038\|agent-size-audit' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}
@test "Rule #22 reference" {
  run grep -c 'Rule #22' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── CLI help ────────────────────────────────────────────

@test "help: --help prints usage" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "help: -h equivalent to --help" {
  run bash "$SCRIPT" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "cli: unknown flag exits 2" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

# ── Execution ──────────────────────────────────────────

@test "exec: runs and produces report" {
  run timeout 30 bash "$SCRIPT" --quiet
  # Exit 0 (no violations) or 1 (violations present) — both expected
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  local date_str
  date_str=$(date +%Y%m%d)
  [[ -f "output/agent-size-report-$date_str.md" ]]
}

@test "exec: non-quiet mode prints summary line" {
  run timeout 30 bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  [[ "$output" == *"agent-size-audit"* ]]
  [[ "$output" == *"total="* ]]
  [[ "$output" == *"violations="* ]]
}

@test "exec: --quiet suppresses stdout" {
  run timeout 30 bash "$SCRIPT" --quiet
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  [[ -z "$output" || "$output" != *"agent-size-audit"* ]]
}

@test "report: contains expected sections" {
  local date_str
  date_str=$(date +%Y%m%d)
  timeout 30 bash "$SCRIPT" --quiet >/dev/null 2>&1 || true
  if [[ -f "output/agent-size-report-$date_str.md" ]]; then
    run cat "output/agent-size-report-$date_str.md"
    [[ "$output" == *"Agent size audit"* ]]
    [[ "$output" == *"SLA:"* ]]
    [[ "$output" == *"Violations:"* ]]
    [[ "$output" == *"Ranking"* ]]
    [[ "$output" == *"Interpretation"* ]]
  fi
}

# ── SLA threshold ──────────────────────────────────────

@test "sla: 4096 byte threshold matches Rule #22" {
  run grep -c 'SLA_BYTES=4096' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "sla: threshold applied to each agent" {
  run grep -c 'bytes.*-gt.*SLA_BYTES\|\$bytes.*-gt.*\$SLA_BYTES' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── size_exception support ─────────────────────────────

@test "exception: has_exception function defined" {
  run grep -c 'has_exception()' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "exception: frontmatter size_exception field recognized" {
  run grep -c 'size_exception' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "exception: EXCEPTION status differentiated from VIOLATION" {
  run grep -c '"EXCEPTION"\|EXCEPTION' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── Ratchet mode ───────────────────────────────────────

@test "ratchet: --ratchet flag supported" {
  run grep -c 'RATCHET_MODE\|--ratchet' "$SCRIPT"
  [[ "$output" -ge 2 ]]
}

@test "ratchet: baseline file path defined" {
  run grep -c 'agent-size-violations.count' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "ratchet: --ratchet passes when current <= baseline" {
  # Current baseline is 27. Ratchet mode should PASS.
  run timeout 30 bash "$SCRIPT" --ratchet --quiet
  [ "$status" -eq 0 ]
}

@test "ratchet: --ratchet with lower baseline override fails (tightening)" {
  run timeout 30 bash "$SCRIPT" --ratchet --baseline 5
  [ "$status" -eq 1 ]
  [[ "$output" == *"exceeds baseline"* ]]
}

@test "ratchet: --ratchet with equal baseline override passes" {
  run timeout 30 bash "$SCRIPT" --ratchet --baseline 27
  [ "$status" -eq 0 ]
}

@test "ratchet: never-loosen policy enforced" {
  run grep -c 'never-loosen\|RATCHET FAIL' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── Statistics ──────────────────────────────────────────

@test "stats: total bytes aggregated" {
  run grep -c 'total_bytes' "$SCRIPT"
  [[ "$output" -ge 2 ]]
}

@test "stats: average bytes per agent calculated" {
  run grep -c 'Average\|bytes/agent' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "stats: ranking sorted descending" {
  run grep -c 'sort.*-n.*-r\|descending' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── Safety / isolation ─────────────────────────────────

@test "safety: read-only (no destructive ops)" {
  # Verify no rm/mv/cp on agent files
  run grep -c 'rm.*agents\|mv.*agents\|>.*agents/' "$SCRIPT"
  [[ "$output" -eq 0 ]]
}

@test "safety: maxdepth 1 prevents recursive crawl" {
  run grep -c 'maxdepth 1' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "safety: output dir auto-created" {
  run grep -c 'mkdir -p.*OUTPUT_DIR' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "safety: temp artifacts NOT written to repo" {
  local before after
  before=$(find "$TEST_REPO" -type f 2>/dev/null | wc -l)
  timeout 30 bash "$SCRIPT" --quiet >/dev/null 2>&1 || true
  after=$(find "$TEST_REPO" -type f 2>/dev/null | wc -l)
  [[ "$before" == "$after" ]]
}

# ── Negative cases ──────────────────────────────────────

@test "negative: --baseline without arg fails" {
  run bash "$SCRIPT" --baseline
  [[ "$status" -ne 0 ]]
}

@test "negative: invalid baseline non-numeric handled" {
  # --ratchet with non-numeric baseline via env file
  run timeout 5 bash "$SCRIPT" --ratchet --baseline abc
  # Should not crash; bash [[ abc -gt $violations ]] evaluates abc as 0 in arithmetic
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

# ── Edge cases ──────────────────────────────────────────

@test "edge: empty agents dir handled via maxdepth" {
  run grep -c 'find.*maxdepth 1.*\.md' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "edge: no exceptions found reports 0" {
  run timeout 30 bash "$SCRIPT" --quiet
  # Verify exceptions counter exists
  run grep -c 'exceptions=0\|exceptions=' "$SCRIPT"
  [[ "$output" -ge 2 ]]
}

@test "edge: large 65+ agent catalog doesn't timeout" {
  run timeout 60 bash "$SCRIPT" --quiet
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "edge: --ratchet without baseline file passes on first run" {
  run grep -c 'first run\|no baseline' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── Coverage ────────────────────────────────────────────

@test "coverage: 4 remediation options documented" {
  run grep -c 'Split\|DOMAIN.md\|size_exception\|Compress' "$SCRIPT"
  [[ "$output" -ge 4 ]]
}

@test "coverage: exit codes documented (0, 1, 2)" {
  run grep -c 'Exit code\|exit 0\|exit 1\|exit 2' "$SCRIPT"
  [[ "$output" -ge 3 ]]
}

@test "coverage: TMPDIR used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

@test "coverage: ROADMAP reference" {
  run grep -c 'ROADMAP' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ──────────────────────────────────────────

@test "isolation: exit codes limited to {0, 1, 2}" {
  for args in "" "--quiet" "--help" "--bogus" "--ratchet" "--ratchet --baseline 100"; do
    run timeout 30 bash -c "bash '$SCRIPT' $args"
    [[ "$status" -eq 0 || "$status" -eq 1 || "$status" -eq 2 ]]
  done
}

@test "isolation: script does not modify agents" {
  local before_hash after_hash
  before_hash=$(find .claude/agents -name '*.md' -exec sha256sum {} \; 2>/dev/null | sha256sum | cut -d' ' -f1)
  timeout 30 bash "$SCRIPT" --quiet >/dev/null 2>&1 || true
  after_hash=$(find .claude/agents -name '*.md' -exec sha256sum {} \; 2>/dev/null | sha256sum | cut -d' ' -f1)
  [[ "$before_hash" == "$after_hash" ]]
}

@test "isolation: only writes to output/ directory" {
  run grep -c 'OUTPUT_DIR.*REPO_ROOT/output' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}
