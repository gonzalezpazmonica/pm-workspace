"""Context Guard — CLI entry point.

Provides sub-commands:
  recall   <run_id> [--summary-id ID] [--caller-level N1|N2|N3|N4|N4b]
  list     <run_id>
  summarize <run_id> --turns-file <path.json> [options]

Rule #26: Python for structured logic; scripts/context-guard-recall.sh is the Bash wrapper.
Spec §2.5: recall_summary(run_id, summary_id?) → SummaryV1.
"""

from __future__ import annotations

import argparse
import json
import logging
import sys
from pathlib import Path
from typing import Any

import yaml


def _resolve_base_dir() -> Path:
    """Resolve the output/context-guard directory relative to this file's location."""
    _here = Path(__file__).resolve()
    _workspace = _here.parents[3]  # scripts/lib/context_guard → workspace root
    return _workspace / "output" / "context-guard"


def _confidentiality_index(level: str) -> int:
    _order = ["N1", "N2", "N3", "N4", "N4b"]
    try:
        return _order.index(level)
    except ValueError:
        return 0


def _check_access(caller_level: str, resource_level: str) -> None:
    if _confidentiality_index(caller_level) < _confidentiality_index(resource_level):
        raise PermissionError(
            f"403 Forbidden: caller={caller_level!r} cannot access "
            f"resource={resource_level!r}. Spec §2.8."
        )


# ---------------------------------------------------------------------------
# Sub-command: recall
# ---------------------------------------------------------------------------


def cmd_recall(args: argparse.Namespace) -> int:
    from scripts.lib.context_guard.store import SummaryStore

    base_dir: Path = args.base_dir or _resolve_base_dir()
    run_id: str = args.run_id
    summary_id: str | None = args.summary_id or None
    caller_level: str = args.caller_level

    # Search across confidentiality dirs (most restricted first)
    _levels = ["N4b", "N4", "N3", "N2", "N1"]
    data: dict[str, Any] | None = None
    found_level: str = "N1"

    for lvl in _levels:
        store = SummaryStore(base_dir=base_dir, confidentiality=lvl)  # type: ignore[arg-type]
        try:
            data = store.load(run_id=run_id, summary_id=summary_id)
            found_level = lvl
            break
        except FileNotFoundError:
            continue

    if data is None:
        print(
            json.dumps({"error": f"No summaries found for run_id={run_id!r}"}),
            file=sys.stderr,
        )
        return 1

    resource_level = data.get("_meta", {}).get("confidentiality", found_level)
    try:
        _check_access(caller_level, resource_level)
    except PermissionError as exc:
        print(json.dumps({"error": str(exc)}), file=sys.stderr)
        return 1

    print(yaml.dump(data, allow_unicode=True))
    return 0


# ---------------------------------------------------------------------------
# Sub-command: list
# ---------------------------------------------------------------------------


def cmd_list(args: argparse.Namespace) -> int:
    from scripts.lib.context_guard.store import SummaryStore

    base_dir: Path = args.base_dir or _resolve_base_dir()
    run_id: str = args.run_id

    summaries: list[str] = []
    for lvl in ["N4b", "N4", "N3", "N2", "N1"]:
        store = SummaryStore(base_dir=base_dir, confidentiality=lvl)  # type: ignore[arg-type]
        found = store.list_summaries(run_id=run_id)
        summaries.extend(found)

    if not summaries:
        print(json.dumps({"run_id": run_id, "summaries": []}))
        return 0

    print(json.dumps({"run_id": run_id, "summaries": sorted(set(summaries))}))
    return 0


# ---------------------------------------------------------------------------
# Sub-command: summarize
# ---------------------------------------------------------------------------


