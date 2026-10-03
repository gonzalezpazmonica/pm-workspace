#!/usr/bin/env bash
# cache-metrics.sh — SE-371: ledger local de métricas de prompt cache.
#
# Sin métrica no hay gestión. Este script registra y agrega usage del cache
# del provider en un ledger local (CRIT-001: cero telemetría a proveedor).
#
#   record --model M --input N [--cache-read R] [--cache-creation C] [--session S]
#   record --usage-json '{...}' [--model M] [--session S]   # formato Anthropic
#   ingest-opencode [--db PATH] [--days N]  # lee opencode.db local (dedupe por sesion)
#   capture                                 # alias de ingest-opencode (para hooks)
#   report [--session S] [--model M]                        # hit rate + coste relativo
#   --validate                                              # schema de lineas
#
# Linea ledger: {"ts":"...","session":S,"model":M,"input":N,"cache_read":R,
#                "cache_creation":C}
# Coste relativo estimado (multiplicadores provider estandar): reads x0.1,
# writes (cache_creation) x1.25 vs input x1.0.
# CRIT-001: todo local, sin reloj obligatorio (ts opcional para tests).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LEDGER="${SAVIA_CACHE_METRICS_DIR:-$REPO_ROOT/data/cache-metrics.jsonl}"
# Pese al nombre, la variable admite fichero o directorio: si es un directorio,
# el ledger es <dir>/cache-metrics.jsonl.
[[ -d "$LEDGER" ]] && LEDGER="$LEDGER/cache-metrics.jsonl"
READ_COST=0.1
WRITE_COST=1.25

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-2}"; }
die() { echo "ERROR: $*" >&2; exit 2; }
# Flag que exige valor: evita "variable sin asignar" con set -u.
need() { [[ $# -ge 2 ]] || die "$1 exige un valor"; }
# Recuento de tokens: entero no negativo. Rechaza "1.000" y "1,5" (es_ES)
# en vez de guardarlos como 1 o romper con traceback.
is_count() { [[ "$1" =~ ^[0-9]+$ ]]; }

cmd_record() {
  local model="" input="" read_="" create_="" session="" usage_json=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --model) need "$@"; model="$2"; shift 2 ;;
      --input) need "$@"; input="$2"; shift 2 ;;
      --cache-read) need "$@"; read_="$2"; shift 2 ;;
      --cache-creation) need "$@"; create_="$2"; shift 2 ;;
      --session) need "$@"; session="$2"; shift 2 ;;
      --usage-json) need "$@"; usage_json="$2"; shift 2 ;;
      *) usage ;;
    esac
  done
  if [[ -n "$usage_json" ]]; then
    # formato Anthropic: input_tokens, cache_read_input_tokens, cache_creation_input_tokens.
    # El JSON viaja por argv: es dato, nunca se interpola en codigo Python.
    local parsed
    parsed="$(python3 -c '
import json, sys
try:
    u = json.loads(sys.argv[1])
except json.JSONDecodeError as e:
    sys.exit(f"ERROR: --usage-json no es JSON valido: {e}")
if not isinstance(u, dict):
    sys.exit("ERROR: --usage-json debe ser un objeto JSON")
out = []
for k in ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"):
    v = u.get(k, 0)
    if isinstance(v, bool) or not isinstance(v, int) or v < 0:
        sys.exit(f"ERROR: --usage-json: {k} debe ser entero >= 0 (es {v!r})")
    out.append(str(v))
print(" ".join(out))
' "$usage_json")" || exit 2
    read -r input read_ create_ <<< "$parsed"
  fi
  [[ -n "$model" && -n "$input" ]] || die "record exige --model y --input (o --usage-json)"
  read_="${read_:-0}"; create_="${create_:-0}"
  local v
  for v in "$input" "$read_" "$create_"; do
    is_count "$v" || die "recuento de tokens invalido: '$v' (entero >= 0, sin separador de miles ni decimales)"
  done
  local ts=""; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo '')"
  mkdir -p "$(dirname "$LEDGER")"
  python3 - "$LEDGER" "$ts" "$session" "$model" "$input" "$read_" "$create_" <<'PY'
import json, sys
ledger, ts, session, model = sys.argv[1:5]
input_, read_, create_ = (int(x) for x in sys.argv[5:8])
row = {"model": model, "input": input_, "cache_read": read_,
       "cache_creation": create_}
if ts: row["ts"] = ts
if session: row["session"] = session
with open(ledger, "a") as f:
    f.write(json.dumps(row) + "\n")
print("recorded:", json.dumps(row))
PY
}

cmd_report() {
  local session="" model=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --session) need "$@"; session="$2"; shift 2 ;;
      --model) need "$@"; model="$2"; shift 2 ;;
      *) usage ;;
    esac
  done
  [[ -f "$LEDGER" ]] || { echo "report: ledger vacío o inexistente: $LEDGER"; return 0; }
  python3 - "$LEDGER" "$session" "$model" <<'PY'
import json, sys
from collections import defaultdict
ledger, fsess, fmodel = sys.argv[1:4]
agg = defaultdict(lambda: {"input": 0, "read": 0, "create": 0, "n": 0})
skipped = 0
def count_ok(v):
    return isinstance(v, int) and not isinstance(v, bool) and v >= 0
