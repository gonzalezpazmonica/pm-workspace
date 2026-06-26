#!/usr/bin/env python3
"""
speculative-tool-probe.py -- Feasibility validation script for SE-220 S0.

Runs 20 synthetic workspace intents through the heuristic predictor, compares
predictions against ground-truth labels, and emits a GO/NO-GO verdict.

Threshold:
  acceptance_rate >= 0.60  -> verdict: PROCEED  (Slices 1-4 can proceed)
  acceptance_rate <  0.60  -> verdict: ABORT    (SE-220 infeasible)

Output (stdout, JSON):
  {
    "acceptance_rate": 0.80,
    "total_cases": 20,
    "correct": 16,
    "incorrect": 4,
    "verdict": "PROCEED",
    "cases": [
      {"id": 1, "intent": "...", "expected": "Read", "predicted": ["Read", ...],
       "hit": true, "confidence": 0.75}
    ]
  }

Ref: SE-220 -- Speculative Tool Execution, Slice 0
"""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
PREDICTOR_SCRIPT = ROOT / "scripts" / "speculative-tool-predictor.py"

ACCEPT_THRESHOLD = 0.60

# ---------------------------------------------------------------------------
# Ground-truth dataset -- 20 representative workspace intents.
# "expected" = the PRIMARY tool the orchestrator would call first.
# A prediction is a HIT when expected is in predicted_tools[:3].
# ---------------------------------------------------------------------------
DATASET: list[dict[str, str]] = [
    # 1 -- Sprint management (ADO WIQL queries)
    {
        "id": "1",
        "intent": "dame el estado del sprint actual con capacity y velocity",
        "expected": "Bash",
    },
    # 2 -- Read a file
    {
        "id": "2",
        "intent": "lee el fichero docs/propuestas/SE-220.md",
        "expected": "Read",
    },
    # 3 -- Search for a function
    {
        "id": "3",
        "intent": "busca la funcion predict en scripts del proyecto",
        "expected": "Grep",
    },
    # 4 -- Edit a file
    {
        "id": "4",
        "intent": "modifica el metodo calculate_velocity para añadir filtro de outliers",
        "expected": "Edit",
    },
    # 5 -- Create a new file
    {
        "id": "5",
        "intent": "crea el fichero scripts/new-report.py con el esqueleto inicial",
        "expected": "Write",
    },
    # 6 -- Run tests
    {
        "id": "6",
        "intent": "ejecuta los tests de pytest en tests/scripts/",
        "expected": "Bash",
    },
    # 7 -- Git diff
    {
        "id": "7",
        "intent": "muestrame el git diff del ultimo commit",
        "expected": "Bash",
    },
    # 8 -- Show architecture doc
    {
        "id": "8",
        "intent": "muestra el contenido de docs/architecture.md",
        "expected": "Read",
    },
    # 9 -- Find references
    {
        "id": "9",
        "intent": "encuentra todas las referencias a AUTONOMOUS_REVIEWER en el workspace",
        "expected": "Grep",
    },
    # 10 -- Build/deploy
    {
        "id": "10",
        "intent": "ejecuta el script de build y comprueba que no hay errores",
        "expected": "Bash",
    },
    # 11 -- ADO backlog
    {
        "id": "11",
        "intent": "consulta el backlog del sprint en Azure DevOps y filtra por IterationPath",
        "expected": "Bash",
    },
    # 12 -- Edit config
    {
        "id": "12",
        "intent": "actualiza el fichero opencode.json para añadir el nuevo MCP server",
        "expected": "Edit",
    },
    # 13 -- Read spec
    {
        "id": "13",
        "intent": "revisa la spec SE-218 en docs/propuestas",
        "expected": "Read",
    },
    # 14 -- Security audit
    {
        "id": "14",
        "intent": "ejecuta el script de security audit contra el codigo del proyecto",
        "expected": "Bash",
    },
    # 15 -- Create changelog
    {
        "id": "15",
        "intent": "genera el fichero CHANGELOG.d/se-220.md con la entrada de release",
        "expected": "Write",
    },
    # 16 -- Search pattern in code
    {
        "id": "16",
        "intent": "busca todos los ficheros que contienen el patron acceptance_rate",
        "expected": "Grep",
    },
    # 17 -- Run bats tests
    {
        "id": "17",
        "intent": "corre los bats tests del directorio tests/bats",
        "expected": "Bash",
    },
    # 18 -- Read memory file
    {
        "id": "18",
        "intent": "lee el indice de memoria del usuario activo",
        "expected": "Read",
    },
    # 19 -- Modify function
    {
        "id": "19",
        "intent": "cambia la funcion parse_wiql para soportar multiples proyectos",
        "expected": "Edit",
    },
    # 20 -- Git log
    {
        "id": "20",
        "intent": "muestra el git log de los ultimos 10 commits con formato oneline",
        "expected": "Bash",
    },
]

AVAILABLE_TOOLS = ["Bash", "Read", "Grep", "Edit", "Write"]


def _load_predictor():
    """Dynamically load the predictor module."""
    spec = importlib.util.spec_from_file_location("speculative_tool_predictor", PREDICTOR_SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def run_probe(dataset: list[dict[str, str]] | None = None) -> dict[str, Any]:
    """Execute the full probe and return the results dict."""
    if dataset is None:
        dataset = DATASET

    predictor = _load_predictor()
    cases: list[dict[str, Any]] = []
    correct = 0

    for entry in dataset:
        result = predictor.predict(entry["intent"], AVAILABLE_TOOLS)
        predicted = result["predicted_tools"]
        hit = entry["expected"] in predicted
        if hit:
            correct += 1
        cases.append({
            "id": entry["id"],
            "intent": entry["intent"],
            "expected": entry["expected"],
            "predicted": predicted,
            "hit": hit,
            "confidence": result["confidence"],
            "rationale": result.get("rationale", ""),
        })

    total = len(dataset)
    acceptance_rate = round(correct / total, 4) if total > 0 else 0.0
    verdict = "PROCEED" if acceptance_rate >= ACCEPT_THRESHOLD else "ABORT"

    return {
        "acceptance_rate": acceptance_rate,
        "total_cases": total,
        "correct": correct,
        "incorrect": total - correct,
        "verdict": verdict,
        "threshold": ACCEPT_THRESHOLD,
        "cases": cases,
    }


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(
        description="SE-220 S0 -- Speculative tool prediction feasibility probe",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--summary", action="store_true",
                        help="Print human-readable summary to stderr")
    args = parser.parse_args()

    results = run_probe()
    print(json.dumps(results, ensure_ascii=False, indent=2))

    if args.summary:
        print(
            f"\n=== SE-220 S0 FEASIBILITY PROBE ===\n"
            f"  acceptance_rate : {results['acceptance_rate']:.2%}\n"
            f"  correct/total   : {results['correct']}/{results['total_cases']}\n"
            f"  verdict         : {results['verdict']}\n",
            file=sys.stderr,
        )

    return 0 if results["verdict"] == "PROCEED" else 1


if __name__ == "__main__":
    sys.exit(main())
