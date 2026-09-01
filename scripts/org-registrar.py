#!/usr/bin/env python3
"""
org-registrar.py — SE-365: validador y consulta del grafo de entidades organizacionales.

Company as Code: entidades en markdown+frontmatter (roles/units/people/policies,
projects, resources) con vocabulario de relaciones controlado. CRITERIO.md valida,
no almacena. Escritura mediada por humano.

Uso:
  org-registrar.py validate --file entity.md [--known-ids "id1 id2"]
  org-registrar.py index --dir company/ [--json]
  org-registrar.py query --graph graph.json --what uses_resource --id resource-x
  org-registrar.py propose --file entity.md --out proposals/   # genera diff sin aplicar

Ref: SE-365 — Company as Code
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

VALID_TYPES = {"role", "unit", "person", "policy", "project", "resource"}
VALID_RELATIONS = {
    "BelongsToUnit", "ManagedBy", "AppliesTo", "ImplementsCriterio",
    "ImplementsSpec", "UsesResource", "UsedByProject", "OwnedByUnit", "GovernedByPolicy",
}
VALID_STATUS = {"active", "deprecated", "proposed"}
VALID_CATEGORIES = {"infra", "tool", "knowledge", "credential-ref"}
OWNER_ONLY_TYPES = {"policy"}  # políticas solo las declara origin: owner

# pares válidos (dominio → rango aproximado) — validación estructural
RELATION_DOMAINS = {
    "BelongsToUnit": {"person", "role"},
    "ManagedBy": {"person"},
    "AppliesTo": {"policy"},
    "ImplementsCriterio": {"policy"},
    "ImplementsSpec": {"project"},
    "UsesResource": {"project"},
    "UsedByProject": {"resource"},
    "OwnedByUnit": {"project", "resource"},
    "GovernedByPolicy": {"resource"},
}


def _parse_frontmatter(text: str) -> tuple[dict | None, str]:
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n?(.*)$", text, re.S)
    if not m:
        return None, text
    yaml_block, body = m.group(1), m.group(2)
    # parse YAML simple (sin dep) — claves top-level y listas de dicts
    data: dict = {}
    current_key = None
    in_list = False
    for line in yaml_block.splitlines():
        m2 = re.match(r"^(\w+):\s*(.*)$", line)
        if m2:
            key, val = m2.group(1), m2.group(2).strip().strip('"').strip("'")
            data[key] = val if val else ""
            current_key = key
            in_list = key in ("relations", "responsibilities")
            continue
        if in_list and line.lstrip().startswith("- {"):
            m3 = re.match(r"-\s*\{\s*type:\s*(\w+)\s*,\s*target:\s*([\w\-.]+)\s*\}", line.lstrip())
            if m3:
                if not isinstance(data.get(current_key), list):
                    data[current_key] = []
                data[current_key].append({"type": m3.group(1), "target": m3.group(2)})
    return data, body


def validate(path: Path, known_ids: set[str] | None = None) -> dict:
    """Valida una entidad contra el esquema común."""
    if not path.exists():
        return {"valid": False, "errors": [f"archivo no existe: {path}"]}
    text = path.read_text(encoding="utf-8")
    data, _ = _parse_frontmatter(text)
    if data is None:
        return {"valid": False, "errors": ["frontmatter ausente o malformado"]}

    errors: list[str] = []

    # campos requeridos
    for field in ("id", "type", "name", "status"):
        if not data.get(field):
            errors.append(f"falta campo obligatorio: {field}")

    if data.get("type") not in VALID_TYPES:
        errors.append(f"type inválido: {data.get('type')} (válidos: {sorted(VALID_TYPES)})")
    if data.get("status") not in VALID_STATUS:
        errors.append(f"status inválido: {data.get('status')}")
    if data.get("type") == "resource":
        cat = data.get("category", "")
        if cat not in VALID_CATEGORIES:
            errors.append(f"resource category inválida: {cat}")

    # sensitivity nunca "secret" (CRIT-001)
    if data.get("sensitivity") == "secret":
        errors.append("sensitivity 'secret' prohibida: credenciales nunca viven en el vault")

    # origin/source (SE-352)
    origin = data.get("origin", "")
    source = data.get("source", "")
    if origin not in ("owner", "agent"):
        errors.append(f"origin inválido: {origin} (owner|agent)")
    if origin == "owner" and source != "human":
        errors.append("origin: owner requiere source: human")

    # políticas solo por owner
    if data.get("type") in OWNER_ONLY_TYPES and origin != "owner":
        errors.append(f"tipo {data['type']} solo puede declararlo origin: owner")

    # relaciones: vocabulario cerrado + consistencia referencial
    for rel in data.get("relations", []) or []:
        rtype = rel.get("type", "")
        target = rel.get("target", "")
        if rtype not in VALID_RELATIONS:
            errors.append(f"relación no listada: {rtype} (vocabulario cerrado)")
        if known_ids is not None and target and target not in known_ids:
            errors.append(f"target inexistente: {target}")

    if not errors:
        return {"valid": True, "errors": [], "entity": data}
    return {"valid": False, "errors": errors, "entity": data}


def index_dir(directory: Path) -> dict:
    """Indexa entidades de un directorio → grafo {id: {type, relations}}."""
    graph: dict[str, dict] = {}
    if not directory.exists():
        return {"entities": graph, "count": 0}
    for f in sorted(directory.rglob("*.md")):
        if f.name.startswith("_"):
            continue
        text = f.read_text(encoding="utf-8")
        data, _ = _parse_frontmatter(text)
        # solo entidades válidas (id + type conocido); ignora README/templates/docs
        if data and data.get("id") and data.get("type") in VALID_TYPES:
            graph[data["id"]] = {
                "type": data.get("type", ""),
                "file": str(f),
                "relations": data.get("relations", []) or [],
            }
    return {"entities": graph, "count": len(graph)}


def query_uses_resource(graph: dict, resource_id: str) -> list[str]:
    """¿Qué entidades usan el recurso X?"""
    result = []
    for eid, ent in graph.items():
        for rel in ent.get("relations", []):
            if rel.get("type") in ("UsesResource", "UsedByProject") and rel.get("target") == resource_id:
                result.append(eid)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="org-registrar (SE-365)")
    sub = parser.add_subparsers(dest="cmd")

    p_val = sub.add_parser("validate", help="valida una entidad")
    p_val.add_argument("--file", required=True)
    p_val.add_argument("--known-ids", default="", help="ids separados por espacio")

    p_idx = sub.add_parser("index", help="indexa un directorio a grafo")
    p_idx.add_argument("--dir", required=True)
    p_idx.add_argument("--json", action="store_true")

    p_q = sub.add_parser("query", help="consulta el grafo")
    p_q.add_argument("--graph", required=True, help="JSON del grafo (index --json)")
    p_q.add_argument("--what", default="uses_resource")
    p_q.add_argument("--id", required=True)

    p_prop = sub.add_parser("propose", help="prepara una propuesta sin aplicarla")
    p_prop.add_argument("--file", required=True)
    p_prop.add_argument("--out", default="proposals/")

    args = parser.parse_args()

    if args.cmd == "validate":
        known = set(args.known_ids.split()) if args.known_ids else None
        res = validate(Path(args.file), known)
        print(json.dumps(res, indent=2, ensure_ascii=False))
        return 0 if res["valid"] else 2

    if args.cmd == "index":
        res = index_dir(Path(args.dir))
        print(json.dumps(res, indent=2, ensure_ascii=False) if args.json else f"indexado: {res['count']} entidades")
        return 0

    if args.cmd == "query":
        try:
            graph = json.loads(Path(args.graph).read_text()).get("entities", {})
        except Exception:
            graph = {}
        if args.what == "uses_resource":
            result = query_uses_resource(graph, args.id)
            print(json.dumps(result))
        return 0

    if args.cmd == "propose":
        res = validate(Path(args.file))
        out_dir = Path(args.out)
        out_dir.mkdir(parents=True, exist_ok=True)
        out_file = out_dir / Path(args.file).name
        out_file.write_text(Path(args.file).read_text(encoding="utf-8"), encoding="utf-8")
        print(f"propuesta preparada en {out_file} — requiere confirmación humana (escritura mediada)")
        return 0 if res["valid"] else 2

    parser.print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
