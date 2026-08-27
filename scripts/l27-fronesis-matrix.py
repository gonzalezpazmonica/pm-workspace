#!/usr/bin/env python3
"""l27-fronesis-matrix.py — E14: matriz de frónesis de la propia Savia.

Inventario de los puntos de decisión del workspace con exposición a IA,
ambigüedad, criterio requerido y quién decide (operadora / agente / automático).
Distingue: decisión retenida por humano (frónesis), delegada con precedentes
(gate FxC), o automatizada por regla (sin frónesis — ya graduada).

Salida: output/l27-fronesis-matrix.md (tabla) + JSON. CRIT-001: local, N2.
"""

import argparse
import json
import os
from datetime import datetime, timezone

# Inventario declarativo de puntos de decisión de Savia (N2, sin datos de contenido)
DECISION_POINTS = [
    {"id": "merge-pr", "punto": "Merge de PR", "exposicion_ia": "alta", "ambiguedad": "alta",
     "criterio": "alto", "quien": "operadora", "frónesis": "retenida",
     "nota": "el agente propone (PR draft), la operadora mergea (grant exprés)"},
    {"id": "aprob-spec", "punto": "Aprobación de specs", "exposicion_ia": "alta", "ambiguedad": "alta",
     "criterio": "alto", "quien": "operadora", "frónesis": "retenida",
     "nota": "spec PROPOSED -> APPROVED solo por la operadora"},
    {"id": "grant-merge", "punto": "Grant de merge/autonomía", "exposicion_ia": "media", "ambiguedad": "media",
     "criterio": "alto", "quien": "operadora", "frónesis": "retenida",
     "nota": "SE-343: permiso exprés registrado, one-shot"},
    {"id": "gate-fronesis", "punto": "Gate de frónesis (precedentes)", "exposicion_ia": "alta", "ambiguedad": "alta",
     "criterio": "alto", "quien": "operadora+agente", "frónesis": "delegada-con-precedentes",
     "nota": "fronema.py query: los agentes traen precedentes; no deciden (SE-344)"},
    {"id": "court-review", "punto": "Court de revisión de código", "exposicion_ia": "alta", "ambiguedad": "media",
     "criterio": "medio", "quien": "agente", "frónesis": "delegada-con-precedentes",
     "nota": "5 jueces con modelos por tier (SE-265); veredicto revisable"},
    {"id": "router-modelo", "punto": "Recomendación de modelo por incertidumbre", "exposicion_ia": "alta",
     "ambiguedad": "media", "criterio": "medio", "quien": "agente", "frónesis": "delegada-con-precedentes",
     "nota": "SE-346: advisory; el dispatch real lo decide el flujo (fallo escala)"},
    {"id": "gate-commit", "punto": "Gate de commit (reglas)", "exposicion_ia": "baja", "ambiguedad": "baja",
     "criterio": "bajo", "quien": "automático", "frónesis": "automatizada",
     "nota": "commit-guardian, block-commit-to-main: regla explícita, no frónesis"},
    {"id": "gate-branch", "punto": "Gate de branch-switch-dirty", "exposicion_ia": "baja", "ambiguedad": "baja",
     "criterio": "bajo", "quien": "automático", "frónesis": "automatizada",
     "nota": "regla mecánica (evitar pérdida de trabajo)"},
    {"id": "security-gates", "punto": "Gates de seguridad (credencial/force-push/infra)", "exposicion_ia": "baja",
     "ambiguedad": "baja", "criterio": "alto (codificado)", "quien": "automático", "frónesis": "automatizada",
     "nota": "bloqueo por patrón; la frónesis vive en quién diseñó la regla"},
    {"id": "shield-gate", "punto": "Shield gate (PII)", "exposicion_ia": "media", "ambiguedad": "media",
     "criterio": "medio", "quien": "automático", "frónesis": "automatizada",
     "nota": "regex + NER (SE-348 activado); decisión de bloqueo automática"},
    {"id": "adopcion-modelo", "punto": "Adopción de modelos/specs", "exposicion_ia": "alta", "ambiguedad": "alta",
     "criterio": "alto", "quien": "operadora", "frónesis": "retenida",
     "nota": "descargas, activaciones, plan: solo la operadora"},
]


def to_md(points):
    lines = [
        "# Matriz de frónesis — Savia (L27 E14)",
        "",
        "> Inventario de puntos de decisión: exposición a IA × ambigüedad × criterio × quién.",
        "> **Frónesis retenida** = humana · **delegada-con-precedentes** = gate FxC · **automatizada** = regla (graduada).",
        "",
        "| Punto de decisión | Exposición IA | Ambigüedad | Criterio | Quién | Frónesis |",
        "|---|---|---|---|---|---|",
    ]
    for p in points:
        lines.append(
            f"| {p['punto']} | {p['exposicion_ia']} | {p['ambiguedad']} | {p['criterio']} "
            f"| {p['quien']} | {p['frónesis']} |"
        )
    lines += ["", "| Veredicto | Conteo |", "|---|---|"]
    for label in ("retenida", "delegada-con-precedentes", "automatizada"):
        n = sum(1 for p in points if p["frónesis"] == label)
        lines.append(f"| {label} | {n} |")
    lines += ["", "## Notas", ""]
    for p in points:
        lines.append(f"- **{p['punto']}**: {p['nota']}")
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser(description="E14 matriz de frónesis (L27)")
    ap.add_argument("--out", default=os.path.join("output", "l27-fronesis-matrix.md"))
    args = ap.parse_args()

    points = DECISION_POINTS
    md = to_md(points)
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        f.write(md)
    counts = {}
    for p in points:
        counts[p["frónesis"]] = counts.get(p["frónesis"], 0) + 1
    report = {
        "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "puntos": len(points),
        "por_tipo": counts,
        "out": args.out,
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    main()
