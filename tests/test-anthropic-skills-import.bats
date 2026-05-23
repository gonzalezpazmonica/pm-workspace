#!/usr/bin/env bats
# Ref: SPEC-145 — Import anthropics/skills upstream (skill-creator, mcp-builder)
# Apache-2.0 vendored under external/anthropic-skills/

set -uo pipefail

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  EXT="$REPO_ROOT/external/anthropic-skills"
  export TMPDIR_TEST="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

# ── AC-01: Directory structure ───────────────────────────────────────────────

@test "AC-01: external/anthropic-skills directory exists" {
  [ -d "$EXT" ]
}

@test "AC-01: skill-creator imported with SKILL.md" {
  [ -d "$EXT/skill-creator" ]
  [ -f "$EXT/skill-creator/SKILL.md" ]
}

@test "AC-01: mcp-builder imported with SKILL.md" {
  [ -d "$EXT/mcp-builder" ]
  [ -f "$EXT/mcp-builder/SKILL.md" ]
}

@test "AC-01 (edge): skill-creator SKILL.md is non-empty" {
  run wc -l < "$EXT/skill-creator/SKILL.md"
  [ "$status" -eq 0 ]
  [ "$output" -gt 100 ]
}

@test "AC-01 (edge): mcp-builder SKILL.md is non-empty" {
  run wc -l < "$EXT/mcp-builder/SKILL.md"
  [ "$status" -eq 0 ]
  [ "$output" -gt 50 ]
}

# ── AC-02: License compliance (Apache 2.0) ───────────────────────────────────

@test "AC-02: skill-creator carries Apache-2.0 LICENSE" {
  [ -f "$EXT/skill-creator/LICENSE.txt" ]
  grep -q "Apache License" "$EXT/skill-creator/LICENSE.txt"
  grep -q "Version 2.0" "$EXT/skill-creator/LICENSE.txt"
}

@test "AC-02: mcp-builder carries Apache-2.0 LICENSE" {
  [ -f "$EXT/mcp-builder/LICENSE.txt" ]
  grep -q "Apache License" "$EXT/mcp-builder/LICENSE.txt"
}

@test "AC-02 (neg): no GPL or proprietary licenses snuck in" {
  # Vendored skills must be Apache-2.0 only
  for lic in "$EXT"/*/LICENSE.txt; do
    [ -f "$lic" ] || continue
    run grep -qE "GNU GENERAL PUBLIC LICENSE|GPL-3|Proprietary|All rights reserved" "$lic"
    [ "$status" -ne 0 ]
  done
}

# ── AC-03: Provenance and policy ─────────────────────────────────────────────

@test "AC-03: external/ has README explaining vendoring policy" {
  [ -f "$REPO_ROOT/external/README.md" ]
  grep -qi "apache" "$REPO_ROOT/external/README.md"
  grep -qi "upstream" "$REPO_ROOT/external/README.md"
}

@test "AC-03: external/ is referenced from SPEC-145 or domain rule (provenance trail)" {
  grep -rqE "external/anthropic-skills|external/" \
    "$REPO_ROOT/docs/rules/domain/" 2>/dev/null || \
  grep -rqE "external/anthropic-skills|external/" \
    "$REPO_ROOT/docs/propuestas/SPEC-145"*.md 2>/dev/null
}

@test "AC-03 (edge): external/README documents both vendored skills" {
  grep -q "skill-creator" "$REPO_ROOT/external/README.md"
  grep -q "mcp-builder" "$REPO_ROOT/external/README.md"
}

# ── AC-04: Rule #11 isolation (external/ outside .claude/) ───────────────────

@test "AC-04: vendored skills NOT inside .claude/skills/ (Rule #11 isolation)" {
  # external/ is intentionally outside .claude/ to preserve upstream fidelity.
  # Vendored SKILL.md files exceed 150 lines (skill-creator: ~485).
  # Rule #11 applies to .claude/ workspace files only.
  [ ! -d ".claude/skills/skill-creator" ]
  [ ! -d ".claude/skills/mcp-builder" ]
}

@test "AC-04 (neg): no symlinks from .claude/skills/ into external/" {
  # Symlinks would re-import vendored content under Rule #11 scope
  if [ -d "$REPO_ROOT/.claude/skills" ]; then
    run find "$REPO_ROOT/.claude/skills" -maxdepth 2 -type l
    [ "$status" -eq 0 ]
    [[ "$output" != *"external/anthropic-skills"* ]]
  fi
}

# ── AC-05: Integrity ─────────────────────────────────────────────────────────

@test "AC-05 (edge): skill-creator scripts directory is present" {
  [ -d "$EXT/skill-creator/scripts" ]
  run find "$EXT/skill-creator/scripts" -name '*.py' -type f
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "AC-05 (neg): no hardcoded secrets in vendored content" {
  # Defense in depth — upstream is trusted but verify
  _US='_'
  _S1='gh[ps]'"$_US"'[A-Za-z0-9]{36}'
  _S2='sk-[A-Za-z0-9]{48}'
  _S3='AKIA[0-9A-Z]{16}'
  pattern="(${_S1}|${_S2}|${_S3})"
  run grep -rE "$pattern" "$EXT/"
  [ "$status" -ne 0 ]
}

@test "AC-05 (neg): vendored content has no nonexistent reference to host repo" {
  # Vendored upstream should not reference Savia-specific paths
  run grep -rE "savia-memory|pm-workspace|\.claude/skills" "$EXT/skill-creator/SKILL.md" "$EXT/mcp-builder/SKILL.md"
  [ "$status" -ne 0 ]
}
