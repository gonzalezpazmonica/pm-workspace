"""CLI entrypoint: `python3 -m agent_architect.cli ...`.

Modes:
  --agent <id|path>      analyze one agent
  --all                  analyze all agents under .opencode/agents/
  --threshold <level>    filter (info|warn|alert): only print agents with ≥ N at this level
  --json                 emit JSON instead of markdown
  --thresholds <path>    YAML override
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import List

from .detector import AnalysisResult, aggregate, analyze_path, load_thresholds
from .parser import discover_agents
from .report import render_aggregate, render_single


def _resolve_agent_path(spec: str, root: Path) -> Path:
    """Accept either an agent id (looked up in .opencode/agents/) or a direct path."""
    p = Path(spec)
    if p.exists():
        return p
    candidate = root / ".opencode" / "agents" / f"{spec}.md"
    if candidate.exists():
        return candidate
    raise FileNotFoundError(f"agent not found: {spec}")


def _filter_by_threshold(results: List[AnalysisResult], threshold: str) -> List[AnalysisResult]:
    if threshold == "alert":
        return [r for r in results if r.is_candidate]
    if threshold == "warn":
        return [r for r in results if r.warns + r.alerts >= 2]
    return results


def main(argv: List[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="agent-architect", description="Detect monolithic agents and propose decompositions.")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--agent", help="agent id or path to .md")
    g.add_argument("--all", action="store_true", help="analyze all agents under .opencode/agents/")
    ap.add_argument("--threshold", choices=("info", "warn", "alert"), default="info")
    ap.add_argument("--json", action="store_true", help="emit JSON instead of markdown")
    ap.add_argument("--thresholds", help="YAML override path")
    ap.add_argument("--root", default=".", help="repo root (default: cwd)")
    args = ap.parse_args(argv)

    root = Path(args.root).resolve()
    cfg = load_thresholds(Path(args.thresholds)) if args.thresholds else load_thresholds()

    if args.all:
        paths = discover_agents(root)
        results = [analyze_path(p, cfg) for p in paths]
        results = aggregate(results)
        results = _filter_by_threshold(results, args.threshold)
        if args.json:
            print(json.dumps([r.to_dict() for r in results], indent=2, ensure_ascii=False))
        else:
            print(render_aggregate(results))
        return 0

    # Single agent.
    try:
        path = _resolve_agent_path(args.agent, root)
    except FileNotFoundError as e:
        print(str(e), file=sys.stderr)
        return 2
    result = analyze_path(path, cfg)
    if args.json:
        print(json.dumps(result.to_dict(), indent=2, ensure_ascii=False))
    else:
        print(render_single(result, header_level=1))
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
