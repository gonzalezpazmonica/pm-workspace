#!/usr/bin/env bash
# loop-run-log.sh — CLI para gestión del run-log append-only de skills autónomas
# SE-228 Slice 3 — Schema: docs/rules/domain/loop-run-log-schema.md
#
# Usage:
#   loop-run-log.sh append --skill <n> --items N --actions N --escalations N --tokens N --outcome <O> [--notes "texto"]
#   loop-run-log.sh tail   --skill <n> [--lines N]
#   loop-run-log.sh stats  --skill <n>
#   loop-run-log.sh prune  --skill <n> [--days N]
#   loop-run-log.sh --help
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

LOOP_RUN_LOG_DIR="${LOOP_RUN_LOG_DIR:-$PROJECT_ROOT/output/loop-run-log}"

usage() {
  cat <<'EOF'
loop-run-log.sh — Run-log append-only para skills autónomas (SE-228 S3)

Subcomandos:
  append  --skill <n> --items N --actions N --escalations N --tokens N
          --outcome DONE|ESCALATED|ABORTED|TIMEOUT [--notes "texto"]
          Añade una entrada al run-log. Crea el fichero si no existe.

  tail    --skill <n> [--lines N]
          Muestra las últimas N entradas (default 10).

  stats   --skill <n>
          Imprime: total_runs, success_rate, avg_tokens, total_escalations.

  prune   --skill <n> [--days N]
          Elimina entradas más antiguas de N días (default 90).

  --help  Muestra este mensaje y sale con código 0.

Variables de entorno:
  LOOP_RUN_LOG_DIR   Directorio base (default: output/loop-run-log)

Esquema: docs/rules/domain/loop-run-log-schema.md
EOF
}

# ---------- helpers ----------------------------------------------------------

die() { echo "ERROR: $*" >&2; exit 1; }

log_file() {
  local skill="$1"
  echo "$LOOP_RUN_LOG_DIR/$skill/run-log.md"
}

ensure_log() {
  local skill="$1"
  local dir="$LOOP_RUN_LOG_DIR/$skill"
  mkdir -p "$dir"
  local f
  f="$(log_file "$skill")"
  if [[ ! -f "$f" ]]; then
    cat >"$f" <<EOF
# Loop Run Log — ${skill}

> Append-only. Schema: docs/rules/domain/loop-run-log-schema.md

EOF
  fi
}

# ---------- subcomando: append -----------------------------------------------

cmd_append() {
  local skill="" items="" actions="" escalations="" tokens="" outcome="" notes="—"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --skill)       skill="$2";       shift 2 ;;
      --items)       items="$2";       shift 2 ;;
      --actions)     actions="$2";     shift 2 ;;
      --escalations) escalations="$2"; shift 2 ;;
      --tokens)      tokens="$2";      shift 2 ;;
      --outcome)     outcome="$2";     shift 2 ;;
      --notes)       notes="$2";       shift 2 ;;
      *) die "append: argumento desconocido: $1" ;;
    esac
  done

  [[ -z "$skill" ]]       && die "append requiere --skill"
  [[ -z "$items" ]]       && die "append requiere --items"
  [[ -z "$actions" ]]     && die "append requiere --actions"
  [[ -z "$escalations" ]] && die "append requiere --escalations"
  [[ -z "$tokens" ]]      && die "append requiere --tokens"
  [[ -z "$outcome" ]]     && die "append requiere --outcome"

  case "$outcome" in
    DONE|ESCALATED|ABORTED|TIMEOUT) ;;
    *) die "outcome debe ser DONE|ESCALATED|ABORTED|TIMEOUT, recibido: $outcome" ;;
  esac

  ensure_log "$skill"

  local now_date now_iso
  now_date="$(date -u '+%Y-%m-%d %H:%M')"
  now_iso="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  local started="${LOOP_RUN_STARTED:-$now_iso}"

  local f
  f="$(log_file "$skill")"

  cat >>"$f" <<EOF

## ${now_date} UTC — ${skill} — ${outcome}
- started: ${started}
- ended: ${now_iso}
- items_found: ${items}
- actions_taken: ${actions}
- escalations: ${escalations}
- tokens_estimated: ${tokens}
- outcome: ${outcome}
- notes: ${notes}
EOF

  echo "run-log: entrada añadida → $f"
}

# ---------- subcomando: tail --------------------------------------------------

cmd_tail() {
  local skill="" lines=10

  while [[ $# -gt 0 ]]; do
    case $1 in
      --skill) skill="$2"; shift 2 ;;
      --lines) lines="$2"; shift 2 ;;
      *) die "tail: argumento desconocido: $1" ;;
    esac
  done

  [[ -z "$skill" ]] && die "tail requiere --skill"

  local f
  f="$(log_file "$skill")"
  [[ ! -f "$f" ]] && { echo "(sin entradas — log no existe)"; return 0; }

  # Extraer bloques ## (una entrada = bloque que empieza con "## ")
  # Separar por "## " y tomar los últimos N bloques
  python3 - "$f" "$lines" <<'PYEOF'
import sys, re

path = sys.argv[1]
n = int(sys.argv[2])

