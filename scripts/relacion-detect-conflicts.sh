#!/usr/bin/env bash
# scripts/relacion-detect-conflicts.sh — SE-256 Slice 2
# Detecta entradas contradictorias en el libro de la relacion.
# Estrategia: agrupa por ambito/topico, busca pares con decisiones opuestas.
# Uso: bash scripts/relacion-detect-conflicts.sh [--json]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
LEDGER="${LEDGER:-$ROOT/data/relacion/ledger.jsonl}"
JSON_OUT=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_OUT=true; shift ;;
    *) echo "ERROR: unknown flag: $1" >&2; exit 1 ;;
  esac
done

if [[ ! -f "$LEDGER" ]]; then
  echo "[]"
  exit 0
fi

python3 << 'PYEOF'
import json, sys, os
from collections import defaultdict

ledger_path = os.environ.get("LEDGER_PATH", os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "data/relacion/ledger.jsonl"
))

try:
    with open(ledger_path) as f:
        entries = [json.loads(line) for line in f if line.strip()]
except (FileNotFoundError, json.JSONDecodeError):
    print("[]")
    sys.exit(0)

if len(entries) < 2:
    print("[]")
    sys.exit(0)

json_out = os.environ.get("JSON_OUT", "false") == "true" or "--json" in sys.argv

# Agrupar por tipo de entrada en el mismo ambito
by_type = defaultdict(list)
for e in entries:
    tipo = e.get("tipo", "unknown")
    texto = e.get("texto", "")
    by_type[tipo].append(e)

conflicts = []

# Detectar pares de overrides que se contradicen
overrides = by_type.get("override", [])
for i in range(len(overrides)):
    for j in range(i + 1, len(overrides)):
        a, b = overrides[i], overrides[j]
        a_text = a.get("texto", "")
        b_text = b.get("texto", "")
        # Heuristica: si ambos mencionan el mismo topico pero con verbos opuestos
        # (descarta, rechaza, ignora vs acepta, aprueba, confirma)
        a_words = set(a_text.lower().split())
        b_words = set(b_text.lower().split())
        common = a_words & b_words
        if len(common) >= 3:
            a_ts = a.get("ts", "")
            b_ts = b.get("ts", "")
            relation = "supersedes" if a_ts < b_ts else "conflicts_with"
            conflicts.append({
                "type": "conflict",
                "relation": relation,
                "entry_a": a.get("entry_id", ""),
                "entry_b": b.get("entry_id", ""),
                "text_a": a_text[:80],
                "text_b": b_text[:80],
                "common_words": list(common)[:5],
            })

# Detectar pares de error_reconocido + override en mismo topico
errors = by_type.get("error_reconocido", [])
for err in errors:
    for ovr in overrides:
        if err.get("entry_id") == ovr.get("entry_id"):
            continue
        err_text = err.get("texto", "").lower()
        ovr_text = ovr.get("texto", "").lower()
        err_words = set(err_text.split())
        ovr_words = set(ovr_text.split())
        common = err_words & ovr_words
        if len(common) >= 2:
            conflicts.append({
                "type": "error_override",
                "entry_error": err.get("entry_id", ""),
                "entry_override": ovr.get("entry_id", ""),
                "text_error": err.get("texto", "")[:80],
                "text_override": ovr.get("texto", "")[:80],
                "common_words": list(common)[:5],
            })

if json_out:
    print(json.dumps(conflicts, indent=2, ensure_ascii=False))
else:
    if not conflicts:
        print("No se detectaron conflictos en el ledger.")
    else:
        print(f"Detectados {len(conflicts)} conflictos potenciales:")
        for c in conflicts:
            print(f"  {c.get('relation','?')}: {c.get('entry_a','')} <-> {c.get('entry_b','')}")
            print(f"    {c.get('text_a','')[:60]}")
            print(f"    {c.get('text_b','')[:60]}")
            print("")
PYEOF
