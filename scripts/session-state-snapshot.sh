#!/usr/bin/env bash
# session-state-snapshot.sh — Snapshot de estado de sesión (SE-347 lección PMA)
#
# Lección de Prime Agent (docs/session-format.md): PMA persiste entradas
# `git_state` (snapshot append-only del repo) y `label` (bookmark manual) por
# sesión para recuperación. Savia lo implementa en disco propio.
#
# Uso:
#   session-state-snapshot.sh record [--label "nombre"] [--session ID] [--dir PATH]
#   session-state-snapshot.sh list [--session ID] [--last N]
#   session-state-snapshot.sh label <name> [--session ID]   # bookmark
#
# Env: SAVIA_SESSION_STATE_DIR (default ~/.savia/session-state)

set -uo pipefail

STATE_DIR="${SAVIA_SESSION_STATE_DIR:-$HOME/.savia/session-state}"
mkdir -p "$STATE_DIR"
ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
FILE="$STATE_DIR/sessions.jsonl"

cmd_record() {
  local label="" session="" dir=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --label) label="$2"; shift 2 ;;
      --session) session="$2"; shift 2 ;;
      --dir) dir="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -n "$dir" ]] || dir="$PWD"
  [[ -n "$session" ]] || session="ses-$(date +%s%N)"
  local branch head dirty files
  if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
    head="$(git -C "$dir" rev-parse --short HEAD 2>/dev/null || echo '?')"
    dirty="$(git -C "$dir" status --porcelain 2>/dev/null | wc -l)"
    files="$(git -C "$dir" status --porcelain 2>/dev/null | cut -c4- | head -5 | tr '\n' ',' )"
  else
    branch="-" head="-" dirty=0 files=""
  fi
  python3 -c "
import json,sys
print(json.dumps({
  'type':'git_state','ts':'$ISO','session':'$session','dir':'$dir',
  'branch':'$branch','head':'$head','dirty':$dirty,'files':'$files',
  'label':'$label'}, ensure_ascii=False))" >> "$FILE"
  echo "recorded session=$session branch=$branch head=$head dirty=$dirty label=${label:-none}"
}

cmd_list() {
  local session="" last=10
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --session) session="$2"; shift 2 ;;
      --last) last="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -f "$FILE" ]] || { echo "(sin snapshots)"; return 0; }
  python3 -c "
import json,sys
rows=[json.loads(l) for l in open(sys.argv[1]) if l.strip()]
if sys.argv[2]: rows=[r for r in rows if r.get('session')==sys.argv[2]]
for r in rows[-int(sys.argv[3]):]:
    print(f\"{r['ts']} {r['session']} branch={r['branch']} head={r['head']} dirty={r['dirty']} label={r.get('label') or '-'} dir={r['dir']}\")" "$FILE" "$session" "$last"
}

cmd_label() {
  local label="${1:-}" session=""
  shift || true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --session) session="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -n "$label" ]] || { echo "ERROR: label name required" >&2; return 2; }
  cmd_record --label "$label" --session "${session:-manual-$(date +%s%N)}"
}

case "${1:-help}" in
  record) shift; cmd_record "$@" ;;
  list) shift; cmd_list "$@" ;;
  label) shift; cmd_label "$@" ;;
  help|--help|-h)
    sed -n '2,16p' "${BASH_SOURCE[0]}" | grep -E '^#\s+session-|^#\s+  ' | sed 's/^#//' ;;
  *)
    echo "Uso: session-state-snapshot.sh {record|list|label}" >&2
    exit 2 ;;
esac
