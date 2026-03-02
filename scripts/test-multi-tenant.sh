#!/bin/bash
# Test Suite: v0.70.0 Multi-Tenant & Skills Marketplace
# Validates command files, frontmatter, line counts, concepts, and metadata updates

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMANDS_DIR="${REPO_ROOT}/.claude/commands"
TEST_RESULTS=()
PASS_COUNT=0
FAIL_COUNT=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_pass() { 
  echo -e "${GREEN}✓ PASS:${NC} $1"
  ((PASS_COUNT++))
  TEST_RESULTS+=("PASS: $1")
}

log_fail() {
  echo -e "${RED}✗ FAIL:${NC} $1"
  ((FAIL_COUNT++))
  TEST_RESULTS+=("FAIL: $1")
}

log_info() {
  echo -e "${YELLOW}ℹ${NC} $1"
}

# Test 1: Check all 4 command files exist
test_files_exist() {
  log_info "Test 1: Checking command files exist..."
  for cmd in tenant-create tenant-share marketplace-publish marketplace-install; do
    if [ -f "${COMMANDS_DIR}/${cmd}.md" ]; then
      log_pass "File exists: ${cmd}.md"
    else
      log_fail "File missing: ${cmd}.md"
    fi
  done
}

# Test 2: Check YAML frontmatter
test_frontmatter() {
  log_info "Test 2: Checking YAML frontmatter..."
  for cmd in tenant-create tenant-share marketplace-publish marketplace-install; do
    file="${COMMANDS_DIR}/${cmd}.md"
    if grep -q "^---$" "$file"; then
      if grep -q "^name:" "$file" && grep -q "^description:" "$file" && \
         grep -q "^developer_type:" "$file" && grep -q "^agent:" "$file" && \
         grep -q "^context_cost:" "$file"; then
        log_pass "Frontmatter valid: ${cmd}.md"
      else
        log_fail "Missing frontmatter fields: ${cmd}.md"
      fi
    else
      log_fail "No YAML frontmatter: ${cmd}.md"
    fi
  done
}

# Test 3: Check line counts (≤150)
test_line_counts() {
  log_info "Test 3: Checking line counts (max 150)..."
  for cmd in tenant-create tenant-share marketplace-publish marketplace-install; do
    file="${COMMANDS_DIR}/${cmd}.md"
    lines=$(wc -l < "$file")
    if [ "$lines" -le 150 ]; then
      log_pass "${cmd}.md: $lines lines (≤150)"
    else
      log_fail "${cmd}.md: $lines lines (> 150 limit!)"
    fi
  done
}

# Test 4: Check key concepts
test_concepts() {
  log_info "Test 4: Checking key concepts..."
  
  # tenant-create: tenant, isolation, workspace, profiles, roles
  file="${COMMANDS_DIR}/tenant-create.md"
  concepts=("tenant" "isolation" "workspace" "profiles" "roles")
  for concept in "${concepts[@]}"; do
    if grep -qi "$concept" "$file"; then
      log_pass "tenant-create.md contains: $concept"
    else
      log_fail "tenant-create.md missing: $concept"
    fi
  done
  
  # tenant-share: share, tenant, approval, versioning, resources
  file="${COMMANDS_DIR}/tenant-share.md"
  concepts=("share" "tenant" "approval" "versioning" "resource")
  for concept in "${concepts[@]}"; do
    if grep -qi "$concept" "$file"; then
      log_pass "tenant-share.md contains: $concept"
    else
      log_fail "tenant-share.md missing: $concept"
    fi
  done
  
  # marketplace-publish: marketplace, publish, skill, quality, rating
  file="${COMMANDS_DIR}/marketplace-publish.md"
  concepts=("marketplace" "publish" "skill" "quality" "rating")
  for concept in "${concepts[@]}"; do
    if grep -qi "$concept" "$file"; then
      log_pass "marketplace-publish.md contains: $concept"
    else
      log_fail "marketplace-publish.md missing: $concept"
    fi
  done
  
  # marketplace-install: marketplace, install, dependency, rollback, compatibility
  file="${COMMANDS_DIR}/marketplace-install.md"
  concepts=("marketplace" "install" "dependency\|dependencies" "rollback" "compatibility\|compatible")
  for concept in "${concepts[@]}"; do
    if grep -qi "$concept" "$file"; then
      log_pass "marketplace-install.md contains: $concept"
    else
      log_fail "marketplace-install.md missing: $concept"
    fi
  done
}

