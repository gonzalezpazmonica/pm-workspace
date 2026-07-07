#!/usr/bin/env bash
# scripts/relacion-report.sh — SE-255 Slice 3
# Vista /relacion: tasa de override, patrones de error, trayectoria.
# Uso: bash scripts/relacion-report.sh [--ambito nombre]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
LEDGER="$ROOT/data/relacion/ledger.jsonl"

if [[ ! -f "$LEDGER" ]]; then
  echo "No hay libro de la relacion todavia."
  exit 0
fi

python3 << 'PYEOF'
import json, sys, os
from collections import defaultdict, Counter

ledger_path = os.environ.get("LEDGER_PATH", "data/relacion/ledger.jsonl")
entries = []
try:
    with open(ledger_path) as f:
        for line in f:
            line = line.strip()
            if line:
                entries.append(json.loads(line))
except FileNotFoundError:
    print("No hay libro de la relacion todavia.")
    sys.exit(0)

tipos = Counter(e["tipo"] for e in entries)
total = len(entries)

print("=== Libro de la Relacion ===")
print(f"  Total entradas: {total}")
print(f"  Overrides:       {tipos.get('override', 0)}")
print(f"  Errores:         {tipos.get('error_reconocido', 0)}")
print(f"  Aciertos:        {tipos.get('acierto_verificado', 0)}")
print(f"  No-se:           {tipos.get('no_se_declarado', 0)}")
print(f"  Enmiendas:       {tipos.get('enmienda_criterio', 0)}")
print(f"  Feedback:        {tipos.get('feedback_explicito', 0)}")
print("")

if total > 1:
    errores = tipos.get("error_reconocido", 0)
    aciertos = tipos.get("acierto_verificado", 0)
    if aciertos + errores > 0:
        tasa = (aciertos / (aciertos + errores)) * 100
        print(f"  Tasa de acierto: {tasa:.0f}% ({aciertos}/{aciertos+errores})")

    overrides = tipos.get("override", 0)
    if total > 5:
        ratio = (overrides / total) * 100
        print(f"  Ratio override:  {ratio:.0f}%")
        if ratio > 30:
            print("  ⚠️  Overrides altos: revisar precision del agente")
        elif ratio < 5:
            print("  ⚠️  Overrides bajos: ¿el agente esta preguntando suficiente?")

print("")
print("  Ultimas entradas:")
for e in entries[-5:]:
    ts = e.get("ts", "")[:16]
    tipo = e.get("tipo", "?")
    texto = e.get("texto", "")[:60]
    print(f"  {ts}  {tipo:22s}  {texto}")
PYEOF