def cmd_summarize(args: argparse.Namespace) -> int:
    from scripts.lib.context_guard.monitor import ContextGuardConfig, ContextMonitor, TurnMessage
    from scripts.lib.context_guard.store import SummaryStore
    from scripts.lib.context_guard.summarizer import Summarizer, SummarizationError
    from scripts.lib.context_guard.tokenizer import TierTokenizer
    from scripts.lib.context_guard.mcp_server import _build_mock_invoke_fn  # noqa: PLC2701

    base_dir: Path = args.base_dir or _resolve_base_dir()
    run_id: str = args.run_id
    tier: str = args.tier
    confidentiality: str = args.confidentiality
    threshold_pct: int = args.threshold_pct
    recent_turns: int = args.recent_turns
    force: bool = args.force

    # Load turns from JSON file
    turns_file = Path(args.turns_file)
    if not turns_file.exists():
        print(
            json.dumps({"error": f"turns_file not found: {turns_file}"}),
            file=sys.stderr,
        )
        return 1

    raw: list[dict[str, Any]] = json.loads(turns_file.read_text(encoding="utf-8"))
    turns = [
        TurnMessage(
            role=str(t.get("role", "user")),
            content=str(t.get("content", "")),
            timestamp=t.get("timestamp"),
            is_artifact=bool(t.get("is_artifact", False)),
        )
        for t in raw
    ]

    config = ContextGuardConfig(
        enabled=True,
        threshold_pct=max(50, threshold_pct),
        recent_turns=recent_turns,
    )
    tokenizer = TierTokenizer(tier=tier)  # type: ignore[arg-type]
    monitor = ContextMonitor(config=config, tokenizer=tokenizer, tier=tier)  # type: ignore[arg-type]

    if force:
        turns_to_summarize = turns[: max(0, len(turns) - recent_turns)]
        if not turns_to_summarize:
            turns_to_summarize = turns
    else:
        decision = monitor.check(turns)
        if not decision.should_summarize:
            print(
                json.dumps(
                    {
                        "triggered": False,
                        "pct_used": round(decision.pct_used, 2),
                        "threshold_pct": threshold_pct,
                    }
                )
            )
            return 0
        turns_to_summarize = decision.turns_to_summarize

    turns_text = "\n".join(f"[{t.role}] {t.content}" for t in turns_to_summarize)
    tokens_before = sum(tokenizer.count(t.content) for t in turns_to_summarize)

    invoke_fn = _build_mock_invoke_fn(tier)
    summarizer = Summarizer(invoke_fn=invoke_fn, initial_tier=tier)  # type: ignore[arg-type]

    try:
        result = summarizer.summarize(turns_text=turns_text, tokens_before=tokens_before)
    except SummarizationError as exc:
        print(json.dumps({"error": str(exc)}), file=sys.stderr)
        return 1

    store = SummaryStore(base_dir=base_dir, confidentiality=confidentiality)  # type: ignore[arg-type]
    summary_path = store.save(run_id=run_id, result=result)
    store.write_trace_event(run_id=run_id, result=result, summary_path=summary_path)

    print(
        json.dumps(
            {
                "triggered": True,
                "summary_id": summary_path.stem,
                "run_id": run_id,
                "tokens_before": result.tokens_before,
                "tokens_after": result.tokens_after,
                "tier_used": result.tier_used,
                "confidentiality": confidentiality,
            }
        )
    )
    return 0


# ---------------------------------------------------------------------------
# Argument parser
# ---------------------------------------------------------------------------


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="context_guard",
        description="Context Guard — context window management for Savia agents.",
    )
    parser.add_argument(
        "--base-dir",
        type=Path,
        default=None,
        metavar="DIR",
        help="Override output/context-guard base directory.",
    )

    sub = parser.add_subparsers(dest="command", required=True)

    # --- recall ---
    p_recall = sub.add_parser("recall", help="Retrieve a stored summary.")
    p_recall.add_argument("run_id", help="Run identifier.")
    p_recall.add_argument("--summary-id", default=None, help="Specific summary id (e.g. summary-001).")
    p_recall.add_argument(
        "--caller-level",
        default="N1",
        choices=["N1", "N2", "N3", "N4", "N4b"],
        help="Confidentiality level of the caller (default: N1).",
    )
    p_recall.set_defaults(func=cmd_recall)

    # --- list ---
    p_list = sub.add_parser("list", help="List all summary ids for a run.")
    p_list.add_argument("run_id", help="Run identifier.")
    p_list.set_defaults(func=cmd_list)

    # --- summarize ---
    p_sum = sub.add_parser("summarize", help="Summarize turns from a JSON file.")
    p_sum.add_argument("run_id", help="Run identifier.")
    p_sum.add_argument("--turns-file", required=True, metavar="FILE", help="JSON file with turns array.")
    p_sum.add_argument("--tier", default="fast", choices=["heavy", "mid", "fast"])
    p_sum.add_argument(
        "--confidentiality",
        default="N1",
        choices=["N1", "N2", "N3", "N4", "N4b"],
        help="Confidentiality level of the summary.",
    )
    p_sum.add_argument("--threshold-pct", type=int, default=75, metavar="PCT")
    p_sum.add_argument("--recent-turns", type=int, default=5, metavar="N")
    p_sum.add_argument(
        "--force",
        action="store_true",
        help="Force summarization even if threshold not crossed.",
    )
    p_sum.set_defaults(func=cmd_summarize)

    return parser


def main() -> None:
    logging.basicConfig(level=logging.WARNING, stream=sys.stderr)
    parser = build_parser()
    args = parser.parse_args()
    sys.exit(args.func(args))


if __name__ == "__main__":
    main()
