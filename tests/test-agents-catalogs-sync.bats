#!/usr/bin/env bats
# tests/test-agents-catalogs-sync.bats — SE-073 Plan-Then-Execute
#
# Invariante: AGENTS.md, agents-catalog.md y .opencode/agents/ DEBEN coincidir
# en número y nombres. Drift entre catálogos = vector de skill confusion attack
# (typosquatting de skills/agents) según informe jailbreak §2.4.
#
# Source of truth canónica: .opencode/agents/*.md frontmatter.

ROOT="$BATS_TEST_DIRNAME/.."
AGENTS_DIR="$ROOT/.opencode/agents"
AGENTS_MD="$ROOT/AGENTS.md"
CATALOG_MD="$ROOT/docs/rules/domain/agents-catalog.md"

# Helpers
agents_on_disk() {
  ls "$AGENTS_DIR"/*.md 2>/dev/null | xargs -n1 basename | sed 's/\.md$//' | sort
}
agents_in_md() {
  awk -F'|' '/^\|/ && !/Name.*Model/ && !/^\|---/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' \
    "$1" 2>/dev/null | sort
}
agents_in_catalog() {
  awk -F'|' '/^\|/ && !/Agent.*Model/ && !/^\|---/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' \
    "$1" 2>/dev/null | sort
}

@test "directorio .opencode/agents existe" {
  [ -d "$AGENTS_DIR" ]
}

@test "AGENTS.md existe" {
  [ -f "$AGENTS_MD" ]
}

@test "agents-catalog.md existe" {
  [ -f "$CATALOG_MD" ]
}

@test "AGENTS.md count = .opencode/agents count" {
  disk=$(agents_on_disk | wc -l)
  md=$(agents_in_md "$AGENTS_MD" | wc -l)
  [ "$disk" -eq "$md" ]
}

@test "agents-catalog.md count = .opencode/agents count" {
  disk=$(agents_on_disk | wc -l)
  cat=$(agents_in_catalog "$CATALOG_MD" | wc -l)
  [ "$disk" -eq "$cat" ]
}

@test "AGENTS.md set = .opencode/agents set (mismos nombres)" {
  diff <(agents_on_disk) <(agents_in_md "$AGENTS_MD")
}

@test "agents-catalog.md set = .opencode/agents set (mismos nombres)" {
  diff <(agents_on_disk) <(agents_in_catalog "$CATALOG_MD")
}

@test "scripts/agents-md-drift-check.sh reporta sync" {
  run bash "$ROOT/scripts/agents-md-drift-check.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"in sync"* ]] || [[ -z "$output" ]]
}

@test "scripts/agents-catalog-sync.sh --check exit 0" {
  run bash "$ROOT/scripts/agents-catalog-sync.sh" --check
  [ "$status" -eq 0 ]
}
