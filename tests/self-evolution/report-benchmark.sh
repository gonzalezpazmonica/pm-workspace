#!/usr/bin/env bash
# SE-387 H — Agrega resultados de benchmark a tabla de comparación.
set -uo pipefail
ROOT="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"
RES="$ROOT/tests/self-evolution/results"
echo "# Benchmark results (SE-384/387 H)"
for f in "$RES"/last-*.json; do
  [[ -f "$f" ]] || continue
  python3 -c "import json;d=json.load(open('$f'));print(f\"- {d.get('task')}: {d.get('status','?')} baseline={str(d.get('baseline'))[:9]}\")"
done
echo "Ejecución real por tarea: sesión agente en worktree aislado; resultados aquí (cero auto-merge)."
