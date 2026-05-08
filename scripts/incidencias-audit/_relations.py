"""Relation classification for SPEC-IA01.

Filters and classifies the `relations` array returned by Azure DevOps
$expand=relations into 3 buckets: tasks, bugs, other_relations.

Also derives the treatment phase (Pendiente análisis / Analizadas con BUG abierto / etc).
"""
from __future__ import annotations

import re
from typing import Iterable

# Work item type sets (RN: case-insensitive comparison via .casefold())
TASK_TYPES = {"task"}
BUG_TYPES = {"bug"}
KEEP_OTHER_TYPES = {"product backlog item", "feature", "epic", "issue", "user story"}
IGNORE_TYPES = {
    "test case", "test suite", "test plan", "shared steps", "shared parameter"
}

# Link type rel mappings (the "rel" field in a relation object)
LINK_TYPE_MAP = {
    "System.LinkTypes.Hierarchy-Forward": "child",
    "System.LinkTypes.Hierarchy-Reverse": "parent",
    "System.LinkTypes.Related": "related",
    "System.LinkTypes.Dependency-Forward": "successor",
    "System.LinkTypes.Dependency-Reverse": "predecessor",
}

# Bug states considered "open" for treatment phase calc
BUG_OPEN_STATES = {"new", "approved", "committed", "in progress", "to do", "active"}

# Task states that mean "not yet started" — treated as Pendiente análisis
TASK_NOT_STARTED_STATES = {"new", "to do"}

_WORKITEM_URL_RE = re.compile(r"/_apis/wit/workItems/(\d+)$", re.IGNORECASE)


def extract_ids(relations: Iterable[dict]) -> list[int]:
    """Pull unique work item IDs from a relations array, preserving first-seen order."""
    seen: set[int] = set()
    out: list[int] = []
    for r in relations or []:
        url = r.get("url") or ""
        m = _WORKITEM_URL_RE.search(url)
        if not m:
            continue
        wid = int(m.group(1))
        if wid in seen:
            continue
        seen.add(wid)
        out.append(wid)
    return out


def classify(
    relations: Iterable[dict],
    related_by_id: dict[int, dict],
) -> dict:
    """Bucket relations into tasks, bugs, other_relations.

    related_by_id: map of wid -> normalized work item dict (must contain
                   workItemType and state).
    Returns: {"tasks": [...], "bugs": [...], "other_relations": [...]}
    Each bucketed item is enriched with `link_type` (child/parent/related/...).
    Sort: by id ascending within each bucket.
    """
    tasks: list[dict] = []
    bugs: list[dict] = []
    other: list[dict] = []

    seen: set[int] = set()
    for r in relations or []:
        url = r.get("url") or ""
        m = _WORKITEM_URL_RE.search(url)
        if not m:
            continue
        wid = int(m.group(1))
        if wid in seen:
            continue
        seen.add(wid)

        info = related_by_id.get(wid)
        if not info:
            # Relation points to an ID we don't have data for — skip silently.
            continue

        wit = (info.get("workItemType") or "").strip()
        wit_lc = wit.casefold()
        if wit_lc in IGNORE_TYPES:
            continue

        link_type = LINK_TYPE_MAP.get(r.get("rel") or "", r.get("rel") or "unknown")

        item = {
            "id": wid,
            "state": info.get("state"),
            "workItemType": wit,
            "link_type": link_type,
            "assignedTo": info.get("assignedTo"),
            "iterationPath": info.get("iterationPath"),
        }

        if wit_lc in TASK_TYPES:
            tasks.append(item)
        elif wit_lc in BUG_TYPES:
            bugs.append(item)
        elif wit_lc in KEEP_OTHER_TYPES:
            other.append(item)
        # else: silently skip unknown types

    tasks.sort(key=lambda x: x["id"])
    bugs.sort(key=lambda x: x["id"])
    other.sort(key=lambda x: x["id"])

    return {"tasks": tasks, "bugs": bugs, "other_relations": other}


def treatment_phase(tasks: list[dict], bugs: list[dict]) -> str:
    """Compute the treatment phase from tasks and bugs (already classified).

    Rules (from SPEC-IA01 §1.3):
      - "Pendiente análisis" — no Task, OR all Tasks in New/To Do.
      - "Descartadas (task cerrado sin BUG)" — Task Done and 0 Bugs.
      - "Analizadas con BUG Done" — Task Done AND >=1 Bug AND all Bugs Done.
      - "Analizadas con BUG abierto" — Task Done AND >=1 Bug NOT Done.
    """
    if not tasks:
        return "Pendiente análisis"

    task_states_lc = {(t.get("state") or "").casefold() for t in tasks}
    if task_states_lc.issubset(TASK_NOT_STARTED_STATES):
        return "Pendiente análisis"

    if not bugs:
        # At least one Task is Done (or in progress) and no Bug exists
        return "Descartadas (task cerrado sin BUG)"

    bug_states_lc = [(b.get("state") or "").casefold() for b in bugs]
    if all(s == "done" for s in bug_states_lc):
        return "Analizadas con BUG Done"
    return "Analizadas con BUG abierto"


__all__ = [
    "TASK_TYPES",
    "BUG_TYPES",
    "KEEP_OTHER_TYPES",
    "IGNORE_TYPES",
    "LINK_TYPE_MAP",
    "extract_ids",
    "classify",
    "treatment_phase",
]
