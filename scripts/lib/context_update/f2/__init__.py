"""f2/__init__.py — F2 runner: LLM agents with heuristic fallback.

Primary path: invoker.py calls the 4 spec LLM agents in parallel
(context-quality-judge, context-coherence-judge, context-obsolescence-judge,
context-redundancy-judge).

Fallback: if the LLM runner is unavailable (no claude CLI, no run-agent.sh),
falls back to the local heuristic modules so the pipeline never hard-fails.

SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2 §7.3 F2.
"""
from __future__ import annotations

import json
import logging
import time
from pathlib import Path
from typing import Any

log = logging.getLogger(__name__)


def run_all(
    files: list[dict],
    f1_findings: list[dict] | None = None,
    workspace: str | None = None,
    store_dir: Path | None = None,
) -> dict[str, Any]:
    """Run F2 semantic analysis.

    Tries the LLM invoker first. Falls back to heuristic judges if unavailable.

    Args:
        files:       list of file dicts from discovery (should include 'content').
        f1_findings: flat list of F1 findings (used for coherence/redundancy pairs).
        workspace:   workspace root (needed to locate claude CLI).
        store_dir:   optional path to write per-judge JSON files.

    Returns:
        Aggregated result dict:
          {
            "agents"|"judges": {id: result},
            "findings": [all findings],
            "summary":  {total_files, total_findings, by_severity, by_job, elapsed_s},
            "mode":     "llm" | "heuristic",
          }
    """
    f1_findings = f1_findings or []
    workspace = workspace or ""

    # --- Try LLM invoker ---
    try:
        from .invoker import _find_claude_cli, _find_run_agent_sh, run_all as _llm_run

        if _find_claude_cli() or _find_run_agent_sh(workspace):
            log.info("F2: using LLM invoker (claude CLI or run-agent.sh available)")
            result = _llm_run(
                files=files,
                f1_findings=f1_findings,
                workspace=workspace,
                store_dir=store_dir,
            )
            result["mode"] = "llm"
            return result
        else:
            log.info("F2: LLM runner not available — falling back to heuristic judges")
    except Exception as exc:  # noqa: BLE001
        log.warning("F2: LLM invoker failed (%s) — falling back to heuristic judges", exc)

    # --- Heuristic fallback ---
    return _run_heuristic(files, store_dir)


def _run_heuristic(
    files: list[dict],
    store_dir: Path | None = None,
) -> dict[str, Any]:
    """Heuristic fallback: run the 4 local judge modules sequentially."""
    from . import (
        actionability_judge,
        completeness_judge,
        consistency_judge,
        relevance_judge,
    )

    if store_dir:
        store_dir = Path(store_dir)
        store_dir.mkdir(parents=True, exist_ok=True)

    _JUDGES = [
        (relevance_judge,      "relevance_judge"),
        (consistency_judge,    "consistency_judge"),
        (completeness_judge,   "completeness_judge"),
        (actionability_judge,  "actionability_judge"),
    ]

    judges_results: dict[str, Any] = {}
    all_findings: list[dict] = []
    t0 = time.monotonic()

    for module, judge_id in _JUDGES:
        jt0 = time.monotonic()
        try:
            result = module.run(files)
        except Exception as exc:  # noqa: BLE001
            result = {
                "job": judge_id,
                "findings": [],
                "error": str(exc),
                "summary": {"findings_count": 0},
            }
        result["elapsed_s"] = round(time.monotonic() - jt0, 3)
        judges_results[judge_id] = result
        all_findings.extend(result.get("findings", []))

        if store_dir:
            (store_dir / f"{judge_id}.json").write_text(
                json.dumps(result, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )

    elapsed = round(time.monotonic() - t0, 3)

    by_severity: dict[str, int] = {}
    by_job: dict[str, int] = {}
    for finding in all_findings:
        sev = finding.get("severity", "INFO")
        by_severity[sev] = by_severity.get(sev, 0) + 1
        jid = finding.get("job", "unknown")
        by_job[jid] = by_job.get(jid, 0) + 1

    aggregated: dict[str, Any] = {
        "judges": judges_results,
        "findings": all_findings,
        "summary": {
            "total_files": len(files),
            "total_findings": len(all_findings),
            "by_severity": by_severity,
            "by_job": by_job,
            "elapsed_s": elapsed,
        },
        "mode": "heuristic",
    }

    if store_dir:
        (store_dir / "_aggregate.json").write_text(
            json.dumps(aggregated["summary"], ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    return aggregated
