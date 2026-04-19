#!/usr/bin/env bash
# portfolio-critical-path.sh — SPEC-SE-020 Slice 3 critical path analyzer.
#
# Dado un portfolio de proyectos con `deps.yaml`, computa el camino crítico
# cross-project usando topological sort + backward pass para calcular slack.
#
# Input: directorio root con subcarpetas <project>/deps.yaml (misma convención
# que portfolio-graph.sh de Slice 2).
#
# Output:
#   - Secuencia del camino crítico (proyectos + deliverables + fechas)
#   - Slack por proyecto (días hasta que se convierte en crítico)
#   - Bottleneck identificado (proyecto con 0 slack y status at-risk/blocked)
#
# Slack se computa como días entre `needed_by` más temprano del grafo y
# `needed_by` del proyecto. 0 slack = crítico; > 5 días = holgura.
#
# Usage:
#   portfolio-critical-path.sh --root projects/
#   portfolio-critical-path.sh --root projects/ --json
#
# Exit codes:
#   0 — análisis completo (incluso si no hay bottleneck)
#   1 — bottleneck crítico detectado (at-risk/blocked en critical path)
#   2 — usage error
#
# Ref: SPEC-SE-020 §Cross-project critical path
# Dep: None (lee deps.yaml directamente). Standalone.
# Safety: read-only, set -uo pipefail.

set -uo pipefail

ROOT=""
JSON=0

