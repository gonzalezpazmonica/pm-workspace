#!/usr/bin/env bash
# court-score-aggregator.sh
#
# SE-236: Agregador de scoring numérico para el Code Review Court.
#
# Lee output JSONL de los jueces (uno por línea), calcula la energía total
# ponderada (inspirado en Proto's energy-based constraints), y reporta:
#   - total_energy: float [0.0, 1.0]
#   - bottleneck_judge: juez con mayor score ponderado
#   - convergence_score: 1.0 - total_energy
#   - verdict: PASS / CONDITIONAL / FAIL
#
# Uso:
#   cat jueces-output.jsonl | court-score-aggregator.sh
#   court-score-aggregator.sh jueces-output.jsonl
#
# Variables de entorno:
#   COURT_ENERGY_THRESHOLD  — umbral de pass (default: 0.2)
#   COURT_OUTPUT_FORMAT     — "json" (default) o "text"
#
# Ref: docs/propuestas/SE-236-court-numeric-scoring.md
#
# Exit codes:
#   0 — PASS
#   1 — FAIL
#   2 — CONDITIONAL
#   3 — error de sintaxis en input

set -euo pipefail

# ── Configuración ────────────────────────────────────────────────────────────
COURT_ENERGY_THRESHOLD="${COURT_ENERGY_THRESHOLD:-0.2}"
COURT_CONDITIONAL_THRESHOLD="${COURT_CONDITIONAL_THRESHOLD:-0.5}"
COURT_OUTPUT_FORMAT="${COURT_OUTPUT_FORMAT:-json}"

# ── Verificar dependencias ───────────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
  echo '{"error":"python3 requerido para court-score-aggregator.sh"}' >&2
  exit 3
fi

# ── Escribir script Python en fichero temporal ────────────────────────────────
PYTHON_SCRIPT=$(mktemp /tmp/court-aggregator-XXXXXX.py)
trap 'rm -f "$PYTHON_SCRIPT"' EXIT

cat > "$PYTHON_SCRIPT" << 'PYTHON_SCRIPT_EOF'
import sys
import json

input_file = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] else None
energy_threshold = float(sys.argv[2]) if len(sys.argv) > 2 else 0.2
conditional_threshold = float(sys.argv[3]) if len(sys.argv) > 3 else 0.5
output_format = sys.argv[4] if len(sys.argv) > 4 else "json"

# Leer líneas JSONL
lines = []
try:
    if input_file and input_file != "STDIN":
        with open(input_file) as f:
            lines = [l.strip() for l in f if l.strip()]
    else:
        lines = [l.strip() for l in sys.stdin if l.strip()]
except Exception as e:
    print(json.dumps({"error": str(e)}))
    sys.exit(3)

# Sin jueces → PASS por defecto (nada que violar)
if not lines:
    result = {
        "total_energy": 0.0,
        "bottleneck_judge": None,
        "convergence_score": 1.0,
        "verdict": "PASS",
        "judge_scores": {},
        "note": "no judges — PASS by default"
    }
    if output_format == "text":
        print("total_energy:      0.0000")
        print("bottleneck_judge:  none")
        print("convergence_score: 1.0000")
        print("verdict:           PASS")
    else:
        print(json.dumps(result))
    sys.exit(0)

# Parsear jueces
judges = {}
for i, line in enumerate(lines):
    try:
        entry = json.loads(line)
        judge = entry.get("judge", f"judge_{i}")
        score = float(entry.get("score", 0.0))
        weight = float(entry.get("weight", 1.0))
        blocking = bool(entry.get("blocking", False))
        blocking_threshold = float(entry.get("blocking_threshold", 0.5))
        rationale = entry.get("rationale", "")
        judges[judge] = {
            "score": max(0.0, min(1.0, score)),
            "weight": max(0.0, weight),
            "blocking": blocking,
            "blocking_threshold": blocking_threshold,
            "rationale": rationale
        }
    except (json.JSONDecodeError, ValueError) as e:
        sys.stderr.write(f"línea {i+1} inválida: {e}\n")

