#!/usr/bin/env python3
"""Local, evidence-first GRC assessment. No certification or legal sign-off."""
from __future__ import annotations

import argparse
import hashlib
import json
from datetime import date
from pathlib import Path


STATES = {"COMPLIANT", "PARTIALLY_COMPLIANT", "NON_COMPLIANT", "NOT_APPLICABLE", "NOT_ASSESSED", "INSUFFICIENT_EVIDENCE", "NEEDS_REVIEW"}
FORBIDDEN = {"CERTIFY", "LEGAL_SIGN_OFF", "ACCEPT_RISK", "CLOSE_FINDING", "APPROVE_POLICY", "MODIFY_CONTROL_STATE"}


class AssessmentError(ValueError):
    pass


def required(item: dict, fields: tuple[str, ...], kind: str) -> None:
    missing = [field for field in fields if item.get(field) in (None, "", [])]
    if missing:
        raise AssessmentError(f"{kind}: faltan {', '.join(missing)}")


def assess(data: dict, base: Path, today: date | None = None) -> dict:
    today = today or date.today()
    if any(str(action).upper() in FORBIDDEN for action in data.get("actions", [])):
        raise AssessmentError("Acción reservada a autoridad humana o prohibida")
    scope = data.get("scope", {})
    required(scope, ("id", "systems", "owner"), "scope")
    if not isinstance(scope["systems"], list):
        raise AssessmentError("scope.systems debe ser una lista")
    framework_items = data.get("frameworks", [])
    if len({f.get("id") for f in framework_items}) != len(framework_items):
        raise AssessmentError("IDs de framework duplicados")
    frameworks = {f["id"]: f for f in framework_items}
    if not frameworks:
        raise AssessmentError("Faltan frameworks y fuentes normativas")
    for framework in frameworks.values():
        required(framework, ("version", "status", "official_source", "last_verified"), "framework")
        if framework["status"] != "current":
            raise AssessmentError(f"Referencia obsoleta: {framework['id']}")
        try:
            verified = date.fromisoformat(framework["last_verified"])
        except ValueError as exc:
            raise AssessmentError("last_verified debe ser ISO 8601") from exc
        if verified > today or (today - verified).days > 90:
            raise AssessmentError(f"Verificación normativa caducada: {framework['id']}")
    control_items = data.get("controls", [])
    if len({c.get("id") for c in control_items}) != len(control_items):
        raise AssessmentError("IDs de control duplicados")
    controls = {c["id"]: c for c in control_items}
    requirements = data.get("requirements", [])
    if not requirements:
        raise AssessmentError("Faltan requisitos aplicables y trazables")
    if len({r.get("id") for r in requirements}) != len(requirements):
        raise AssessmentError("IDs de requisito duplicados")
    evidence = data.get("evidence", [])
    ids = [e.get("id") for e in evidence]
    if len(ids) != len(set(ids)):
        raise AssessmentError("IDs de evidencia duplicados")
    checked = {}
    for item in evidence:
        required(item, ("id", "title", "source", "source_type", "owner", "collected_at", "valid_from", "valid_until", "hash", "classification", "frameworks", "controls", "system_scope", "trust_level", "verification_status", "test_result"), "evidence")
        path = (base / item["source"]).resolve()
        if not path.is_relative_to(base.resolve()) or not path.is_file():
            raise AssessmentError(f"Fuente de evidencia inaccesible: {item['id']}")
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != item["hash"]:
            raise AssessmentError(f"Hash de evidencia no coincide: {item['id']}")
        try:
            start, end = date.fromisoformat(item["valid_from"]), date.fromisoformat(item["valid_until"])
            collected = date.fromisoformat(item["collected_at"])
        except ValueError as exc:
            raise AssessmentError("Fecha de evidencia inválida") from exc
        if start > end or start > today or collected > today:
            raise AssessmentError(f"Periodo de evidencia inválido: {item['id']}")
        if item["test_result"] not in {"PASS", "FAIL", "UNKNOWN"}:
            raise AssessmentError("test_result inválido")
        checked[item["id"]] = {"item": item, "expired": end < today, "hash_verified": True}
    matrix, findings, risks = [], [], []
    for req in requirements:
        required(req, ("id", "framework", "control", "source_ref", "applicability"), "requirement")
        if req["framework"] not in frameworks or req["control"] not in controls:
            raise AssessmentError(f"Mapping sin referencia válida: {req['id']}")
        if req["applicability"] not in {"IN_SCOPE", "OUT_OF_SCOPE", "NOT_APPLICABLE"}:
            raise AssessmentError("applicability inválida")
        control = controls[req["control"]]
        required(control, ("id", "title", "system_scope"), "control")
        if req["applicability"] == "IN_SCOPE" and control["system_scope"] not in scope["systems"]:
            raise AssessmentError(f"Control fuera del alcance: {control['id']}")
        matches = [entry for entry in checked.values() if req["control"] in entry["item"]["controls"] and req["framework"] in entry["item"]["frameworks"] and control["system_scope"] in entry["item"]["system_scope"]]
        usable = [entry for entry in matches if not entry["expired"] and entry["item"]["verification_status"] == "VERIFIED" and entry["item"]["trust_level"] == "HIGH"]
        results = {entry["item"]["test_result"] for entry in usable}
        if req["applicability"] == "NOT_APPLICABLE":
            state, reason = "NOT_APPLICABLE", "Exclusión declarada; requiere revisión humana"
        elif req["applicability"] == "OUT_OF_SCOPE":
            state, reason = "NOT_ASSESSED", "Fuera del alcance declarado"
        elif "PASS" in results and "FAIL" in results:
            state, reason = "INSUFFICIENT_EVIDENCE", "Evidencias contradictorias"
        elif "FAIL" in results:
            state, reason = "NON_COMPLIANT", "Prueba verificada con resultado adverso"
        elif "PASS" in results:
            state, reason = "COMPLIANT", "Prueba verificada en el alcance y periodo indicados"
        elif matches and all(entry["expired"] for entry in matches):
            state, reason = "NEEDS_REVIEW", "Todas las evidencias han caducado"
        else:
            state, reason = "INSUFFICIENT_EVIDENCE", "No hay prueba verificada suficiente"
        refs = [entry["item"]["id"] for entry in matches]
        row = {"requirement": req["id"], "framework": req["framework"], "source_ref": req["source_ref"], "control": req["control"], "state": state, "reason": reason, "evidence": refs}
        matrix.append(row)
        if state == "NON_COMPLIANT":
            finding_id = f"F-{req['id']}"
            findings.append({"id": finding_id, "requirement": req["id"], "control": req["control"], "evidence": [e["item"]["id"] for e in usable if e["item"]["test_result"] == "FAIL"], "status": "DRAFT", "severity": "REVIEW_REQUIRED", "confidence": "HIGH"})
            risks.append({"id": f"R-{req['id']}", "finding": finding_id, "scenario": f"Fallo del control {req['control']}", "treatment": "REDUCE", "status": "PROPOSED", "risk_owner": scope["owner"]})
    counts = {state: sum(row["state"] == state for row in matrix) for state in sorted(STATES)}
    return {"kind": "PRELIMINARY_GRC_ASSESSMENT", "scope": scope, "as_of": today.isoformat(), "frameworks": list(frameworks.values()), "matrix": matrix, "findings": findings, "risks": risks, "evidence_provenance": [{"id": e["id"], "source": e["source"], "sha256": e["hash"], "owner": e["owner"], "collected_at": e["collected_at"], "verification_status": e["verification_status"]} for e in evidence], "executive_summary": {"overall_posture": "Revisión humana requerida", "states": counts, "material_risks": [r["id"] for r in risks], "decisions_required": ["Validar alcance, aplicabilidad y hallazgos", "Aprobar tratamientos y aceptaciones de riesgo"]}}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        result = assess(json.loads(args.input.read_text()), args.input.parent)
    except (AssessmentError, KeyError, json.JSONDecodeError) as exc:
        parser.error(str(exc))
    content = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.write_text(content)
    else:
        print(content, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
