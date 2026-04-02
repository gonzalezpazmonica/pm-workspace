#!/bin/bash
# nidos-lib.sh — Shared utilities for Savia Nidos
# Sourced by nidos.sh. Not executable standalone.

NIDOS_DIR=""
NIDOS_DIR_POSIX=""
NIDOS_REGISTRY=""
REPO_ROOT=""

to_posix_path() {
  local p="$1"
  case "${OSTYPE:-}" in
    msys*|cygwin*)
      if command -v cygpath >/dev/null 2>&1; then
        cygpath -u "$p"
      else
        p="${p//\\//}"
        if [[ "$p" =~ ^([A-Za-z]):/ ]]; then
          local drive="${BASH_REMATCH[1]}"
          drive=$(echo "$drive" | tr '[:upper:]' '[:lower:]')
          p="/${drive}${p:2}"
        fi
        echo "$p"
      fi
      ;;
    *) echo "$p" ;;
  esac
}

resolve_nidos_dir() {
  case "${OSTYPE:-}" in
    msys*|cygwin*) NIDOS_DIR="${USERPROFILE:-$HOME}/.savia/nidos" ;;
    *)             NIDOS_DIR="$HOME/.savia/nidos" ;;
  esac
  mkdir -p "$NIDOS_DIR"
  NIDOS_REGISTRY="$NIDOS_DIR/.registry"
  touch "$NIDOS_REGISTRY"
  NIDOS_DIR_POSIX=$(to_posix_path "$NIDOS_DIR")
}

resolve_repo_root() {
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null | tr -d '\r')
  if [[ -z "$REPO_ROOT" ]]; then
    echo "Error: not inside a git repository" >&2
    exit 1
  fi
}

validate_name() {
  local name="$1"
  if [[ -z "$name" ]]; then
    echo "Error: nido name required" >&2
    exit 1
  fi
  if ! echo "$name" | grep -qE '^[a-z0-9][a-z0-9-]*$'; then
    echo "Error: name must be lowercase alphanumeric with hyphens (e.g., feat-auth)" >&2
    exit 1
  fi
  if [[ ${#name} -gt 50 ]]; then
    echo "Error: name must be 50 characters or less" >&2
    exit 1
  fi
}

# portable sed -i (macOS vs GNU)
portable_sed_i() {
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

nidos_usage() {
  cat <<'EOF'
nidos.sh — Savia Nidos: parallel terminal isolation

Usage:
  nidos.sh create <name> [--branch <branch>]   Create a new nido (worktree)
  nidos.sh list                                 List active nidos
  nidos.sh enter <name>                         Show path to cd into
  nidos.sh remove <name> [--force]              Remove a nido
  nidos.sh status                               Detect current nido
  nidos.sh help                                 Show this help

Examples:
  nidos.sh create feat-auth                     # branch: nido/feat-auth
  nidos.sh create bugfix --branch fix/login     # custom branch
  cd $(nidos.sh enter feat-auth)                # navigate to nido
  nidos.sh remove feat-auth                     # clean up after merge

Nidos are stored in ~/.savia/nidos/ (outside cloud-synced folders).
Each nido is an isolated git worktree with its own branch.
EOF
}
