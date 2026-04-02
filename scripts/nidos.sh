#!/bin/bash
set -uo pipefail
# nidos.sh — Savia Nidos: parallel terminal isolation via named git worktrees
# Usage: nidos.sh create <name> [--branch <b>] | list | enter <name> | remove <name> [--force] | status | help

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPTS_DIR/savia-compat.sh" 2>/dev/null || true

NIDOS_DIR=""
NIDOS_REGISTRY=""
REPO_ROOT=""

to_posix_path() {
  # Convert Windows path to POSIX for Git Bash comparison
  local p="$1"
  case "${OSTYPE:-}" in
    msys*|cygwin*)
      if command -v cygpath >/dev/null 2>&1; then
        cygpath -u "$p"
      else
        # Manual: C:\Users\x -> /c/Users/x
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
  # Normalize for path comparison on Windows Git Bash
  NIDOS_DIR_POSIX=$(to_posix_path "$NIDOS_DIR")
}

resolve_repo_root() {
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null | tr -d '\r')
  if [[ -z "$REPO_ROOT" ]]; then
    echo "Error: not inside a git repository" >&2
    exit 1
  fi
}

usage() {
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

do_create() {
  local name="" branch=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --branch) branch="${2:-}"; shift 2 ;;
      -*) echo "Error: unknown option $1" >&2; exit 1 ;;
      *)  name="$1"; shift ;;
    esac
  done
  validate_name "$name"
  [[ -z "$branch" ]] && branch="nido/$name"

  if grep -q "^${name}=" "$NIDOS_REGISTRY" 2>/dev/null; then
    echo "Error: nido '$name' already exists. Use: nidos.sh enter $name" >&2
    exit 1
  fi

  local nido_path="$NIDOS_DIR/$name"
  echo "Creating nido '$name' on branch '$branch'..."
  git -C "$REPO_ROOT" worktree add "$nido_path" -b "$branch" 2>&1 | tr -d '\r'

  if [[ $? -ne 0 ]] || [[ ! -d "$nido_path" ]]; then
    echo "Error: worktree creation failed" >&2
    exit 1
  fi

  echo "${name}=${branch}" >> "$NIDOS_REGISTRY"
  echo ""
  echo "Nido '$name' created successfully."
  echo "  Branch: $branch"
  echo "  Path:   $nido_path"
  echo ""
  echo "To start working:  cd \"$nido_path\""
  echo "Then open Claude Code in that directory."
}

do_list() {
  if [[ ! -s "$NIDOS_REGISTRY" ]]; then
    echo "No active nidos. Create one with: nidos.sh create <name>"
    return
  fi

  local current_nido=""
  if [[ "${PWD}" == "${NIDOS_DIR_POSIX}"/* ]]; then
    current_nido="${PWD#"${NIDOS_DIR_POSIX}"/}"
    current_nido="${current_nido%%/*}"
  fi

  printf "%-20s %-30s %-6s %s\n" "NAME" "BRANCH" "ACTIVE" "PATH"
  printf "%-20s %-30s %-6s %s\n" "----" "------" "------" "----"

  while IFS='=' read -r name branch; do
    [[ -z "$name" ]] && continue
    local nido_path="$NIDOS_DIR/$name"
    local active=""
    if [[ "$name" == "$current_nido" ]]; then
      active="*"
    fi
    if [[ -d "$nido_path" ]]; then
      local actual_branch
      actual_branch=$(git -C "$nido_path" branch --show-current 2>/dev/null | tr -d '\r')
      printf "%-20s %-30s %-6s %s\n" "$name" "${actual_branch:-$branch}" "$active" "$nido_path"
    else
      printf "%-20s %-30s %-6s %s\n" "$name" "$branch" "GONE" "(path missing)"
    fi
  done < "$NIDOS_REGISTRY"
}

do_enter() {
  local name="${1:-}"
  validate_name "$name"

  if ! grep -q "^${name}=" "$NIDOS_REGISTRY" 2>/dev/null; then
    echo "Error: nido '$name' not found. Run: nidos.sh list" >&2
    exit 1
  fi

  local nido_path="$NIDOS_DIR/$name"
  if [[ ! -d "$nido_path" ]]; then
    echo "Error: path $nido_path missing. Cleaning registry." >&2
    portable_sed_i "/^${name}=/d" "$NIDOS_REGISTRY" 2>/dev/null || \
      sed -i "/^${name}=/d" "$NIDOS_REGISTRY"
    exit 1
  fi

  echo "$nido_path"
}

do_remove() {
  local name="${1:-}" force=false
  [[ "$name" == "--force" ]] && { force=true; name="${2:-}"; }
  [[ "${2:-}" == "--force" ]] && force=true
  validate_name "$name"

  if ! grep -q "^${name}=" "$NIDOS_REGISTRY" 2>/dev/null; then
    echo "Error: nido '$name' not found" >&2
    exit 1
  fi

  local nido_path="$NIDOS_DIR/$name"
  local branch
  branch=$(grep "^${name}=" "$NIDOS_REGISTRY" | cut -d= -f2- | tr -d '\r')

  if [[ -d "$nido_path" ]]; then
    local dirty
    dirty=$(git -C "$nido_path" status --porcelain 2>/dev/null | tr -d '\r')
    if [[ -n "$dirty" ]] && [[ "$force" != true ]]; then
      echo "Error: nido '$name' has uncommitted changes. Use --force to discard." >&2
      echo "Dirty files:" >&2
      echo "$dirty" >&2
      exit 1
    fi

    if [[ "$force" == true ]]; then
      git -C "$REPO_ROOT" worktree remove "$nido_path" --force 2>/dev/null || rm -rf "$nido_path"
    else
      git -C "$REPO_ROOT" worktree remove "$nido_path" 2>/dev/null || rm -rf "$nido_path"
    fi
    # Clean up stale worktree refs (OneDrive may lock .git/worktrees/)
    git -C "$REPO_ROOT" worktree prune 2>/dev/null || true
  fi

  portable_sed_i "/^${name}=/d" "$NIDOS_REGISTRY" 2>/dev/null || \
    sed -i "/^${name}=/d" "$NIDOS_REGISTRY"

  git -C "$REPO_ROOT" branch -d "$branch" 2>/dev/null | tr -d '\r' || true

  echo "Nido '$name' removed."
}

do_status() {
  if [[ "${PWD}" == "${NIDOS_DIR_POSIX}"/* ]]; then
    local name="${PWD#"${NIDOS_DIR_POSIX}"/}"
    name="${name%%/*}"
    local branch
    branch=$(git branch --show-current 2>/dev/null | tr -d '\r')
    echo "Nido:   $name"
    echo "Branch: ${branch:-N/A}"
    echo "Path:   $PWD"
  else
    echo "Not in a nido."
    echo "Current: $PWD"
    echo ""
    echo "Create one with: nidos.sh create <name>"
  fi
}

# ── Init ──
resolve_nidos_dir

# ── Dispatcher ──
case "${1:-}" in
  create) shift; resolve_repo_root; do_create "$@" ;;
  list)   do_list ;;
  enter)  do_enter "${2:-}" ;;
  remove) shift; resolve_repo_root; do_remove "$@" ;;
  status) do_status ;;
  help|-h|--help) usage ;;
  "")     do_list ;;
  *)
    echo "Unknown command: $1" >&2
    usage >&2
    exit 1
    ;;
esac
