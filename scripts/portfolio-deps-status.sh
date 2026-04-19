#!/usr/bin/env bash
# portfolio-deps-status.sh — SPEC-SE-020 Slice 5 project status dashboard.
#
# Muestra el estado completo de dependencias de un proyecto específico:
#   - Upstream blockers (quién me bloquea, estado, deadline)
#   - Downstream consumers (a quién bloqueo yo)
#   - Shared resources (personas con allocation en otros proyectos)
#   - Resumen salud: BLOCKED / AT-RISK / ON-TRACK
#
# Usage:
#   portfolio-deps-status.sh --project projects/erp-migration
#   portfolio-deps-status.sh --project projects/erp-migration --root projects/
#   portfolio-deps-status.sh --project projects/erp-migration --json
#
# Exit codes:
#   0 — status OK (on-track)
#   1 — at-risk (1+ upstream at-risk)
#   2 — blocked (1+ upstream blocked) OR usage error
#
# Ref: SPEC-SE-020 §6, docs/rules/domain/portfolio-as-graph.md
# Safety: read-only, set -uo pipefail.

set -uo pipefail

PROJECT=""
ROOT=""
JSON=0

usage() {
  cat <<EOF
Usage:
  $0 --project PATH [--root DIR] [--json]

  --project PATH  Path to project directory (must have deps.yaml)
  --root DIR      Portfolio root for downstream discovery (default: parent of project)
  --json          Output JSON

Muestra upstream/downstream/shared-resources status del proyecto.
Exit: 0 on-track, 1 at-risk, 2 blocked/usage-error.

Ref: docs/rules/domain/portfolio-as-graph.md §6
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --root) ROOT="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

[[ -z "$PROJECT" ]] && { echo "ERROR: --project required" >&2; exit 2; }
[[ ! -d "$PROJECT" ]] && { echo "ERROR: project dir not found: $PROJECT" >&2; exit 2; }

# Auto-derive root if not given.
[[ -z "$ROOT" ]] && ROOT=$(dirname "$PROJECT")
[[ ! -d "$ROOT" ]] && { echo "ERROR: root dir not found: $ROOT" >&2; exit 2; }

DEPS_FILE="$PROJECT/deps.yaml"
[[ ! -f "$DEPS_FILE" ]] && { echo "ERROR: deps.yaml not found in $PROJECT" >&2; exit 2; }

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required" >&2; exit 2; }

python3 - "$PROJECT" "$ROOT" "$JSON" <<'PY'
import json, re, sys
from pathlib import Path

project_dir = Path(sys.argv[1])
root = Path(sys.argv[2])
json_out = int(sys.argv[3])

deps_file = project_dir / "deps.yaml"
project_name = None

def parse_entries(content, section_name):
    """Extract list of entries under a section (upstream/downstream)."""
    m = re.search(rf'^  {section_name}:\s*$', content, re.MULTILINE)
    if not m:
        return []
    rest = content[m.end():]
    # End at next top-level section.
    end_m = re.search(r'^(\w|  \w)', rest, re.MULTILINE)
    # Find next 2-space-indent key.
    next_section = re.search(r'^  (downstream|shared_resources|upstream):', rest, re.MULTILINE)
    block = rest[:next_section.start()] if next_section else rest
    entries = re.split(r'^    - project:\s*', block, flags=re.MULTILINE)
    out = []
    for e in entries[1:]:
        e_proj = re.match(r'"?([^"\n]+)"?', e)
        if not e_proj:
            continue
        name = e_proj.group(1).strip()
        date_m = re.search(r'needed_by:\s*"?([^"\n]+)"?', e)
        status_m = re.search(r'status:\s*"?([^"\n]+)"?', e)
        type_m = re.search(r'type:\s*"?([^"\n]+)"?', e)
        deliv_m = re.search(r'deliverable:\s*"?([^"\n]+)"?', e)
        out.append({
            "project": name,
            "type": type_m.group(1).strip() if type_m else "?",
            "deliverable": deliv_m.group(1).strip() if deliv_m else "?",
            "needed_by": date_m.group(1).strip() if date_m else "?",
            "status": status_m.group(1).strip() if status_m else "?",
        })
    return out

