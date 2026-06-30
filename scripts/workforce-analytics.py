"""scripts/workforce-analytics.py — SPEC-SE-025 Agentic Workforce Analytics

Calculates agent workforce metrics from existing data sources.

Input:  data_dir (default: output/)
Output: {agent_invocations, avg_durations, success_rates, summary}

Sources:
  - output/agent-trace/*.jsonl   (agent trace logs)
  - data/agent-actuals.jsonl     (predicted vs actual agent hours)
  - output/**/.review.crc        (Court verdicts per PR)

Used by workforce-analytics.sh via python3.
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path


def _load_jsonl(path: Path) -> list[dict]:
    """Read a JSONL file; skip malformed lines silently."""
    records: list[dict] = []
    if not path.exists():
        return records
    with path.open(encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except json.JSONDecodeError:
                pass
    return records


def _load_trace_logs(data_dir: Path) -> list[dict]:
    traces: list[dict] = []
    trace_dir = data_dir / "agent-trace"
    if trace_dir.is_dir():
        for f in sorted(trace_dir.glob("*.jsonl")):
            traces.extend(_load_jsonl(f))
    return traces


def _load_actuals(repo_root: Path) -> list[dict]:
    return _load_jsonl(repo_root / "data" / "agent-actuals.jsonl")


def _load_crc_files(repo_root: Path) -> list[dict]:
    results: list[dict] = []
    output_dir = repo_root / "output"
    if not output_dir.is_dir():
        return results
    for crc in output_dir.rglob("*.review.crc"):
        try:
            results.append(json.loads(crc.read_text(encoding="utf-8")))
        except (json.JSONDecodeError, OSError):
            pass
    return results


def _parse_ts(ts: str | None) -> datetime | None:
    if not ts:
        return None
    for fmt in (
        "%Y-%m-%dT%H:%M:%SZ",
        "%Y-%m-%dT%H:%M:%S",
        "%Y-%m-%dT%H:%M:%S.%fZ",
        "%Y-%m-%d",
    ):
        try:
            dt = datetime.strptime(ts, fmt)
            return dt.replace(tzinfo=timezone.utc)
        except ValueError:
            continue
    return None


def _since_filter(records: list[dict], since: str | None, ts_key: str) -> list[dict]:
    if not since:
        return records
    cutoff = _parse_ts(since)
    if cutoff is None:
        return records
    filtered = []
    for r in records:
        ts = _parse_ts(r.get(ts_key, ""))
        if ts is None or ts >= cutoff:
            filtered.append(r)
    return filtered


def compute_metrics(
    data_dir: Path,
    repo_root: Path | None = None,
    since: str | None = None,
) -> dict:
    """Return workforce metrics dict.

    Fields:
        agent_invocations   dict[agent_name, int]
        avg_durations       dict[agent_name, float]   minutes
        success_rates       dict[agent_name, float]   0.0-1.0
        most_active_hours   dict[agent_name, int]     0-23
        top_agents          list[str]                 max 5 by invocations
        review_court        dict  with pass_rate, total_prs
        summary             dict  with totals
    """
    if repo_root is None:
        repo_root = data_dir.parent if data_dir.name == "output" else data_dir

    traces = _load_trace_logs(data_dir)
    actuals = _load_actuals(repo_root)

    all_runs: list[dict] = []
    for r in actuals:
        if r.get("schema_version") == "2" or "agent" in r:
            all_runs.append(r)
    for t in traces:
        if "agent" in t:
            all_runs.append(t)

    all_runs = _since_filter(all_runs, since, "started_at")

    invocations: dict[str, int] = {}
    durations_sum: dict[str, float] = {}
    durations_cnt: dict[str, int] = {}
    success_cnt: dict[str, int] = {}
    total_cnt: dict[str, int] = {}
    hour_counts: dict[str, dict[int, int]] = {}

    for run in all_runs:
        agent = run.get("agent", "").strip()
        if not agent:
            continue
        invocations[agent] = invocations.get(agent, 0) + 1

        dur_s: float | None = None
        if "duration_s" in run:
            try:
                dur_s = float(run["duration_s"])
            except (ValueError, TypeError):
                pass
        if dur_s is None:
            t_start = _parse_ts(run.get("started_at"))
            t_end = _parse_ts(run.get("finished_at"))
            if t_start and t_end:
                dur_s = max(0.0, (t_end - t_start).total_seconds())

        if dur_s is not None and dur_s >= 0:
            durations_sum[agent] = durations_sum.get(agent, 0.0) + dur_s
            durations_cnt[agent] = durations_cnt.get(agent, 0) + 1

        status = run.get("run_status", "")
        total_cnt[agent] = total_cnt.get(agent, 0) + 1
        if status == "completed":
            success_cnt[agent] = success_cnt.get(agent, 0) + 1

        ts = _parse_ts(run.get("started_at"))
        if ts:
            h = ts.hour
            if agent not in hour_counts:
                hour_counts[agent] = {}
            hour_counts[agent][h] = hour_counts[agent].get(h, 0) + 1

    avg_durations: dict[str, float] = {}
    for agent, s in durations_sum.items():
        cnt = durations_cnt.get(agent, 1)
        avg_durations[agent] = max(0.0, s / cnt / 60.0)

    success_rates: dict[str, float] = {}
    for agent in total_cnt:
        n = total_cnt[agent]
        s_count = success_cnt.get(agent, 0)
        success_rates[agent] = s_count / n if n > 0 else 0.0

    most_active_hours: dict[str, int] = {}
    for agent, hmap in hour_counts.items():
        most_active_hours[agent] = max(hmap, key=hmap.__getitem__)

    top_agents = sorted(invocations, key=invocations.__getitem__, reverse=True)[:5]

    crc_records = _load_crc_files(repo_root)
    crc_pass = sum(1 for r in crc_records if r.get("verdict", "").lower() in ("pass", "approved"))
    crc_total = len(crc_records)
    court_pass_rate = crc_pass / crc_total if crc_total > 0 else None

    summary = {
        "total_invocations": sum(invocations.values()),
        "total_agents": len(invocations),
        "total_run_hours": sum(durations_sum.values()) / 3600.0,
        "since": since,
        "computed_at": datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }

    return {
        "agent_invocations": invocations,
        "avg_durations": avg_durations,
        "success_rates": success_rates,
        "most_active_hours": most_active_hours,
        "top_agents": top_agents,
        "review_court": {
            "pass_rate": court_pass_rate,
            "total_prs": crc_total,
        },
        "summary": summary,
    }


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        description="Workforce analytics metrics calculator (SE-025)"
    )
    parser.add_argument("--data-dir", default="output")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--since", default=None)
    args = parser.parse_args(argv)

    data_dir = Path(args.data_dir).resolve()
    repo_root = Path(args.repo_root).resolve()

    metrics = compute_metrics(data_dir, repo_root, since=args.since)
    print(json.dumps(metrics, indent=2))


if __name__ == "__main__":
    main()
