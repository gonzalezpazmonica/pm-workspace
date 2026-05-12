"""Tests for context_guard.cli — Slice 2.

Covers:
  - recall command: happy path, not found, 403, explicit summary-id
  - list command: empty, with summaries
  - summarize command: threshold not crossed, force triggers

Rule #26: Python for structured test logic.
"""

from __future__ import annotations

import asyncio
import json
import sys
from pathlib import Path
from typing import Any
from unittest.mock import patch

import pytest
import yaml


# ---------------------------------------------------------------------------
# Helpers to populate the store
# ---------------------------------------------------------------------------


async def _write_summary(
    base_dir: Path,
    run_id: str,
    confidentiality: str = "N1",
) -> str:
    from scripts.lib.context_guard.mcp_server import _handle_summarize

    turns = [
        {"role": "user", "content": "hello world " * 10, "is_artifact": False},
        {"role": "assistant", "content": "response content " * 10, "is_artifact": False},
    ]
    results = await _handle_summarize(
        {
            "turns": turns,
            "run_id": run_id,
            "force": True,
            "confidentiality": confidentiality,
            "caller_confidentiality": confidentiality,
        },
        base_dir,
    )
    data = json.loads(results[0].text)
    assert data["triggered"] is True
    return data["summary_id"]


def _run(base_dir: Path, *args: str, expect_rc: int = 0) -> str:
    """Invoke CLI and return stdout, asserting exit code."""
    from scripts.lib.context_guard.cli import build_parser, cmd_recall, cmd_list, cmd_summarize
    import io

    parser = build_parser()
    argv = ["--base-dir", str(base_dir), *args]
    parsed = parser.parse_args(argv)
    captured = io.StringIO()
    with patch("sys.stdout", captured):
        rc = parsed.func(parsed)
    assert rc == expect_rc, f"Expected rc={expect_rc}, got {rc}. stdout={captured.getvalue()!r}"
    return captured.getvalue()


# ---------------------------------------------------------------------------
# Tests: cli recall
# ---------------------------------------------------------------------------


class TestCliRecall:
    def test_recall_latest(self, tmp_path: Path) -> None:
        asyncio.run(_write_summary(tmp_path, "cli-recall-01"))
        out = _run(tmp_path, "recall", "cli-recall-01")
        data = yaml.safe_load(out)
        assert "summary_v1" in data
        assert "_meta" in data

    def test_recall_not_found_returns_rc1(self, tmp_path: Path) -> None:
        _run(tmp_path, "recall", "no-such-run", expect_rc=1)

    def test_recall_explicit_summary_id(self, tmp_path: Path) -> None:
        sid = asyncio.run(_write_summary(tmp_path, "cli-recall-sid"))
        out = _run(tmp_path, "recall", "cli-recall-sid", "--summary-id", sid)
        data = yaml.safe_load(out)
        assert data["_meta"]["index"] == 1

    def test_recall_n3_from_n1_returns_rc1(self, tmp_path: Path) -> None:
        asyncio.run(_write_summary(tmp_path, "cli-n3-run", confidentiality="N3"))
        _run(
            tmp_path,
            "recall", "cli-n3-run",
            "--caller-level", "N1",
            expect_rc=1,
        )


# ---------------------------------------------------------------------------
# Tests: cli list
# ---------------------------------------------------------------------------


class TestCliList:
    def test_list_empty(self, tmp_path: Path) -> None:
        out = _run(tmp_path, "list", "no-summaries-here")
        data = json.loads(out)
        assert data["summaries"] == []

    def test_list_with_summaries(self, tmp_path: Path) -> None:
        asyncio.run(_write_summary(tmp_path, "cli-list-run"))
        asyncio.run(_write_summary(tmp_path, "cli-list-run"))
        out = _run(tmp_path, "list", "cli-list-run")
        data = json.loads(out)
        assert len(data["summaries"]) == 2
