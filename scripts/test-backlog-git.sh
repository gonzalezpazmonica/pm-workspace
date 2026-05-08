#!/usr/bin/env bash
# test-backlog-git.sh — Structural tests for BacklogGit (Era 32 — v2.7.0)
set -uo pipefail

PASS=0; FAIL=0

pass() { ((PASS+=1)) || true; echo "  ✅ $1"; }
fail() { ((FAIL+=1)) || true; echo "  ❌ $1"; }
check() { if eval "$2" > /dev/null 2>&1; then pass "$1"; else fail "$1"; fi; }

echo "══════════════════════════════════════════"
echo "  BacklogGit Tests (Era 32 — v2.7.0)"
echo "══════════════════════════════════════════"

# ── Section 1: Command file ────────────────────────────────────────────────
echo ""
echo "── Section 1: Command file ──"
CMD=".opencode/commands/backlog-git.md"
check "Command exists" "[ -f $CMD ]"
LINES=$(wc -l < "$CMD")
check "Command within line limit ($LINES/150 lines)" "[ $LINES -le 150 ]"
check "Has snapshot subcommand" "grep -q 'snapshot' $CMD"
check "Has diff subcommand" "grep -q 'diff' $CMD"
check "Has rollback subcommand" "grep -q 'rollback' $CMD"
check "Has deviation-report subcommand" "grep -q 'deviation-report' $CMD"
check "References config rule" "grep -q 'backlog-git-config' $CMD"
check "References savia-hub" "grep -q 'savia-hub' $CMD"
check "References client profiles" "grep -q 'client-profile' $CMD"
check "Has snapshot format" "grep -q 'YYYYMMDD' $CMD"

# ── Section 2: Domain rule ─────────────────────────────────────────────────
echo ""
echo "── Section 2: Domain rule ──"
RULE="docs/rules/domain/backlog-git-config.md"
check "Config rule exists" "[ -f $RULE ]"
LINES=$(wc -l < "$RULE")
check "Config rule within limit ($LINES/150 lines)" "[ $LINES -le 150 ]"
check "Has snapshot location" "grep -q 'backlog-snapshots' $RULE"
check "Has Azure DevOps source" "grep -q 'Azure DevOps' $RULE"
check "Has Jira source" "grep -q 'Jira' $RULE"
check "Has GitLab source" "grep -q 'GitLab' $RULE"
check "Has Savia Flow source" "grep -q 'Savia Flow' $RULE"
check "Has manual source" "grep -q 'Manual' $RULE"
check "Has diff algorithm" "grep -q 'Algoritmo de diff' $RULE"
check "Has scope creep metric" "grep -q 'scope creep' $RULE"
check "Has immutability rule" "grep -q 'INMUTABLES' $RULE"
check "Has frequency guidance" "grep -q 'Frecuencia' $RULE"
check "Has security section" "grep -q 'Seguridad' $RULE"

# ── Section 3: Skill ──────────────────────────────────────────────────────
echo ""
echo "── Section 3: Skill ──"
SKILL=".opencode/skills/backlog-git-tracker/SKILL.md"
check "Skill exists" "[ -f $SKILL ]"
LINES=$(wc -l < "$SKILL")
check "Skill within limit ($LINES/150 lines)" "[ $LINES -le 150 ]"
check "Has correct name" "grep -q 'backlog-git-tracker' $SKILL"
check "Has snapshot flow" "grep -q 'Flujo: Snapshot' $SKILL"
check "Has diff flow" "grep -q 'Flujo: Diff' $SKILL"
check "Has rollback flow" "grep -q 'Flujo: Rollback' $SKILL"
check "Has deviation flow" "grep -q 'Flujo: Deviation' $SKILL"
check "Has manual snapshot" "grep -q 'Snapshot manual' $SKILL"
check "Has error handling" "grep -q 'Errores' $SKILL"
check "Has append-only rule" "grep -q 'append-only' $SKILL"
check "References savia-hub-sync" "grep -q 'savia-hub-sync' $SKILL"
check "References client-profile" "grep -q 'client-profile' $SKILL"
check "NEVER auto-rollback" "grep -q 'NUNCA ejecutar' $SKILL"

# ── Section 4: Cross-references ────────────────────────────────────────────
echo ""
echo "── Section 4: Cross-references ──"
HUB_CONFIG="docs/rules/domain/savia-hub-config.md"
check "SaviaHub mentions backlog-snapshots" "grep -q 'backlog-snapshots' $HUB_CONFIG"
check "Skill references hub config" "grep -q 'savia-hub-config' $SKILL"
check "Skill references backlog rule" "grep -q 'backlog-git-config' $SKILL"
check "Command mentions output dir" "grep -q 'output/' $CMD"
check "Rule mentions deviation metrics" "grep -q 'Re-estimación' $RULE"

echo ""
echo "══════════════════════════════════════════"
echo "  Results: $PASS/$((PASS+FAIL)) passed, $FAIL failed"
echo "══════════════════════════════════════════"
[ "$FAIL" -eq 0 ] || exit 1
