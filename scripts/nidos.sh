#!/bin/bash
set -uo pipefail
# nidos.sh — Savia Nidos: parallel terminal isolation via named git worktrees
# Usage: nidos.sh create <name> [--branch <b>] | list | enter <name> | remove <name> [--force] | status | help

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPTS_DIR/savia-compat.sh" 2>/dev/null || true
# shellcheck source=nidos-lib.sh
source "$SCRIPTS_DIR/nidos-lib.sh"

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
  echo "Nido '$name' created on branch '$branch' at $nido_path"
  echo "To start working:  cd \"$nido_path\""
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
    [[ "$name" == "$current_nido" ]] && active="*"
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

# ── Init & Dispatch ──
resolve_nidos_dir

case "${1:-}" in
  create) shift; resolve_repo_root; do_create "$@" ;;
  list)   do_list ;;
  enter)  do_enter "${2:-}" ;;
  remove) shift; resolve_repo_root; do_remove "$@" ;;
  status) do_status ;;
  help|-h|--help) nidos_usage ;;
  "")     do_list ;;
  *)      echo "Unknown command: $1" >&2; nidos_usage >&2; exit 1 ;;
esac