def parse_shared(content):
    m = re.search(r'^shared_resources:\s*$', content, re.MULTILINE)
    if not m:
        return []
    rest = content[m.end():]
    end_m = re.search(r'^\S', rest, re.MULTILINE)
    block = rest[:end_m.start()] if end_m else rest
    entries = re.split(r'^  - person:\s*', block, flags=re.MULTILINE)
    out = []
    for e in entries[1:]:
        person_m = re.match(r'"?([^"\n]+)"?', e)
        if not person_m:
            continue
        proj_m = re.search(r'projects:\s*\[([^\]]+)\]', e)
        alloc_m = re.search(r'allocation_pct:\s*\[([^\]]+)\]', e)
        conflict_m = re.search(r'conflict:\s*(true|false)', e)
        if not proj_m or not alloc_m:
            continue
        try:
            alloc = [int(a.strip()) for a in alloc_m.group(1).split(',')]
        except ValueError:
            continue
        out.append({
            "person": person_m.group(1).strip(),
            "projects": [p.strip().strip('"') for p in proj_m.group(1).split(',')],
            "allocation_pct": alloc,
            "total_allocation": sum(alloc),
            "conflict": conflict_m.group(1) == "true" if conflict_m else False,
        })
    return out

content = deps_file.read_text()
project_m = re.search(r'^project:\s*"?([^"\n]+)"?', content, re.MULTILINE)
project_name = project_m.group(1).strip() if project_m else project_dir.name

upstream = parse_entries(content, "upstream")
downstream = parse_entries(content, "downstream")
shared = parse_shared(content)

# Scan other projects for implicit downstream (projects whose upstream includes us).
implicit_downstream = []
for other_deps in root.glob("*/deps.yaml"):
    if other_deps == deps_file:
        continue
    other_content = other_deps.read_text()
    other_proj_m = re.search(r'^project:\s*"?([^"\n]+)"?', other_content, re.MULTILINE)
    other_name = other_proj_m.group(1).strip() if other_proj_m else other_deps.parent.name
    other_upstream = parse_entries(other_content, "upstream")
    for u in other_upstream:
        if u["project"] == project_name:
            implicit_downstream.append({
                "project": other_name,
                "type": u["type"],
                "deliverable": u["deliverable"],
                "needed_by": u["needed_by"],
                "status": u["status"],
            })

# Compute overall health.
blocked_upstream = [u for u in upstream if u["status"] == "blocked"]
atrisk_upstream = [u for u in upstream if u["status"] == "at-risk"]

if blocked_upstream:
    health = "BLOCKED"
    exit_code = 2
elif atrisk_upstream:
    health = "AT-RISK"
    exit_code = 1
else:
    health = "ON-TRACK"
    exit_code = 0

report = {
    "project": project_name,
    "health": health,
    "upstream": upstream,
    "downstream_declared": downstream,
    "downstream_implicit": implicit_downstream,
    "shared_resources": shared,
    "n_blocked": len(blocked_upstream),
    "n_at_risk": len(atrisk_upstream),
}

if json_out:
    print(json.dumps(report, ensure_ascii=False))
else:
    print(f"=== Project Status: {project_name} ===")
    print(f"Health: {health}")
    print()
    print(f"Upstream ({len(upstream)}):")
    if not upstream:
        print("  (none)")
    for u in upstream:
        marker = "🚫" if u["status"] == "blocked" else ("⚠️" if u["status"] == "at-risk" else "✓")
        print(f"  {marker} {u['project']:<25} {u['type']:<18} {u['deliverable']:<30} needed_by={u['needed_by']} ({u['status']})")
    print()
    print(f"Downstream declared ({len(downstream)}):")
    for d in downstream:
        print(f"  → {d['project']:<25} {d['type']:<18} {d['deliverable']:<30} needed_by={d['needed_by']}")
    if implicit_downstream:
        print()
        print(f"Downstream implicit — projects depending on me ({len(implicit_downstream)}):")
        for d in implicit_downstream:
            print(f"  ← {d['project']:<25} {d['type']:<18} {d['deliverable']:<30} needed_by={d['needed_by']}")
    if shared:
        print()
        print(f"Shared resources ({len(shared)}):")
        for s in shared:
            conflict_mark = " 🔥" if s["conflict"] else ""
            print(f"  {s['person']:<20} total={s['total_allocation']}% across {len(s['projects'])} projects{conflict_mark}")

sys.exit(exit_code)
PY
