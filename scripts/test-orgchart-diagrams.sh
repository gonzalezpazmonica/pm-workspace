#!/usr/bin/env bash
# ============================================================================
# test-orgchart-diagrams.sh — Tests for orgchart diagram generation
# ============================================================================
# Validates orgchart configuration, shapes, templates, and Mermaid output.
#
# Usage:
#   ./scripts/test-orgchart-diagrams.sh
#   ./scripts/test-orgchart-diagrams.sh --verbose
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

VERBOSE=false
[[ "${1:-}" == "--verbose" ]] && VERBOSE=true

TESTS_TOTAL=0; TESTS_PASSED=0; TESTS_FAILED=0
declare -a FAILED_TESTS=()

pass() { echo -e "  ${GREEN}✅ PASS${NC} — $1"; TESTS_PASSED=$((TESTS_PASSED+1)); TESTS_TOTAL=$((TESTS_TOTAL+1)); }
fail() { echo -e "  ${RED}❌ FAIL${NC} — $1"; echo -e "     ${RED}↳ $2${NC}"; TESTS_FAILED=$((TESTS_FAILED+1)); TESTS_TOTAL=$((TESTS_TOTAL+1)); FAILED_TESTS+=("$1: $2"); }
log_header() { echo ""; echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════${NC}"; echo -e "${BOLD}${BLUE}  $1${NC}"; echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════${NC}"; }
log_section() { echo ""; echo -e "${CYAN}▶ $1${NC}"; }

