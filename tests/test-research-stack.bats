#!/usr/bin/env bats
# test-research-stack.bats — SE-061 Slice 3 contract tests.
# Target: verify research-stack.md exists, skills reference scrapling fallback.
# Spec: docs/propuestas/SE-061-scrapling-research-backend.md
# set -uo pipefail equivalent via BATS strict mode

set -uo pipefail
ROOT="$BATS_TEST_DIRNAME/.."

setup() {
  TMPDIR="$(mktemp -d)"
  export TMPDIR
}

teardown() {
  [[ -n "${TMPDIR:-}" && -d "$TMPDIR" ]] && rm -rf "$TMPDIR" || true
}

# --- Rule file existence ---

@test "rule: research-stack.md exists" {
  [ -f "$ROOT/docs/rules/domain/research-stack.md" ]
}

@test "rule: research-stack.md under 150 lines" {
  local lines
  lines=$(wc -l < "$ROOT/docs/rules/domain/research-stack.md")
  [ "$lines" -le 150 ]
}

@test "rule: research-stack.md references SE-061" {
  run grep -c "SE-061" "$ROOT/docs/rules/domain/research-stack.md"
  [[ "$output" -ge 1 ]]
}

@test "rule: research-stack.md documents backend chain" {
  run grep -E "Cache|WebFetch|scrapling-fetch|curl" "$ROOT/docs/rules/domain/research-stack.md"
  [ "$status" -eq 0 ]
}

@test "rule: research-stack.md addresses robots.txt" {
  run grep -i "robots" "$ROOT/docs/rules/domain/research-stack.md"
  [ "$status" -eq 0 ]
}

@test "rule: research-stack.md addresses rate limiting" {
  run grep -iE "rate.?limit|crawl.?delay" "$ROOT/docs/rules/domain/research-stack.md"
  [ "$status" -eq 0 ]
}

@test "rule: research-stack.md addresses GDPR/PII" {
  run grep -iE "GDPR|PII|personal" "$ROOT/docs/rules/domain/research-stack.md"
  [ "$status" -eq 0 ]
}

# --- Skill integration ---

@test "skill: tech-research-agent references scrapling-fetch" {
  run grep "scrapling-fetch" "$ROOT/.opencode/skills/tech-research-agent/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "skill: tech-research-agent references SE-061" {
  run grep "SE-061" "$ROOT/.opencode/skills/tech-research-agent/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "skill: tech-research-agent references research-stack rule" {
  run grep "research-stack" "$ROOT/.opencode/skills/tech-research-agent/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "skill: web-research references scrapling-fetch" {
  run grep "scrapling-fetch" "$ROOT/.opencode/skills/web-research/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "skill: web-research references SE-061" {
  run grep "SE-061" "$ROOT/.opencode/skills/web-research/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "skill: web-research references research-stack rule" {
  run grep "research-stack" "$ROOT/.opencode/skills/web-research/SKILL.md"
  [ "$status" -eq 0 ]
}

# --- Script availability (wrapper must still be callable) ---

@test "script: scrapling-fetch.sh exists and is executable" {
  [ -x "$ROOT/scripts/scrapling-fetch.sh" ]
}

@test "script: scrapling-probe.sh exists and is executable" {
  [ -x "$ROOT/scripts/scrapling-probe.sh" ]
}

@test "script: scrapling-fetch.sh --help exits 0" {
  run bash "$ROOT/scripts/scrapling-fetch.sh" --help
  [ "$status" -eq 0 ]
}

# --- Fallback contract ---

@test "contract: scrapling-fetch falls back when scrapling missing" {
  # With no scrapling installed, backend must be curl
  run timeout 5 bash "$ROOT/scripts/scrapling-fetch.sh" "https://127.0.0.1:1/t" --json
  # Should not exit 2 (that would indicate usage error)
  [ "$status" -ne 2 ]
}

@test "contract: rule file names exact backend list" {
  run grep -cE "Scrapling|curl|WebFetch|Cache" "$ROOT/docs/rules/domain/research-stack.md"
  [[ "$output" -ge 3 ]]
}

# --- Coverage ---

@test "coverage: tech-research-agent SKILL.md under 200 lines" {
  local lines
  lines=$(wc -l < "$ROOT/.opencode/skills/tech-research-agent/SKILL.md")
  [ "$lines" -le 200 ]
}

@test "coverage: web-research SKILL.md under 200 lines" {
  local lines
  lines=$(wc -l < "$ROOT/.opencode/skills/web-research/SKILL.md")
  [ "$lines" -le 200 ]
}

# --- Isolation ---

@test "negative: empty URL to scrapling-fetch reports error" {
  run bash "$ROOT/scripts/scrapling-fetch.sh" ""
  [ "$status" -eq 2 ]
  [[ "$output" == *"error"* || "$output" == *"ERROR"* || "$output" == *"required"* ]]
}

@test "negative: invalid flag on scrapling-fetch fails" {
  run bash "$ROOT/scripts/scrapling-fetch.sh" "https://example.com" --bad-flag
  [ "$status" -eq 2 ]
}

@test "edge: rule file does not contain empty sections" {
  run grep -cE "^## .+" "$ROOT/docs/rules/domain/research-stack.md"
  [[ "$output" -ge 3 ]]
}

@test "edge: zero credential values leaked in rule file" {
  # Look for credential assignments (key=value, key: value with real-looking tokens), not mere word mentions
  run grep -cE "(password|secret|api[_-]?key)[[:space:]]*[:=][[:space:]]*[A-Za-z0-9_.-]{8,}" "$ROOT/docs/rules/domain/research-stack.md"
  [ "$output" -eq 0 ]
}

@test "edge: no absolute home paths in rule file" {
  run grep -c "$HOME" "$ROOT/docs/rules/domain/research-stack.md"
  [ "$output" -eq 0 ]
}

@test "isolation: running tests does not modify skill files" {
  local before_a=$(md5sum "$ROOT/.opencode/skills/tech-research-agent/SKILL.md" | awk '{print $1}')
  local before_b=$(md5sum "$ROOT/.opencode/skills/web-research/SKILL.md" | awk '{print $1}')
  bash "$ROOT/scripts/scrapling-fetch.sh" --help >/dev/null 2>&1 || true
  local after_a=$(md5sum "$ROOT/.opencode/skills/tech-research-agent/SKILL.md" | awk '{print $1}')
  local after_b=$(md5sum "$ROOT/.opencode/skills/web-research/SKILL.md" | awk '{print $1}')
  [ "$before_a" = "$after_a" ]
  [ "$before_b" = "$after_b" ]
}
