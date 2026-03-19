#!/usr/bin/env bash
# vault-ops.sh — Personal Vault operations library (N3). Sourced by vault.sh.
set -uo pipefail

# ── Init ──────────────────────────────────────────────────────────────────────
do_init() {
  if vault_exists; then
    echo "Vault already exists at $VAULT_PATH"; do_status; return 0
  fi

  echo "Creating vault at $VAULT_PATH ..."
  mkdir -p "$VAULT_PATH"/{profile,rules,globals,instincts,memory,cache,history}

  local active_file="$WORKSPACE_ROOT/.claude/profiles/active-user.md"
  local slug=""
  [[ -f "$active_file" ]] && slug=$(grep -oP 'active_slug:\s*\K\S+' "$active_file" 2>/dev/null || true)

  local migrated=0
  if [[ -n "$slug" && -d "$WORKSPACE_ROOT/.claude/profiles/users/$slug" ]]; then
    cp -r "$WORKSPACE_ROOT/.claude/profiles/users/$slug/"* "$VAULT_PATH/profile/" 2>/dev/null && migrated=$((migrated+1))
    echo "  Migrated profile ($slug)"
  fi
  if [[ -d "$HOME/.claude/rules" ]]; then
    cp "$HOME/.claude/rules/"*.md "$VAULT_PATH/rules/" 2>/dev/null && migrated=$((migrated+1))
    echo "  Migrated user rules"
  fi
  if [[ -f "$HOME/.claude/CLAUDE.md" ]]; then
    cp "$HOME/.claude/CLAUDE.md" "$VAULT_PATH/globals/CLAUDE.md" 2>/dev/null && migrated=$((migrated+1))
    echo "  Migrated global CLAUDE.md"
  fi
  if [[ -f "$WORKSPACE_ROOT/.claude/instincts/registry.json" ]]; then
    cp "$WORKSPACE_ROOT/.claude/instincts/registry.json" "$VAULT_PATH/instincts/" 2>/dev/null && migrated=$((migrated+1))
    echo "  Migrated instincts"
  fi

  cat > "$VAULT_PATH/CLAUDE.md" << 'EOF'
# Personal Vault — N3 (USUARIO)
> Datos personales. NUNCA mezclar con datos de proyecto (N4) ni empresa (N2).
## Estructura
- profile/ — identity, tone, workflow, tools, preferences
- rules/ — reglas personales del usuario
- globals/ — CLAUDE.md personal
- instincts/ — patrones aprendidos
- memory/ — memoria persistente cross-project N3
- cache/ — logs de confianza y contexto
- history/ — registro de sincronizaciones
EOF

  printf "cache/*.log\nhistory/sync-log.jsonl\n*.tmp\n*.bak\n" > "$VAULT_PATH/.gitignore"

  git -C "$VAULT_PATH" init -b main > /dev/null 2>&1
  git -C "$VAULT_PATH" add -A > /dev/null 2>&1
  git -C "$VAULT_PATH" commit -m "feat: initial vault" > /dev/null 2>&1

  local junctions=0
  if [[ -n "$slug" ]]; then
    local profile_src="$WORKSPACE_ROOT/.claude/profiles/users/$slug"
    if [[ -d "$profile_src" && ! -L "$profile_src" ]]; then
      rm -rf "$profile_src"
      create_junction "$VAULT_PATH/profile" "$profile_src" && junctions=$((junctions+1))
      echo "  Junction: profiles/users/$slug/ -> vault/profile/"
    fi
  fi
  if [[ -d "$WORKSPACE_ROOT/.claude/instincts" && ! -L "$WORKSPACE_ROOT/.claude/instincts" ]]; then
    rm -rf "$WORKSPACE_ROOT/.claude/instincts"
    create_junction "$VAULT_PATH/instincts" "$WORKSPACE_ROOT/.claude/instincts" && junctions=$((junctions+1))
    echo "  Junction: .claude/instincts/ -> vault/instincts/"
  fi

  echo "Vault initialized: $VAULT_PATH ($migrated migrated, $junctions junctions, N3)"
}

