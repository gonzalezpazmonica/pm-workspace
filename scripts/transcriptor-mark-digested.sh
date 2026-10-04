#!/usr/bin/env bash
# transcriptor-mark-digested.sh — marcar una reunion como digerida
# Usage: bash scripts/transcriptor-mark-digested.sh [--force --confirm <nombre>] <carpeta>
#
# <carpeta>: nombre bajo $SAVIA_TRANSCRIPTOR_DIR/reuniones o ruta con '/'.
# Exit: 0 marcada (o ya lo estaba) · 1 error (uso, carpeta, meta.json ilegible,
# python3 ausente, escritura fallida, --force sin --confirm valido) · 3 reunion
# sin transcribir o, con --force, con actividad reciente (grabacion en curso).
# --force solo por peticion expresa de la usuaria: exige --confirm con el nombre
# exacto de la carpeta y se niega si algun fichero de la reunion cambio en los
# ultimos SAVIA_TRANSCRIPTOR_ACTIVE_SECS segundos (300 por defecto).
# La escritura es atomica (fichero temporal + rename en la misma carpeta): un
# lector concurrente ve el meta.json anterior o el nuevo, nunca uno truncado.
# Tras escribir, relee el fichero y solo declara exito si digested es true.
set -uo pipefail

TRANSCRIPTOR_DIR="${SAVIA_TRANSCRIPTOR_DIR:-$HOME/.savia/transcriptor}"
MEETINGS_DIR="$TRANSCRIPTOR_DIR/reuniones"

USAGE="Usage: transcriptor-mark-digested.sh [--force --confirm <nombre>] <carpeta>"
FORCE=0
CONFIRM=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --confirm)
      if [[ $# -lt 2 ]]; then echo "$USAGE" >&2; exit 1; fi
      CONFIRM="$2"; shift 2 ;;
    --*) echo "ERROR: opcion desconocida: $1" >&2; echo "$USAGE" >&2; exit 1 ;;
    *) break ;;
  esac
done
SESSION="${1:-}"
if [[ -z "$SESSION" || $# -gt 1 ]]; then
  echo "$USAGE" >&2
  exit 1
fi
ACTIVE_SECS="${SAVIA_TRANSCRIPTOR_ACTIVE_SECS:-300}"
if [[ ! "$ACTIVE_SECS" =~ ^[0-9]+$ ]]; then
  echo "ERROR: SAVIA_TRANSCRIPTOR_ACTIVE_SECS no es un entero: $ACTIVE_SECS" >&2
  exit 1
fi

# Resolver: si es un nombre (YYYY-MM-DD-HH-MM) o una ruta
if [[ "$SESSION" == */* ]]; then
  SESSION_PATH="${SESSION%/}"
else
  if [[ "$SESSION" == "." || "$SESSION" == ".." ]]; then
    echo "ERROR: nombre de reunion invalido: $SESSION" >&2
    exit 1
  fi
  SESSION_PATH="$MEETINGS_DIR/$SESSION"
fi

if [[ ! -d "$SESSION_PATH" ]]; then
  echo "ERROR: no se encuentra la reunion $SESSION_PATH" >&2
  exit 1
fi

if [[ "$FORCE" == "1" && "$CONFIRM" != "$(basename "$SESSION_PATH")" ]]; then
  echo "ERROR: --force exige --confirm $(basename "$SESSION_PATH") (peticion expresa de la usuaria); la reunion NO se ha marcado" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 no disponible; la reunion NO se ha marcado" >&2
  exit 1
fi

python3 - "$SESSION_PATH" "$FORCE" "$ACTIVE_SECS" <<'PY'
import json
import os
import sys
import tempfile
import time
from datetime import datetime, timezone

session, force, active_secs = sys.argv[1], sys.argv[2] == "1", int(sys.argv[3])
name = os.path.basename(session)
meta_path = os.path.join(session, "meta.json")


def fail(msg, code=1):
    print(f"ERROR: {msg}; la reunion NO se ha marcado", file=sys.stderr)
    sys.exit(code)


if os.path.isfile(meta_path):
    try:
        with open(meta_path, encoding="utf-8") as fh:
            meta = json.load(fh)
    except (OSError, ValueError) as exc:
        fail(f"meta.json ilegible en {name}: {exc}")
    if not isinstance(meta, dict):
        fail(f"meta.json de {name} no es un objeto JSON")
    mode = os.stat(meta_path).st_mode & 0o7777
elif os.path.exists(meta_path):
    fail(f"{meta_path} existe pero no es un fichero")
else:
    meta, mode = {}, 0o644

if meta.get("digested") is True:
    print(f"Reunion ya estaba digerida: {name}")
    sys.exit(0)

if "transcribed" in meta:
    transcribed = meta.get("transcribed") is True
else:
    transcribed = any(os.path.isfile(os.path.join(session, f))
                      for f in ("transcript.md", "transcript.vtt"))
if not transcribed and not force:
    fail(f"{name} aun no esta transcrita (grabacion o transcripcion en curso); "
         "no reintentes: informa a la usuaria y espera a que se transcriba", 3)


def newest_mtime(root):
    newest = 0.0
    for dirpath, _dirs, files in os.walk(root):
        for entry in [dirpath] + [os.path.join(dirpath, f) for f in files]:
            try:
                newest = max(newest, os.stat(entry).st_mtime)
            except OSError as exc:
                print(f"AVISO: no se pudo leer {entry}: {exc}", file=sys.stderr)
    return newest


if not transcribed:
    idle = time.time() - newest_mtime(session)
    if idle < active_secs:
        fail(f"{name} tiene actividad reciente (hace {int(idle)} s; umbral "
             f"{active_secs} s): puede estar grabando; no reintentes", 3)

meta["digested"] = True
meta["digested_at"] = datetime.now(timezone.utc).isoformat(timespec="seconds")

fd, tmp = tempfile.mkstemp(prefix=".meta.json.", suffix=".tmp", dir=session)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        json.dump(meta, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
        fh.flush()
        os.fsync(fh.fileno())
    os.chmod(tmp, mode)
    os.replace(tmp, meta_path)
except OSError as exc:
    try:
        os.unlink(tmp)
    except OSError as cleanup_exc:
        print(f"AVISO: no se pudo borrar el temporal {tmp}: {cleanup_exc}", file=sys.stderr)
    fail(f"no se pudo escribir {meta_path}: {exc}")

try:
    with open(meta_path, encoding="utf-8") as fh:
        ok = json.load(fh).get("digested") is True
except (OSError, ValueError) as exc:
    fail(f"verificacion tras escribir {meta_path} fallida: {exc}")
if not ok:
    fail(f"verificacion tras escribir {meta_path}: digested no quedo en true")
print(f"Marcada como digerida: {name}")
PY
