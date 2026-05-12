"""store.py — Run store: persist F0-F4 outputs to ~/.savia/context-update-tmp/{run_id}/."""
from __future__ import annotations

import json
import os
import time
import uuid
from pathlib import Path
from typing import Any, Optional


SAVIA_HOME = Path.home() / ".savia"
TMP_ROOT = SAVIA_HOME / "context-update-tmp"


def new_run_id() -> str:
    ts = time.strftime("%Y%m%d-%H%M%S")
    short = str(uuid.uuid4())[:8]
    return f"{ts}-{short}"


def run_dir(run_id: str) -> Path:
    d = TMP_ROOT / run_id
    d.mkdir(parents=True, exist_ok=True)
    return d


def write_json(run_id: str, phase: str, name: str, data: Any) -> Path:
    """Write JSON artefact. phase e.g. 'F0', 'F1', 'F2'. name e.g. 'inventory'."""
    d = run_dir(run_id) / phase
    d.mkdir(parents=True, exist_ok=True)
    p = d / f"{name}.json"
    p.write_text(json.dumps(data, indent=2, default=str), encoding="utf-8")
    return p


def read_json(run_id: str, phase: str, name: str) -> Optional[Any]:
    p = run_dir(run_id) / phase / f"{name}.json"
    if not p.exists():
        return None
    return json.loads(p.read_text(encoding="utf-8"))


def write_manifest(run_id: str, manifest: dict) -> Path:
    p = run_dir(run_id) / "manifest.json"
    p.write_text(json.dumps(manifest, indent=2, default=str), encoding="utf-8")
    return p


def list_runs(n: int = 10) -> list[str]:
    if not TMP_ROOT.exists():
        return []
    runs = sorted(
        [d.name for d in TMP_ROOT.iterdir() if d.is_dir()],
        reverse=True,
    )
    return runs[:n]


def latest_run_id() -> Optional[str]:
    runs = list_runs(1)
    return runs[0] if runs else None


# ---------------------------------------------------------------------------
# Trend / metrics ledger  (sub-slice 6c)
# ---------------------------------------------------------------------------
METRICS_LEDGER = SAVIA_HOME / "context-update-metrics.jsonl"


def append_metrics(run_id: str, scope: str, summary: dict) -> None:
    """Append a metrics snapshot to the trend ledger (JSONL, append-only)."""
    import datetime

    record = {
        "ts": datetime.datetime.now(tz=datetime.timezone.utc).isoformat(),
        "run_id": run_id,
        "scope": scope,
        "total_findings": summary.get("total_findings", 0),
        "by_severity": summary.get("by_severity", {}),
        "by_phase": summary.get("by_phase", {}),
        "files_scanned": summary.get("total_files", 0),
    }
    METRICS_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    with METRICS_LEDGER.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(record, ensure_ascii=False) + "\n")


def read_trend(n: int = 10, scope: Optional[str] = None) -> list[dict]:
    """Read the last *n* metrics records (optionally filtered by scope)."""
    if not METRICS_LEDGER.exists():
        return []
    records = []
    for line in METRICS_LEDGER.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        if scope and rec.get("scope") != scope:
            continue
        records.append(rec)
    return records[-n:]

