#!/usr/bin/env python3
"""
governance-sync.py — SE-363: capa de registro consultable sobre CRITERIO.md.

Extrae los CRIT de CRITERIO.md y los escribe como registro JSONL estructurado
(criterios.jsonl), con estado, aprobación y policy ref. El Markdown es la vista;
el JSONL es el registro consultable.

Uso:
  governance-sync.py --source CRITERIO.md --output data/governance/criterios.jsonl [--check]
  governance-sync.py --query data/governance/criterios.jsonl --status ACTIVE
  governance-sync.py --query data/governance/criterios.jsonl --approved-by X

Ref: SE-363 — registros-no-archivos (playbook Anthropic)
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


def extract_crits(path: str | Path) -> list[dict]:
    """Extrae los CRIT de CRITERIO.md (secciones ## con bloques CRIT-XXX)."""
    p = Path(path)
    if not p.exists():
        return []
    text = p.read_text(encoding="utf-8")
    crits = []
    # patrón: CRIT-### — título\n  campos
    for m in re.finditer(r"(?m)^(CRIT-\d+)\s*—\s*(.+?)\n((?:.*\n)*?)(?=^CRIT-\d+|\Z)", text):
        cid = m.group(1)
        title = m.group(2).strip()
        block = m.group(3)
        fields = {}
        for fm in re.finditer(r"(?m)^\s+(\w+):\s*(.+?)(?:\s*\|\s*|$)", block):
            fields[fm.group(1)] = fm.group(2).strip()
        crits.append({
            "id": cid,
            "title": title,
            "dureza": fields.get("dureza", ""),
            "principio": fields.get("principio", ""),
            "enforcement": fields.get("enforcement", ""),
            "provenance": fields.get("provenance", ""),
            "status": "ACTIVE",
            "approved_by": "operadora",
        })
    return crits


def write_jsonl(crits: list[dict], out: Path) -> int:
    """Escribe registro idempotente por crit id."""
    out.parent.mkdir(parents=True, exist_ok=True)
    existing: dict[str, dict] = {}
    if out.exists():
        for line in out.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
                existing[rec["id"]] = rec
            except json.JSONDecodeError:
                continue
    for c in crits:
        existing[c["id"]] = c  # upsert idempotente
    with out.open("w", encoding="utf-8") as fh:
        for rec in sorted(existing.values(), key=lambda r: r["id"]):
            fh.write(json.dumps(rec, ensure_ascii=False) + "\n")
    return len(crits)


def check_drift(crits: list[dict], registry: Path) -> dict:
    """Detecta CRIT en MD sin registro, o registro sin MD."""
    reg_ids = set()
    if registry.exists():
        for line in registry.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                reg_ids.add(json.loads(line)["id"])
            except Exception:
                continue
    md_ids = {c["id"] for c in crits}
    return {
        "unregistered": len(md_ids - reg_ids),
        "missing_in_md": sorted(reg_ids - md_ids),
        "total_md": len(md_ids),
        "total_registry": len(reg_ids),
    }


def query(registry: Path, status: str | None = None, approved_by: str | None = None) -> list[dict]:
    if not registry.exists():
        return []
    rows = []
    for line in registry.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        if status and rec.get("status") != status:
            continue
        if approved_by and rec.get("approved_by") != approved_by:
            continue
        rows.append(rec)
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description="Sincronizador de gobernanza (SE-363)")
    sub = parser.add_subparsers(dest="cmd")

    p_sync = sub.add_parser("sync", help="Extrae CRIT y escribe registro")
    p_sync.add_argument("--source", default="CRITERIO.md")
    p_sync.add_argument("--output", default="data/governance/criterios.jsonl")
    p_sync.add_argument("--check", action="store_true")

    p_query = sub.add_parser("query", help="Consulta el registro")
    p_query.add_argument("--registry", default="data/governance/criterios.jsonl")
    p_query.add_argument("--status")
    p_query.add_argument("--approved-by")
    p_query.add_argument("--json", action="store_true")

    args = parser.parse_args()

    if args.cmd == "query":
        rows = query(Path(args.registry), args.status, args.approved_by)
        if args.json:
            print(json.dumps(rows, indent=2, ensure_ascii=False))
        else:
            for r in rows:
                print(f"  {r['id']} [{r.get('status')}] {r.get('title','')[:60]} — aprobado por {r.get('approved_by')}")
        return 0

    crits = extract_crits(args.source)
    out = Path(args.output)
    write_jsonl(crits, out)

    if args.check:
        drift = check_drift(crits, out)
        print(f"Drift: unregistered={drift['unregistered']} missing_in_md={len(drift['missing_in_md'])}")
        return 1 if drift["unregistered"] > 0 else 0

    print(f"Registro gobernanza: {len(crits)} CRIT en {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