text = open(path).read()
# Split on entry headers (## YYYY-...)
entries = re.split(r'(?=^## \d{4}-\d{2}-\d{2})', text, flags=re.MULTILINE)
# Filter blank/header-only entries
entries = [e.strip() for e in entries if re.match(r'^## \d{4}-\d{2}-\d{2}', e.strip())]

tail = entries[-n:] if len(entries) >= n else entries
print('\n\n'.join(tail))
PYEOF
}

# ---------- subcomando: stats -------------------------------------------------

cmd_stats() {
  local skill=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --skill) skill="$2"; shift 2 ;;
      *) die "stats: argumento desconocido: $1" ;;
    esac
  done

  [[ -z "$skill" ]] && die "stats requiere --skill"

  local f
  f="$(log_file "$skill")"
  if [[ ! -f "$f" ]]; then
    echo "total_runs: 0"
    echo "success_rate: 0.00"
    echo "avg_tokens: 0"
    echo "total_escalations: 0"
    return 0
  fi

  python3 - "$f" <<'PYEOF'
import sys, re

path = sys.argv[1]
text = open(path).read()

entries = re.split(r'(?=^## \d{4}-\d{2}-\d{2})', text, flags=re.MULTILINE)
entries = [e.strip() for e in entries if re.match(r'^## \d{4}-\d{2}-\d{2}', e.strip())]

total = len(entries)
done = 0
tokens_sum = 0
escalations_sum = 0

for e in entries:
    m_outcome = re.search(r'^- outcome:\s*(\S+)', e, re.MULTILINE)
    m_tokens  = re.search(r'^- tokens_estimated:\s*(\d+)', e, re.MULTILINE)
    m_esc     = re.search(r'^- escalations:\s*(\d+)', e, re.MULTILINE)

    if m_outcome and m_outcome.group(1) == 'DONE':
        done += 1
    if m_tokens:
        tokens_sum += int(m_tokens.group(1))
    if m_esc:
        escalations_sum += int(m_esc.group(1))

rate = (done / total) if total > 0 else 0.0
avg  = (tokens_sum // total) if total > 0 else 0

print(f"total_runs: {total}")
print(f"success_rate: {rate:.2f}")
print(f"avg_tokens: {avg}")
print(f"total_escalations: {escalations_sum}")
PYEOF
}

# ---------- subcomando: prune -------------------------------------------------

cmd_prune() {
  local skill="" days=90

  while [[ $# -gt 0 ]]; do
    case $1 in
      --skill) skill="$2"; shift 2 ;;
      --days)  days="$2";  shift 2 ;;
      *) die "prune: argumento desconocido: $1" ;;
    esac
  done

  [[ -z "$skill" ]] && die "prune requiere --skill"

  local f
  f="$(log_file "$skill")"
  [[ ! -f "$f" ]] && { echo "prune: log no existe, nada que podar"; return 0; }

  python3 - "$f" "$days" <<'PYEOF'
import sys, re
from datetime import datetime, timezone, timedelta

path = sys.argv[1]
days = int(sys.argv[2])
cutoff = datetime.now(timezone.utc) - timedelta(days=days)

text = open(path).read()

# Split header (lines before first entry) and entries
header_match = re.search(r'^## \d{4}-\d{2}-\d{2}', text, re.MULTILINE)
if not header_match:
    print("prune: sin entradas que evaluar")
    sys.exit(0)

header = text[:header_match.start()]
body = text[header_match.start():]

entries = re.split(r'(?=^## \d{4}-\d{2}-\d{2})', body, flags=re.MULTILINE)
entries = [e for e in entries if re.match(r'^## \d{4}-\d{2}-\d{2}', e.strip())]

kept = []
pruned = 0

for e in entries:
    m = re.match(r'^## (\d{4}-\d{2}-\d{2} \d{2}:\d{2}) UTC', e.strip())
    if not m:
        kept.append(e)
        continue
    try:
        dt = datetime.strptime(m.group(1), '%Y-%m-%d %H:%M').replace(tzinfo=timezone.utc)
    except ValueError:
        kept.append(e)
        continue
    if dt >= cutoff:
        kept.append(e)
    else:
        pruned += 1

new_text = header + '\n'.join(kept)
# Normalize trailing newline
new_text = new_text.rstrip('\n') + '\n'

with open(path, 'w') as fh:
    fh.write(new_text)

print(f"prune: {pruned} entradas eliminadas, {len(kept)} conservadas (cutoff: {cutoff.strftime('%Y-%m-%d')})")
PYEOF
}

# ---------- dispatcher -------------------------------------------------------

if [[ $# -eq 0 ]]; then
  usage
  exit 2
fi

SUBCMD="$1"
shift

case "$SUBCMD" in
  append) cmd_append "$@" ;;
  tail)   cmd_tail   "$@" ;;
  stats)  cmd_stats  "$@" ;;
  prune)  cmd_prune  "$@" ;;
  --help|-h) usage; exit 0 ;;
  *) echo "ERROR: subcomando desconocido: $SUBCMD" >&2; usage; exit 2 ;;
esac
