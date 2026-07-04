#!/usr/bin/env python3
"""scripts/calibracion.py — SE-255 Slice 4

Calibracion medida: registra claims, resuelve con outcomes del ledger,
genera curvas de calibracion por ambito, y ajusta confianza inline.
"""
from __future__ import annotations

import json
import sys
import os
from datetime import datetime, timezone
from pathlib import Path
from collections import defaultdict

ROOT = Path(__file__).parent.parent
LEDGER = ROOT / "data" / "relacion" / "ledger.jsonl"
CLAIMS = ROOT / "data" / "relacion" / "claims.jsonl"
MIN_CLAIMS = 25
GAP_THRESHOLD = 15


def load_ledger() -> list[dict]:
    if not LEDGER.exists():
        return []
    entries = []
    with open(LEDGER) as f:
        for line in f:
            line = line.strip()
            if line:
                entries.append(json.loads(line))
    return entries


def load_claims() -> list[dict]:
    if not CLAIMS.exists():
        return []
    entries = []
    with open(CLAIMS) as f:
        for line in f:
            line = line.strip()
            if line:
                entries.append(json.loads(line))
    return entries


def register_claim(claim_id: str, texto: str, confianza: int, ambito: str, 
                   resolvible: bool = True) -> None:
    entry = {
        "claim_id": claim_id,
        "texto": texto,
        "confianza": confianza,
        "ambito": ambito,
        "resolvible_para": datetime.now(timezone.utc).isoformat(),
        "ts": datetime.now(timezone.utc).isoformat(),
        "resuelto": False,
        "acierto": None,
        "outcome": None,
    }
    with open(CLAIMS, "a") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")


def resolve_claims_from_ledger() -> int:
    claims = load_claims()
    ledger = load_ledger()
    resolved = 0
    claim_map = {c["claim_id"]: c for c in claims}

    for entry in ledger:
        if entry.get("tipo") == "acierto_verificado" and "claim_id" in entry:
            cid = entry["claim_id"]
            if cid in claim_map and not claim_map[cid].get("resuelto"):
                claim_map[cid]["resuelto"] = True
                claim_map[cid]["acierto"] = True
                claim_map[cid]["outcome"] = entry.get("texto", "")
                resolved += 1
        elif entry.get("tipo") == "error_reconocido" and "claim_id" in entry:
            cid = entry["claim_id"]
            if cid in claim_map and not claim_map[cid].get("resuelto"):
                claim_map[cid]["resuelto"] = True
                claim_map[cid]["acierto"] = False
                claim_map[cid]["outcome"] = entry.get("texto", "")
                resolved += 1

    if resolved > 0:
        with open(CLAIMS, "w") as f:
            for c in claim_map.values():
                f.write(json.dumps(c, ensure_ascii=False) + "\n")

    return resolved


def calibration_by_scope() -> dict:
    claims = [c for c in load_claims() if c.get("resuelto")]
    by_scope = defaultdict(list)
    for c in claims:
        by_scope[c["ambito"]].append(c)

    result = {}
    for ambito, scope_claims in by_scope.items():
        if len(scope_claims) < MIN_CLAIMS:
            result[ambito] = {"status": "sin_datos", "n": len(scope_claims)}
            continue
        aciertos = sum(1 for c in scope_claims if c["acierto"])
        tasa = (aciertos / len(scope_claims)) * 100
        confianza_media = sum(c["confianza"] for c in scope_claims) / len(scope_claims)
        gap = confianza_media - tasa
        result[ambito] = {
            "status": "calibrado",
            "n": len(scope_claims),
            "tasa_acierto": round(tasa, 1),
            "confianza_media": round(confianza_media, 1),
            "gap": round(gap, 1),
            "ajuste_activo": abs(gap) > GAP_THRESHOLD,
        }
    return result


def adjusted_confidence(ambito: str, declared: int) -> dict:
    cal = calibration_by_scope().get(ambito)
    if not cal or cal.get("status") != "calibrado" or not cal.get("ajuste_activo"):
        return {"declarada": declared, "ajustada": None, "gap": cal.get("gap", 0) if cal else 0}
    return {
        "declarada": declared,
        "ajustada": round(declared - cal["gap"]),
        "gap": cal["gap"],
        "historial_n": cal["n"],
    }


def monthly_report() -> str:
    cal = calibration_by_scope()
    lines = ["# Informe mensual de calibracion", "", f"Generado: {datetime.now(timezone.utc).isoformat()}", ""]
    for ambito, data in sorted(cal.items()):
        if data["status"] == "sin_datos":
            lines.append(f"## {ambito}: sin datos (n={data['n']}, minimo {MIN_CLAIMS})")
        else:
            lines.append(f"## {ambito}: {data['tasa_acierto']}% acierto vs {data['confianza_media']}% confianza (gap={data['gap']}pp, n={data['n']})")
    return "\n".join(lines)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "report"
    if cmd == "register":
        register_claim(sys.argv[2], sys.argv[3], int(sys.argv[4]), sys.argv[5])
    elif cmd == "resolve":
        n = resolve_claims_from_ledger()
        print(f"Resueltos: {n}")
    elif cmd == "calibrate":
        print(json.dumps(calibration_by_scope(), indent=2, ensure_ascii=False))
    elif cmd == "adjust":
        result = adjusted_confidence(sys.argv[2], int(sys.argv[3]))
        print(json.dumps(result, indent=2, ensure_ascii=False))
    elif cmd == "report":
        print(monthly_report())
    else:
        print(f"Usage: {sys.argv[0]} register|resolve|calibrate|adjust|report")
