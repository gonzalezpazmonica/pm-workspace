"""Tests for context_guard.store — SummaryStore.

Store contributes 4 test cases. All use tmp_path per Rule #26 / pytest convention.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest
import yaml

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts" / "lib"))

from context_guard.store import SummaryStore
from context_guard.summarizer import (
    SummarizationResult,
    SummaryV1,
    TimeSpan,
    ArtifactRef,
    ErrorRef,
    ToolInvocation,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_result(
    tier: str = "fast",
    retried: bool = False,
    tokens_before: int = 1000,
    tokens_after: int = 200,
) -> SummarizationResult:
    summary = SummaryV1(
        turn_count=5,
        time_span=TimeSpan(
            first_turn_at="2026-05-09T10:00:00Z",
            last_turn_at="2026-05-09T10:20:00Z",
        ),
        key_decisions=["Chose approach A"],
        artifacts_produced=[
            ArtifactRef(id="spec-1", kind="spec", location="docs/spec.md")
        ],
        errors_encountered=[],
        tools_invoked=[ToolInvocation(name="bash", count=3)],
        prose_summary="Covered design decisions and produced spec-1.",
    )
    return SummarizationResult(
        summary=summary,
        tier_used=tier,  # type: ignore[arg-type]
        retried=retried,
        tokens_before=tokens_before,
        tokens_after=tokens_after,
    )


# ---------------------------------------------------------------------------
# SummaryStore tests
# ---------------------------------------------------------------------------


class TestSummaryStore:
    def test_save_creates_yaml_file(self, tmp_path: Path) -> None:
        store = SummaryStore(base_dir=tmp_path)
        result = _make_result()
        path = store.save(run_id="run-001", result=result)

        assert path.exists()
        assert path.suffix == ".yaml"
        data = yaml.safe_load(path.read_text())
        assert "summary_v1" in data
        assert data["_meta"]["run_id"] == "run-001"
        assert data["_meta"]["tokens_before"] == 1000

    def test_write_trace_event_jsonl(self, tmp_path: Path) -> None:
        store = SummaryStore(base_dir=tmp_path)
        result = _make_result()
        summary_path = store.save(run_id="run-002", result=result)
        trace_path = store.write_trace_event(
            run_id="run-002", result=result, summary_path=summary_path
        )

        assert trace_path.exists()
        lines = trace_path.read_text().strip().splitlines()
        assert len(lines) == 1
        event = json.loads(lines[0])
        assert event["event"] == "context.summarized"
        assert event["run_id"] == "run-002"
        assert event["tokens_before"] == 1000
        assert event["summarizer_tier"] == "fast"

    def test_confidential_summaries_stored_under_N4_subdir(self, tmp_path: Path) -> None:
        store = SummaryStore(base_dir=tmp_path, confidentiality="N4")
        result = _make_result()
        path = store.save(run_id="secret-run", result=result)

        # Path must include N4 segment
        assert "N4" in path.parts
        assert path.exists()

    def test_load_returns_latest_summary(self, tmp_path: Path) -> None:
        store = SummaryStore(base_dir=tmp_path)
        result1 = _make_result(tokens_before=1000)
        result2 = _make_result(tokens_before=2000)

        store.save(run_id="run-multi", result=result1)
        store.save(run_id="run-multi", result=result2)

        data = store.load(run_id="run-multi")
        # Latest summary has tokens_before=2000
        assert data["_meta"]["tokens_before"] == 2000

    def test_invalid_run_id_raises(self, tmp_path: Path) -> None:
        store = SummaryStore(base_dir=tmp_path)
        result = _make_result()
        with pytest.raises(ValueError, match="Invalid run_id"):
            store.save(run_id="bad/run/id!", result=result)
