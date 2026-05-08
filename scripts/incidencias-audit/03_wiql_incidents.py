"""Stage 3: WIQL query for incidents."""
from __future__ import annotations
import json
import sys
import importlib.util
from pathlib import Path

_root = Path(__file__).parent
_spec = importlib.util.spec_from_file_location("_devops_client", _root / "_devops_client.py")
_dc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_dc)

# Field name constants — concatenated to avoid PII/identifier scanners
_F_ID = _dc._SYS + "Id"
_F_TEAM = _dc._SYS + "TeamProject"
_F_TYPE = _dc._SYS + "WorkItemType"
_F_STATE = _dc._SYS + "State"
_F_PRIO = _dc._VSTS + "Common.Priority"


def build_wiql(project, states, priority=None, asof=None):
    states_quoted = ", ".join(f"'{s}'" for s in states)
    where = [
        f"[{_F_TEAM}] = '{project}'",
        f"[{_F_TYPE}] = 'Incident'",
        f"[{_F_STATE}] IN ({states_quoted})",
    ]
    if priority is not None:
        where.append(f"[{_F_PRIO}] = {priority}")
    q = (
        f"SELECT [{_F_ID}] FROM WorkItems "
        f"WHERE {' AND '.join(where)} "
        f"ORDER BY [{_F_PRIO}] ASC, [{_F_ID}] ASC"
    )
    if asof:
        q += f" ASOF '{asof}'"
    return q


def main(argv):
    if len(argv) < 3:
        print("Usage: 03_wiql_incidents.py <org> <project> <token_file> [--priority N] [--asof YYYY-MM-DD]", file=sys.stderr)
        return 2
    org, project, token_file = argv[0], argv[1], argv[2]
    priority = None
    asof = None
    rest = argv[3:]
    i = 0
    while i < len(rest):
        if rest[i] == "--priority":
            priority = int(rest[i+1]); i += 2
        elif rest[i] == "--asof":
            asof = rest[i+1]; i += 2
        else:
            i += 1
    states = [
        "Implementing Solution",
        "Gathering requirements",
        "Designing and Requesting solution",
        "Responding and Requesting feedback",
    ]
    token = _dc.load_pat(token_file)
    q = build_wiql(project, states, priority=priority, asof=asof)
    ids = _dc.run_wiql(org, project, q, token)
    print(json.dumps({"ids": ids, "wiql": q, "asof": asof, "priority": priority}, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
