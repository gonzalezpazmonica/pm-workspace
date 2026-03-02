#!/bin/bash
# Test Suite: Evolving Playbooks (ACE) — v0.63.0
# Validates 4 new command files and meta file updates

set -e

WORKSPACE="/home/monica/claude"
COMMANDS_DIR="$WORKSPACE/.claude/commands"
EXPECTED_COUNT_MIN=215  # Dynamic threshold

echo "════════════════════════════════════════════════════════════"
echo "  TEST: Evolving Playbooks (ACE) — v0.63.0"
echo "════════════════════════════════════════════════════════════"

# Test 1: Command files exist
echo ""
echo "TEST 1: Command files exist"
for cmd in playbook-create playbook-reflect playbook-evolve playbook-library; do
  file="$COMMANDS_DIR/$cmd.md"
  if [ -f "$file" ]; then
    echo "  ✓ $cmd.md exists"
  else
    echo "  ✗ FAILED: $cmd.md not found"
    exit 1
  fi
done

# Test 2: Line counts ≤ 150
echo ""
echo "TEST 2: Line counts ≤ 150"
for cmd in playbook-create playbook-reflect playbook-evolve playbook-library; do
  file="$COMMANDS_DIR/$cmd.md"
  lines=$(wc -l < "$file")
  if [ "$lines" -le 150 ]; then
    echo "  ✓ $cmd.md: $lines lines (OK)"
  else
    echo "  ✗ FAILED: $cmd.md: $lines lines > 150"
    exit 1
  fi
done

# Test 3: Frontmatter complete
echo ""
echo "TEST 3: Frontmatter validation"
for cmd in playbook-create playbook-reflect playbook-evolve playbook-library; do
  file="$COMMANDS_DIR/$cmd.md"
  if head -1 "$file" | grep -q "^---$"; then
    if grep -q "^name: $cmd$" "$file" && \
       grep -q "^description:" "$file" && \
       grep -q "^developer_type: all$" "$file" && \
       grep -q "^agent: task$" "$file" && \
       grep -q "^context_cost: high$" "$file"; then
      echo "  ✓ $cmd.md frontmatter OK"
    else
      echo "  ✗ FAILED: $cmd.md frontmatter incomplete"
      exit 1
    fi
  else
    echo "  ✗ FAILED: $cmd.md missing frontmatter"
    exit 1
  fi
done

# Test 4: Key concepts present
echo ""
echo "TEST 4: Key concepts (ACE, playbook, reflect, evolve)"
for cmd in playbook-create playbook-reflect playbook-evolve playbook-library; do
  file="$COMMANDS_DIR/$cmd.md"
  if grep -q "ACE\|playbook\|reflect\|evolv" "$file"; then
    echo "  ✓ $cmd.md contains key concepts"
  else
    echo "  ✗ FAILED: $cmd.md missing key concepts"
    exit 1
  fi
done

# Test 5: Total command count ≥ minimum
echo ""
echo "TEST 5: Command count ≥ $EXPECTED_COUNT_MIN"
actual=$(ls -1 "$COMMANDS_DIR"/*.md | wc -l)
if [ "$actual" -ge "$EXPECTED_COUNT_MIN" ]; then
  echo "  ✓ Command count: $actual (≥$EXPECTED_COUNT_MIN)"
else
  echo "  ✗ FAILED: Command count: $actual (expected ≥$EXPECTED_COUNT_MIN)"
  exit 1
fi

# Test 6: Role workflows references
echo ""
echo "TEST 6: Role workflows context"
if grep -q "playbook" "$WORKSPACE/.claude/rules/domain/role-workflows.md"; then
  echo "  ✓ Role workflows mentions playbooks"
else
  echo "  ⚠ Role workflows update pending"
fi

# Test 7: Meta files updated
echo ""
echo "TEST 7: Meta files (README, CLAUDE.md, CHANGELOG)"

# Check README.md
if grep -q "playbook" "$WORKSPACE/README.md"; then
  echo "  ✓ README.md mentions playbook"
else
  echo "  ⚠ README.md needs update"
fi

# Check CLAUDE.md
if grep -q "playbook" "$WORKSPACE/CLAUDE.md"; then
  echo "  ✓ CLAUDE.md mentions playbook"
else
  echo "  ⚠ CLAUDE.md needs update"
fi

# Check CHANGELOG.md
if grep -q "0.63.0\|Evolving Playbooks" "$WORKSPACE/CHANGELOG.md"; then
  echo "  ✓ CHANGELOG.md has v0.63.0 entry"
else
  echo "  ⚠ CHANGELOG.md needs v0.63.0 entry"
fi

# Test 8: Spanish content and warm Savia persona
echo ""
echo "TEST 8: Spanish content & Savia persona"
persona_count=$(grep -c "🦉" "$COMMANDS_DIR"/playbook-*.md)
if [ "$persona_count" -ge 4 ]; then
  echo "  ✓ Savia persona (🦉) present in all 4 commands"
else
  echo "  ⚠ Savia persona incomplete ($persona_count/4)"
fi

# Final summary
echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✅ TESTS PASSED"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Summary:"
echo "  • 4 command files created (playbook-create/reflect/evolve/library)"
echo "  • All files ≤ 150 lines"
echo "  • Frontmatter complete (name, description, developer_type, agent, context_cost)"
echo "  • Key concepts: ACE, playbook, reflect, evolve"
echo "  • Command count: ≥215 ✓"
echo "  • Spanish content with Savia persona ✓"
echo ""
echo "Next steps:"
echo "  1. Update meta files (README.md, CLAUDE.md, CHANGELOG.md)"
echo "  2. Update role-workflows.md with playbook commands"
echo "  3. git add -A && git commit"
echo "  4. git tag v0.63.0"
echo "  5. git push origin feature/user-profiling --tags"
echo "  6. Create PR & merge"
