#!/usr/bin/env bash
# agent-scratchpad.sh — SE-216 Slice 1: shared state document for parallel agents
# Ref: docs/propuestas/SE-216-evo-patterns.md
set -uo pipefail

# ── Path resolution ──────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="${SAVIA_WORKSPACE_DIR:-${CLAUDE_PROJECT_DIR:-${OPENCODE_PROJECT_DIR:-$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || pwd)}}}"
OUTPUT_DIR="${AGENT_SCRATCHPAD_OUTPUT_DIR:-$WORKSPACE_DIR/output}"

# ── Helpers ──────────────────────────────────────────────────────────────────
_now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

_scratchpad_path() {
  local run_id="$1"
  echo "${OUTPUT_DIR}/scratchpad-${run_id}.md"
}

_die() { echo "ERROR: $*" >&2; exit 1; }

# ── Subcommand: generate ─────────────────────────────────────────────────────
_cmd_generate() {
  local run_id="" agents="" context_files="" objective="No especificado"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --run-id)       run_id="$2";       shift 2 ;;
      --agents)       agents="$2";       shift 2 ;;
      --context-files) context_files="$2"; shift 2 ;;
      --objective)    objective="$2";    shift 2 ;;
      *) _die "generate: unknown option '$1'" ;;
    esac
  done

  [[ -n "$run_id" ]]  || _die "generate requires --run-id"
  [[ -n "$agents" ]]  || _die "generate requires --agents"

  mkdir -p "$OUTPUT_DIR"
  local ts; ts="$(_now_iso)"
  local pad_path; pad_path="$(_scratchpad_path "$run_id")"

  # Collect What Not To Try from SE-217 TSV logs (optional — fail gracefully)
  local wntt_block="_Sin hipótesis descartadas_"
  local tsv_files=()
  # shellcheck disable=SC2207
  mapfile -t tsv_files < <(ls "${OUTPUT_DIR}"/agent-run-log-*.tsv 2>/dev/null || true)
  if [[ ${#tsv_files[@]} -gt 0 ]]; then
    local entries=()
    for f in "${tsv_files[@]}"; do
      while IFS=$'\t' read -r _ts _run _type hypo reason _rest || [[ -n "$_ts" ]]; do
        [[ "$_type" == "discard" ]] || continue
        entries+=("- \"${hypo}\" → ${reason}")
      done < "$f"
    done
    if [[ ${#entries[@]} -gt 0 ]]; then
      wntt_block="$(printf '%s\n' "${entries[@]}")"
    fi
  fi

  cat > "$pad_path" <<EOF
# Agent Scratchpad — run-${run_id}
**Generated:** ${ts} | **Agents:** ${agents} | **Round:** 1

## Objetivo
${objective}

## Frontier (tareas pendientes)
_Sin tareas registradas_

## Anotaciones por agente
_Sin anotaciones_

## What Not To Try
${wntt_block}

## Cross-cutting notes
_Sin notas_
EOF

  echo "Generated: $pad_path"
}

# ── Subcommand: annotate ─────────────────────────────────────────────────────
_cmd_annotate() {
  local run_id="" agent="" finding="" severity=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --run-id)   run_id="$2";   shift 2 ;;
      --agent)    agent="$2";    shift 2 ;;
      --finding)  finding="$2";  shift 2 ;;
      --severity) severity="$2"; shift 2 ;;
      *) _die "annotate: unknown option '$1'" ;;
    esac
  done

  [[ -n "$run_id" ]]   || _die "annotate requires --run-id"
  [[ -n "$agent" ]]    || _die "annotate requires --agent"
  [[ -n "$finding" ]]  || _die "annotate requires --finding"
  [[ -n "$severity" ]] || _die "annotate requires --severity"

  local pad_path; pad_path="$(_scratchpad_path "$run_id")"
  [[ -f "$pad_path" ]] || _die "Scratchpad not found for run-id '$run_id': $pad_path"

  local ts; ts="$(_now_iso)"
  local entry="- [${severity}] ${finding} — ${ts}"

  # Atomic write with flock (advisory lock on the scratchpad file itself)
  local lockfile="${pad_path}.lock"
  (
    flock -x 9
    local content; content="$(cat "$pad_path")"
    local header="### ${agent}"

    if echo "$content" | grep -qF "$header"; then
      # Append under existing agent section
      local tmp; tmp="$(mktemp)"
      awk -v header="$header" -v entry="$entry" '
        $0 == header { print; found=1; next }
        found && /^(###|##) / { print entry; found=0 }
        found && /^$/ && !pending { pending=1; print; next }
        { if (pending && found) { print entry; found=0; pending=0 } print }
        END { if (found) print entry }
      ' "$pad_path" > "$tmp"
      mv "$tmp" "$pad_path"
    else
      # Remove placeholder if present and add new agent section
      local tmp; tmp="$(mktemp)"
      awk -v header="$header" -v entry="$entry" '
        /^## Anotaciones por agente$/ {
          print
          in_section=1
          next
        }
        in_section && /^_Sin anotaciones_$/ {
          printf "%s\n%s\n", header, entry
          in_section=0
          next
        }
        in_section && /^(##) / {
          # First time hitting next section without having seen placeholder
          printf "%s\n%s\n\n", header, entry
          in_section=0
        }
        { print }
        END { if (in_section) { printf "%s\n%s\n", header, entry } }
      ' "$pad_path" > "$tmp"
      mv "$tmp" "$pad_path"
    fi
  ) 9>"$lockfile"

  echo "Annotated run-${run_id} [${agent}]: [${severity}] ${finding}"
}

