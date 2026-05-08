"""Azure DevOps REST client for SPEC-IA01.

Refactor of scripts/enrich_sprint.py — exposes:
  - load_pat(pat_file)      → str
  - run_wiql(org, proj, q, pat) → list[int]
  - fetch_batch(org, ids, fields, pat, expand=None) → list[dict]
  - fetch_in_chunks(...)    → list[dict]
  - normalize_workitem(value)   → dict (canonical shape)
  - sprint_label(iter_path)     → str | None

Read-only. Retries on 429/503 with exponential backoff. Stdlib only.
"""
from __future__ import annotations

import base64
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Iterable

_SYS = "System."
_VSTS = "Microsoft.VSTS."

DEFAULT_FIELDS = (
    _SYS + "Id",
    _SYS + "Title",
    _SYS + "State",
    _SYS + "WorkItemType",
    _SYS + "AssignedTo",
    _SYS + "Tags",
    _SYS + "CreatedDate",
    _SYS + "ChangedDate",
    _SYS + "IterationPath",
    _SYS + "AreaPath",
    _SYS + "Parent",
    _VSTS + "Common.Priority",
    _VSTS + "Scheduling.Effort",
    _VSTS + "Scheduling.CompletedWork",
    _VSTS + "Scheduling.RemainingWork",
)


class DevOpsError(Exception):
    """Base for client errors with stable categorisation."""

    def __init__(self, message: str, kind: str = "generic") -> None:
        super().__init__(message)
        self.kind = kind


def load_pat(pat_file: str | os.PathLike[str]) -> str:
    """Load PAT from disk. RN-15: never hardcode."""
    p = Path(os.path.expandvars(os.path.expanduser(str(pat_file))))
    if not p.exists():
        raise DevOpsError(f"PAT file missing: {p}", kind="pat_missing")
    val = p.read_text(encoding="utf-8").strip()
    if not val:
        raise DevOpsError(f"PAT file is empty: {p}", kind="pat_empty")
    return val


def _basic_auth(pat: str) -> str:
    token = base64.b64encode((":" + pat).encode("utf-8")).decode("ascii")
    return "Basic " + token


def _make_request(url: str, pat: str, body: dict | None = None) -> urllib.request.Request:
    headers = {
        "Authorization": _basic_auth(pat),
        "Accept": "application/json",
        "User-Agent": "incidencias-audit/1.0 (SPEC-IA01)",
    }
    if body is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(body, ensure_ascii=False).encode("utf-8")
        return urllib.request.Request(url, data=data, headers=headers, method="POST")
    return urllib.request.Request(url, headers=headers, method="GET")


def _do_request(req: urllib.request.Request, *, timeout: int, retries: int = 3) -> dict:
    delay = 1.0
    last_err: Exception | None = None
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                raw = resp.read()
            return json.loads(raw)
        except urllib.error.HTTPError as err:
            if err.code == 401:
                raise DevOpsError("HTTP 401 Unauthorized — PAT inválido o sin permisos", kind="pat_unauthorized")
            if err.code in (429, 503) and attempt < retries - 1:
                time.sleep(delay)
                delay *= 2
                last_err = err
                continue
            raise DevOpsError(f"HTTP {err.code} {err.reason}: {url_short(req.full_url)}", kind="http_error")
        except urllib.error.URLError as err:
            last_err = err
            if attempt < retries - 1:
                time.sleep(delay)
                delay *= 2
                continue
            raise DevOpsError(f"Network error: {err.reason}", kind="network")
        except json.JSONDecodeError as err:
            raise DevOpsError(f"Invalid JSON response: {err}", kind="bad_response")
    raise DevOpsError(f"Retries exhausted: {last_err}", kind="retries_exhausted")


def url_short(url: str) -> str:
    return url[:120] + ("…" if len(url) > 120 else "")


def run_wiql(org: str, project: str, query: str, pat: str, *, timeout: int = 60) -> list[int]:
    """Run a WIQL query, return list of work item IDs in the order returned."""
    url = (
        "https://dev.azure.com/" + urllib.parse.quote(org)
        + "/" + urllib.parse.quote(project)
        + "/_apis/wit/wiql?api-version=7.1"
    )
    req = _make_request(url, pat, body={"query": query})
    data = _do_request(req, timeout=timeout)
    return [w["id"] for w in data.get("workItems", [])]