if not judges:
    result = {
        "total_energy": 0.0,
        "bottleneck_judge": None,
        "convergence_score": 1.0,
        "verdict": "PASS",
        "judge_scores": {},
        "note": "no valid judges — PASS by default"
    }
    print(json.dumps(result))
    sys.exit(0)

# Calcular energía total ponderada
total_weight = sum(j["weight"] for j in judges.values())
if total_weight == 0:
    total_weight = 1.0

weighted_sum = sum(j["score"] * j["weight"] for j in judges.values())
total_energy = weighted_sum / total_weight
total_energy = max(0.0, min(1.0, total_energy))
convergence_score = round(1.0 - total_energy, 4)

# Detectar bottleneck (mayor contribución ponderada)
bottleneck_judge = None
max_contribution = -1.0
for judge_name, j in judges.items():
    contribution = j["score"] * j["weight"]
    if contribution > max_contribution:
        max_contribution = contribution
        bottleneck_judge = judge_name

# Verificar jueces bloqueantes
blocking_triggered = []
for judge_name, j in judges.items():
    if j["blocking"] and j["score"] > j["blocking_threshold"]:
        blocking_triggered.append(judge_name)

# Determinar veredicto
if blocking_triggered:
    verdict = "FAIL"
    verdict_reason = f"blocking judges: {', '.join(blocking_triggered)}"
elif total_energy >= conditional_threshold:
    verdict = "FAIL"
    verdict_reason = f"total_energy {total_energy:.4f} >= {conditional_threshold}"
elif total_energy >= energy_threshold:
    verdict = "CONDITIONAL"
    verdict_reason = f"total_energy {total_energy:.4f} >= threshold {energy_threshold}"
else:
    verdict = "PASS"
    verdict_reason = f"total_energy {total_energy:.4f} < threshold {energy_threshold}"

result = {
    "total_energy": round(total_energy, 4),
    "bottleneck_judge": bottleneck_judge,
    "convergence_score": convergence_score,
    "verdict": verdict,
    "verdict_reason": verdict_reason,
    "judge_scores": {
        name: {
            "score": j["score"],
            "weight": j["weight"],
            "blocking": j["blocking"],
            "weighted_contribution": round(j["score"] * j["weight"] / total_weight, 4)
        }
        for name, j in judges.items()
    }
}
if blocking_triggered:
    result["blocking_judges"] = blocking_triggered

if output_format == "text":
    print(f"total_energy:      {total_energy:.4f}")
    print(f"bottleneck_judge:  {bottleneck_judge}")
    print(f"convergence_score: {convergence_score:.4f}")
    print(f"verdict:           {verdict}")
    print(f"verdict_reason:    {verdict_reason}")
else:
    print(json.dumps(result, indent=2))

if verdict == "PASS":
    sys.exit(0)
elif verdict == "CONDITIONAL":
    sys.exit(2)
else:
    sys.exit(1)
PYTHON_SCRIPT_EOF

# ── Leer input ───────────────────────────────────────────────────────────────
INPUT_ARG="STDIN"
if [[ $# -gt 0 && -f "$1" ]]; then
  INPUT_ARG="$1"
fi

# ── Ejecutar ─────────────────────────────────────────────────────────────────
if [[ "$INPUT_ARG" == "STDIN" ]]; then
  # Leer stdin y pasarlo al script Python
  STDIN_CONTENT=$(cat)
  echo "$STDIN_CONTENT" | python3 "$PYTHON_SCRIPT" "STDIN" \
    "$COURT_ENERGY_THRESHOLD" \
    "$COURT_CONDITIONAL_THRESHOLD" \
    "$COURT_OUTPUT_FORMAT"
else
  python3 "$PYTHON_SCRIPT" "$INPUT_ARG" \
    "$COURT_ENERGY_THRESHOLD" \
    "$COURT_CONDITIONAL_THRESHOLD" \
    "$COURT_OUTPUT_FORMAT"
fi
