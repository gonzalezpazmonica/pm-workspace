#!/usr/bin/env bash
set -uo pipefail
# edit-ledger.sh — SE-402: registro de ediciones atribuidas.
#
#   record            lee el payload del hook (JSON por stdin) y añade un registro
#   verify [--base REF] [--json] [--strict]
#                     lista los ficheros cambiados que ningún registro atribuye
#
# Ledger: ${SAVIA_EDIT_LEDGER_DIR:-$HOME/.savia/edits}/<session>.jsonl
# Registro: {ts, session, agent, tool, path, sha256_after, repo_root, branch}
# Solo ruta y hash; nunca contenido (AC2). `record` nunca falla (exit 0).
# Ref: docs/specs/SE-402-attributed-edit-ledger.spec.md

LEDGER_DIR="${SAVIA_EDIT_LEDGER_DIR:-$HOME/.savia/edits}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cmd_record() {
  command -v jq >/dev/null 2>&1 || return 0
  local payload; payload=$(cat 2>/dev/null) || return 0
  [[ -z "$payload" ]] && return 0
  local fields
  fields=$(jq -r '
    def failed: (.tool_response // {}) | (type == "object") and ((.error // .is_error // false) != false);
    if failed then empty else
    [ (.session_id // "nosession"),
      (.tool_name // ""),
      (.tool_input.file_path // .tool_input.notebook_path // .tool_input.filePath // ""),
      (.agent_type // .agent_id // env.SAVIA_AGENT // "main"),
      (.cwd // "") ] | @tsv end' <<<"$payload" 2>/dev/null) || return 0
  [[ -z "$fields" ]] && return 0
  local session tool path agent cwd
  IFS=$'\t' read -r session tool path agent cwd <<<"$fields"
  case "$tool" in Edit|Write|NotebookEdit|MultiEdit|edit|write) ;; *) return 0 ;; esac
  [[ -z "$path" ]] && return 0
  [[ "$path" != /* && -n "$cwd" ]] && path="$cwd/$path"
  local dir; dir=$(dirname "$path")
  [[ -d "$dir" ]] || return 0
  local root; root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || return 0
  local rel="${path#"$root"/}"
  [[ "$rel" == "$path" ]] && return 0
  local sha=""
  [[ -f "$path" ]] && sha=$(sha256sum "$path" | cut -d' ' -f1)
  local branch; branch=$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  session=${session//[^A-Za-z0-9._-]/_}
  mkdir -p "$LEDGER_DIR" 2>/dev/null || return 0
  jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg session "$session" --arg agent "$agent" \
    --arg tool "$tool" --arg path "$rel" --arg sha "$sha" --arg root "$root" --arg branch "$branch" \
    '{ts:$ts, session:$session, agent:$agent, tool:$tool, path:$path, sha256_after:$sha, repo_root:$root, branch:$branch}' \
    >> "$LEDGER_DIR/$session.jsonl" 2>/dev/null
  return 0
}

case "${1:-}" in
  record) cmd_record; exit 0 ;;
  verify) shift; exec python3 "$SCRIPT_DIR/edit_ledger_verify.py" --ledger-dir "$LEDGER_DIR" "$@" ;;
  -h|--help|help)
    sed -n 3,12p "$0"; exit 0 ;;
  *) echo "Usage: $0 {record|verify [--base REF] [--json] [--strict]}" >&2; exit 2 ;;
esac
