#!/usr/bin/env python3
"""
context-audience-graph.py — SE-221 Slice 3 — Audience graph generator

Lee frontmatter `audience:` de docs/rules/domain/*.md y .opencode/skills/*/SKILL.md
y produce dos artefactos:
  - JSON con mapping {agent: [paths audience-targeted]}
  - TSV con pares (path_A, path_B, shared_audience_agents, audience_count) para
    todos los pares con >=2 agentes en comun. Es la evidencia de conexiones
    cross-concept (SE-221 AC-14).

Spec: docs/propuestas/SE-221-inverted-security-patterns-as-context-engineering.md (AC-14)
Inspiracion: CaMeL capabilities + revelacion de conexiones cross-concept.

Uso:
  python3 scripts/context-audience-graph.py [--workspace DIR] [--out-dir DIR]
"""
import sys
import os
import re
import json
import argparse
import datetime
from itertools import combinations
from pathlib import Path
from typing import Dict, List, Tuple, Set


def find_workspace(start: str) -> str:
    p = Path(start).resolve()
    while p != p.parent:
        if (p / ".git").exists() or (p / "AGENTS.md").exists():
            return str(p)
        p = p.parent
    return start


def list_target_files(ws: str) -> List[str]:
    out = []
    rules_dir = Path(ws) / "docs" / "rules" / "domain"
    if rules_dir.is_dir():
        out.extend(str(p) for p in rules_dir.glob("*.md"))
    skills_dir = Path(ws) / ".opencode" / "skills"
    if skills_dir.is_dir():
        out.extend(str(p) for p in skills_dir.glob("*/SKILL.md"))
    return sorted(set(out))


def list_valid_agents(ws: str) -> Set[str]:
    agents_dir = Path(ws) / ".opencode" / "agents"
    out = {"all-agents", "humans-only"}
    if agents_dir.is_dir():
        for p in agents_dir.glob("*.md"):
            out.add(p.stem)
    return out


def extract_audience(file: str) -> List[str]:
    try:
        with open(file, "r", encoding="utf-8") as fh:
            text = fh.read()
    except Exception:
        return []
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    if not m:
        return []
    fm = m.group(1)
    lines = fm.splitlines()
    out: List[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        am = re.match(r"^audience:\s*(.*)$", line)
        if am:
            inline = am.group(1).strip()
            if inline.startswith("["):
                content = inline.strip("[]")
                for part in content.split(","):
                    v = part.strip().strip('"').strip("'")
                    if v:
                        out.append(v)
            elif inline:
                out.append(inline.strip('"').strip("'"))
            else:
                j = i + 1
                while j < len(lines):
                    ml = re.match(r"^\s*-\s*(.+)$", lines[j])
                    if ml:
                        v = ml.group(1).strip().strip('"').strip("'")
                        if v:
                            out.append(v)
                        j += 1
                    elif re.match(r"^\S", lines[j]):
                        break
                    else:
                        j += 1
            break
        i += 1
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", default=None)
    parser.add_argument("--out-dir", default=None,
                        help="dir donde escribir artefactos (default: $WS/output)")
    parser.add_argument("--min-shared", type=int, default=2,
                        help="numero minimo de agents compartidos para emitir par (default 2)")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    ws = args.workspace or os.environ.get("SAVIA_WORKSPACE_DIR") or find_workspace(os.getcwd())
    out_dir = Path(args.out_dir) if args.out_dir else Path(ws) / "output"
    out_dir.mkdir(parents=True, exist_ok=True)

    valid_agents = list_valid_agents(ws)
    files = list_target_files(ws)

    # Mapping: file -> set(agents) (excluyendo all-agents/humans-only para grafo
    # cross-concept). Mantenemos all-agents en el mapeo agent->files para JSON.
    file_audience_full: Dict[str, Set[str]] = {}
    file_audience_specific: Dict[str, Set[str]] = {}
    agent_to_files: Dict[str, List[str]] = {}

    for f in files:
        agents = extract_audience(f)
        # Filtrar agentes invalidos (no fallar — los reporta capability-check)
        agents_set = set(a for a in agents if a in valid_agents)
        rel = os.path.relpath(f, ws)
        file_audience_full[rel] = agents_set
        # Para cross-concept: ignorar all-agents/humans-only (universales)
        specific = agents_set - {"all-agents", "humans-only"}
        file_audience_specific[rel] = specific
        for a in agents_set:
            agent_to_files.setdefault(a, []).append(rel)

    # Cross pairs: combinaciones de ficheros con >= min-shared agentes especificos
    pairs: List[Tuple[str, str, List[str], int]] = []
    keys = sorted(file_audience_specific.keys())
    for a, b in combinations(keys, 2):
        sa = file_audience_specific[a]
        sb = file_audience_specific[b]
        shared = sa & sb
        if len(shared) >= args.min_shared:
            pairs.append((a, b, sorted(shared), len(shared)))

    # Output JSON
    json_path = out_dir / "context-audience-graph.json"
    json_data = {
        "ts": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "workspace": ws,
        "n_files_scanned": len(files),
        "n_files_with_audience": sum(1 for v in file_audience_full.values() if v),
        "n_agents_referenced": len(agent_to_files),
        "agents": {a: sorted(files) for a, files in agent_to_files.items()},
    }
    with open(json_path, "w", encoding="utf-8") as fh:
        json.dump(json_data, fh, indent=2, ensure_ascii=False)
        fh.write("\n")

    # Output TSV
    tsv_path = out_dir / "context-audience-cross.tsv"
    with open(tsv_path, "w", encoding="utf-8") as fh:
        fh.write("path_a\tpath_b\tshared_agents\taudience_count\n")
        for a, b, shared, count in sorted(pairs, key=lambda x: -x[3]):
            fh.write(f"{a}\t{b}\t{','.join(shared)}\t{count}\n")

    if not args.quiet:
        print(f"Scanned: {len(files)} files")
        print(f"With audience: {json_data['n_files_with_audience']}")
        print(f"Agents referenced: {json_data['n_agents_referenced']}")
        print(f"Cross-concept pairs (>= {args.min_shared} shared): {len(pairs)}")
        print(f"JSON: {json_path}")
        print(f"TSV:  {tsv_path}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
