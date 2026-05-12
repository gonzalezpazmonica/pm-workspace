"""f3/__init__.py — F3 consolidator: merge F1 + F2 findings into a 4-block action plan.

Produces:
  - F3_plan.json      canonical machine-readable plan
  - F3_plan.md        human-readable markdown report
  - consolidated.json full findings list (all F1 + F2)

Metrics:
  - composite_quality (0.0–1.0 with letter grade)
  - coverage_frontmatter
  - confidentiality_integrity
  - trend vs previous run

SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2 §7.3 F3.
"""
from __future__ import annotations

import datetime
import json
import time
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

_SEV_ORDER = {"ERROR": 0, "WARNING": 1, "INFO": 2}
_MAX_PLAN_ITEMS = 30   # top items across all blocks; rest go to backlog

# Block definitions: (block_key, label, assignment_fn)
# Assignment is decided by _assign_block() below.

_BLOCK_CRITICAL    = "block_1_critical"
_BLOCK_IMPORTANT   = "block_2_important"
_BLOCK_MAINTENANCE = "block_3_maintenance"
_BLOCK_QUALITY     = "block_4_quality"

_BLOCK_LABELS = {
    _BLOCK_CRITICAL:    "CRÍTICO — errores estructurales y secretos",
    _BLOCK_IMPORTANT:   "IMPORTANTE — frontmatter, confidencialidad, wikilinks",
    _BLOCK_MAINTENANCE: "MANTENIMIENTO — obsolescencia, staleness, duplicados",
    _BLOCK_QUALITY:     "CALIDAD — prose vaga, incoherencias, secciones huérfanas",
}

# Jobs/agents that belong to each block
_CRITICAL_JOBS    = {"secret_scan", "confidentiality_leak"}
_IMPORTANT_JOBS   = {"frontmatter_lint", "wikilink_check", "context_coherence_judge",
                     "consistency_judge", "context-coherence-judge"}
_MAINTENANCE_JOBS = {"staleness", "duplicate_detection", "context_obsolescence_judge",
                     "context_redundancy_judge", "context-obsolescence-judge",
                     "context-redundancy-judge"}
_QUALITY_JOBS     = {"tag_consistency", "context_quality_judge", "context-quality-judge",
                     "relevance_judge", "completeness_judge", "actionability_judge"}


# ---------------------------------------------------------------------------
# Block assignment
# ---------------------------------------------------------------------------

def _assign_block(finding: dict) -> str:
    job = finding.get("job", "")
    sev = finding.get("severity", "INFO")

    if sev == "ERROR":
        return _BLOCK_CRITICAL
    if job in _CRITICAL_JOBS:
        return _BLOCK_CRITICAL
    if job in _IMPORTANT_JOBS:
        return _BLOCK_IMPORTANT
    if job in _MAINTENANCE_JOBS:
        return _BLOCK_MAINTENANCE
    if job in _QUALITY_JOBS:
        return _BLOCK_QUALITY
    # Default: WARNING → IMPORTANT, INFO → MAINTENANCE
    if sev == "WARNING":
        return _BLOCK_IMPORTANT
    return _BLOCK_MAINTENANCE


# ---------------------------------------------------------------------------
# Composite quality score
# ---------------------------------------------------------------------------

def _compute_composite_quality(findings: list[dict], previous: float | None = None) -> dict:
    """Score 0.0–1.0 based on finding severity counts."""
    error_count   = sum(1 for f in findings if f.get("severity") == "ERROR")
    warning_count = sum(1 for f in findings if f.get("severity") == "WARNING")
    info_count    = sum(1 for f in findings if f.get("severity") == "INFO")

    score = 1.0
    score -= min(error_count   * 0.05, 0.40)
    score -= min(warning_count * 0.02, 0.30)
    score -= min(info_count    * 0.01, 0.15)
    score = max(round(score, 3), 0.0)

    if score >= 0.90:
        grade = "A"
    elif score >= 0.80:
        grade = "B+"
    elif score >= 0.70:
        grade = "B"
    elif score >= 0.60:
        grade = "C"
    else:
        grade = "D"

    trend = None
    if previous is not None:
        delta = round(score - previous, 3)
        trend = f"{'+' if delta >= 0 else ''}{delta}"

    return {
        "composite_quality": score,
        "composite_quality_grade": grade,
        "trend": trend,
    }


