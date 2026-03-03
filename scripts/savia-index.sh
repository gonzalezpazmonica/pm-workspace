#!/usr/bin/env bash
# ── savia-index.sh ──────────────────────────────────────────────────────────
# Git Persistence Engine: Core index operations (lookup, update, remove, compact).
# Rebuild logic delegated to savia-index-rebuild.sh
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

[ -f "scripts/savia-compat.sh" ] && source scripts/savia-compat.sh

INDEX_DIR=".savia-index"
MKDIR="${MKDIR:-mkdir -p}"
GREP="${GREP:-grep}"
SED="${SED:-sed}"
AWK="${AWK:-awk}"

ensure_index_dir() { "$MKDIR" "$INDEX_DIR" 2>/dev/null || true; }
get_index_path() { echo "$INDEX_DIR/$1.idx"; }

init_index() {
  local idx="$(get_index_path "$1")"
  ensure_index_dir
  [ -f "$idx" ] || echo "$2" > "$idx"
}

lookup() {
  local idx="$(get_index_path "$1")"
  [ -f "$idx" ] || { echo "INDEX_NOT_FOUND"; return 1; }
  "$GREP" "^$2" "$idx" || echo "NOT_FOUND"
}

update_entry() {
  local name="$1" key="$2"
  local idx="$(get_index_path "$name")"
  shift 2
  ensure_index_dir
  [ -f "$idx" ] || touch "$idx"
  "$SED" -i '' "/^$key\t/d" "$idx" 2>/dev/null || "$SED" -i "/^$key\t/d" "$idx" 2>/dev/null || true
  printf '%s\t%s\n' "$key" "$*" >> "$idx"
}

remove_entry() {
  local idx="$(get_index_path "$1")"
  [ -f "$idx" ] || return 0
  "$SED" -i '' "/^$2\t/d" "$idx" 2>/dev/null || "$SED" -i "/^$2\t/d" "$idx" 2>/dev/null || true
}

verify_index() {
  local idx="$(get_index_path "${1:-profiles}")"
  [ -f "$idx" ] || { echo "INDEX_NOT_FOUND"; return 1; }
  local entries="$("$AWK" 'NR>1' "$idx" | wc -l)"
  local updated="$(date -r "$idx" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo 'unknown')"
  echo "index=${1:-profiles}|entries=$entries|updated=$updated"
}

compact_index() {
  local idx="$(get_index_path "${1:-profiles}")"
  [ -f "$idx" ] || return 0
  case "$1" in
    profiles) "$AWK" -F'\t' 'NR==1 || (NR>1 && system("test -f " $2 "/identity.md") == 0)' "$idx" > "$idx.tmp" ;;
    messages|specs|timesheets) "$AWK" -F'\t' 'NR==1 || (NR>1 && system("test -f " $2) == 0)' "$idx" > "$idx.tmp" ;;
    projects) "$AWK" -F'\t' 'NR==1 || (NR>1 && system("test -f " $2 "/CLAUDE.md") == 0)' "$idx" > "$idx.tmp" ;;
  esac
  [ -f "$idx.tmp" ] && mv "$idx.tmp" "$idx"
}

case "${1:-help}" in
  rebuild|rebuild-*) bash scripts/savia-index-rebuild.sh "${1#rebuild-}" ;;
  lookup) lookup "$2" "$3" ;;
  update) update_entry "$2" "$3" "${@:4}" ;;
  init) init_index "${2:-profiles}" "${3:-}" ;;
  remove) remove_entry "$2" "$3" ;;
  verify) verify_index "${2:-profiles}" ;;
  compact) compact_index "${2:-profiles}" ;;
  help|*) cat <<EOF
Git Persistence Engine — Savia Index
Usage: savia-index.sh <command> [args]

CORE:  lookup|update|remove|verify|compact <index> [key] [values]
       index: profiles | messages | projects | specs | timesheets
REBUILD: rebuild [mode: all|profiles|messages|projects|specs|timesheets]
EOF
    ;;
esac