# ── Sync ──────────────────────────────────────────────────────────────────────
do_sync() {
  if ! vault_exists; then echo "ERROR: No vault. Run vault.sh init"; return 1; fi
  local changes
  changes=$(git -C "$VAULT_PATH" status --porcelain 2>/dev/null | wc -l)
  if [[ "$changes" -eq 0 ]]; then echo "Vault clean."; return 0; fi

  git -C "$VAULT_PATH" add -A > /dev/null 2>&1
  git -C "$VAULT_PATH" commit -m "sync: $(date +%Y-%m-%d_%H:%M)" > /dev/null 2>&1
  echo "Committed $changes file(s)."

  local remote; remote=$(git -C "$VAULT_PATH" remote get-url origin 2>/dev/null || true)
  if [[ -n "$remote" ]]; then
    git -C "$VAULT_PATH" push 2>/dev/null && echo "Pushed to $remote" || echo "WARNING: Push failed."
  else
    echo "No remote. Local commit only."
  fi
  mkdir -p "$VAULT_PATH/history"
  echo "{\"ts\":\"$(date -Iseconds)\",\"files\":$changes}" >> "$VAULT_PATH/history/sync-log.jsonl"
}

# ── Status ────────────────────────────────────────────────────────────────────
do_status() {
  if ! vault_exists; then echo "No vault at $VAULT_PATH. Run: vault.sh init"; return 1; fi
  echo "Vault: $VAULT_PATH"

  local ok=0 total=0 slug=""
  local active_file="$WORKSPACE_ROOT/.claude/profiles/active-user.md"
  [[ -f "$active_file" ]] && slug=$(grep -oP 'active_slug:\s*\K\S+' "$active_file" 2>/dev/null || true)
  [[ -n "$slug" ]] && { total=$((total+1)); junction_ok "$WORKSPACE_ROOT/.claude/profiles/users/$slug" && ok=$((ok+1)); }
  total=$((total+1)); junction_ok "$WORKSPACE_ROOT/.claude/instincts" && ok=$((ok+1))
  echo "Junctions: $ok/$total valid"

  local changes; changes=$(git -C "$VAULT_PATH" status --porcelain 2>/dev/null | wc -l)
  echo "Uncommitted: $changes file(s)"
  echo "Last commit: $(git -C "$VAULT_PATH" log -1 --format="%ci" 2>/dev/null || echo "never")"

  local remote; remote=$(git -C "$VAULT_PATH" remote get-url origin 2>/dev/null || true)
  echo "Remote: ${remote:-not configured}"
  echo "Size: $(du -sh "$VAULT_PATH" 2>/dev/null | cut -f1)"
}

# ── Restore ───────────────────────────────────────────────────────────────────
do_restore() {
  local remote_url="${1:-}"
  [[ -z "$remote_url" ]] && { echo "Usage: vault.sh restore <url>"; return 1; }
  vault_exists && { echo "ERROR: Vault exists. Remove first."; return 1; }

  mkdir -p "$(dirname "$VAULT_PATH")"
  git clone "$remote_url" "$VAULT_PATH" 2>&1

  local slug="" junctions=0
  local active_file="$WORKSPACE_ROOT/.claude/profiles/active-user.md"
  [[ -f "$active_file" ]] && slug=$(grep -oP 'active_slug:\s*\K\S+' "$active_file" 2>/dev/null || true)
  if [[ -n "$slug" ]]; then
    local dst="$WORKSPACE_ROOT/.claude/profiles/users/$slug"
    [[ -d "$dst" && ! -L "$dst" ]] && rm -rf "$dst"
    create_junction "$VAULT_PATH/profile" "$dst" && junctions=$((junctions+1))
  fi
  [[ -d "$WORKSPACE_ROOT/.claude/instincts" && ! -L "$WORKSPACE_ROOT/.claude/instincts" ]] && rm -rf "$WORKSPACE_ROOT/.claude/instincts"
  create_junction "$VAULT_PATH/instincts" "$WORKSPACE_ROOT/.claude/instincts" && junctions=$((junctions+1))
  echo "Restored: $VAULT_PATH | Junctions: $junctions"
}

# ── Export ────────────────────────────────────────────────────────────────────
do_export() {
  vault_exists || { echo "ERROR: No vault"; return 1; }
  local dest="${1:-$HOME/pm-vault-export.enc}"
  echo "Passphrase (will NOT be stored):"; read -rs PASSPHRASE; echo
  [[ -z "$PASSPHRASE" ]] && { echo "ERROR: Empty passphrase."; return 1; }

  tar czf - -C "$(dirname "$VAULT_PATH")" "$(basename "$VAULT_PATH")" \
    | openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 -pass "pass:$PASSPHRASE" -out "$dest" 2>/dev/null

  echo "Exported: $dest ($(du -sh "$dest" 2>/dev/null | cut -f1), AES-256-CBC)"
  unset PASSPHRASE
}