# ── Subcommand: discard ──────────────────────────────────────────────────────
_cmd_discard() {
  local run_id="" hypothesis="" reason=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --run-id)     run_id="$2";     shift 2 ;;
      --hypothesis) hypothesis="$2"; shift 2 ;;
      --reason)     reason="$2";     shift 2 ;;
      *) _die "discard: unknown option '$1'" ;;
    esac
  done

  [[ -n "$run_id" ]]     || _die "discard requires --run-id"
  [[ -n "$hypothesis" ]] || _die "discard requires --hypothesis"
  [[ -n "$reason" ]]     || _die "discard requires --reason"

  local pad_path; pad_path="$(_scratchpad_path "$run_id")"
  [[ -f "$pad_path" ]] || _die "Scratchpad not found for run-id '$run_id': $pad_path"

  local entry="- \"${hypothesis}\" → ${reason}"
  local lockfile="${pad_path}.lock"

  (
    flock -x 9
    local tmp; tmp="$(mktemp)"
    awk -v entry="$entry" '
      /^## What Not To Try$/ {
        print
        in_section=1
        next
      }
      in_section && /^_Sin hipótesis descartadas_$/ {
        print entry
        in_section=0
        next
      }
      in_section && /^(##) / {
        print entry
        print ""
        in_section=0
      }
      { print }
      END { if (in_section) print entry }
    ' "$pad_path" > "$tmp"
    mv "$tmp" "$pad_path"
  ) 9>"$lockfile"

  echo "Discarded hypothesis in run-${run_id}"
}

# ── Subcommand: read ─────────────────────────────────────────────────────────
_cmd_read() {
  local run_id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --run-id) run_id="$2"; shift 2 ;;
      *) _die "read: unknown option '$1'" ;;
    esac
  done

  [[ -n "$run_id" ]] || _die "read requires --run-id"

  local pad_path; pad_path="$(_scratchpad_path "$run_id")"
  [[ -f "$pad_path" ]] || _die "Scratchpad not found for run-id '$run_id': $pad_path"

  cat "$pad_path"
}

# ── Dispatch ─────────────────────────────────────────────────────────────────
SUBCMD="${1:-}"
[[ -n "$SUBCMD" ]] || _die "Usage: agent-scratchpad.sh <generate|annotate|discard|read> [options]"
shift

case "$SUBCMD" in
  generate) _cmd_generate "$@" ;;
  annotate) _cmd_annotate "$@" ;;
  discard)  _cmd_discard  "$@" ;;
  read)     _cmd_read     "$@" ;;
  *) _die "Unknown subcommand '$SUBCMD'. Valid: generate annotate discard read" ;;
esac