def fetch_batch(
    org: str,
    ids: Iterable[int],
    pat: str,
    *,
    fields: Iterable[str] = DEFAULT_FIELDS,
    expand: str | None = None,
    timeout: int = 60,
) -> list[dict]:
    """Fetch work items in batch. expand='relations' returns relations array."""
    id_list = list(ids)
    if not id_list:
        return []
    if len(id_list) > 200:
        raise DevOpsError(f"batch size {len(id_list)} > 200 (Azure DevOps limit)", kind="bad_input")

    params = ["ids=" + ",".join(str(i) for i in id_list), "api-version=7.1-preview.3"]
    if expand:
        params.append("$expand=" + urllib.parse.quote(expand))
    else:
        params.append("fields=" + ",".join(fields))

    url = "https://dev.azure.com/" + urllib.parse.quote(org) + "/_apis/wit/workitems?" + "&".join(params)
    req = _make_request(url, pat)
    data = _do_request(req, timeout=timeout)
    return data.get("value", [])


def fetch_in_chunks(
    org: str,
    ids: Iterable[int],
    pat: str,
    *,
    fields: Iterable[str] = DEFAULT_FIELDS,
    expand: str | None = None,
    batch_size: int = 200,
    sleep_between: float = 0.3,
    timeout: int = 60,
) -> list[dict]:
    """Fetch many IDs by chunking into batches."""
    id_list = list(ids)
    out: list[dict] = []
    for i in range(0, len(id_list), batch_size):
        chunk = id_list[i : i + batch_size]
        out.extend(fetch_batch(org, chunk, pat, fields=fields, expand=expand, timeout=timeout))
        if i + batch_size < len(id_list):
            time.sleep(sleep_between)
    return out


def normalize_workitem(value: dict) -> dict:
    """Project a raw work item dict into the canonical IA01 shape.

    Drops vendor-specific fields and extracts what the audit needs.
    """
    f = value.get("fields", {}) or {}
    at = f.get(_SYS + "AssignedTo")
    assigned_to: str | None = None
    if isinstance(at, dict):
        assigned_to = at.get("displayName") or at.get("uniqueName")
    elif isinstance(at, str):
        assigned_to = at

    tags_raw = f.get(_SYS + "Tags") or ""
    tags = [t.strip() for t in tags_raw.split(";") if t.strip()]

    return {
        "id": int(value["id"]),
        "title": (f.get(_SYS + "Title") or "").strip(),
        "state": f.get(_SYS + "State"),
        "workItemType": f.get(_SYS + "WorkItemType"),
        "assignedTo": assigned_to,
        "tags": tags,
        "createdDate": _date_only(f.get(_SYS + "CreatedDate")),
        "changedDate": _date_only(f.get(_SYS + "ChangedDate")),
        "iterationPath": f.get(_SYS + "IterationPath"),
        "areaPath": f.get(_SYS + "AreaPath"),
        "parent": f.get(_SYS + "Parent"),
        "priority": _as_int_or_none(f.get(_VSTS + "Common.Priority")),
        "effort": _as_int_or_none(f.get(_VSTS + "Scheduling.Effort")),
        "completedWork": _as_int_or_none(f.get(_VSTS + "Scheduling.CompletedWork")),
        "remainingWork": _as_int_or_none(f.get(_VSTS + "Scheduling.RemainingWork")),
        "relations": value.get("relations") or [],
    }


def _date_only(iso: str | None) -> str | None:
    if not iso:
        return None
    return iso[:10] if len(iso) >= 10 else iso


def _as_int_or_none(v: Any) -> int | None:
    if v is None:
        return None
    try:
        return int(v)
    except (TypeError, ValueError):
        try:
            return int(float(v))
        except (TypeError, ValueError):
            return None


def sprint_label(iteration_path: str | None) -> str | None:
    """Extract the trailing iteration label (e.g. 'Sprint 26') from a path."""
    if not iteration_path:
        return None
    parts = iteration_path.replace("\\", "/").split("/")
    last = parts[-1].strip() if parts else ""
    return last if last else None


__all__ = [
    "DevOpsError",
    "DEFAULT_FIELDS",
    "load_pat",
    "run_wiql",
    "fetch_batch",
    "fetch_in_chunks",
    "normalize_workitem",
    "sprint_label",
]
