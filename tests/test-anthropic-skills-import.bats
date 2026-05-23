#!/usr/bin/env bats
# Ref: SPEC-145 — Import anthropics/skills upstream (skill-creator, mcp-builder)
# Apache-2.0 vendored under external/anthropic-skills/

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  EXT="$REPO_ROOT/external/anthropic-skills"
}

@test "external/anthropic-skills directory exists" {
  [ -d "$EXT" ]
}

@test "skill-creator imported" {
  [ -d "$EXT/skill-creator" ]
  [ -f "$EXT/skill-creator/SKILL.md" ]
}

@test "mcp-builder imported" {
  [ -d "$EXT/mcp-builder" ]
  [ -f "$EXT/mcp-builder/SKILL.md" ]
}

@test "skill-creator carries Apache-2.0 LICENSE" {
  [ -f "$EXT/skill-creator/LICENSE.txt" ]
  grep -q "Apache License" "$EXT/skill-creator/LICENSE.txt"
  grep -q "Version 2.0" "$EXT/skill-creator/LICENSE.txt"
}

@test "mcp-builder carries Apache-2.0 LICENSE" {
  [ -f "$EXT/mcp-builder/LICENSE.txt" ]
  grep -q "Apache License" "$EXT/mcp-builder/LICENSE.txt"
}

@test "external/ has README explaining vendoring policy" {
  [ -f "$REPO_ROOT/external/README.md" ]
  grep -qi "apache" "$REPO_ROOT/external/README.md"
  grep -qi "upstream" "$REPO_ROOT/external/README.md"
}

@test "external/anthropic-skills excluded from .claude/ rule #11 line cap" {
  # external/ is intentionally outside .claude/ to preserve upstream fidelity.
  # SKILL.md files in upstream are >150 lines (485 in skill-creator).
  # Rule #11 applies to .claude/ workspace files only.
  [ ! -d ".claude/skills/skill-creator" ]
  [ ! -d ".claude/skills/mcp-builder" ]
}

@test "external/ is referenced from a domain rule (provenance trail)" {
  grep -rqE "external/anthropic-skills|external/" \
    "$REPO_ROOT/docs/rules/domain/" 2>/dev/null || \
  grep -rqE "external/anthropic-skills|external/" \
    "$REPO_ROOT/docs/propuestas/SPEC-145"*.md 2>/dev/null
}
