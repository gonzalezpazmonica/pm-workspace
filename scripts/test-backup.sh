#!/bin/bash
# test-backup.sh — Tests del sistema de backup cifrado
set -euo pipefail

PASS=0
FAIL=0
WORKSPACE_DIR="${PM_WORKSPACE_ROOT:-$HOME/claude}"

pass() { PASS=$((PASS+1)); echo "  ✅ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }

check_file() {
  local file="$WORKSPACE_DIR/$1"
  local label="$2"
  [ -f "$file" ] && pass "Existe: $label" || fail "No existe: $label"
}

check_contains() {
  local file="$WORKSPACE_DIR/$1"
  local pattern="$2"
  local label="$3"
  if grep -q "$pattern" "$file" 2>/dev/null; then
    pass "Contiene '$pattern' en $label"
  else
    fail "No contiene '$pattern' en $label"
  fi
}

check_executable() {
  local file="$WORKSPACE_DIR/$1"
  local label="$2"
  [ -x "$file" ] && pass "Ejecutable: $label" || fail "No ejecutable: $label"
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Test Suite: Backup System"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "📄 Ficheros del sistema de backup"
check_file "scripts/backup.sh" "scripts/backup.sh"
check_executable "scripts/backup.sh" "scripts/backup.sh"
check_file ".claude/commands/backup.md" "backup.md"
check_file ".claude/rules/domain/backup-protocol.md" "backup-protocol.md"

echo ""
echo "🔧 Contenido de scripts/backup.sh"
check_contains "scripts/backup.sh" "do_now" "backup.sh"
check_contains "scripts/backup.sh" "do_restore" "backup.sh"
check_contains "scripts/backup.sh" "do_auto_on" "backup.sh"
check_contains "scripts/backup.sh" "do_auto_off" "backup.sh"
check_contains "scripts/backup.sh" "do_status" "backup.sh"
check_contains "scripts/backup.sh" "do_encrypt" "backup.sh"
check_contains "scripts/backup.sh" "do_decrypt" "backup.sh"
check_contains "scripts/backup.sh" "aes-256-cbc" "backup.sh (cipher)"
check_contains "scripts/backup.sh" "pbkdf2" "backup.sh (key derivation)"
check_contains "scripts/backup.sh" "100000" "backup.sh (iterations)"
check_contains "scripts/backup.sh" "sha256sum" "backup.sh (manifest)"
check_contains "scripts/backup.sh" "MANIFEST" "backup.sh (manifest file)"
check_contains "scripts/backup.sh" "rotate_backups" "backup.sh"
check_contains "scripts/backup.sh" "MAX_BACKUPS" "backup.sh"
check_contains "scripts/backup.sh" "upload_nextcloud" "backup.sh"
check_contains "scripts/backup.sh" "WebDAV" "backup.sh"
check_contains "scripts/backup.sh" "gdrive" "backup.sh"
check_contains "scripts/backup.sh" "active-user.md" "backup.sh"
check_contains "scripts/backup.sh" "CLAUDE.local.md" "backup.sh"
check_contains "scripts/backup.sh" "devops-pat" "backup.sh"

echo ""
echo "📋 Contenido de backup.md (comando)"
check_contains ".claude/commands/backup.md" "name: backup" "backup.md"
check_contains ".claude/commands/backup.md" "now" "backup.md"
check_contains ".claude/commands/backup.md" "restore" "backup.md"
check_contains ".claude/commands/backup.md" "auto-on" "backup.md"
check_contains ".claude/commands/backup.md" "auto-off" "backup.md"
check_contains ".claude/commands/backup.md" "status" "backup.md"
check_contains ".claude/commands/backup.md" "AES-256" "backup.md"
check_contains ".claude/commands/backup.md" "Savia" "backup.md"
check_contains ".claude/commands/backup.md" "NUNCA" "backup.md"
check_contains ".claude/commands/backup.md" "backup-protocol" "backup.md"

echo ""
echo "🔒 Contenido de backup-protocol.md"
check_contains ".claude/rules/domain/backup-protocol.md" "AES-256-CBC" "backup-protocol.md"
check_contains ".claude/rules/domain/backup-protocol.md" "PBKDF2" "backup-protocol.md"
check_contains ".claude/rules/domain/backup-protocol.md" "100.000" "backup-protocol.md"
check_contains ".claude/rules/domain/backup-protocol.md" "NextCloud" "backup-protocol.md"
check_contains ".claude/rules/domain/backup-protocol.md" "Google Drive" "backup-protocol.md"
check_contains ".claude/rules/domain/backup-protocol.md" "SHA-256" "backup-protocol.md"
check_contains ".claude/rules/domain/backup-protocol.md" "7 backups" "backup-protocol.md"
check_contains ".claude/rules/domain/backup-protocol.md" "profiles/users" "backup-protocol.md"
check_contains ".claude/rules/domain/backup-protocol.md" "CLAUDE.local.md" "backup-protocol.md"
check_contains ".claude/rules/domain/backup-protocol.md" "devops-pat" "backup-protocol.md"

echo ""
echo "🪝 Integración con session-init.sh"
check_contains ".claude/hooks/session-init.sh" "backup" "session-init.sh"
check_contains ".claude/hooks/session-init.sh" "backup-config" "session-init.sh"
check_contains ".claude/hooks/session-init.sh" "auto_backup" "session-init.sh"
check_contains ".claude/hooks/session-init.sh" "86400" "session-init.sh"
check_contains ".claude/hooks/session-init.sh" "/backup" "session-init.sh"

echo ""
echo "📖 Integración con CLAUDE.md"
check_contains "CLAUDE.md" "/backup" "CLAUDE.md"
check_contains "CLAUDE.md" "commands/ (150)" "CLAUDE.md"

echo ""
echo "📖 Integración con README.md"
check_contains "README.md" "/backup" "README.md"
check_contains "README.md" "150 comandos" "README.md"
check_contains "README.md" "Backup" "README.md"

echo ""
echo "📖 Integración con README.en.md"
check_contains "README.en.md" "/backup" "README.en.md"
check_contains "README.en.md" "150 commands" "README.en.md"
check_contains "README.en.md" "backup" "README.en.md"

echo ""
echo "🔐 Cifrado/descifrado funciona"
TEST_DIR=$(mktemp -d)
mkdir -p "$TEST_DIR/data"
echo "test-content-$(date +%s)" > "$TEST_DIR/data/test.txt"
sha256sum "$TEST_DIR/data/test.txt" > "$TEST_DIR/data/MANIFEST.sha256"
TEST_PASS="test-passphrase-12345"
TEST_ENC="$TEST_DIR/test.enc"

# Cifrar
tar czf - -C "$TEST_DIR" data 2>/dev/null | \
  openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 \
  -pass "pass:$TEST_PASS" -out "$TEST_ENC" 2>/dev/null
if [ -f "$TEST_ENC" ]; then
  pass "Cifrado AES-256 funciona"
else
  fail "Cifrado AES-256 NO funciona"
fi

# Descifrar
RESTORE_DIR="$TEST_DIR/restore"
mkdir -p "$RESTORE_DIR"
openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 \
  -pass "pass:$TEST_PASS" -in "$TEST_ENC" 2>/dev/null | \
  tar xzf - -C "$RESTORE_DIR" 2>/dev/null
if [ -f "$RESTORE_DIR/data/test.txt" ]; then
  pass "Descifrado funciona"
else
  fail "Descifrado NO funciona"
fi

# Verificar integridad
if [ -f "$RESTORE_DIR/data/MANIFEST.sha256" ]; then
  cd "$RESTORE_DIR/data"
  if sha256sum -c MANIFEST.sha256 --quiet 2>/dev/null; then
    pass "Verificación SHA256 funciona"
  else
    fail "Verificación SHA256 NO funciona"
  fi
  cd - >/dev/null
else
  fail "MANIFEST.sha256 no encontrado tras descifrar"
fi

rm -rf "$TEST_DIR"

echo ""
echo "📋 backup.sh help funciona"
HELP_OUTPUT=$(cd "$WORKSPACE_DIR" && bash scripts/backup.sh help 2>&1)
if echo "$HELP_OUTPUT" | grep -q "Comandos"; then
  pass "backup.sh help muestra ayuda"
else
  fail "backup.sh help NO muestra ayuda"
fi

echo ""
echo "📋 backup.sh status funciona"
STATUS_OUTPUT=$(cd "$WORKSPACE_DIR" && bash scripts/backup.sh status 2>&1)
if echo "$STATUS_OUTPUT" | grep -q "Auto-backup"; then
  pass "backup.sh status muestra auto-backup"
else
  fail "backup.sh status NO muestra auto-backup"
fi

echo ""
echo "⚙️  Hook produce JSON válido"
HOOK_OUTPUT=$(cd "$WORKSPACE_DIR" && bash .claude/hooks/session-init.sh 2>/dev/null)
if echo "$HOOK_OUTPUT" | jq . >/dev/null 2>&1; then
  pass "session-init.sh produce JSON válido"
else
  fail "session-init.sh NO produce JSON válido"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
TOTAL=$((PASS + FAIL))
echo "📊 Resultado: $PASS/$TOTAL tests passed ($FAIL failed)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$FAIL" -eq 0 ]; then
  echo "✅ Todos los tests pasaron"
else
  echo "❌ Hay tests fallidos"
  exit 1
fi
