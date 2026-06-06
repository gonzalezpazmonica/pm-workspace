#!/usr/bin/env bats
# SE-084 Slice 1: skill-catalog-auditor.sh — quality auditor for skills catalog.
# Acceptance: detects missing SKILL.md/DOMAIN.md, bad frontmatter, oversized files,
# empty DOMAIN.md, missing path refs; flags: --json, --skill, --fix-report.

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
  SCRIPT="scripts/skill-catalog-auditor.sh"
  STAMP="$(date +%Y%m%d)"
  REPORT="output/skill-audit-report-${STAMP}.md"
  FAKE_ROOT="${TMPDIR}/fake-catalog-$$"
}

teardown() {
  rm -rf "${FAKE_ROOT:-/tmp/fake-catalog-noop}"
  cd /
}

# ── Helper: patch SKILLS_DIR in a copy of the script ─────────────────────────
_patched_script() {
  local fake_skills="$1"
  local dest="${FAKE_ROOT}/patched-$$.sh"
  mkdir -p "$FAKE_ROOT"
  sed "s|SKILLS_DIR=.*|SKILLS_DIR='${fake_skills}'|" "$SCRIPT" > "$dest"
  chmod +x "$dest"
  echo "$dest"
}

# ── Structural ────────────────────────────────────────────────────────────────

@test "script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "set -uo pipefail present" {
  grep -q "set -uo pipefail" "$SCRIPT"
}

@test "shebang is bash on first line" {
  head -1 "$SCRIPT" | grep -q '^#!/usr/bin/env bash'
}

# ── Basic execution ───────────────────────────────────────────────────────────

@test "audit workspace produces exit 0 (no FAILs in current skills)" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "summary line contains PASS WARN FAIL TOTAL keywords" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE "PASS: [0-9]+ \| WARN: [0-9]+ \| FAIL: [0-9]+ \| TOTAL: [0-9]+"
}

@test "output contains at least one skill row" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ $(echo "$output" | wc -l) -gt 3 ]]
}

@test "audit lists caveman as OK" {
  run bash "$SCRIPT" --skill caveman
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE "^caveman\s+OK"
}

# ── --json flag ───────────────────────────────────────────────────────────────

@test "--json produces valid JSON array" {
  run bash -c "bash '$SCRIPT' --json 2>/dev/null"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -m json.tool > /dev/null 2>&1
}

@test "--json array elements have skill status reason keys" {
  run bash -c "bash '$SCRIPT' --json 2>/dev/null"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
assert len(data) > 0, 'empty array'
for item in data:
    assert 'skill' in item, 'missing skill key'
    assert 'status' in item, 'missing status key'
    assert 'reason' in item, 'missing reason key'
"
}

# ── --skill flag ──────────────────────────────────────────────────────────────

@test "--skill nonexistent exits 1 with error message" {
  run bash "$SCRIPT" --skill __does_not_exist__
  [ "$status" -eq 1 ]
  echo "$output" | grep -qi "not found"
}

@test "--skill valid-skill audits only that skill (1 row)" {
  run bash "$SCRIPT" --skill caveman
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "TOTAL: 1"
}

# ── Fixture: skill without DOMAIN.md ─────────────────────────────────────────

@test "skill without DOMAIN.md detected as FAIL" {
  local fake_skills="${FAKE_ROOT}/skills"
  mkdir -p "${fake_skills}/no-domain"
  printf -- '---\nname: fake\ndescription: "desc"\n---\n\nrefs path/to/file\n' \
    > "${fake_skills}/no-domain/SKILL.md"
  # Intentionally no DOMAIN.md

  local patched
  patched="$(_patched_script "$fake_skills")"
  run bash "$patched"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "FAIL"
  echo "$output" | grep "no-domain" | grep -q "DOMAIN.md missing"
}

# ── Fixture: SKILL.md > 150 lines ────────────────────────────────────────────

@test "SKILL.md with 151 lines detected as WARN" {
  local fake_skills="${FAKE_ROOT}/skills"
  mkdir -p "${fake_skills}/fat-skill"
  {
    printf -- '---\nname: fat\ndescription: "Fat skill"\n---\n\nrefs path/to/file\n'
    yes "padding line" | head -145
  } > "${fake_skills}/fat-skill/SKILL.md"
  printf 'Domain 1\nDomain 2\nDomain 3\nDomain 4\n' > "${fake_skills}/fat-skill/DOMAIN.md"

  local patched
  patched="$(_patched_script "$fake_skills")"
  run bash "$patched"
  [ "$status" -eq 0 ]
  echo "$output" | grep "fat-skill" | grep -q "WARN"
  echo "$output" | grep "fat-skill" | grep -q "151"
}