def _compute_coverage_frontmatter(f1_result: dict) -> float:
    """Fraction of files with valid frontmatter."""
    total = f1_result.get("summary", {}).get("total_files", 0)
    if total == 0:
        return 1.0
    fm_job = f1_result.get("jobs", {}).get("frontmatter_lint", {})
    fm_findings = fm_job.get("findings", [])
    # Each finding is one file with a frontmatter issue
    files_with_issues = len({f.get("file") for f in fm_findings if f.get("file")})
    return round(max(0.0, (total - files_with_issues) / total), 3)


def _compute_confidentiality_integrity(f1_result: dict) -> float:
    """1.0 if no confidentiality_leak findings, else fraction of clean files."""
    total = f1_result.get("summary", {}).get("total_files", 0)
    if total == 0:
        return 1.0
    cl_job = f1_result.get("jobs", {}).get("confidentiality_leak", {})
    leak_count = len(cl_job.get("findings", []))
    if leak_count == 0:
        return 1.0
    return round(max(0.0, 1.0 - leak_count / total), 3)


# ---------------------------------------------------------------------------
# Plan builder
# ---------------------------------------------------------------------------

def _build_plan(findings: list[dict]) -> tuple[dict, list[dict]]:
    """Group findings into 4 blocks. Returns (plan_dict, backlog_list)."""
    # Group by (block, file, job) to deduplicate
    grouped: dict[str, dict[tuple, dict]] = {
        _BLOCK_CRITICAL:    {},
        _BLOCK_IMPORTANT:   {},
        _BLOCK_MAINTENANCE: {},
        _BLOCK_QUALITY:     {},
    }

    for finding in findings:
        block = _assign_block(finding)
        file_  = finding.get("file", "")
        job    = finding.get("job", "")
        key    = (file_, job)
        if key not in grouped[block]:
            # First finding for this (file, job) pair — use as representative
            grouped[block][key] = finding

    # Flatten and sort within each block by severity then file
    def _to_items(block_dict: dict) -> list[dict]:
        items = list(block_dict.values())
        items.sort(key=lambda x: (
            _SEV_ORDER.get(x.get("severity", "INFO"), 99),
            x.get("file", ""),
        ))
        return items

    all_items: list[dict] = []
    block_items: dict[str, list[dict]] = {}
    for block in (_BLOCK_CRITICAL, _BLOCK_IMPORTANT, _BLOCK_MAINTENANCE, _BLOCK_QUALITY):
        items = _to_items(grouped[block])
        block_items[block] = items
        all_items.extend(items)

    # Apply global cap of _MAX_PLAN_ITEMS
    top_items = all_items[:_MAX_PLAN_ITEMS]
    backlog   = all_items[_MAX_PLAN_ITEMS:]

    # Rebuild per-block from top_items
    top_set = set(id(i) for i in top_items)
    plan: dict[str, Any] = {}
    item_counter = 0
    for block_idx, block in enumerate(
        (_BLOCK_CRITICAL, _BLOCK_IMPORTANT, _BLOCK_MAINTENANCE, _BLOCK_QUALITY), 1
    ):
        block_top = [i for i in block_items[block] if id(i) in top_set]
        plan_items = []
        for item in block_top:
            item_counter += 1
            plan_items.append({
                "id": f"{block_idx}.{len(plan_items) + 1}",
                "action": _action_from_finding(item),
                "command_hint": _command_hint(item),
                "auto_applicable": item.get("auto_applicable", False),
                "severity": item.get("severity", "INFO"),
                "file": item.get("file", ""),
                "job": item.get("job", ""),
                "finding_refs": [f"{item.get('job', '?')}:{item.get('file', '?')}"],
            })
        plan[block] = {
            "label": _BLOCK_LABELS[block],
            "item_count": len(plan_items),
            "items": plan_items,
        }

    return plan, backlog


