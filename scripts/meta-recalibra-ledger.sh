#!/usr/bin/env bash
# meta-recalibra-ledger.sh — L13 F4: recalibración desde señal real (ledger).
#
# Cierro el bucle F4: convierte la señal REAL del bucle SCL (ledger de ciclo de
# vida en output/learning-loop/lifecycle.jsonl) en entradas de calibración para
# meta-recalibrate.sh. La promoción canary→active por la operadora es "éxito"
# (el sistema acertó: la lección sobrevivió la validación humana); el revert es
# "fallo" (el cambio introdujo error). Sin LLM, sin red, CRIT-001.
#
# La curva así nutrida es la que meta-monitor.sh consulta después: el juicio
# metacognitivo se recalibra con la realidad del bucle, no con fixtures.
#
# Usage:
#   meta-recalibra-ledger.sh [--ledger PATH] [--calibration-file PATH]
#     [--predicted 70] [--task-type default]
# Exit: 0 ok (siempre; reporta) · 2 input inválido · 3 dependencia ausente
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_LEDGER="$ROOT/output/learning-loop/lifecycle.jsonl"
DEFAULT_CAL_FILE="$ROOT/output/meta/calibration.json"
RECAL="$ROOT/scripts/meta-recalibrate.sh"

LEDGER="$DEFAULT_LEDGER"
CAL_FILE="$DEFAULT_CAL_FILE"
PREDICTED="70"
TASK_TYPE="default"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ledger) LEDGER="${2:-}"; shift 2 ;;
    --calibration-file) CAL_FILE="${2:-}"; shift 2 ;;
    --predicted) PREDICTED="${2:-}"; shift 2 ;;
    --task-type) TASK_TYPE="${2:-}"; shift 2 ;;
    *) echo "usage: $0 [--ledger P] [--calibration-file P] [--predicted N] [--task-type T]" >&2; exit 2 ;;
  esac
done

[[ -x "$RECAL" ]] || { echo "ERROR: falta $RECAL (L13 F1)" >&2; exit 3; }
[[ -f "$LEDGER" ]] || { echo "ERROR: ledger no encontrado: $LEDGER" >&2; exit 3; }

mkdir -p "$(dirname "$CAL_FILE")"

processed=0
success=0
fail=0
skipped=0

# Leer el ledger JSONL y traducir la señal ¬metadata.
python3 - "$LEDGER" "$RECAL" "$CAL_FILE" "$PREDICTED" "$TASK_TYPE" <<'PY'
import json, subprocess, sys
ledger, rec, cal, predicted, task_type = sys.argv[1:]

def recalibrate(task, outcome, predicted):
    r = subprocess.run(
        ["bash", rec, "--task", task, "--predicted", str(predicted),
         "--outcome", outcome, "--calibration-file", cal],
        capture_output=True, text=True,
    )
    return r.returncode == 0

counts = {"processed": 0, "success": 0, "fail": 0, "skipped": 0}
with open(ledger, encoding="utf-8") as fh:
    for line in fh:
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except Exception:
            counts["skipped"] += 1
            continue
        lp_id = ev.get("id", "")
        if not lp_id:
            counts["skipped"] += 1
            continue
        fr = ev.get("from", "")
        to = ev.get("to", "")
        revert = ev.get("revert", "false")
        actor = ev.get("actor", "")
        # Señal de "éxito": la operadora ha activado la lección (→active).
        if to == "active" and actor == "operadora":
            ok = recalibrate(f"{task_type}:{lp_id}", "success", predicted)
            counts["success"] += ok
        elif revert == "true" or (to == "proposed" and fr in ("canary", "active")):
            # Señal de "fallo": reintrodujo error (revert) o fue reverted.
            ok = recalibrate(f"{task_type}:{lp_id}", "fail", predicted)
            counts["fail"] += ok
        # Promociones agent→canary (o eventos sin señal humana) se omiten.
        counts["processed"] += 1

print(f"ledger_rows={counts['processed']} signal_success={counts['success']} signal_fail={counts['fail']} skipped={counts['skipped']}")
PY