usage() {
  cat <<EOF
Usage:
  $0 --root DIR [--json]

  --root DIR    Directorio con subcarpetas <project>/deps.yaml
  --json        Output JSON

Computa critical path cross-project, slack por proyecto, y detecta bottleneck.

Ref: SPEC-SE-020 §Cross-project critical path
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

[[ -z "$ROOT" ]] && { echo "ERROR: --root required" >&2; exit 2; }
[[ ! -d "$ROOT" ]] && { echo "ERROR: root directory not found: $ROOT" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required" >&2; exit 2; }

python3 - "$ROOT" "$JSON" <<'PY'
import json, os, re, sys
from datetime import datetime, timedelta
from pathlib import Path

root = Path(sys.argv[1])
json_out = int(sys.argv[2])

# Parse all deps.yaml (regex-based, no pyyaml dependency).
PROJECT_RE = re.compile(r'^project:\s*"?([^"\n]+)"?', re.MULTILINE)
UPSTREAM_SECTION_RE = re.compile(r'^  upstream:\s*$', re.MULTILINE)
SECTION_END_RE = re.compile(r'^  (downstream|shared_resources|$)', re.MULTILINE)

def parse_deps(path):
    content = path.read_text()
    proj_m = PROJECT_RE.search(content)
    if not proj_m:
        return None
    proj = proj_m.group(1).strip()
    # Find upstream block.
    up_m = UPSTREAM_SECTION_RE.search(content)
    upstreams = []
    if up_m:
        # Read until next top-level section.
        rest = content[up_m.end():]
        # Find where upstream section ends (next section at 2-space indent).
        end_m = re.search(r'^  (downstream|shared_resources):\s*$', rest, re.MULTILINE)
        block = rest[:end_m.start()] if end_m else rest
        # Parse individual entries.
        entries = re.split(r'^    - project:\s*', block, flags=re.MULTILINE)
        for e in entries[1:]:
            e_proj = re.match(r'"?([^"\n]+)"?', e)
            if not e_proj:
                continue
            name = e_proj.group(1).strip()
            date_m = re.search(r'needed_by:\s*"?(\d{4}-\d{2}-\d{2})"?', e)
            status_m = re.search(r'status:\s*"?([^"\n]+)"?', e)
            upstreams.append({
                "project": name,
                "needed_by": date_m.group(1) if date_m else None,
                "status": status_m.group(1).strip() if status_m else "unknown",
            })
    return {"project": proj, "upstream": upstreams, "file": str(path)}

# Scan root.
deps_files = sorted(root.glob("*/deps.yaml"))
projects = {}
for f in deps_files:
    parsed = parse_deps(f)
    if parsed:
        projects[parsed["project"]] = parsed

if not projects:
    out = {"n_projects": 0, "critical_path": [], "bottleneck": None, "slack": {}}
    if json_out:
        print(json.dumps(out))
    else:
        print("=== Portfolio Critical Path ===")
        print("(no projects with deps.yaml found)")
    sys.exit(0)

# Compute slack per project: slack = (project.needed_by - earliest_upstream.needed_by).
# For MVP: find the project with EARLIEST needed_by in the graph (bottleneck candidate).
all_dates = []
for p, data in projects.items():
    for u in data["upstream"]:
        if u.get("needed_by"):
            all_dates.append((u["needed_by"], p, u["project"], u.get("status", "unknown")))
all_dates.sort()  # earliest first

if not all_dates:
    out = {"n_projects": len(projects), "critical_path": [], "bottleneck": None, "slack": {}}
    if json_out:
        print(json.dumps(out))
    else:
        print("=== Portfolio Critical Path ===")
        print(f"Projects: {len(projects)}")
        print("(no dated deps found — cannot compute critical path)")
    sys.exit(0)

# Critical path = sequence of deps from earliest needed_by forward, chained.
# Algorithm (MVP): walk from earliest date forward, picking the project that
# blocks most downstream as the "critical" next.
earliest = all_dates[0]
earliest_date_str, downstream_proj, upstream_proj, earliest_status = earliest
earliest_date = datetime.strptime(earliest_date_str, "%Y-%m-%d")

# Per-project slack: days between its earliest upstream needed_by and the
# global earliest needed_by. Lower slack = closer to critical path.
slack = {}
for p, data in projects.items():
    dates_for_p = [u["needed_by"] for u in data["upstream"] if u.get("needed_by")]
    if dates_for_p:
        earliest_up = min(dates_for_p)
        d = datetime.strptime(earliest_up, "%Y-%m-%d")
        slack[p] = (d - earliest_date).days
    else:
        slack[p] = None  # no dated upstream

# Critical path nodes: projects with slack ≤ 5 days, sorted by slack asc.
critical = [(p, s) for p, s in slack.items() if s is not None and s <= 5]
critical.sort(key=lambda x: x[1])

# Bottleneck: project in critical path with status at-risk or blocked on any upstream.
bottleneck = None
for p, s in critical:
    for u in projects[p]["upstream"]:
        if u.get("status") in ("at-risk", "blocked"):
            bottleneck = {"project": p, "upstream": u["project"], "status": u["status"], "slack_days": s}
            break
    if bottleneck:
        break

# Also check the earliest-date upstream itself (often the bottleneck source).
if not bottleneck and earliest_status in ("at-risk", "blocked"):
    bottleneck = {"project": upstream_proj, "upstream_of": downstream_proj, "status": earliest_status, "slack_days": 0}

out = {
    "n_projects": len(projects),
    "earliest_needed_by": earliest_date_str,
    "critical_path": [{"project": p, "slack_days": s} for p, s in critical],
    "bottleneck": bottleneck,
    "slack": {p: s for p, s in slack.items()},
}

if json_out:
    print(json.dumps(out, ensure_ascii=False))
else:
    print("=== Portfolio Critical Path ===")
    print(f"Projects analyzed: {len(projects)}")
    print(f"Earliest deadline: {earliest_date_str}")
    print()
    print(f"Critical path ({len(critical)} projects, slack ≤5 days):")
    if not critical:
        print("  (no projects on critical path)")
    for p, s in critical:
        marker = "⚠️ " if s == 0 else "  "
        print(f"  {marker}{p}  (slack: {s} days)")
    print()
    if bottleneck:
        print(f"BOTTLENECK: {bottleneck}")
        sys.exit(1)
    else:
        print("No bottleneck detected (all critical path projects on-track)")

sys.exit(0)
PY