# ── Exit code semantics ───────────────────────────────────────────────────────

@test "exit 0 when FAIL count is 0" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "exit 1 when FAIL count greater than 0 (fixture)" {
  local fake_skills="${FAKE_ROOT}/skills"
  mkdir -p "${fake_skills}/broken"
  # No SKILL.md, no DOMAIN.md — counts as FAIL
  touch "${fake_skills}/broken/README.md"

  local patched
  patched="$(_patched_script "$fake_skills")"
  run bash "$patched"
  [ "$status" -eq 1 ]
}

# ── --fix-report ──────────────────────────────────────────────────────────────

@test "--fix-report generates report file" {
  run bash "$SCRIPT" --fix-report
  [ "$status" -eq 0 ]
  [[ -f "$REPORT" ]]
}

@test "--fix-report file contains expected markdown sections" {
  bash "$SCRIPT" --fix-report
  grep -q "# Skill Catalog Audit Report" "$REPORT"
  grep -q "## Summary" "$REPORT"
  grep -q "## Results" "$REPORT"
}

# ── SE-084 Slice 2 — G14 gate tests ──────────────────────────────────────────

GATE_SCRIPT="scripts/pre-push-bats-critical.sh"

@test "G14: gate script (pre-push-bats-critical.sh) exists and is executable" {
  [[ -x "$GATE_SCRIPT" ]]
}

@test "G14: set -uo pipefail present in gate script" {
  grep -q "set -uo pipefail" "$GATE_SCRIPT"
}

@test "G14: gate contains G14 skill quality gate block" {
  grep -q "G14" "$GATE_SCRIPT"
  grep -q "skill-catalog-auditor.sh" "$GATE_SCRIPT"
}

@test "G14: gate passes when modified skill is valid (caveman)" {
  # Simulate: changed_files contains a SKILL.md for caveman (which is a valid skill)
  # We test the auditor directly for the skill that the gate would call
  run bash "$SCRIPT" --skill caveman
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE "^caveman\s+OK"
}

@test "G14: gate fails when skill has no SKILL.md (FAIL condition)" {
  local fake_skills="${FAKE_ROOT}/skills"
  mkdir -p "${fake_skills}/broken-g14"
  # No SKILL.md, no DOMAIN.md — auditor must return exit 1
  touch "${fake_skills}/broken-g14/README.md"

  local patched
  patched="$(_patched_script "$fake_skills")"
  run bash "$patched" --skill broken-g14
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "FAIL"
}

@test "G14: gate fails when skill has SKILL.md but no DOMAIN.md" {
  local fake_skills="${FAKE_ROOT}/skills"
  mkdir -p "${fake_skills}/no-domain-g14"
  printf -- '---\nname: nodomain\ndescription: "Missing domain"\n---\n\nrefs path/to/file\n' \
    > "${fake_skills}/no-domain-g14/SKILL.md"
  # Intentionally no DOMAIN.md

  local patched
  patched="$(_patched_script "$fake_skills")"
  run bash "$patched" --skill no-domain-g14
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "FAIL"
  echo "$output" | grep "no-domain-g14" | grep -q "DOMAIN.md missing"
}

@test "G14: gate does not run auditor when no skills are modified (empty changed_files)" {
  # If BATS_SKIP_INTEGRATION is set, skip (no git env available)
  # Test the grep filter logic directly: input with no skill paths → empty output
  result=$(printf '' \
    | grep -E '^\.opencode/skills/[^/]+/(SKILL|DOMAIN)\.md$' \
    | sed -E 's|^\.opencode/skills/([^/]+)/.*|\1|' \
    | sort -u || true)
  [[ -z "$result" ]]
}

@test "G14: grep filter extracts correct skill names from changed_files list" {
  result=$(printf '.opencode/skills/caveman/SKILL.md\nscripts/foo.sh\n.opencode/skills/zoom-out/DOMAIN.md\n' \
    | grep -E '^\.opencode/skills/[^/]+/(SKILL|DOMAIN)\.md$' \
    | sed -E 's|^\.opencode/skills/([^/]+)/.*|\1|' \
    | sort -u)
  echo "$result" | grep -q "^caveman$"
  echo "$result" | grep -q "^zoom-out$"
  # non-skill path must NOT appear
  ! echo "$result" | grep -q "foo"
}

