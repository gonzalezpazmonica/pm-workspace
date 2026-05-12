"""f1/inventory.py — F1 job: count files by type, age, level, size."""
from __future__ import annotations

import datetime
from collections import Counter
from pathlib import Path
from typing import Any


def run(files: list[dict]) -> dict:
    """Analyse inventory of discovered markdown files.

    Returns:
        dict with findings list and summary stats.
    """
    now = datetime.datetime.now(tz=datetime.timezone.utc)
    findings = []
    by_conf: Counter = Counter()
    by_scope: Counter = Counter()
    age_buckets: Counter = Counter()  # <7d, 7-30d, 30-90d, 90-180d, >180d
    total_bytes = 0

    for f in files:
        by_conf[f.get("conf_level", "N1")] += 1
        by_scope[f.get("scope_tag", "?")] += 1
        total_bytes += f.get("size_bytes", 0)

        mtime_str = f.get("mtime_iso", "")
        if mtime_str:
            try:
                mtime = datetime.datetime.fromisoformat(mtime_str)
                age_days = (now - mtime).days
            except Exception:
                age_days = -1
        else:
            age_days = -1

        if age_days < 0:
            age_buckets["unknown"] += 1
        elif age_days < 7:
            age_buckets["<7d"] += 1
        elif age_days < 30:
            age_buckets["7-30d"] += 1
        elif age_days < 90:
            age_buckets["30-90d"] += 1
        elif age_days < 180:
            age_buckets["90-180d"] += 1
        else:
            age_buckets[">180d"] += 1

        # Flag very large files (>100KB) as potential bloat
        if f.get("size_bytes", 0) > 100_000:
            findings.append({
                "job": "inventory",
                "severity": "info",
                "confidence": "HIGH",
                "file": f["rel_path"],
                "message": f"Large file ({f['size_bytes']//1024}KB) — consider splitting.",
                "auto_aplicable": False,
            })

    return {
        "job": "inventory",
        "status": "ok",
        "total_files": len(files),
        "total_bytes": total_bytes,
        "by_conf_level": dict(by_conf),
        "by_scope": dict(by_scope),
        "age_buckets": dict(age_buckets),
        "findings": findings,
    }
