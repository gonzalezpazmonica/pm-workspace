#!/usr/bin/env bash
# test-vaults-cli.sh — Comprehensive test suite for vaults CLI v2
# Copyright (c) 2026 Savia. MIT License.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULTS="${SCRIPT_DIR}/vaults"
TEST_DIR="/tmp/savia-vaults-test-$$"

PASS=0; FAIL=0
GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'

pass() { echo -e "  ${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
section() { echo -e "\n${CYAN}── $1 ──${NC}"; }

cleanup() { find /tmp -maxdepth 1 -name "savia-vaults-test-*" -mmin -5 -exec rm -rf {} \; 2>/dev/null || true; }
trap cleanup EXIT

# Ensure clean state
find /tmp -maxdepth 1 -name "savia-vaults-test-$$*" -exec rm -rf {} \; 2>/dev/null || true
mkdir -p "$TEST_DIR"
export SAVIA_VAULT_ROOT="$TEST_DIR"

# Helper: run vaults command, capture stdout+stderr, return exit code + output
run_vaults() {
  local output
  set +o pipefail
  output=$("$VAULTS" "$@" 2>&1) || true
  set -o pipefail
  echo "$output"
}

echo "============================================"
echo "  vaults CLI — Test Suite v2"
echo "============================================"

# ═══ 1. Help & Version ═══
section "1. Help & Version"

run_vaults help | grep -q "Usage:" && pass "vaults help" || fail "vaults help"
run_vaults version | grep -q "v0" && pass "vaults version" || fail "vaults version"
run_vaults --help | grep -q "Usage:" && pass "vaults --help" || fail "vaults --help"
OUT=$(run_vaults invalid-cmd); echo "$OUT" | grep -q "Unknown" && pass "Unknown command rejected" || fail "Unknown cmd: $(echo "$OUT" | head -1)"

# ═══ 2. Sub-command help ═══
section "2. Sub-command help"

for cmd in server dome user backup confidentiality config; do
  run_vaults "$cmd" --help | grep -q "Usage:" && pass "vaults $cmd --help" || fail "vaults $cmd --help"
done

# ═══ 3. Dome CRUD ═══
section "3. Dome create/list/info/rename/delete"

run_vaults dome create my-docs | grep -q "created" && pass "Dome created" || fail "Dome create"
[[ -d "$TEST_DIR/my-docs" ]] && pass "Dir exists" || fail "Dir missing"
[[ -f "$TEST_DIR/my-docs/INDEX.md" ]] && pass "INDEX.md" || fail "INDEX.md"
[[ -f "$TEST_DIR/my-docs/MAP.md" ]] && pass "MAP.md" || fail "MAP.md"
[[ -d "$TEST_DIR/my-docs/.git" ]] && pass ".git init" || fail ".git"
[[ -f "$TEST_DIR/my-docs/.savia-vault/users.json" ]] && pass "users.json" || fail "users.json"

OUT=$(run_vaults dome create my-docs); echo "$OUT" | grep -q "already exists" && pass "Duplicate blocked" || fail "Duplicate not blocked: $(echo "$OUT" | head -1)"

run_vaults dome info my-docs | grep -q "my-docs" && pass "Dome info" || fail "Dome info"
run_vaults dome list | grep -q "my-docs" && pass "Dome list" || fail "Dome list"

run_vaults dome create tmp-x | grep -q "created"
run_vaults dome rename tmp-x final-x | grep -q "Renamed" && pass "Dome rename" || fail "Dome rename"
[[ -d "$TEST_DIR/final-x" && ! -d "$TEST_DIR/tmp-x" ]] && pass "Rename verified" || fail "Rename verify"

echo "y" | run_vaults dome delete final-x | grep -q "deleted" && pass "Dome delete" || fail "Dome delete"

# ═══ 4. Content & Search ═══
section "4. Content & Search"

mkdir -p "$TEST_DIR/my-docs/notes"
cat > "$TEST_DIR/my-docs/notes/arch.md" << 'DOC'
---
title: Architecture
tags: [architecture, design]
---
# Architecture
Hexagonal architecture with event sourcing and CQRS pattern.
Uses asynchronous messaging between bounded contexts.
DOC

cat > "$TEST_DIR/my-docs/notes/security.md" << 'DOC'
---
title: Security Model
tags: [security, auth, jwt]
---
# Security
JWT-based authentication with refresh token rotation.
All endpoints require Bearer token in Authorization header.
DOC

cd "$TEST_DIR/my-docs" && git add -A && git commit -m "add notes" 2>/dev/null || true
cd "$SCRIPT_DIR"

run_vaults dome search "hexagonal" --dome my-docs | grep -q "arch" && pass "Search: content found" || fail "Search: hexagonal not found"
run_vaults dome search "JWT" --dome my-docs | grep -q "security" && pass "Search: JWT found" || fail "Search: JWT not found"
OUT=$(run_vaults dome search "nonexistent99999" --dome my-docs); [[ -z "$(echo "$OUT" | grep -v '^\s*$' | grep -v '^$')" ]] && pass "Search: no results for missing" || fail "Search: false positive"

run_vaults dome stats my-docs | grep -q "my-docs" && pass "Dome stats" || fail "Dome stats"

# ═══ 5. User management ═══
section "5. User management"

echo -e "admin1234\nadmin1234" | run_vaults user add admin1 --role admin --dome my-docs | grep -q "added" && pass "User add admin" || fail "User add admin"
echo -e "reader123\nreader123" | run_vaults user add reader1 --role reader --dome my-docs | grep -q "added" && pass "User add reader" || fail "User add reader"
echo -e "writer12\nwriter12" | run_vaults user add writer1 --role writer --dome my-docs | grep -q "added" && pass "User add writer" || fail "User add writer"

run_vaults user list --dome my-docs | grep -q "admin1" && pass "User list: admin1" || fail "User list admin1"
run_vaults user list --dome my-docs | grep -q "reader1" && pass "User list: reader1" || fail "User list reader1"
run_vaults user list --dome my-docs | grep -q "writer1" && pass "User list: writer1" || fail "User list writer1"

echo -e "newpass1\nnewpass1" | run_vaults user passwd reader1 --dome my-docs | grep -q "changed" && pass "Password changed" || fail "Passwd change"

run_vaults user perm reader1 read true --dome my-docs | grep -q "Permission" && pass "Permission set" || fail "Perm set"

run_vaults user remove writer1 --dome my-docs | grep -q "removed" && pass "User removed" || fail "User remove"
! run_vaults user list --dome my-docs | grep -q "writer1" && pass "Removed user gone" || fail "Removed user persists"

# ═══ 6. Federation ═══
section "6. Federation"

run_vaults dome federate add remote1 http://localhost:19001 --weight 1.5 | grep -q "registered" && pass "Federate add" || fail "Federate add"
run_vaults dome federate add remote2 http://localhost:19002 --token tok123 | grep -q "registered" && pass "Federate add token" || fail "Federate add token"
run_vaults dome federate list | grep -q "remote1" && pass "Federate list remote1" || fail "Federate list remote1"
run_vaults dome federate list | grep -q "remote2" && pass "Federate list remote2" || fail "Federate list remote2"
run_vaults dome federate remove remote1 | grep -q "removed" && pass "Federate remove" || fail "Federate remove"
! run_vaults dome federate list | grep -q "remote1" && pass "Removed federate gone" || fail "Removed federate persists"
run_vaults dome federate health | grep -q "remote2" && pass "Federate health" || fail "Federate health"

# ═══ 7. Confidentiality ═══
section "7. Confidentiality"

run_vaults confidentiality set N2 --dome my-docs | grep -q "set to N2" && pass "Conf set N2" || fail "Conf set"
run_vaults confidentiality get --dome my-docs | grep -q "N2" && pass "Conf get N2" || fail "Conf get"
run_vaults confidentiality set N1 --dome my-docs | grep -q "set to N1" && pass "Conf set N1" || fail "Conf set N1"
run_vaults confidentiality list | grep -q "my-docs" && pass "Conf list" || fail "Conf list"
run_vaults confidentiality audit --dome my-docs | grep -q "complete" && pass "Conf audit" || fail "Conf audit"

# ═══ 8. Backup ═══
section "8. Backup"

run_vaults backup create --name my-docs --compress | grep -q "created" && pass "Backup create" || fail "Backup create"
run_vaults backup list | grep -q "backup" && pass "Backup list" || fail "Backup list"
run_vaults backup status >/dev/null 2>&1 && pass "Backup status" || fail "Backup status"

BACKUP_ID=$(ls "$TEST_DIR/.backups/" 2>/dev/null | head -1)
if [[ -n "$BACKUP_ID" ]]; then
  run_vaults backup restore "$BACKUP_ID" --target "$TEST_DIR/restore-test" --dry-run | grep -q "Dry run" && pass "Backup dry-run" || fail "Backup dry-run"
fi

# ═══ 9. Config ═══
section "9. Config"

run_vaults config show | grep -q "savia-vaults" && pass "Config show" || fail "Config show"

# ═══ 10. Server commands ═══
section "10. Server commands"

run_vaults server start --name nonexistent123 | grep -q "not found" && pass "Server start: missing dome error" || fail "Server start missing dome"
run_vaults server stop --name nonexistent123 | grep -q "No running" && pass "Server stop: not running error" || fail "Server stop"
run_vaults server status --name nonexistent123 | grep -q "STOPPED" && pass "Server status: stopped shown" || fail "Server status"

# ═══ 11. Health ═══
section "11. Health"

run_vaults health | grep -q "Vault root" && pass "Health: vault root" || fail "Health vault root"
run_vaults health | grep -q "Domes:" && pass "Health: domes count" || fail "Health domes"
run_vaults health | grep -q "Backups:" && pass "Health: backups count" || fail "Health backups"

echo ""
echo "============================================"
echo "  Result: $PASS PASS | $FAIL FAIL"
echo "============================================"

[[ $FAIL -gt 0 ]] && exit 1 || exit 0
