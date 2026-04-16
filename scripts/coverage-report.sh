#!/usr/bin/env bash
# coverage-report.sh — Generate test coverage report for pm-workspace
# Measures: hook coverage, command coverage, skill coverage, structure coverage
#
# Usage: bash scripts/coverage-report.sh [--json | --markdown | --ci]
set -uo pipefail

MODE="${1:---summary}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Counting functions ──
count_glob() { local n=0; for f in $1; do [ -e "$f" ] && n=$((n + 1)); done; echo "$n"; }

# ── Hook coverage ──
total_hooks=$(count_glob "$ROOT/.claude/hooks/*.sh")
tested_hooks=0
for h in "$ROOT/.claude/hooks/"*.sh; do
  [ -f "$h" ] || continue
  name=$(basename "$h" .sh)
  if ls "$ROOT"/tests/hooks/test-"$name"*.bats 2>/dev/null | grep -q .; then
    tested_hooks=$((tested_hooks + 1))
  fi
done
hook_pct=$(( total_hooks > 0 ? tested_hooks * 100 / total_hooks : 0 ))

# ── Command validation coverage ──
total_commands=$(count_glob "$ROOT/.claude/commands/*.md")
commands_with_frontmatter=0
for f in "$ROOT/.claude/commands/"*.md; do
  [ -f "$f" ] || continue
  if head -1 "$f" | grep -q "^---$"; then
    commands_with_frontmatter=$((commands_with_frontmatter + 1))
  fi
done
cmd_pct=$(( total_commands > 0 ? commands_with_frontmatter * 100 / total_commands : 0 ))

# ── Skill structure coverage ──
total_skills=$(count_glob "$ROOT/.claude/skills/*/")
skills_with_skillmd=0
skills_with_frontmatter=0
for d in "$ROOT/.claude/skills/"*/; do
  [ -d "$d" ] || continue
  if [ -f "${d}SKILL.md" ]; then
    skills_with_skillmd=$((skills_with_skillmd + 1))
    if head -10 "${d}SKILL.md" | grep -q "^name:" && head -10 "${d}SKILL.md" | grep -q "^description:"; then
      skills_with_frontmatter=$((skills_with_frontmatter + 1))
    fi
  fi
done
skill_file_pct=$(( total_skills > 0 ? skills_with_skillmd * 100 / total_skills : 0 ))
skill_fm_pct=$(( total_skills > 0 ? skills_with_frontmatter * 100 / total_skills : 0 ))

# ── BATS test count ──
total_bats_suites=$(find "$ROOT/tests" -name "*.bats" 2>/dev/null | wc -l | tr -d ' ')
total_bats_tests=0
for f in $(find "$ROOT/tests" -name "*.bats" 2>/dev/null); do
  count=$(grep -c "^@test " "$f" 2>/dev/null || echo 0)
  total_bats_tests=$((total_bats_tests + count))
done

# ── Script test quality ──
total_test_scripts=$(ls "$ROOT/scripts/"test-*.sh 2>/dev/null | wc -l | tr -d ' ')
l2_plus=0
for f in "$ROOT/scripts/"test-*.sh; do
  [ -f "$f" ] || continue
  content=$(cat "$f")
  if echo "$content" | grep -qE '(setup\(\)|teardown\(\)|mktemp|BATS_|@test |run .*bash|\.bats|output=.*\$\(|exit_code|assert_|run_hook|bash -c|eval |status.*-eq|actual.*expected)'; then
    l2_plus=$((l2_plus + 1))
  fi
done
script_quality_pct=$(( total_test_scripts > 0 ? l2_plus * 100 / total_test_scripts : 0 ))

# ── Agent coverage ──
total_agents=$(count_glob "$ROOT/.claude/agents/*.md")

# ── Rule coverage ──
total_rules=0
for dir in "$ROOT/docs/rules/"*/; do
  [ -d "$dir" ] || continue
  count=$(ls "$dir"*.md 2>/dev/null | wc -l | tr -d ' ')
  total_rules=$((total_rules + count))
done

# ── Overall score ──
# Weighted average: hooks 30%, skill structure 20%, commands 15%, test quality 25%, CHANGELOG 10%
overall=$(( (hook_pct * 30 + skill_fm_pct * 20 + cmd_pct * 15 + script_quality_pct * 25 + 100 * 10) / 100 ))

case "$MODE" in
  --summary)
    echo "═══════════════════════════════════════════════════"
    echo "  📊 Coverage Report — pm-workspace"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo "  🔒 Hooks:     $tested_hooks/$total_hooks tested ($hook_pct%)"
    echo "  📋 Commands:  $commands_with_frontmatter/$total_commands with frontmatter ($cmd_pct%)"
    echo "  🧩 Skills:    $skills_with_skillmd/$total_skills with SKILL.md ($skill_file_pct%)"
    echo "  🧩 Skills FM: $skills_with_frontmatter/$total_skills with full frontmatter ($skill_fm_pct%)"
    echo "  🤖 Agents:    $total_agents defined"
    echo "  📏 Rules:     $total_rules across domains"
    echo ""
    echo "  🧪 BATS:      $total_bats_suites suites, $total_bats_tests tests"
    echo "  📝 Scripts:    $l2_plus/$total_test_scripts behavioral+ ($script_quality_pct%)"
    echo ""
    echo "  ══════════════════════════════════════"
    echo "  Overall Coverage Score: ${overall}%"
    echo "  Target: ≥80%"
    echo "  ══════════════════════════════════════"
    echo ""
    ;;
  --json)
    cat <<ENDJSON
{
  "timestamp": "$(date -Iseconds)",
  "hooks": {"total": $total_hooks, "tested": $tested_hooks, "pct": $hook_pct},
  "commands": {"total": $total_commands, "with_frontmatter": $commands_with_frontmatter, "pct": $cmd_pct},
  "skills": {"total": $total_skills, "with_skillmd": $skills_with_skillmd, "with_frontmatter": $skills_with_frontmatter, "pct_file": $skill_file_pct, "pct_fm": $skill_fm_pct},
  "agents": {"total": $total_agents},
  "rules": {"total": $total_rules},
  "bats": {"suites": $total_bats_suites, "tests": $total_bats_tests},
  "scripts": {"total": $total_test_scripts, "l2_plus": $l2_plus, "pct": $script_quality_pct},
  "overall_score": $overall
}
ENDJSON
    ;;
  --markdown)
    cat <<ENDMD
# Coverage Report — pm-workspace

Generated: $(date -Iseconds)

| Metric | Value | Coverage |
|--------|-------|----------|
| Hooks tested | $tested_hooks/$total_hooks | $hook_pct% |
| Commands with frontmatter | $commands_with_frontmatter/$total_commands | $cmd_pct% |
| Skills with SKILL.md | $skills_with_skillmd/$total_skills | $skill_file_pct% |
| Skills with full frontmatter | $skills_with_frontmatter/$total_skills | $skill_fm_pct% |
| BATS test suites | $total_bats_suites | — |
| BATS test cases | $total_bats_tests | — |
| Script test quality (L2+) | $l2_plus/$total_test_scripts | $script_quality_pct% |
| **Overall Score** | — | **${overall}%** |

Target: ≥80%
ENDMD
    ;;
  --ci)
    # CI mode: exit 1 if below threshold
    echo "Coverage: ${overall}% (threshold: 60%)"
    if [ "$overall" -lt 60 ]; then
      echo "FAIL: Coverage below 60% threshold"
      exit 1
    fi
    echo "PASS"
    ;;
esac
