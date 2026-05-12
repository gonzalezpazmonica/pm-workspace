"""f1/__init__.py — F1 runner: execute all 8 canonical jobs in parallel.

Jobs (spec §7.3 F1):
  inventory, frontmatter_lint, wikilink_check, tag_consistency,
  confidentiality_leak, secret_scan, staleness, duplicate_detection

ThreadPoolExecutor with 8 workers. Hard time-box: 5 min total.
Each job has its own per-job timeout (see _JOBS).

SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2 §7.3 F1.
"""
from __future__ import annotations

import json
import time
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FuturesTimeout
from pathlib import Path
from typing import Any

from . import (
    confidentiality_leak,
    duplicate_detection,
    frontmatter_lint,
    inventory,
    secret_scan,
    staleness,
    tag_consistency,
    wikilink_check,
)

# (module, job_id, per_job_timeout_seconds)
_JOBS = [
    (inventory,            "inventory",            60),
    (frontmatter_lint,     "frontmatter_lint",     120),
    (wikilink_check,       "wikilink_check",       120),
    (tag_consistency,      "tag_consistency",      60),
    (confidentiality_leak, "confidentiality_leak", 90),
    (secret_scan,          "secret_scan",          120),
    (staleness,            "staleness",            60),
    (duplicate_detection,  "duplicate_detection",  180),
]

F1_MAX_TOTAL_SECONDS = 300   # 5 min hard cap


def run_all(files: list[dict], store_dir: Path | None = None) -> dict[str, Any]:
    """Run all 8 F1 jobs in parallel (ThreadPoolExecutor, 8 workers).

    Args:
        files:      list of file dicts from discovery.
        store_dir:  optional path to write per-job JSON files.

    Returns:
        Aggregated result dict:
          {
            "jobs":     {job_id: result_dict},
            "findings": [all findings from all jobs],
            "summary":  {total_files, total_findings, by_severity, by_job, elapsed_s},
          }
    """
    if store_dir:
        store_dir = Path(store_dir)
        store_dir.mkdir(parents=True, exist_ok=True)

    jobs_results: dict[str, Any] = {}
    all_findings: list[dict] = []
    t0 = time.monotonic()

    def _run_job(module_job_timeout: tuple) -> tuple[str, dict]:
        module, job_id, timeout = module_job_timeout
        jt0 = time.monotonic()
        try:
            result = module.run(files)
        except Exception as exc:  # noqa: BLE001
            result = {
                "job": job_id,
                "findings": [],
                "error": str(exc),
                "summary": {"findings_count": 0},
            }
        result["elapsed_s"] = round(time.monotonic() - jt0, 3)
        return job_id, result

    remaining = F1_MAX_TOTAL_SECONDS
    with ThreadPoolExecutor(max_workers=8) as executor:
        futures = {
            executor.submit(_run_job, (module, job_id, per_timeout)): (job_id, per_timeout)
            for module, job_id, per_timeout in _JOBS
        }
        for future, (job_id, per_timeout) in futures.items():
            elapsed_so_far = time.monotonic() - t0
            time_left = max(0, min(per_timeout, F1_MAX_TOTAL_SECONDS - elapsed_so_far))
            try:
                jid, result = future.result(timeout=time_left)
            except FuturesTimeout:
                result = {
                    "job": job_id,
                    "findings": [],
                    "error": f"timeout after {per_timeout}s",
                    "summary": {"findings_count": 0},
                    "elapsed_s": per_timeout,
                }
                jid = job_id
            except Exception as exc:  # noqa: BLE001
                result = {
                    "job": job_id,
                    "findings": [],
                    "error": str(exc),
                    "summary": {"findings_count": 0},
                    "elapsed_s": 0,
                }
                jid = job_id

            jobs_results[jid] = result
            all_findings.extend(result.get("findings", []))

            if store_dir:
                (store_dir / f"{jid}.json").write_text(
                    json.dumps(result, ensure_ascii=False, indent=2),
                    encoding="utf-8",
                )

    elapsed = round(time.monotonic() - t0, 3)

    by_severity: dict[str, int] = {}
    by_job: dict[str, int] = {}
    for f in all_findings:
        sev = f.get("severity", "INFO")
        by_severity[sev] = by_severity.get(sev, 0) + 1
        jid = f.get("job", "unknown")
        by_job[jid] = by_job.get(jid, 0) + 1

    aggregated = {
        "jobs": jobs_results,
        "findings": all_findings,
        "summary": {
            "total_files": len(files),
            "total_findings": len(all_findings),
            "by_severity": by_severity,
            "by_job": by_job,
            "elapsed_s": elapsed,
        },
    }

    if store_dir:
        (store_dir / "_aggregate.json").write_text(
            json.dumps(aggregated["summary"], ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    return aggregated
