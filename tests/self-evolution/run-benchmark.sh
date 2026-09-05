#!/usr/bin/env bash
# run-benchmark.sh — SE-384: Savia Self-Evolution Benchmark (piloto, 3 tareas).
# Ejecuta el ciclo por tarea en worktree aislado (baseline_commit), con gates
# del workspace activos. v0 = feasibility probe: runner + 3 tareas piloto;
# dataset completo (>=20) queda como hito siguiente.
#
# Uso:  bash tests/self-evolution/run-benchmark.sh [--dry]   # --dry: lista tareas
# Salida: tests/self-evolution/results/last-{ID}.json + resumen markdown.
# Cero auto-merge; revisión humana = autoridad final. Todo local (CRIT-001).
set -uo pipefail
ROOT="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"
DS="$ROOT/tests/self-evolution/dataset"
OUT="$ROOT/tests/self-evolution/results"
mkdir -p "$OUT"

if [[ "${1:-}" == "--dry" ]]; then
  for t in "$DS"/*.yaml; do echo "tarea: $(basename "$t")"; done
  exit 0
fi

echo "# Self-Evolution Benchmark — piloto $(date -u +%Y-%m-%d)"
echo
echo "| tarea | baseline | estado |"
echo "|---|---|---|"

for t in "$DS"/*.yaml; do
  ID=$(basename "$t" .yaml)
  BASE=$(grep -oP 'baseline_commit:\s*\K[0-9a-f]+' "$t" | head -1)
  # v0 probe: valida que la tarea esté bien formada y su baseline exista.
  # La ejecución del agente por tarea se dispara manualmente (sesión dedicada)
  # grabando results; el runner v0 verifica prerequisitos y genera el esqueleto.
  OK=1
  for k in problem expected_files invariants risk_level evaluation; do
    grep -q "^$k:" "$t" || { OK=0; break; }
  done
  if [[ -n "$BASE" ]] && ! git -C "$ROOT" cat-file -e "$BASE" 2>/dev/null; then
    OK=0
  fi
  if [[ $OK -eq 1 ]]; then
    printf '{"task":"%s","baseline":"%s","status":"READY","runner_version":0}\n' "$ID" "$BASE" \
      > "$OUT/last-$ID.json"
    echo "| $ID | ${BASE:0:9} | READY |"
  else
    printf '{"task":"%s","status":"INVALID_TASK","runner_version":0}\n' "$ID" \
      > "$OUT/last-$ID.json"
    echo "| $ID | ${BASE:-?} | INVALID |"
  fi
done
echo
echo "Runner v0 (probe): prerequisitos verificados. Ejecución real por tarea ="
echo "sesión agente dedicada con gates activos + registro en results/. Cero auto-merge."
exit 0