# ─────────────────────────────────────────────────────────────────────────────
# SUITE 1: Configuration
# ─────────────────────────────────────────────────────────────────────────────
test_config() {
  log_header "SUITE 1 — Orgchart Configuration"

  log_section "diagram-config.md"

  if grep -q 'orgchart' "$WORKSPACE_ROOT/docs/rules/domain/diagram-config.md"; then
    pass "DIAGRAM_TYPES includes orgchart"
  else
    fail "DIAGRAM_TYPES missing orgchart" "diagram-config.md should list orgchart"
  fi

  if grep -q 'ORGCHART_DATA_DIR' "$WORKSPACE_ROOT/docs/rules/domain/diagram-config.md"; then
    pass "ORGCHART_DATA_DIR defined"
  else
    fail "ORGCHART_DATA_DIR not defined" "diagram-config.md should define data dir"
  fi

  if grep -q 'ORGCHART_OUTPUT_DIR' "$WORKSPACE_ROOT/docs/rules/domain/diagram-config.md"; then
    pass "ORGCHART_OUTPUT_DIR defined"
  else
    fail "ORGCHART_OUTPUT_DIR not defined" "diagram-config.md should define output dir"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# SUITE 2: File structure
# ─────────────────────────────────────────────────────────────────────────────
test_structure() {
  log_header "SUITE 2 — File Structure"

  log_section "Required files exist"

  local files=(
    "teams/diagrams/.gitkeep"
    ".claude/skills/diagram-generation/references/orgchart-shapes.md"
    ".claude/skills/diagram-generation/references/orgchart-mermaid-template.md"
  )

  for f in "${files[@]}"; do
    if [[ -f "$WORKSPACE_ROOT/$f" ]]; then
      pass "$f exists"
    else
      fail "$f missing" "File should exist"
    fi
  done

  log_section "File size limits (<=150 lines)"

  local sized_files=(
    ".claude/skills/diagram-generation/references/orgchart-shapes.md"
    ".claude/skills/diagram-generation/references/orgchart-mermaid-template.md"
    ".claude/commands/diagram-generate.md"
    ".claude/skills/diagram-generation/SKILL.md"
  )

  for f in "${sized_files[@]}"; do
    local lines
    lines=$(wc -l < "$WORKSPACE_ROOT/$f")
    if [[ "$lines" -le 150 ]]; then
      pass "$f has $lines lines (<=150)"
    else
      fail "$f exceeds 150 lines" "Has $lines lines"
    fi
  done
}

# ─────────────────────────────────────────────────────────────────────────────
# SUITE 3: Shapes reference
# ─────────────────────────────────────────────────────────────────────────────
test_shapes() {
  log_header "SUITE 3 — Orgchart Shapes Reference"

  local shapes_file="$WORKSPACE_ROOT/.claude/skills/diagram-generation/references/orgchart-shapes.md"

  log_section "Required entity shapes"

  local entities=("Departamento" "Equipo" "Lead" "Miembro" "Supervisor" "Jerarqu")
  for entity in "${entities[@]}"; do
    if grep -qi "$entity" "$shapes_file"; then
      pass "Shape defined for: $entity"
    else
      fail "Missing shape for: $entity" "orgchart-shapes.md should define $entity"
    fi
  done

  log_section "XML snippets present"

  if grep -q '<mxCell' "$shapes_file"; then
    pass "Contains Draw.io XML snippets"
  else
    fail "No XML snippets" "Should contain <mxCell examples"
  fi

  local shape_types=("swimlane" "rounded=1" "shape=mxgraph.basic.person" "dashed=1")
  for st in "${shape_types[@]}"; do
    if grep -q "$st" "$shapes_file"; then
      pass "XML contains style: $st"
    else
      fail "Missing XML style: $st" "orgchart-shapes.md should use $st"
    fi
  done
}

# ─────────────────────────────────────────────────────────────────────────────
# SUITE 4: Mermaid template
# ─────────────────────────────────────────────────────────────────────────────
test_mermaid_template() {
  log_header "SUITE 4 — Mermaid Template"

  local tmpl="$WORKSPACE_ROOT/.claude/skills/diagram-generation/references/orgchart-mermaid-template.md"

  log_section "Template structure"

  if grep -q 'graph TB' "$tmpl"; then
    pass "Uses graph TB (top-to-bottom) layout"
  else
    fail "Missing graph TB" "Template should use top-to-bottom layout"
  fi

  if grep -q 'subgraph' "$tmpl"; then
    pass "Uses subgraphs for teams"
  else
    fail "Missing subgraph" "Template should group teams in subgraphs"
  fi

  if grep -q '★' "$tmpl"; then
    pass "Leads marked with ★"
  else
    fail "Missing ★ marker" "Leads should be marked with ★"
  fi

  if grep -q '@' "$tmpl"; then
    pass "Uses @handles for members"
  else
    fail "Missing @handles" "Template should use @handles, not real names"
  fi

  log_section "PII-Free compliance"

  # Check that no real full names appear (handles like @eduardo are OK)
  # Only flag names NOT preceded by @ (PII = real person names in prose)
  if grep -E '(Mónica|González)' "$tmpl" 2>/dev/null | grep -qvE '@'; then
    fail "Real names detected in template" "Template must use @handles only (PII-Free rule)"
  else
    pass "No real names in template (PII-Free compliant)"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# SUITE 5: Command integration
# ─────────────────────────────────────────────────────────────────────────────
test_command() {
  log_header "SUITE 5 — Command Integration"

  local cmd="$WORKSPACE_ROOT/.claude/commands/diagram-generate.md"

  log_section "Orgchart support in command"

  if grep -q 'orgchart' "$cmd"; then
    pass "Command mentions orgchart type"
  else
    fail "Command missing orgchart" "diagram-generate.md should support orgchart"
  fi

  if grep -q 'teams/' "$cmd"; then
    pass "Command references teams/ directory"
  else
    fail "Command missing teams/ reference" "Should read from teams/"
  fi

  if grep -q 'dept.md' "$cmd"; then
    pass "Command references dept.md"
  else
    fail "Command missing dept.md reference" "Should read dept.md"
  fi

  if grep -q 'team.md' "$cmd"; then
    pass "Command references team.md"
  else
    fail "Command missing team.md reference" "Should read team.md"
  fi

  if grep -q 'PII' "$cmd"; then
    pass "Command has PII-Free restriction"
  else
    fail "Command missing PII restriction" "Should mention PII-Free rule"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# SUITE 6: Skill integration
# ─────────────────────────────────────────────────────────────────────────────
test_skill() {
  log_header "SUITE 6 — Skill Integration"

  local skill="$WORKSPACE_ROOT/.claude/skills/diagram-generation/SKILL.md"

  if grep -q 'Orgchart' "$skill"; then
    pass "SKILL.md lists Orgchart type"
  else
    fail "SKILL.md missing Orgchart" "Should list Orgchart in supported types"
  fi

  if grep -q 'orgchart-shapes.md' "$skill"; then
    pass "SKILL.md references orgchart-shapes.md"
  else
    fail "SKILL.md missing shapes ref" "Should reference orgchart-shapes.md"
  fi

  if grep -q 'orgchart-mermaid-template.md' "$skill"; then
    pass "SKILL.md references orgchart-mermaid-template.md"
  else
    fail "SKILL.md missing template ref" "Should reference orgchart-mermaid-template.md"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# SUITE 7: Mermaid output generation test
# ─────────────────────────────────────────────────────────────────────────────
test_mermaid_generation() {
  log_header "SUITE 7 — Mermaid Output Generation (SoftwareEngineering)"

  log_section "Generate orgchart from teams data"

  local dept_dir="$WORKSPACE_ROOT/teams/SoftwareEngineering"
  local output_dir="$WORKSPACE_ROOT/teams/diagrams/local"
  local output_file="$output_dir/orgchart-SoftwareEngineering.mermaid"

  mkdir -p "$output_dir"

  # Read department data
  if [[ ! -f "$dept_dir/dept.md" ]]; then
    fail "dept.md not found" "$dept_dir/dept.md missing"
    return
  fi
  pass "Department data found: SoftwareEngineering"

  # Parse teams
  local teams=()
  while IFS= read -r line; do
    teams+=("$line")
  done < <(find "$dept_dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)

  if [[ ${#teams[@]} -gt 0 ]]; then
    pass "Found ${#teams[@]} teams: ${teams[*]}"
  else
    fail "No teams found" "Expected subdirectories in $dept_dir"
    return
  fi

  # Generate Mermaid
  {
    echo "graph TB"
    echo "    DEPT[\"🏢 SoftwareEngineering<br/><i>Responsable: —</i>\"]"
    echo ""

    for team in "${teams[@]}"; do
      local team_file="$dept_dir/$team/team.md"
      if [[ ! -f "$team_file" ]]; then
        continue
      fi

      # Parse capacity
      local cap
      cap=$(grep 'capacity_total' "$team_file" | head -1 | sed 's/.*: *//' || echo "0")

      echo "    subgraph ${team}[\"${team} (cap: ${cap})\"]"

      # Parse members
      while IFS= read -r handle_line; do
        local handle
        handle=$(echo "$handle_line" | sed 's/.*handle: *"\{0,1\}//' | sed 's/"\{0,1\} *$//')
        local clean_handle="${handle#@}"
        local node_id="SQ_${team}_${clean_handle}"

        # Check if lead
        local is_lead=false
        if grep -q "\"$handle\"" <(grep -A1 '^lead:' "$team_file" 2>/dev/null) 2>/dev/null; then
          is_lead=true
        fi

        # Get role
        local role
        role=$(grep -A3 "handle: *\"*${handle}" "$team_file" | grep 'role:' | head -1 | sed 's/.*role: *//' || echo "member")

        if $is_lead; then
          echo "        ${node_id}[\"${handle}<br/>${role} ★\"]"
        else
          echo "        ${node_id}[\"${handle}<br/>${role}\"]"
        fi
      done < <(grep 'handle:' "$team_file")

      echo "    end"
      echo ""
    done

    for team in "${teams[@]}"; do
      echo "    DEPT --- ${team}"
    done
  } > "$output_file"

  if [[ -f "$output_file" ]]; then
    pass "Generated: $output_file"
  else
    fail "Output not generated" "Expected $output_file"
    return
  fi

  log_section "Validate Mermaid structure"

  # Check graph TB
  if grep -q '^graph TB' "$output_file"; then
    pass "Starts with graph TB"
  else
    fail "Missing graph TB header" "Mermaid should start with graph TB"
  fi

  # Check department node
  if grep -q 'DEPT\[' "$output_file"; then
    pass "Department root node present"
  else
    fail "Missing department node" "Should have DEPT node"
  fi

  # Check subgraphs
  local subgraph_count
  subgraph_count=$(grep -c 'subgraph' "$output_file" || true)
  if [[ "$subgraph_count" -eq ${#teams[@]} ]]; then
    pass "Correct number of subgraphs ($subgraph_count)"
  else
    fail "Wrong subgraph count" "Expected ${#teams[@]}, got $subgraph_count"
  fi

  # Check hierarchy connections
  local conn_count
  conn_count=$(grep -c 'DEPT ---' "$output_file" || true)
  if [[ "$conn_count" -eq ${#teams[@]} ]]; then
    pass "All teams connected to department ($conn_count)"
  else
    fail "Missing hierarchy connections" "Expected ${#teams[@]}, got $conn_count"
  fi

  # Check member nodes exist
  local member_count
  member_count=$(grep -c 'SQ_' "$output_file" || true)
  if [[ "$member_count" -gt 0 ]]; then
    pass "Member nodes present ($member_count)"
  else
    fail "No member nodes" "Should have SQ_ prefixed nodes"
  fi

  # Check lead markers
  if grep -q '★' "$output_file"; then
    pass "Lead markers (★) present"
  else
    fail "Missing lead markers" "Leads should have ★"
  fi

  # PII check — no real names, only @handles
  if grep -oP '(?<=\[")[^"]*' "$output_file" 2>/dev/null | grep -qiE '(Mónica|González)'; then
    fail "PII detected in output" "Only @handles allowed"
  else
    pass "Output is PII-Free"
  fi

  # Check handles format
  if grep -q '@' "$output_file"; then
    pass "Uses @handle format"
  else
    fail "Missing @handles" "Members should use @handle format"
  fi

  if $VERBOSE; then
    echo ""
    echo -e "${YELLOW}Generated Mermaid:${NC}"
    cat "$output_file"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# RUN ALL
# ─────────────────────────────────────────────────────────────────────────────
main() {
  echo -e "${BOLD}${BLUE}"
  echo "═══════════════════════════════════════════════════════════"
  echo "  TEST SUITE — Orgchart Diagram Generation"
  echo "═══════════════════════════════════════════════════════════"
  echo -e "${NC}"

  test_config
  test_structure
  test_shapes
  test_mermaid_template
  test_command
  test_skill
  test_mermaid_generation

  echo ""
  echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}  RESULTS${NC}"
  echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════${NC}"
  echo -e "  Total:   ${TESTS_TOTAL}"
  echo -e "  ${GREEN}Passed:  ${TESTS_PASSED}${NC}"
  echo -e "  ${RED}Failed:  ${TESTS_FAILED}${NC}"
  echo ""

  if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
    echo -e "${RED}Failed tests:${NC}"
    for ft in "${FAILED_TESTS[@]}"; do
      echo -e "  ${RED}✗${NC} $ft"
    done
    echo ""
    exit 1
  else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
  fi
}

main "$@"
