#!/usr/bin/env bash
# test-client-profiles.sh — Structural tests for Client Profiles (Era 31 — v2.6.0)
set -uo pipefail

PASS=0; FAIL=0

pass() { ((PASS+=1)) || true; echo "  ✅ $1"; }
fail() { ((FAIL+=1)) || true; echo "  ❌ $1"; }
check() { if eval "$2" > /dev/null 2>&1; then pass "$1"; else fail "$1"; fi; }

echo "══════════════════════════════════════════"
echo "  Client Profiles Tests (Era 31 — v2.6.0)"
echo "══════════════════════════════════════════"

# ── Section 1: Command file ────────────────────────────────────────────────
echo ""
echo "── Section 1: Command file ──"
CMD=".claude/commands/client-profile.md"
check "Command exists" "[ -f $CMD ]"
LINES=$(wc -l < "$CMD")
check "Command within line limit ($LINES/150 lines)" "[ $LINES -le 150 ]"
check "Has client-create subcommand" "grep -q 'client-create' $CMD"
check "Has client-show subcommand" "grep -q 'client-show' $CMD"
check "Has client-edit subcommand" "grep -q 'client-edit' $CMD"
check "Has client-list subcommand" "grep -q 'client-list' $CMD"
check "References config rule" "grep -q 'client-profile-config' $CMD"
check "References savia-hub config" "grep -q 'savia-hub-config' $CMD"

# ── Section 2: Domain rule ─────────────────────────────────────────────────
echo ""
echo "── Section 2: Domain rule ──"
RULE="docs/rules/domain/client-profile-config.md"
check "Config rule exists" "[ -f $RULE ]"
LINES=$(wc -l < "$RULE")
check "Config rule within limit ($LINES/150 lines)" "[ $LINES -le 150 ]"
check "Has profile.md format" "grep -q 'profile.md' $RULE"
check "Has contacts.md format" "grep -q 'contacts.md' $RULE"
check "Has rules.md format" "grep -q 'rules.md' $RULE"
check "Has slug generation rules" "grep -q 'kebab-case' $RULE"
check "Has status values" "grep -q 'active.*inactive.*prospect' $RULE"
check "Has SLA tiers" "grep -q 'basic.*standard.*premium' $RULE"
check "Has security section" "grep -q 'Seguridad' $RULE"
check "Has frontmatter format" "grep -q 'name:' $RULE && grep -q 'sector:' $RULE"
check "Has index format" "grep -q '.index.md' $RULE"

# ── Section 3: Skill ──────────────────────────────────────────────────────
echo ""
echo "── Section 3: Skill ──"
SKILL=".claude/skills/client-profile-manager/SKILL.md"
check "Skill exists" "[ -f $SKILL ]"
LINES=$(wc -l < "$SKILL")
check "Skill within limit ($LINES/150 lines)" "[ $LINES -le 150 ]"
check "Has correct name" "grep -q 'client-profile-manager' $SKILL"
check "Has create flow" "grep -q 'Crear cliente' $SKILL"
check "Has show flow" "grep -q 'Mostrar cliente' $SKILL"
check "Has edit flow" "grep -q 'Editar cliente' $SKILL"
check "Has list flow" "grep -q 'Listar clientes' $SKILL"
check "Has add project flow" "grep -q 'Añadir proyecto' $SKILL"
check "Has error handling" "grep -q 'Errores' $SKILL"
check "References savia-hub-sync" "grep -q 'savia-hub-sync' $SKILL"
check "Has security rules" "grep -q 'NUNCA.*secrets' $SKILL"

# ── Section 4: Cross-references ────────────────────────────────────────────
echo ""
echo "── Section 4: Cross-references ──"
check "Command references profile.md" "grep -q 'profile.md' $CMD"
check "Command references contacts.md" "grep -q 'contacts.md' $CMD"
check "Skill references config rule" "grep -q 'client-profile-config' $SKILL"
check "Skill references hub config" "grep -q 'savia-hub-config' $SKILL"
check "Config mentions projects dir" "grep -q 'projects/' $RULE"
check "Config mentions PII rules" "grep -q 'PII' $RULE"

# ── Section 5: Integration with SaviaHub ───────────────────────────────────
echo ""
echo "── Section 5: Integration with SaviaHub ──"
HUB_CONFIG="docs/rules/domain/savia-hub-config.md"
check "SaviaHub config exists" "[ -f $HUB_CONFIG ]"
check "SaviaHub defines clients dir" "grep -q 'clients/' $HUB_CONFIG"
check "SaviaHub defines profile.md" "grep -q 'profile.md' $HUB_CONFIG"
check "SaviaHub defines contacts.md" "grep -q 'contacts.md' $HUB_CONFIG"
check "Skill commit format matches hub" "grep -q 'savia-hub.*client' $SKILL"

echo ""
echo "══════════════════════════════════════════"
echo "  Results: $PASS/$((PASS+FAIL)) passed, $FAIL failed"
echo "══════════════════════════════════════════"
[ "$FAIL" -eq 0 ] || exit 1
