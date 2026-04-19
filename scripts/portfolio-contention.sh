#!/usr/bin/env bash
# portfolio-contention.sh — SPEC-SE-020 Slice 4 contention detector.
#
# Analiza `shared_resources` en todos los `deps.yaml` del portfolio y detecta:
#   1. Over-allocation — suma allocation_pct > 100% para una persona
#   2. Critical-path collision — misma persona en 2+ proyectos en critical path
#   3. Bus-factor risk — proyecto donde una sola persona es critical
#
# Usage:
#   portfolio-contention.sh --root projects/
#   portfolio-contention.sh --root projects/ --json
#   portfolio-contention.sh --root projects/ --critical-path projects/cp.json
#
# Exit codes:
#   0 — no contention detected
#   1 — at least one contention alert
#   2 — usage error
#
# Ref: SPEC-SE-020 §Resource contention detection
# Dep: None (parses YAML con Python stdlib regex). Optional: critical-path JSON.
# Safety: read-only, set -uo pipefail.

set -uo pipefail

ROOT=""
CRITICAL_PATH_FILE=""
JSON=0

usage() {
  cat <<EOF
Usage:
  $0 --root DIR [--critical-path FILE] [--json]

  --root DIR            Portfolio root with <project>/deps.yaml
  --critical-path FILE  JSON from portfolio-critical-path.sh (enables collision detection)
  --json                Output JSON

Detecta: over-allocation (>100%), critical-path collision, bus-factor risk.
Exit 1 si hay contention, 0 si sano.

Ref: SPEC-SE-020 §Resource contention detection
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --critical-path) CRITICAL_PATH_FILE="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

[[ -z "$ROOT" ]] && { echo "ERROR: --root required" >&2; exit 2; }
[[ ! -d "$ROOT" ]] && { echo "ERROR: root not found: $ROOT" >&2; exit 2; }
[[ -n "$CRITICAL_PATH_FILE" && ! -f "$CRITICAL_PATH_FILE" ]] && {
  echo "ERROR: critical-path file not found: $CRITICAL_PATH_FILE" >&2; exit 2;
}

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required" >&2; exit 2; }

python3 - "$ROOT" "${CRITICAL_PATH_FILE:-}" "$JSON" <<'PY'
import json, re, sys
from pathlib import Path

root = Path(sys.argv[1])
cp_file = sys.argv[2] if len(sys.argv) > 2 else ""
json_out = int(sys.argv[3])

# Parse deps.yaml collecting shared_resources.
def parse_shared(path):
    """Extract shared_resources entries from a deps.yaml."""
    content = path.read_text()
    # Find shared_resources: section.
    m = re.search(r'^shared_resources:\s*$', content, re.MULTILINE)
    if not m:
        return []
    rest = content[m.end():]
    # End at next top-level section or EOF.
    end = re.search(r'^\S', rest, re.MULTILINE)
    block = rest[:end.start()] if end else rest
    # Split entries by "  - person:" (2-space indent).
    entries = re.split(r'^  - person:\s*', block, flags=re.MULTILINE)
    out = []
    for e in entries[1:]:
        person_m = re.match(r'"?([^"\n]+)"?', e)
        if not person_m:
            continue
        person = person_m.group(1).strip()
        # Parse projects: and allocation_pct:.
        proj_m = re.search(r'projects:\s*\[([^\]]+)\]', e)
        alloc_m = re.search(r'allocation_pct:\s*\[([^\]]+)\]', e)
        conflict_m = re.search(r'conflict:\s*(true|false)', e)
        if not proj_m or not alloc_m:
            continue
        projects = [p.strip().strip('"') for p in proj_m.group(1).split(',')]
        try:
            alloc = [int(a.strip()) for a in alloc_m.group(1).split(',')]
        except ValueError:
            continue
        out.append({
            "person": person,
            "projects": projects,
            "allocation_pct": alloc,
            "total_allocation": sum(alloc),
            "conflict_declared": conflict_m.group(1) == "true" if conflict_m else False,
        })
    return out

# Scan root.
all_shared = []
for f in sorted(root.glob("*/deps.yaml")):
    entries = parse_shared(f)
    for e in entries:
        e["source_project"] = f.parent.name
        all_shared.append(e)

# Aggregate by person (may appear in multiple projects' deps.yaml).
by_person = {}
for e in all_shared:
    key = e["person"]
    if key not in by_person:
        by_person[key] = {"person": key, "projects": set(), "total_allocation": 0, "sources": []}
    by_person[key]["projects"].update(e["projects"])
    by_person[key]["total_allocation"] = max(by_person[key]["total_allocation"], e["total_allocation"])
    by_person[key]["sources"].append(e["source_project"])

# Load critical path projects if provided.
critical_projects = set()
if cp_file:
    try:
        cp_data = json.loads(Path(cp_file).read_text())
        critical_projects = {c["project"] for c in cp_data.get("critical_path", [])}
    except (json.JSONDecodeError, KeyError):
        pass

# Detect alerts.
alerts = []
for person, data in by_person.items():
    projects = sorted(data["projects"])
    total = data["total_allocation"]
    # Over-allocation.
    if total > 100:
        alerts.append({
            "type": "over-allocation",
            "person": person,
            "total_allocation_pct": total,
            "projects": projects,
            "recommendation": f"Reduce allocation below 100% or add backup",
        })
    # Critical-path collision.
    cp_hits = [p for p in projects if p in critical_projects]
    if len(cp_hits) >= 2:
        alerts.append({
            "type": "critical-path-collision",
            "person": person,
            "projects": cp_hits,
            "recommendation": f"Dedicate to one critical project; assign backup for others",
        })
    # Bus-factor risk: person in 3+ projects with 100% total allocation
    if len(projects) >= 3 and total >= 80:
        alerts.append({
            "type": "bus-factor-risk",
            "person": person,
            "projects": projects,
            "allocation_pct": total,
            "recommendation": f"Cross-train backup — single point of failure across {len(projects)} projects",
        })

report = {
    "n_shared_entries": len(all_shared),
    "n_unique_persons": len(by_person),
    "critical_projects": sorted(critical_projects),
    "alerts": alerts,
    "healthy": len(alerts) == 0,
}

if json_out:
    print(json.dumps(report, ensure_ascii=False, default=list))
else:
    print("=== Portfolio Contention Analysis ===")
    print(f"Shared resource entries: {len(all_shared)}")
    print(f"Unique persons:          {len(by_person)}")
    if critical_projects:
        print(f"Critical projects:       {', '.join(sorted(critical_projects))}")
    print()
    if not alerts:
        print("✅ No contention detected — resources healthy")
    else:
        print(f"⚠ {len(alerts)} contention alert(s):")
        for a in alerts:
            print(f"  [{a['type']}] {a['person']}")
            if 'projects' in a:
                print(f"    projects: {', '.join(a['projects'])}")
            if 'total_allocation_pct' in a:
                print(f"    total:    {a['total_allocation_pct']}%")
            print(f"    → {a['recommendation']}")
            print()

sys.exit(0 if not alerts else 1)
PY
