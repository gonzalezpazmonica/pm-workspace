#!/usr/bin/env python3
"""
pm-backend-query.py -- SE-092 MVP: Generic PM backend query CLI

Supports Azure DevOps (ADO) and mock mode when no backend configured.

Usage:
  python3 scripts/pm-backend-query.py --sprint-status
  python3 scripts/pm-backend-query.py --my-items
  python3 scripts/pm-backend-query.py --sprint-status --json
  python3 scripts/pm-backend-query.py --mock --sprint-status

CRITICAL SECURITY (Rule #1):
  - NEVER read PAT inline -- always via file or AZURE_PAT env var
  - NEVER log or print PAT value
  - NEVER store PAT in output JSON

Exit codes: 0=success, 1=config error, 2=usage error

Ref: SE-092, docs/propuestas/SE-092-PM-BACKEND.md
"""

import argparse
import base64
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Optional


def _resolve_pat() -> Optional[str]:
    """Resolve PAT via env or file. NEVER hardcode. NEVER print."""
    for env_key in ("AZURE_PAT", "AZURE_DEVOPS_EXT_PAT"):
        val = os.environ.get(env_key, "").strip()
        if val:
            return val
    pat_file = os.environ.get(
        "AZURE_DEVOPS_PAT_FILE",
        str(Path.home() / ".azure" / "devops-pat"),
    )
    try:
        content = Path(pat_file).read_text().strip()
        if content:
            return content
    except (OSError, PermissionError):
        pass
    return None


def _pat_available() -> bool:
    return _resolve_pat() is not None


def _detect_backend() -> dict:
    org_url = os.environ.get("AZURE_DEVOPS_ORG_URL", "").strip()
    project = os.environ.get("AZURE_DEVOPS_PROJECT", "").strip()
    if org_url and project and _pat_available():
        return {"type": "ado", "org_url": org_url, "project": project}
    if org_url or project:
        return {"type": "ado_partial", "org_url": org_url, "project": project}
    return {"type": "none"}


MOCK_SPRINT_STATUS = {
    "sprint": "Sprint-Mock-2026-W25",
    "note": "backend not configured -- mock data",
    "summary": {"total": 12, "done": 5, "in_progress": 4, "todo": 3, "blocked": 0},
    "items": [
        {"id": "AB#1001", "title": "Setup project structure", "state": "Done",
         "assigned_to": "dev@example.com", "effort": 3},
        {"id": "AB#1002", "title": "Implement auth service", "state": "In Progress",
         "assigned_to": "dev@example.com", "effort": 8},
        {"id": "AB#1003", "title": "Add unit tests", "state": "To Do",
         "assigned_to": "qa@example.com", "effort": 5},
        {"id": "AB#1004", "title": "Database migration", "state": "Done",
         "assigned_to": "dba@example.com", "effort": 2},
        {"id": "AB#1005", "title": "API documentation", "state": "In Progress",
         "assigned_to": "dev@example.com", "effort": 3},
    ],
}

MOCK_MY_ITEMS = {
    "assigned_to": "current-user@example.com",
    "note": "backend not configured -- mock data",
    "items": [
        {"id": "AB#1002", "title": "Implement auth service", "state": "In Progress",
         "priority": 1, "effort": 8, "iteration": "Sprint-Mock-2026-W25"},
        {"id": "AB#1005", "title": "API documentation", "state": "In Progress",
         "priority": 2, "effort": 3, "iteration": "Sprint-Mock-2026-W25"},
        {"id": "AB#1007", "title": "Review PR #42", "state": "To Do",
         "priority": 1, "effort": 1, "iteration": "Sprint-Mock-2026-W25"},
    ],
}


def _ado_wiql(query: str, org: str, project: str, pat: str) -> list:
    """Execute WIQL query. PAT never logged."""
    auth = base64.b64encode(f":{pat}".encode()).decode()
    result = subprocess.run(
        ["curl", "-sS",
         "-H", f"Authorization: Basic {auth}",
         "-H", "Content-Type: application/json",
         "-X", "POST",
         f"{org.rstrip('/')}/_apis/wit/wiql?api-version=7.1",
         "-d", json.dumps({"query": query})],
        capture_output=True, text=True, timeout=15,
    )
    if result.returncode != 0:
        raise RuntimeError(f"curl error: {result.stderr[:100]}")
    data = json.loads(result.stdout)
    return data.get("workItems", [])