# Test 5: Check meta files updated (245 → 249)
test_meta_files() {
  log_info "Test 5: Checking meta files updated (245 → 249)..."
  
  # Check CLAUDE.md
  if grep -q "249" "${REPO_ROOT}/CLAUDE.md"; then
    log_pass "CLAUDE.md updated: 249 commands"
  else
    log_fail "CLAUDE.md NOT updated: still says 245?"
  fi
  
  # Check README.md
  if grep -q "249" "${REPO_ROOT}/README.md"; then
    log_pass "README.md updated: 249 comandos"
  else
    log_fail "README.md NOT updated"
  fi
  
  # Check README.en.md
  if grep -q "249" "${REPO_ROOT}/README.en.md"; then
    log_pass "README.en.md updated: 249 commands"
  else
    log_fail "README.en.md NOT updated"
  fi
}

# Test 6: Check CHANGELOG entry for v0.70.0
test_changelog() {
  log_info "Test 6: Checking CHANGELOG.md v0.70.0..."
  
  if grep -q "## \[0.70.0\]" "${REPO_ROOT}/CHANGELOG.md"; then
    log_pass "CHANGELOG.md has v0.70.0 entry"
    
    # Check for key concepts in changelog
    if grep -A 10 "## \[0.70.0\]" "${REPO_ROOT}/CHANGELOG.md" | grep -qi "tenant"; then
      log_pass "CHANGELOG mentions tenant"
    else
      log_fail "CHANGELOG missing tenant mention"
    fi
    
    if grep -A 10 "## \[0.70.0\]" "${REPO_ROOT}/CHANGELOG.md" | grep -qi "marketplace"; then
      log_pass "CHANGELOG mentions marketplace"
    else
      log_fail "CHANGELOG missing marketplace mention"
    fi
  else
    log_fail "CHANGELOG.md missing v0.70.0 entry"
  fi
}

# Test 7: Verify command count in README is exactly 249
test_command_count() {
  log_info "Test 7: Checking command count summary..."
  
  # Count commands in .claude/commands directory
  actual_commands=$(find "${COMMANDS_DIR}" -name "*.md" -type f | wc -l)
  
  if [ "$actual_commands" -eq 249 ]; then
    log_pass "Total commands count verified: 249"
  else
    log_fail "Command count mismatch: found $actual_commands (expected 249)"
  fi
}

# Main execution
main() {
  echo "╔════════════════════════════════════════════════════════════════╗"
  echo "║ Test Suite: v0.70.0 Multi-Tenant & Skills Marketplace        ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo ""
  
  test_files_exist
  echo ""
  test_frontmatter
  echo ""
  test_line_counts
  echo ""
  test_concepts
  echo ""
  test_meta_files
  echo ""
  test_changelog
  echo ""
  test_command_count
  
  echo ""
  echo "╔════════════════════════════════════════════════════════════════╗"
  echo "║ Test Results                                                   ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo -e "Passed: ${GREEN}${PASS_COUNT}${NC}"
  echo -e "Failed: ${RED}${FAIL_COUNT}${NC}"
  
  if [ "$FAIL_COUNT" -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ All tests PASSED!${NC}"
    return 0
  else
    echo ""
    echo -e "${RED}✗ Some tests FAILED${NC}"
    return 1
  fi
}

main "$@"
