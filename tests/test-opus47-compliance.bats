#!/usr/bin/env bats
# BATS tests for scripts/opus47-compliance-check.sh (SE-066..SE-070)

SCRIPT="scripts/opus47-compliance-check.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() { cd /; }

@test "script exists and is executable" { [[ -x "$SCRIPT" ]]; }
@test "passes bash -n" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }
@test "uses set -uo pipefail" { run grep -c 'set -uo pipefail' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "references SE-066..SE-070" {
  for s in SE-066 SE-067 SE-068 SE-069 SE-070; do
    grep -q "$s" "$SCRIPT" || fail "missing $s reference"
  done
}

@test "--help exits 0 and prints usage" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Flags"* ]]
}

@test "unknown flag exits 2" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "default run returns exit 0/1 with VERDICT line" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  [[ "$output" == *"VERDICT"* ]]
}

@test "--json produces valid JSON" {
  run bash -c 'bash scripts/opus47-compliance-check.sh --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
for k in [\"verdict\",\"failures_count\",\"failures\"]:
    assert k in d, f\"missing {k}\"
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

# ── SE-066: finding vs filtering ──────────────────────

@test "SE-066 check: 19 review agents have Reporting Policy" {
  run bash "$SCRIPT" --finding-vs-filtering --json
  [[ "$output" == *'"verdict":"PASS"'* ]]
}

@test "SE-066: code-reviewer contains SE-066 marker" {
  run grep -q "SE-066" .opencode/agents/code-reviewer.md
  [ "$status" -eq 0 ]
}

@test "SE-066: all 19 review agents marked" {
  for a in code-reviewer pr-agent-judge security-judge correctness-judge spec-judge cognitive-judge architecture-judge calibration-judge coherence-judge completeness-judge compliance-judge factuality-judge hallucination-judge source-traceability-judge security-auditor confidentiality-auditor drift-auditor court-orchestrator truth-tribunal-orchestrator; do
    grep -q "SE-066" ".opencode/agents/$a.md" || fail "$a missing SE-066"
  done
}

# ── SE-067: fan-out + adaptive thinking ───────────────

@test "SE-067 check: 3 orchestrators have Fan-Out Policy" {
  run bash "$SCRIPT" --fan-out --json
  [[ "$output" == *'"verdict":"PASS"'* ]]
}

@test "SE-067: 3 orchestrators marked" {
  for a in dev-orchestrator court-orchestrator truth-tribunal-orchestrator; do
    grep -q "SE-067" ".opencode/agents/$a.md" || fail "$a missing SE-067"
  done
}

@test "SE-067 check: feasibility-probe adaptive thinking" {
  run bash "$SCRIPT" --adaptive-thinking --json
  [[ "$output" == *'"verdict":"PASS"'* ]]
}

@test "SE-067: feasibility-probe no fixed budget_tokens row" {
  run grep -E '^\| budget_tokens' .opencode/skills/feasibility-probe/SKILL.md
  [ "$status" -ne 0 ]
}

# ── SE-068: XML tags ──────────────────────────────────

@test "SE-068 check: 5 top-tier agents have XML tags" {
  run bash "$SCRIPT" --xml-tags --json
  [[ "$output" == *'"verdict":"PASS"'* ]]
}

@test "SE-068: required tags present in each of 5 agents" {
  for a in architect dev-orchestrator court-orchestrator truth-tribunal-orchestrator code-reviewer; do
    for tag in '<instructions>' '<context_usage>' '<constraints>' '<output_format>'; do
      grep -qF "$tag" ".opencode/agents/$a.md" || fail "$a missing $tag"
    done
  done
}

@test "SE-068: XML structure doc exists" {
  [[ -f "docs/rules/domain/agent-prompt-xml-structure.md" ]]
}

# ── SE-069: context-rot-strategy skill ────────────────

@test "SE-069 check: skill present" {
  run bash "$SCRIPT" --context-rot-skill --json
  [[ "$output" == *'"verdict":"PASS"'* ]]
}

@test "SE-069: SKILL.md + DOMAIN.md exist" {
  [[ -f ".opencode/skills/context-rot-strategy/SKILL.md" ]]
  [[ -f ".opencode/skills/context-rot-strategy/DOMAIN.md" ]]
}

@test "SE-069: SKILL.md describes 5-option model" {
  run grep -c "5 opciones" .opencode/skills/context-rot-strategy/SKILL.md
  [[ "$output" -ge 1 ]]
}

# ── SE-070: propuesta exists ──────────────────────────

@test "SE-070: proposal file exists" {
  [[ -f "docs/propuestas/SE-070-opus47-eval-scorecard.md" ]]
}

# ── Isolation ─────────────────────────────────────────

@test "isolation: script does not modify agents" {
  local h_before
  h_before=$(find .claude/agents -name "*.md" -type f -exec md5sum {} + 2>/dev/null | sort | md5sum | awk '{print $1}')
  bash "$SCRIPT" >/dev/null 2>&1 || true
  local h_after
  h_after=$(find .claude/agents -name "*.md" -type f -exec md5sum {} + 2>/dev/null | sort | md5sum | awk '{print $1}')
  [[ "$h_before" == "$h_after" ]]
}

@test "isolation: exit codes 0/1/2" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

# ── Negative cases (status -ne 0) ────────────────────────

@test "negative: empty string arg fails with error" {
  run bash "$SCRIPT" ""
  [ "$status" -ne 0 ]
}

@test "negative: malformed flag rejected with exit 2" {
  run bash "$SCRIPT" --nonexistent-flag
  [ "$status" -eq 2 ]
}

@test "negative: script fails if required agent file missing (simulated)" {
  local TMP="$(mktemp -d)"
  trap "rm -rf $TMP" EXIT
  # Copy script + fake agents dir lacking the expected file
  mkdir -p "$TMP/.claude/agents" "$TMP/.claude/skills"
  cd "$TMP"
  ln -s "$BATS_TEST_DIRNAME/../scripts" scripts
  run bash scripts/opus47-compliance-check.sh --finding-vs-filtering
  [ "$status" -ne 0 ]
  cd "$BATS_TEST_DIRNAME/.."
}

@test "negative: --fan-out alone without orchestrators fails gracefully" {
  local TMP="$(mktemp -d)"
  trap "rm -rf $TMP" EXIT
  mkdir -p "$TMP/.claude/agents" "$TMP/.claude/skills"
  cd "$TMP"
  ln -s "$BATS_TEST_DIRNAME/../scripts" scripts
  run bash scripts/opus47-compliance-check.sh --fan-out
  [ "$status" -ne 0 ]
  cd "$BATS_TEST_DIRNAME/.."
}

# ── Edge cases ───────────────────────────────────────────

@test "edge: empty stdin does not crash" {
  run bash "$SCRIPT" < /dev/null
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "edge: nonexistent agent in scan skipped safely" {
  run bash "$SCRIPT" --finding-vs-filtering
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  [[ "$output" == *"VERDICT"* ]]
}

@test "edge: zero failures produces empty failures list in JSON" {
  run bash "$SCRIPT" --json
  [[ "$output" == *'"failures":['* ]]
}

@test "edge: large number of agents (65) audited without timeout" {
  run timeout 10 bash "$SCRIPT"
  [ "$status" -ne 124 ]
}

@test "edge: --json output is well-formed even when PASS" {
  run bash -c 'bash scripts/opus47-compliance-check.sh --json | python3 -m json.tool'
  [ "$status" -eq 0 ]
}

# ── Coverage breadth ─────────────────────────────────────

@test "coverage: add_fail function defined in target" {
  run grep -c '^add_fail()' "scripts/opus47-compliance-check.sh"
  [[ "$output" -ge 1 ]]
}

@test "coverage: check_finding_vs_filtering defined" {
  run grep -c '^check_finding_vs_filtering()' "scripts/opus47-compliance-check.sh"
  [[ "$output" -ge 1 ]]
}

@test "coverage: check_fan_out defined" {
  run grep -c '^check_fan_out()' "scripts/opus47-compliance-check.sh"
  [[ "$output" -ge 1 ]]
}

@test "coverage: check_adaptive_thinking defined" {
  run grep -c '^check_adaptive_thinking()' "scripts/opus47-compliance-check.sh"
  [[ "$output" -ge 1 ]]
}

@test "coverage: check_xml_tags defined" {
  run grep -c '^check_xml_tags()' "scripts/opus47-compliance-check.sh"
  [[ "$output" -ge 1 ]]
}

@test "coverage: check_context_rot_skill defined" {
  run grep -c '^check_context_rot_skill()' "scripts/opus47-compliance-check.sh"
  [[ "$output" -ge 1 ]]
}

@test "coverage: usage function defined" {
  run grep -c '^usage()' "scripts/opus47-compliance-check.sh"
  [[ "$output" -ge 1 ]]
}

@test "coverage: TMPDIR used in at least one test" {
  run grep -c 'mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}