def _action_from_finding(f: dict) -> str:
    """Generate a short imperative action string from a finding."""
    job     = f.get("job", "")
    file_   = f.get("file", "?")
    message = f.get("message") or f.get("issue") or f.get("obsolescence_type") or ""
    short   = Path(file_).name

    if "secret" in job:
        return f"Remove secret in `{short}`: {message[:80]}"
    if "confidentiality" in job:
        return f"Fix confidentiality leak in `{short}`: {message[:80]}"
    if "frontmatter" in job:
        return f"Fix frontmatter in `{short}`: {message[:80]}"
    if "wikilink" in job:
        return f"Fix broken wikilink in `{short}`: {message[:80]}"
    if "staleness" in job:
        return f"Review stale note `{short}` ({message[:60]})"
    if "duplicate" in job or "redundancy" in job:
        other = f.get("duplicate_of") or f.get("other_file") or ""
        return f"Resolve duplicate: `{short}` vs `{Path(other).name if other else '?'}`"
    if "obsolescence" in job:
        return f"Archive or update obsolete note `{short}`: {message[:60]}"
    if "coherence" in job:
        return f"Resolve contradiction in `{short}`: {message[:80]}"
    if "quality" in job:
        return f"Improve prose quality in `{short}`: {message[:80]}"
    if "tag" in job:
        return f"Normalise tags in `{short}`: {message[:80]}"
    return f"Fix `{short}` ({job}): {message[:80]}"


def _command_hint(f: dict) -> str:
    job = f.get("job", "")
    if "wikilink" in job:
        return "vault-curator --fix-broken-links"
    if "frontmatter" in job:
        return "vault-curator --fix-frontmatter"
    if "tag" in job:
        return "vault-curator --normalise-tags"
    if "staleness" in job or "obsolescence" in job:
        return "manual — review and archive or update"
    if "duplicate" in job or "redundancy" in job:
        return "manual — merge or remove duplicate"
    if "secret" in job or "confidentiality" in job:
        return "manual — remove sensitive data before committing"
    return "manual"


# ---------------------------------------------------------------------------
# Top problem files
# ---------------------------------------------------------------------------

def _top_problem_files(findings: list[dict], n: int = 5) -> list[str]:
    counts: dict[str, int] = {}
    for f in findings:
        fp = f.get("file", "")
        if fp:
            counts[fp] = counts.get(fp, 0) + 1
    return [fp for fp, _ in sorted(counts.items(), key=lambda x: -x[1])[:n]]


# ---------------------------------------------------------------------------
# Markdown renderer
# ---------------------------------------------------------------------------

