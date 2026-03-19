#!/usr/bin/env bash
# vault.sh — Personal Vault dispatcher (N3)
# Usage: vault.sh {init|sync|status|restore|export} [args]
set -uo pipefail

VAULT_PATH="${VAULT_PATH:-$HOME/.savia/personal-vault}"
WORKSPACE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ── Helpers (shared with vault-ops.sh) ────────────────────────────────────────
is_windows() { [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; }

create_junction() {
  local target="$1" link="$2"
  if is_windows; then
    cmd //c "mklink /J \"$(cygpath -w "$link")\" \"$(cygpath -w "$target")\"" > /dev/null 2>&1
  else
    ln -sf "$target" "$link"
  fi
}

junction_ok() { [[ -d "$1" || -L "$1" ]] && [[ -e "$1" ]]; }
vault_exists() { [[ -d "$VAULT_PATH/.git" ]]; }

# ── Load operations ───────────────────────────────────────────────────────────
source "$(dirname "$0")/vault-ops.sh"

# ── Dispatch ──────────────────────────────────────────────────────────────────
case "${1:-help}" in
  init)    do_init ;;
  sync)    do_sync ;;
  status)  do_status ;;
  restore) do_restore "${2:-}" ;;
  export)  do_export "${2:-}" ;;
  *)
    echo "Usage: vault.sh {init|sync|status|restore|export} [args]"
    echo "  init              Create vault, migrate data, create junctions"
    echo "  sync              Commit + push vault changes"
    echo "  status            Health check: junctions, changes, remote"
    echo "  restore <url>     Clone from remote + recreate junctions"
    echo "  export [path]     AES-256 encrypted archive"
    ;;
esac
