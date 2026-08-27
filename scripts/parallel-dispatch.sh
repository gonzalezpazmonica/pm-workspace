#!/usr/bin/env bash
# parallel-dispatch.sh — Despacho paralelo con admission-handle (SE-347 lección PMA)
#
# Patrón extraído de Prime Agent (docs/rlm.md, docs/rlm-runtime.md):
#   `await rlm("tarea")` devuelve un HANDLE de admisión INMEDIATO (nunca espera
#   la respuesta). El hijo corre como sesión independiente; el resultado llega
#   después (fichero/mensaje). El padre termina el turno sin bloquearse.
#
# Savia lo implementa sobre `opencode run` en background (o cualquier comando):
#   launch devuelve el id al instante; status/collect agregan resultados.
#   CRIT-001: resultados en ~/.savia/dispatch (disco propio, sin red).
#
# Uso:
#   parallel-dispatch.sh launch --id <id> --dir <cwd> --cmd "<shell cmd>" [--timeout N]
#   parallel-dispatch.sh status [--id <id>|--all] [--quiet]
#   parallel-dispatch.sh collect [--id <id>|--all] [--fail-fast]
#   parallel-dispatch.sh clean [--id <id>|--all --done]
#
# Para el caso real PMA-like:
#   parallel-dispatch.sh launch --id api-review \
#     --dir /home/monica/savia \
#     --cmd 'opencode run --format json "Revisa la API y escribe el resultado en output/review-api.md"'
#
# Env: SAVIA_DISPATCH_DIR (default ~/.savia/dispatch) — override para tests.

set -uo pipefail

DISPATCH_DIR="${SAVIA_DISPATCH_DIR:-$HOME/.savia/dispatch}"
mkdir -p "$DISPATCH_DIR"
iso_now() { date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown"; }

job_file() { echo "$DISPATCH_DIR/$1.job.json"; }
out_file() { echo "$DISPATCH_DIR/$1.out"; }

cmd_launch() {
  local id="" dir="" cmd="" timeout=3600
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id) id="$2"; shift 2 ;;
      --dir) dir="$2"; shift 2 ;;
      --cmd) cmd="$2"; shift 2 ;;
      --timeout) timeout="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -n "$id" && -n "$cmd" ]] || { echo "ERROR: --id y --cmd required" >&2; return 2; }
  [[ -d "$dir" ]] || dir="$PWD"
  local jf of
  jf="$(job_file "$id")"
  of="$(out_file "$id")"
  if [[ -f "$jf" ]]; then
    echo "ERROR: job $id ya existe" >&2
    return 1
  fi
  cat > "$jf" <<EOF
{"id":"$id","ts":"$(iso_now)","dir":"$dir","cmd":"$(printf '%s' "$cmd" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')","timeout":$timeout,"status":"running","exit":null,"started_at":"$(iso_now)","finished_at":"","output":"$of"}
EOF
  # admission-handle: lanzar en background y volver YA con el id
  (
    cd "$dir" 2>/dev/null || true
    timeout "$timeout" bash -c "$cmd" > "$of" 2>&1
    local rc=$?
    python3 - "$jf" "$rc" <<'PY'
import json,sys,datetime
f,rc=sys.argv[1],int(sys.argv[2])
d=json.load(open(f))
d['exit']=rc
d['status']='done' if rc==0 else 'failed'
d['finished_at']=datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
json.dump(d,open(f,'w'))
PY
  ) >/dev/null 2>&1 &
  disown 2>/dev/null || true
  echo "launched $id (handle inmediato; status/collect para recoger)"
}

cmd_status() {
  local id="" quiet=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id) id="$2"; shift 2 ;;
      --all) id=""; shift ;;
      --quiet) quiet=true; shift ;;
      *) shift ;;
    esac
  done
  local files
  if [[ -n "$id" ]]; then
    files="$(job_file "$id")"
  else
    files=$(ls "$DISPATCH_DIR"/*.job.json 2>/dev/null || true)
  fi
  [[ -n "$files" ]] || { echo "(sin jobs)"; return 0; }
  for f in $files; do
    [[ -e "$f" ]] || continue
    local jid status exit_code cmd
    jid=$(basename "$f" .job.json)
    status=$(grep -oP '"status":\s*"\K[^"]+' "$f" | head -1)
    exit_code=$(grep -oP '"exit":\s*\K[0-9]+' "$f" | head -1)
    cmd=$(grep -oP '"cmd":\s*"\K[^"]+' "$f" | head -1)
    if $quiet; then
      echo "$jid $status ${exit_code:-n/a}"
    else
      printf '%-16s %-8s exit=%-4s %s\n' "$jid" "$status" "${exit_code:-n/a}" "$cmd"
    fi
  done
}

cmd_collect() {
  local id="" fail_fast=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id) id="$2"; shift 2 ;;
      --all) id=""; shift ;;
      --fail-fast) fail_fast=true; shift ;;
      *) shift ;;
    esac
  done
  local files
  if [[ -n "$id" ]]; then
    files="$(job_file "$id")"
  else
    files=$(ls "$DISPATCH_DIR"/*.job.json 2>/dev/null || true)
  fi
  [[ -n "$files" ]] || { echo "(sin jobs)"; return 0; }
  local fail=0
  for f in $files; do
    [[ -e "$f" ]] || continue
    local jid status exit_code of
    jid=$(basename "$f" .job.json)
    status=$(grep -oP '"status":\s*"\K[^"]+' "$f" | head -1)
    exit_code=$(grep -oP '"exit":\s*\K[0-9]+' "$f" | head -1)
    of="$(out_file "$jid")"
    if [[ "$status" == "running" ]]; then
      echo "[$jid] RUNNING (aún no recogible)"
      fail=1
      continue
    fi
    echo "── [$jid] ${status} exit=${exit_code:-n/a}"
    [[ -f "$of" ]] && { echo "  stdout: $(tail -c 400 "$of" | tr '\n' ' ')"; echo; }
    [[ "$fail_fast" == "true" && "$status" == "failed" ]] && fail=1
  done
  return "$fail"
}

cmd_clean() {
  local id="" all_done=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id) id="$2"; shift 2 ;;
      --done) all_done=true; shift ;;
      *) shift ;;
    esac
  done
  if [[ -n "$id" ]]; then
    local status
    status=$(grep -oP '"status":\s*"\K[^"]+' "$(job_file "$id")" 2>/dev/null | head -1)
    [[ "$status" == "running" ]] && { echo "ERROR: job $id aún corriendo" >&2; return 1; }
    rm -f "$(job_file "$id")" "$(out_file "$id")"
    echo "clean $id"
    return 0
  fi
  if $all_done; then
    for f in "$DISPATCH_DIR"/*.job.json; do
      [[ -e "$f" ]] || continue
      local jid status
      jid=$(basename "$f" .job.json)
      status=$(grep -oP '"status":\s*"\K[^"]+' "$f" | head -1)
      [[ "$status" == "running" ]] && continue
      rm -f "$f" "$(out_file "$jid")"
      echo "clean $jid"
    done
  fi
}

case "${1:-help}" in
  launch) shift; cmd_launch "$@" ;;
  status) shift; cmd_status "$@" ;;
  collect) shift; cmd_collect "$@" ;;
  clean) shift; cmd_clean "$@" ;;
  help|--help|-h)
    sed -n '2,24p' "${BASH_SOURCE[0]}" | grep -E '^#\s+parallel-|^#\s+  ' | sed 's/^#//' ;;
  *)
    echo "Uso: parallel-dispatch.sh {launch|status|collect|clean}" >&2
    exit 2 ;;
esac
