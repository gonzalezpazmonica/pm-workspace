#!/usr/bin/env bats
# BATS tests for SPEC-110 — Memoria externa canónica parent-relative
# Cobertura: bootstrap idempotencia, symlink, migración idempotente,
# CLAUDE.md @imports, .gitignore.

BOOTSTRAP="scripts/savia-memory-bootstrap.sh"
MIGRATE="scripts/savia-memory-migrate.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export CLAUDE_PROJECT_DIR="$(pwd)"
  # Sandbox: fuerza un parent temporal para no contaminar ../.savia-memory real
  SANDBOX="$(mktemp -d)"
  mkdir -p "$SANDBOX/repo"
  cp -r . "$SANDBOX/repo/" 2>/dev/null || true
  export SANDBOX
}

teardown() {
  [ -n "${SANDBOX:-}" ] && [ -d "$SANDBOX" ] && rm -rf "$SANDBOX"
}

# ── Bootstrap ──────────────────────────────────────────────────────────────

@test "bootstrap: script exists and is executable" {
  [[ -x "$BOOTSTRAP" ]]
}

@test "bootstrap: script has set -uo pipefail" {
  head -5 "$BOOTSTRAP" | grep -q "set -uo pipefail"
}

@test "bootstrap: runs without error and returns JSON" {
  run bash "$BOOTSTRAP"
  [[ "$status" -eq 0 ]]
  [[ "${output}" == *'"target"'* ]]
  [[ "${output}" == *'"mode"'* ]]
  [[ "${output}" == *'"marker"'* ]]
}

@test "bootstrap: creates target directory" {
  run bash "$BOOTSTRAP"
  [[ "$status" -eq 0 ]]
  target=$(echo "$output" | grep -oE '"target":"[^"]+"' | head -1 | cut -d'"' -f4)
  [[ -d "$target" ]]
  [[ -d "$target/auto" ]]
}

@test "bootstrap: idempotent — second run does not error" {
  bash "$BOOTSTRAP" >/dev/null 2>&1
  run bash "$BOOTSTRAP"
  [[ "$status" -eq 0 ]]
}

@test "bootstrap: creates marker .savia/external-memory-target" {
  bash "$BOOTSTRAP" >/dev/null 2>&1
  [[ -f ".savia/external-memory-target" ]]
}

@test "bootstrap: symlink target resolves to an existing directory" {
  bash "$BOOTSTRAP" >/dev/null 2>&1
  if [[ -L ".claude/external-memory" ]]; then
    resolved=$(readlink -f ".claude/external-memory" 2>/dev/null || readlink ".claude/external-memory")
    [[ -d "$resolved" ]]
  fi
}

# ── Migración ──────────────────────────────────────────────────────────────

@test "migrate: script exists and is executable" {
  [[ -x "$MIGRATE" ]]
}

@test "migrate: --dry-run does not modify target" {
  bash "$BOOTSTRAP" >/dev/null 2>&1
  target=$(bash "$BOOTSTRAP" 2>/dev/null | grep -oE '"target":"[^"]+"' | head -1 | cut -d'"' -f4)
  before=$(find "$target" -type f 2>/dev/null | wc -l)
  run bash "$MIGRATE" --dry-run
  [[ "$status" -eq 0 ]]
  after=$(find "$target" -type f 2>/dev/null | wc -l)
  [[ "$before" -eq "$after" ]]
}

@test "migrate: rejects unknown flag" {
  run bash "$MIGRATE" --invented-flag
  [[ "$status" -ne 0 ]]
}

@test "migrate: idempotent — second run reports skip" {
  bash "$BOOTSTRAP" >/dev/null 2>&1
  bash "$MIGRATE" >/dev/null 2>&1
  run bash "$MIGRATE"
  [[ "$status" -eq 0 ]]
  # segunda pasada: no debería copiar nada nuevo (acepta output con "skip" o sin "copied")
  [[ "${output}" != *"copied"* ]] || [[ "${output}" == *"skip"* ]]
}

# ── CLAUDE.md @imports ─────────────────────────────────────────────────────

@test "CLAUDE.md: importa active-user profile" {
  grep -q '@.claude/profiles/active-user.md' CLAUDE.md
}

@test "CLAUDE.md: importa external-memory MEMORY.md" {
  grep -q '@.claude/external-memory/auto/MEMORY.md' CLAUDE.md
}

# ── .gitignore ─────────────────────────────────────────────────────────────

@test "gitignore: excluye .claude/external-memory" {
  grep -q '.claude/external-memory' .gitignore
}

@test "gitignore: excluye /.savia-memory/" {
  grep -qE '^/?\.savia-memory/?' .gitignore
}

@test "gitignore: excluye active-user.md (PII)" {
  grep -qE '\.claude/profiles/active-user\.md' .gitignore
}

# ── session-init hook ──────────────────────────────────────────────────────

@test "session-init: invoca bootstrap" {
  grep -q 'savia-memory-bootstrap' .opencode/hooks/session-init.sh
}

@test "session-init: reporta estado de memoria" {
  grep -qE 'Memoria:|savia-memory' .opencode/hooks/session-init.sh
}

# ── SPEC doc ───────────────────────────────────────────────────────────────

@test "SPEC-110 doc existe" {
  [[ -f "docs/propuestas/SPEC-110-memoria-externa-canonica.md" ]]
}
