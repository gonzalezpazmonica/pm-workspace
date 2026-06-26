#!/usr/bin/env python3
"""nl-to-wiql.py — SE-031: Natural Language to WIQL/JQL converter.

Pattern-based NL → query translator. No LLM required.

Usage:
    python3 scripts/nl-to-wiql.py --query "sprint actual de PM-Workspace" --backend ado
    python3 scripts/nl-to-wiql.py --query "mis items bloqueados" --backend jira

Exit codes:
    0  — query translated successfully
    1  — empty/invalid query
    2  — unknown backend
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from typing import Optional


# ── Pattern library ───────────────────────────────────────────────────────────

ADO_PATTERNS = [
    # sprint actual / current iteration
    (re.compile(r"\b(sprint\s+actual|sprint\s+current|iteraci[oó]n\s+actual|current\s+sprint)\b", re.I),
     "IterationPath", "@CurrentIteration"),
    # mis items / my items
    (re.compile(r"\b(mis\s+items?|mis\s+tareas?|my\s+items?|asignados?\s+a\s+m[íi]|assigned\s+to\s+me)\b", re.I),
     "AssignedTo", "@Me"),
    # bloqueados / blocked
    (re.compile(r"\b(bloqueados?|blocked|en\s+bloqueo)\b", re.I),
     "State", "Blocked"),
    # activos / active
    (re.compile(r"\b(activos?|active|en\s+progreso|in\s+progress)\b", re.I),
     "State", "Active"),
    # cerrados / closed / done
    (re.compile(r"\b(cerrados?|closed|done|completados?)\b", re.I),
     "State", "Closed"),
    # bugs
    (re.compile(r"\b(bugs?|defectos?|errores?)\b", re.I),
     "WorkItemType", "Bug"),
    # PBIs / user stories
    (re.compile(r"\b(pbis?|user\s+stories?|historias?)\b", re.I),
     "WorkItemType", "Product Backlog Item"),
    # tasks / tareas
    (re.compile(r"\b(tasks?|tareas?)\b", re.I),
     "WorkItemType", "Task"),
    # high priority / alta prioridad
    (re.compile(r"\b(alta\s+prioridad|high\s+priority|prioridad\s+alta)\b", re.I),
     "Priority", "1"),
]

JQL_PATTERNS = [
    # sprint actual
    (re.compile(r"\b(sprint\s+actual|sprint\s+current|current\s+sprint)\b", re.I),
     "sprint", "openSprints()"),
    # mis items
    (re.compile(r"\b(mis\s+items?|mis\s+tareas?|my\s+items?|assigned\s+to\s+me)\b", re.I),
     "assignee", "currentUser()"),
    # bloqueados
    (re.compile(r"\b(bloqueados?|blocked)\b", re.I),
     "status", "Blocked"),
    # activos / in progress
    (re.compile(r"\b(activos?|active|en\s+progreso|in\s+progress)\b", re.I),
     "status", "In Progress"),
    # cerrados / done
    (re.compile(r"\b(cerrados?|closed|done|completados?)\b", re.I),
     "status", "Done"),
    # bugs
    (re.compile(r"\b(bugs?|defectos?)\b", re.I),
     "issuetype", "Bug"),
    # stories
    (re.compile(r"\b(stories|story|historias?)\b", re.I),
     "issuetype", "Story"),
    # alta prioridad
    (re.compile(r"\b(alta\s+prioridad|high\s+priority)\b", re.I),
     "priority", "High"),
]


# ── Query builders ────────────────────────────────────────────────────────────

def build_wiql(filters: list[tuple[str, str]]) -> str:
    """Build a WIQL SELECT statement from extracted filters."""
    base = (
        "SELECT [System.Id], [System.Title], [System.State], "
        "[System.AssignedTo], [System.ChangedDate]\n"
        "FROM WorkItems\nWHERE [System.TeamProject] = @project"
    )
    clauses = []
    seen_fields: set[str] = set()
    for field, value in filters:
        if field in seen_fields:
            continue
        seen_fields.add(field)
        if field == "IterationPath":
            clauses.append(f"  AND [System.IterationPath] = {value}")
        elif field == "AssignedTo":
            clauses.append(f"  AND [System.AssignedTo] = {value}")
        elif field == "State":
            clauses.append(f'  AND [System.State] = "{value}"')
        elif field == "WorkItemType":
            clauses.append(f'  AND [System.WorkItemType] = "{value}"')
        elif field == "Priority":
            clauses.append(f"  AND [Microsoft.VSTS.Common.Priority] = {value}")
        else:
            clauses.append(f'  AND [{field}] = "{value}"')

    if not clauses:
        # default: active items in current sprint
        return (
            base
            + "\n  AND [System.IterationPath] = @CurrentIteration"
            + "\n  AND [System.State] <> \"Removed\"\n"
            + "ORDER BY [System.ChangedDate] DESC"
        )
    return base + "\n" + "\n".join(clauses) + "\nORDER BY [System.ChangedDate] DESC"


def build_jql(filters: list[tuple[str, str]]) -> str:
    """Build a JQL query string from extracted filters."""
    clauses = []
    seen_fields: set[str] = set()
    for field, value in filters:
        if field in seen_fields:
            continue
        seen_fields.add(field)
        if value.endswith("()"):
            clauses.append(f"{field} in {value}")
        elif value.startswith('"') or value.startswith("'"):
            clauses.append(f'{field} = {value}')
        else:
            clauses.append(f'{field} = "{value}"')

    if not clauses:
        clauses.append("sprint in openSprints()")
        clauses.append("status != Done")

    return " AND ".join(clauses) + " ORDER BY updated DESC"


# ── Translator ────────────────────────────────────────────────────────────────

def translate(query: str, backend: str) -> dict:
    """Translate NL query to WIQL or JQL with a mock JSON result."""
    query = query.strip()
    if not query:
        raise ValueError("Query cannot be empty")
    if backend not in ("ado", "jira"):
        raise ValueError(f"Unknown backend: {backend!r}. Use 'ado' or 'jira'.")

    patterns = ADO_PATTERNS if backend == "ado" else JQL_PATTERNS
    matched_filters: list[tuple[str, str]] = []
    matched_patterns: list[str] = []

    for pat, field, value in patterns:
        if pat.search(query):
            matched_filters.append((field, value))
            matched_patterns.append(f"{field}={value}")

    if backend == "ado":
        translated = build_wiql(matched_filters)
        query_type = "WIQL"
    else:
        translated = build_jql(matched_filters)
        query_type = "JQL"

    # Mock result scaffold
    mock_result = {
        "query_type": query_type,
        "backend": backend,
        "nl_input": query,
        "matched_patterns": matched_patterns,
        "translated_query": translated,
        "mock_result": {
            "total": 3,
            "items": [
                {"id": 1001, "title": "Sample item A", "state": "Active"},
                {"id": 1002, "title": "Sample item B", "state": "Active"},
                {"id": 1003, "title": "Sample item C", "state": "Blocked"},
            ],
        },
    }
    return mock_result


# ── CLI ───────────────────────────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Natural language to WIQL/JQL translator (SE-031)"
    )
    parser.add_argument("--query", "-q", required=True, help="NL query string")
    parser.add_argument(
        "--backend",
        "-b",
        choices=["ado", "jira"],
        default="ado",
        help="Query backend: ado (Azure DevOps / WIQL) or jira (JQL). Default: ado",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        dest="json_out",
        help="Output full JSON result (default: translated query only)",
    )

    args = parser.parse_args()

    if not args.query.strip():
        print("Error: --query cannot be empty", file=sys.stderr)
        return 1

    try:
        result = translate(args.query, args.backend)
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1 if "empty" in str(exc).lower() else 2

    if args.json_out:
        print(json.dumps(result, indent=2))
    else:
        print(result["translated_query"])

    return 0


if __name__ == "__main__":
    sys.exit(main())