def _ado_sprint_status(backend: dict, pat: str) -> dict:
    org = backend["org_url"]
    project = backend["project"]
    auth = base64.b64encode(f":{pat}".encode()).decode()
    try:
        resp = subprocess.run(
            ["curl", "-sS",
             "-H", f"Authorization: Basic {auth}",
             f"{org.rstrip('/')}/{project}/_apis/work/teamsettings/iterations?$timeframe=current&api-version=7.1"],
            capture_output=True, text=True, timeout=10,
        )
        iterations = json.loads(resp.stdout).get("value", [])
        if not iterations:
            return {"error": "No current sprint found", "items": []}
        sprint = iterations[0]
        sprint_name = sprint.get("name", "unknown")
        iter_path = sprint.get("path", "")
        wiql = (
            f"SELECT [System.Id],[System.Title],[System.State],[System.AssignedTo] "
            f"FROM WorkItems WHERE [System.IterationPath] = '{iter_path}'"
        )
        items = _ado_wiql(wiql, org, project, pat)
        return {
            "sprint": sprint_name,
            "items": [{"id": f"AB#{w['id']}", "url": w.get("url", "")} for w in items],
            "summary": {"total": len(items)},
        }
    except Exception as exc:
        return {"error": str(exc), "items": []}


def _ado_my_items(backend: dict, pat: str) -> dict:
    org = backend["org_url"]
    project = backend["project"]
    try:
        wiql = (
            "SELECT [System.Id],[System.Title],[System.State],[System.AssignedTo] "
            "FROM WorkItems WHERE [System.AssignedTo] = @Me "
            "AND [System.State] <> 'Done' AND [System.State] <> 'Closed'"
        )
        items = _ado_wiql(wiql, org, project, pat)
        return {
            "items": [{"id": f"AB#{w['id']}", "url": w.get("url", "")} for w in items],
            "count": len(items),
        }
    except Exception as exc:
        return {"error": str(exc), "items": []}


def _print_table(title: str, data: dict) -> None:
    print(f"\n{'=' * 60}")
    print(f"  {title}")
    print(f"{'=' * 60}")
    if "note" in data:
        print(f"  NOTE: {data['note']}")
    if "error" in data:
        print(f"  ERROR: {data['error']}")
        return
    if "sprint" in data:
        print(f"  Sprint: {data['sprint']}")
    if "summary" in data:
        for k, v in data["summary"].items():
            print(f"  {k:15}: {v}")
    items = data.get("items", [])
    if items:
        print(f"\n  {'ID':<12} {'Title':<35} {'State':<15}")
        print(f"  {'-'*12} {'-'*35} {'-'*15}")
        for item in items[:20]:
            print(f"  {item.get('id',''):<12} {str(item.get('title',''))[:34]:<35} {item.get('state',''):<15}")
        if len(items) > 20:
            print(f"  ... and {len(items) - 20} more items")
    print(f"{'=' * 60}\n")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="PM backend query CLI (SE-092 MVP)",
    )
    parser.add_argument("--sprint-status", action="store_true",
                        help="Get current sprint status")
    parser.add_argument("--my-items", action="store_true",
                        help="Get work items assigned to me")
    parser.add_argument("--json", action="store_true",
                        help="Output JSON")
    parser.add_argument("--mock", action="store_true",
                        help="Force mock mode")
    args = parser.parse_args()

    if not args.sprint_status and not args.my_items:
        parser.print_help()
        return 2

    backend = _detect_backend()
    use_mock = args.mock or backend["type"] == "none"

    if use_mock:
        result = MOCK_SPRINT_STATUS if args.sprint_status else MOCK_MY_ITEMS
    else:
        pat = _resolve_pat()
        if not pat:
            result = {
                "error": "PAT not available. Configure in ~/.azure/devops-pat or AZURE_PAT env var.",
                "items": [],
                "note": "backend not configured",
            }
        elif args.sprint_status:
            result = _ado_sprint_status(backend, pat)
            pat = None  # clear ref
        else:
            result = _ado_my_items(backend, pat)
            pat = None  # clear ref

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        title = "SPRINT STATUS" if args.sprint_status else "MY ITEMS"
        _print_table(title, result)

    return 0


if __name__ == "__main__":
    sys.exit(main())