def _render_markdown(plan: dict, metrics: dict, summary: dict, backlog: list) -> str:
    lines: list[str] = []
    q = metrics.get("composite_quality", 0.0)
    grade = metrics.get("composite_quality_grade", "?")
    trend = metrics.get("trend")
    trend_str = f" (trend: {trend})" if trend else ""

    lines.append("# /context-update — F3 Action Plan")
    lines.append("")
    lines.append(f"**run_id:** `{summary['run_id']}`  ")
    lines.append(f"**generated:** {summary['generated']}  ")
    lines.append(f"**composite_quality:** {q:.2f} / 1.00 — grade **{grade}**{trend_str}  ")
    lines.append(f"**coverage_frontmatter:** {metrics.get('coverage_frontmatter', 1.0):.1%}  ")
    lines.append(f"**confidentiality_integrity:** {metrics.get('confidentiality_integrity', 1.0):.1%}  ")
    lines.append(f"**total findings:** {summary['total_findings']} "
                 f"(F1: {summary['by_phase'].get('F1', 0)}, "
                 f"F2: {summary['by_phase'].get('F2', 0)})  ")
    lines.append(f"**files scanned:** {summary['total_files']}  ")
    lines.append("")

    # Severity summary
    lines.append("## Severity breakdown")
    lines.append("")
    lines.append("| Severity | Count |")
    lines.append("|---|---|")
    for sev in ("ERROR", "WARNING", "INFO"):
        cnt = summary["by_severity"].get(sev, 0)
        if cnt:
            lines.append(f"| {sev} | {cnt} |")
    lines.append("")

    # 4 blocks
    for block in (_BLOCK_CRITICAL, _BLOCK_IMPORTANT, _BLOCK_MAINTENANCE, _BLOCK_QUALITY):
        block_data = plan.get(block, {})
        items = block_data.get("items", [])
        label = block_data.get("label", block)
        if not items:
            continue
        lines.append(f"## {label} ({len(items)})")
        lines.append("")
        for item in items:
            auto = " ✓" if item.get("auto_applicable") else ""
            hint = item.get("command_hint", "")
            hint_str = f" → `{hint}`" if hint and hint != "manual" else ""
            lines.append(f"- **[{item['id']}]** {item['action']}{auto}{hint_str}")
        lines.append("")

    # Backlog
    if backlog:
        lines.append(f"## Backlog ({len(backlog)} items beyond top {_MAX_PLAN_ITEMS})")
        lines.append("")
        lines.append(f"See `consolidated.json` for full list.")
        lines.append("")

    # Top problem files
    top = summary.get("top_files", [])
    if top:
        lines.append("## Top files by finding count")
        lines.append("")
        for item in top[:5]:
            lines.append(f"- `{item['file']}` — {item['count']} findings")
        lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def consolidate(
    f1_result: dict,
    f2_result: dict,
    run_id: str,
    store_dir: Path | None = None,
    previous_composite_quality: float | None = None,
) -> dict[str, Any]:
    """Merge F1 + F2 findings into a 4-block action plan.

    Args:
        f1_result:   result dict from f1.run_all()
        f2_result:   result dict from f2.run_all()
        run_id:      run identifier string
        store_dir:   optional path to write output files
        previous_composite_quality: score from previous run for trend

    Returns:
        {
          "run_id":      str,
          "generated":   ISO timestamp,
          "findings":    list[dict],         # all F1+F2 tagged with phase
          "plan":        dict,               # 4-block plan
          "backlog":     list[dict],         # items beyond top-30
          "metrics":     dict,               # composite_quality, coverage_*, trend
          "summary":     dict,               # totals
          "report_md":   str,                # F3_plan.md content
        }
    """
    t0 = time.monotonic()

    all_findings: list[dict] = []
    for f in f1_result.get("findings", []):
        fc = dict(f)
        fc["phase"] = "F1"
        all_findings.append(fc)
    for f in f2_result.get("findings", []):
        fc = dict(f)
        fc["phase"] = "F2"
        all_findings.append(fc)

    # Sort globally
    all_findings.sort(key=lambda x: (
        _SEV_ORDER.get(x.get("severity", "INFO"), 99),
        x.get("file", ""),
    ))

    # Metrics
    quality_metrics = _compute_composite_quality(all_findings, previous_composite_quality)
    coverage_fm     = _compute_coverage_frontmatter(f1_result)
    conf_integrity  = _compute_confidentiality_integrity(f1_result)
    metrics = {
        **quality_metrics,
        "coverage_frontmatter":      coverage_fm,
        "confidentiality_integrity": conf_integrity,
    }

    # Plan
    plan, backlog = _build_plan(all_findings)

    # Summary
    by_severity: dict[str, int] = {}
    by_phase: dict[str, int] = {"F1": 0, "F2": 0}
    file_counts: dict[str, int] = {}
    for f in all_findings:
        sev = f.get("severity", "INFO")
        by_severity[sev] = by_severity.get(sev, 0) + 1
        phase = f.get("phase", "F1")
        by_phase[phase] = by_phase.get(phase, 0) + 1
        fp = f.get("file", "")
        if fp:
            file_counts[fp] = file_counts.get(fp, 0) + 1

    top_files = sorted(file_counts.items(), key=lambda x: -x[1])[:10]
    generated = datetime.datetime.now(tz=datetime.timezone.utc).isoformat()

    summary = {
        "run_id":         run_id,
        "generated":      generated,
        "total_findings": len(all_findings),
        "total_files":    f1_result.get("summary", {}).get("total_files", 0),
        "by_severity":    by_severity,
        "by_phase":       by_phase,
        "top_files":      [{"file": fp, "count": cnt} for fp, cnt in top_files],
        "elapsed_s":      round(time.monotonic() - t0, 3),
    }

    report_md = _render_markdown(plan, metrics, summary, backlog)

    result: dict[str, Any] = {
        "run_id":    run_id,
        "generated": generated,
        "findings":  all_findings,
        "plan":      plan,
        "backlog":   backlog,
        "metrics":   metrics,
        "summary":   summary,
        "report_md": report_md,
    }

    if store_dir:
        store_dir = Path(store_dir)
        store_dir.mkdir(parents=True, exist_ok=True)

        # Canonical artefact names (spec §7.3 F3)
        plan_json = {
            "run_id":    run_id,
            "generated": generated,
            "metrics":   metrics,
            "summary":   summary,
            "plan":      plan,
            "backlog":   {"count": len(backlog)},
        }
        (store_dir / "F3_plan.json").write_text(
            json.dumps(plan_json, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        (store_dir / "F3_plan.md").write_text(report_md, encoding="utf-8")

        # Full findings dump
        consolidated = {
            "run_id":   run_id,
            "summary":  summary,
            "findings": all_findings,
            "backlog":  backlog,
        }
        (store_dir / "consolidated.json").write_text(
            json.dumps(consolidated, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    return result
