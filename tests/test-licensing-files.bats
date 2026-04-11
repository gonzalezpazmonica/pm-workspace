#!/usr/bin/env bats
# BATS tests for SE-008 licensing & distribution strategy files
# SPEC: docs/propuestas/savia-enterprise/SPEC-SE-008-licensing-distribution.md
# Quality gate: SPEC-055 (audit score ≥80)
# Safety: tests use `set -uo pipefail` equivalents via BATS run/status checks

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export CLAUDE_PROJECT_DIR="$(pwd)"
}

teardown() {
  unset CLAUDE_PROJECT_DIR
}

# ── File existence ──────────────────────────────────────────────────────────

@test "LICENSE-ENTERPRISE.md exists at repo root" {
  [[ -f "LICENSE-ENTERPRISE.md" ]]
}

@test "TRADEMARK.md exists at repo root" {
  [[ -f "TRADEMARK.md" ]]
}

@test "docs/support-offering.md exists" {
  [[ -f "docs/support-offering.md" ]]
}

@test "CODE_OF_CONDUCT.md exists at repo root" {
  [[ -f "CODE_OF_CONDUCT.md" ]]
}

@test "docs/propuestas/TEMPLATE.md RFC template exists" {
  [[ -f "docs/propuestas/TEMPLATE.md" ]]
}

@test "docs/savia-enterprise-mit-forever.md announcement exists" {
  [[ -f "docs/savia-enterprise-mit-forever.md" ]]
}

# ── LICENSE-ENTERPRISE content ──────────────────────────────────────────────

@test "LICENSE-ENTERPRISE.md states MIT license" {
  run grep -c "MIT" LICENSE-ENTERPRISE.md
  [[ "$status" -eq 0 ]]
  [[ "$output" -gt 0 ]]
  [[ "$output" == *[0-9]* ]]
}

@test "LICENSE-ENTERPRISE.md rejects BSL" {
  grep -iq "BSL" LICENSE-ENTERPRISE.md
}

@test "LICENSE-ENTERPRISE.md rejects AGPL" {
  grep -iq "AGPL" LICENSE-ENTERPRISE.md
}

@test "LICENSE-ENTERPRISE.md rejects SaaS hosting model" {
  grep -iq "SaaS" LICENSE-ENTERPRISE.md
}

@test "LICENSE-ENTERPRISE.md rejects pay-per-agent" {
  grep -iq "pay-per-agent\|pay-per-seat\|per-agent" LICENSE-ENTERPRISE.md
}

@test "LICENSE-ENTERPRISE.md mentions Open Core rejection" {
  grep -iq "open core\|open-core" LICENSE-ENTERPRISE.md
}

# ── TRADEMARK content ───────────────────────────────────────────────────────

@test "TRADEMARK.md is non-empty" {
  [[ -s "TRADEMARK.md" ]]
  [[ $(wc -l < TRADEMARK.md) -gt 20 ]]
}

@test "TRADEMARK.md mentions Savia name" {
  grep -q "Savia" TRADEMARK.md
}

@test "TRADEMARK.md allows forks with name change" {
  grep -iq "fork" TRADEMARK.md
}

# ── CODE_OF_CONDUCT ─────────────────────────────────────────────────────────

@test "CODE_OF_CONDUCT.md references Contributor Covenant" {
  grep -iq "contributor covenant" CODE_OF_CONDUCT.md
}

# ── support-offering ────────────────────────────────────────────────────────

@test "support-offering.md lists at least 5 services" {
  count=$(grep -c "^### " docs/support-offering.md)
  [[ $count -ge 5 ]]
}

@test "support-offering.md mentions support with SLA" {
  grep -iq "SLA\|service level" docs/support-offering.md
}

@test "support-offering.md mentions training" {
  grep -iq "training" docs/support-offering.md
}

@test "support-offering.md mentions sovereignty audit" {
  grep -iq "sovereignty\|audit" docs/support-offering.md
}

# ── mit-forever announcement ────────────────────────────────────────────────

@test "mit-forever.md cites the 7 foundational principles" {
  grep -iq "seven\|7.*principle" docs/savia-enterprise-mit-forever.md
}

@test "mit-forever.md references LICENSE-ENTERPRISE" {
  grep -q "LICENSE-ENTERPRISE" docs/savia-enterprise-mit-forever.md
}

@test "mit-forever.md mentions MIT forever commitment" {
  grep -iq "MIT" docs/savia-enterprise-mit-forever.md
  grep -iq "forever" docs/savia-enterprise-mit-forever.md
}

# ── TEMPLATE ────────────────────────────────────────────────────────────────

@test "TEMPLATE.md has Objective section" {
  grep -q "^## Objective" docs/propuestas/TEMPLATE.md
}

@test "TEMPLATE.md has Acceptance criteria section" {
  grep -q "^## Acceptance criteria" docs/propuestas/TEMPLATE.md
}

@test "TEMPLATE.md has Principles affected section" {
  grep -q "^## Principles affected" docs/propuestas/TEMPLATE.md
}

@test "TEMPLATE.md has Out of scope section" {
  grep -q "^## Out of scope" docs/propuestas/TEMPLATE.md
}