for line in open(ledger):
    line = line.strip()
    if not line: continue
    try: r = json.loads(line)
    except json.JSONDecodeError:
        skipped += 1; continue
    # Filas corruptas (no objeto, recuentos no enteros) se cuentan, no rompen.
    if not isinstance(r, dict) or not all(
            count_ok(r.get(k, 0)) for k in ("input", "cache_read", "cache_creation")):
        skipped += 1; continue
    if fsess and r.get("session") != fsess: continue
    if fmodel and r.get("model") != fmodel: continue
    a = agg[r.get("model", "?")]
    a["input"] += r.get("input", 0); a["read"] += r.get("cache_read", 0)
    a["create"] += r.get("cache_creation", 0); a["n"] += 1
tot_in = sum(a["input"] for a in agg.values())
tot_read = sum(a["read"] for a in agg.values())
tot_create = sum(a["create"] for a in agg.values())
hit = tot_read / (tot_in + tot_read) if (tot_in + tot_read) else 0.0
# coste relativo: procesar (input+create*1.25) + servir desde cache (read*0.1)
cost_full = tot_in + tot_read + tot_create
cost_cache = tot_read * 0.1 + tot_create * 1.25 + tot_in
saving = (cost_full - cost_cache) / cost_full if cost_full else 0.0
print(json.dumps({
    "models": {k: dict(v) for k, v in sorted(agg.items())},
    "totals": {"input": tot_in, "cache_read": tot_read, "cache_creation": tot_create},
    "cache_hit_ratio": round(hit, 4),
    "est_saving_pct": round(saving * 100, 1),
    "skipped_lines": skipped,
}, indent=2))
PY
}

cmd_validate() {
  [[ -f "$LEDGER" ]] || { echo "validate: OK (ledger inexistente, valido)"; return 0; }
  local bad=0
  python3 - "$LEDGER" <<'PY'
import json, sys
bad = 0
for i, line in enumerate(open(sys.argv[1]), 1):
    line = line.strip()
    if not line: continue
    try:
        r = json.loads(line)
        assert isinstance(r, dict)
        assert isinstance(r.get("model"), str)
        for k in ("input", "cache_read", "cache_creation"):
            v = r.get(k)
            assert isinstance(v, int) and not isinstance(v, bool) and v >= 0
    except (json.JSONDecodeError, AssertionError):
        print(f"BAD linea {i}"); bad = 1
sys.exit(bad)
PY
  bad=$?
  [[ "$bad" -eq 0 ]] && echo "validate: OK (schema valido)"
  return $bad
}

# ingest-opencode — lee usage agregado de la DB local de OpenCode (CRIT-001).
# Dedupe por session_id contra el ledger: idempotente, seguro en cada SessionEnd.
cmd_ingest() {
  local db="" days=7
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --db) need "$@"; db="$2"; shift 2 ;;
      --days) need "$@"; days="$2"; shift 2 ;;
      *) usage ;;
    esac
  done
  is_count "$days" || die "--days debe ser entero >= 0 (es '$days')"
  [[ -z "$db" ]] && db="${OPENCODE_DB:-}"
  if [[ -z "$db" ]]; then
    local cand="${OPENCODE_DATA:-$HOME/.local/share/opencode}/opencode.db"
    [[ -f "$cand" ]] && db="$cand"
  fi
  if [[ -z "$db" || ! -f "$db" ]]; then
    echo "WARN: opencode.db no encontrado — captura local solo si usas OpenCode" >&2
    return 0
  fi
  python3 - "$db" "$LEDGER" "$days" <<'PY'
import json, os, sqlite3, sys, time
from datetime import datetime, timezone
db, ledger, days = sys.argv[1:4]
# sesiones ya registradas (dedupe por id)
seen = set()
if os.path.exists(ledger):
    for line in open(ledger):
        line = line.strip()
        if line:
            try: seen.add(json.loads(line).get("session", ""))
            except Exception: pass
con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
con.row_factory = sqlite3.Row
cutoff = int((time.time() - int(days) * 86400) * 1000)
try:
    rows = con.execute(
        "SELECT id, model, tokens_input, tokens_output, tokens_cache_read, "
        "tokens_cache_write, cost, time_created FROM session "
        "WHERE time_created >= ? AND (tokens_input > 0 OR tokens_cache_read > 0) "
        "ORDER BY time_created", (cutoff,)).fetchall()
except sqlite3.DatabaseError as e:
    # Esquema distinto (otra version de OpenCode) o fichero no SQLite.
    sys.exit(f"ERROR: {db} no tiene el esquema de sesiones de OpenCode: {e}")
added = 0
with open(ledger, "a") as f:
    for r in rows:
        sid = r["id"]
        if sid in seen: continue
        seen.add(sid)
        model = r["model"] or "?"
        try:
            m = json.loads(model)
            model = f"{m.get('providerID','?')}/{m.get('id','?')}"
        except Exception:
            pass
        ts = datetime.fromtimestamp(r["time_created"] / 1000, timezone.utc)\
                 .strftime("%Y-%m-%dT%H:%M:%SZ")
        row = {"ts": ts, "session": sid, "model": model,
               "input": r["tokens_input"] or 0,
               "cache_read": r["tokens_cache_read"] or 0,
               "cache_creation": r["tokens_cache_write"] or 0,
               "cost": round(r["cost"] or 0.0, 6),
               "source": "opencode-db"}
        f.write(json.dumps(row) + "\n")
        added += 1
print(f"ingested: {added} sesiones nuevas (ledger: {os.path.basename(ledger)})")
PY
}


case "${1:-}" in
  record) shift; cmd_record "$@" ;;
  report) shift; cmd_report "$@" ;;
  ingest-opencode|capture) shift; cmd_ingest "$@" ;;
  --validate|validate) cmd_validate ;;
  -h|--help) usage 0 ;;
  *) usage ;;
esac
exit $?
