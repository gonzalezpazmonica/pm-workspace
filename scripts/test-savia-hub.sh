#!/usr/bin/env bash
# test-savia-hub.sh — Structural tests for SaviaHub (Era 30)
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0

pass() { ((PASS+=1)) || true; ((TOTAL+=1)) || true; echo "  ✅ $1"; }
fail() { ((FAIL+=1)) || true; ((TOTAL+=1)) || true; echo "  ❌ $1"; }

check_file() { [ -f "$1" ] && pass "$2" || fail "$2 — missing: $1"; }
check_dir()  { [ -d "$1" ] && pass "$2" || fail "$2 — missing: $1"; }

check_content() {
  if grep -q "$2" "$1" 2>/dev/null; then
    pass "$3"
  else
    fail "$3 — pattern '$2' not found in $1"
  fi
}

check_lines() {
  local lines
  lines=$(wc -l < "$1" 2>/dev/null || echo 999)
  if [ "$lines" -le "$2" ]; then
    pass "$3 ($lines/$2 lines)"
  else
    fail "$3 — $lines lines exceeds $2 limit"
  fi
}

echo ""
echo "══════════════════════════════════════════"
echo "  SaviaHub Tests (Era 30 — v2.5.0)"
echo "══════════════════════════════════════════"

# ── Section 1: Command ───────────────────────────────────────────────────
echo ""
echo "── Section 1: Command file ──"
check_file ".claude/commands/savia-hub.md" "Command exists"
check_lines ".claude/commands/savia-hub.md" 150 "Command within line limit"
check_content ".claude/commands/savia-hub.md" "savia-hub init" "Has init subcommand"
check_content ".claude/commands/savia-hub.md" "savia-hub status" "Has status subcommand"
check_content ".claude/commands/savia-hub.md" "savia-hub push" "Has push subcommand"
check_content ".claude/commands/savia-hub.md" "savia-hub pull" "Has pull subcommand"
check_content ".claude/commands/savia-hub.md" "flight-mode" "Has flight-mode subcommand"
check_content ".claude/commands/savia-hub.md" "savia-hub-config.md" "References config rule"
check_content ".claude/commands/savia-hub.md" "savia-hub-offline.md" "References offline rule"

# ── Section 2: Rules ─────────────────────────────────────────────────────
echo ""
echo "── Section 2: Domain rules ──"
check_file ".claude/rules/domain/savia-hub-config.md" "Config rule exists"
check_lines ".claude/rules/domain/savia-hub-config.md" 150 "Config rule within limit"
check_content ".claude/rules/domain/savia-hub-config.md" "SAVIA_HUB_PATH" "Has path config"
check_content ".claude/rules/domain/savia-hub-config.md" "SAVIA_HUB_REMOTE" "Has remote config"
check_content ".claude/rules/domain/savia-hub-config.md" "company/" "Has company dir"
check_content ".claude/rules/domain/savia-hub-config.md" "clients/" "Has clients dir"
check_content ".claude/rules/domain/savia-hub-config.md" "users/" "Has users dir"

check_file ".claude/rules/domain/savia-hub-offline.md" "Offline rule exists"
check_lines ".claude/rules/domain/savia-hub-offline.md" 150 "Offline rule within limit"
check_content ".claude/rules/domain/savia-hub-offline.md" "flight.mode" "Has flight mode"
check_content ".claude/rules/domain/savia-hub-offline.md" "sync-queue" "Has sync queue"
check_content ".claude/rules/domain/savia-hub-offline.md" "NUNCA auto-resolver" "Has safety rule"

# ── Section 3: Skill ─────────────────────────────────────────────────────
echo ""
echo "── Section 3: Skill ──"
check_file ".claude/skills/savia-hub-sync/SKILL.md" "Skill exists"
check_lines ".claude/skills/savia-hub-sync/SKILL.md" 150 "Skill within limit"
check_content ".claude/skills/savia-hub-sync/SKILL.md" "name: savia-hub-sync" "Has correct name"
check_content ".claude/skills/savia-hub-sync/SKILL.md" "git init" "Has local init flow"
check_content ".claude/skills/savia-hub-sync/SKILL.md" "git clone" "Has remote clone flow"
check_content ".claude/skills/savia-hub-sync/SKILL.md" "git push" "Has push flow"
check_content ".claude/skills/savia-hub-sync/SKILL.md" "git pull" "Has pull flow"

# ── Section 4: Init script ───────────────────────────────────────────────
echo ""
echo "── Section 4: Init script ──"
check_file "scripts/savia-hub-init.sh" "Init script exists"
check_lines "scripts/savia-hub-init.sh" 150 "Init script within limit"
check_content "scripts/savia-hub-init.sh" "#!/usr/bin/env bash" "Has shebang"
check_content "scripts/savia-hub-init.sh" "set -euo pipefail" "Has strict mode"
check_content "scripts/savia-hub-init.sh" "\-\-remote" "Has --remote flag"
check_content "scripts/savia-hub-init.sh" "\-\-path" "Has --path flag"
check_content "scripts/savia-hub-init.sh" "\-\-help" "Has --help flag"
check_content "scripts/savia-hub-init.sh" "company/identity.md" "Creates company identity"
check_content "scripts/savia-hub-init.sh" "clients/.index.md" "Creates clients index"
check_content "scripts/savia-hub-init.sh" ".gitignore" "Creates .gitignore"
check_content "scripts/savia-hub-init.sh" "savia-hub-config.md" "Creates local config"
[ -x "scripts/savia-hub-init.sh" ] && pass "Init script is executable" || fail "Init script not executable"

# ── Section 5: Cross-references ──────────────────────────────────────────
echo ""
echo "── Section 5: Cross-references ──"
check_content ".claude/commands/savia-hub.md" "company/" "Command references company dir"
check_content ".claude/commands/savia-hub.md" "clients/" "Command references clients dir"
check_content ".claude/rules/domain/savia-hub-config.md" ".savia-hub-config.md" "Config mentions local config file"
check_content ".claude/rules/domain/savia-hub-offline.md" ".sync-queue.jsonl" "Offline references queue file"

# ── Results ──────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════"
echo "  Results: $PASS/$TOTAL passed, $FAIL failed"
echo "══════════════════════════════════════════"
echo ""

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
