"""Tests for context_guard.mcp_server — Slice 2.

Covers:
  - summarize() tool: threshold not crossed, threshold crossed, forced
  - recall_summary() tool: happy path, not found, 403 from N3 summary via N1 caller
  - E2E flow: 15-node simulation without context overflow (mock tokenizer, threshold=1 forced)

Rule #26: Python for structured test logic.
Spec §2.5, §2.8, §4 Slice 2 AC.
"""

from __future__ import annotations

import asyncio
import json
from pathlib import Path
from typing import Any

import pytest

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_turns(n: int, words_per_turn: int = 10) -> list[dict[str, Any]]:
    """Generate n synthetic turns with ~words_per_turn words each."""
    return [
        {
            "role": "user" if i % 2 == 0 else "assistant",
            "content": " ".join(["word"] * words_per_turn),
            "timestamp": f"2026-05-09T10:{i:02d}:00Z",
            "is_artifact": False,
        }
        for i in range(n)
    ]


async def _call_tool(
    base_dir: Path,
    tool_name: str,
    arguments: dict[str, Any],
) -> list[Any]:
    """Helper: build server and call a tool, returning the result list."""
    from scripts.lib.context_guard.mcp_server import build_server

    server = build_server(base_dir=base_dir)

    # Locate the call_tool handler registered on the server
    handler = server._tool_handlers.get("call_tool") or server.call_tool  # type: ignore[attr-defined]
    # mcp Server stores handlers differently; use the registered call directly
    result = await server._tool_call_handler(tool_name, arguments)  # type: ignore[attr-defined]
    return result


async def _direct_summarize(
    base_dir: Path,
    arguments: dict[str, Any],
) -> dict[str, Any]:
    """Call _handle_summarize directly (bypasses MCP wire protocol)."""
    from scripts.lib.context_guard.mcp_server import _handle_summarize  # noqa: PLC2701

    results = await _handle_summarize(arguments, base_dir)
    assert results, "Expected at least one ToolResultContent"
    return json.loads(results[0].text)


async def _direct_recall(
    base_dir: Path,
    arguments: dict[str, Any],
) -> dict[str, Any]:
    from scripts.lib.context_guard.mcp_server import _handle_recall_summary  # noqa: PLC2701

    results = await _handle_recall_summary(arguments, base_dir)
    assert results, "Expected at least one ToolResultContent"
    return json.loads(results[0].text)


# ---------------------------------------------------------------------------
# Tests: summarize()
# ---------------------------------------------------------------------------


class TestMcpSummarize:
    def test_summarize_threshold_not_crossed(self, tmp_path: Path) -> None:
        """When threshold is not crossed and force=False, returns triggered=False."""

        async def run() -> None:
            turns = _make_turns(3, words_per_turn=5)  # very small context
            result = await _direct_summarize(
                tmp_path,
                {
                    "turns": turns,
                    "run_id": "test-not-crossed",
                    "threshold_pct": 95,  # very high threshold
                    "recent_turns": 2,
                    "tier": "fast",
                    "confidentiality": "N1",
                    "force": False,
                },
            )
            assert result["triggered"] is False
            assert "pct_used" in result
            assert result["threshold_pct"] == 95

        asyncio.run(run())

    def test_summarize_force_triggers_always(self, tmp_path: Path) -> None:
        """force=True must trigger summarization regardless of threshold."""

        async def run() -> None:
            turns = _make_turns(6, words_per_turn=5)
            result = await _direct_summarize(
                tmp_path,
                {
                    "turns": turns,
                    "run_id": "test-force",
                    "threshold_pct": 95,
                    "recent_turns": 2,
                    "tier": "fast",
                    "confidentiality": "N1",
                    "force": True,
                },
            )
            assert result["triggered"] is True
            assert "summary_id" in result
            assert result["run_id"] == "test-force"
            assert result["tokens_before"] >= 0
            assert result["tokens_after"] >= 1

        asyncio.run(run())

    def test_summarize_persists_to_disk(self, tmp_path: Path) -> None:
        """After forced summarize, a YAML file must exist on disk."""

        async def run() -> None:
            turns = _make_turns(8, words_per_turn=10)
            result = await _direct_summarize(
                tmp_path,
                {
                    "turns": turns,
                    "run_id": "test-persist",
                    "force": True,
                    "confidentiality": "N1",
                },
            )
            assert result["triggered"] is True
            summary_path = tmp_path / "test-persist" / f"{result['summary_id']}.yaml"
            assert summary_path.exists(), f"Expected summary file at {summary_path}"

        asyncio.run(run())

    def test_summarize_writes_trace_event(self, tmp_path: Path) -> None:
        """After summarization, trace.jsonl must contain a context.summarized event."""

        async def run() -> None:
            turns = _make_turns(6, words_per_turn=10)
            await _direct_summarize(
                tmp_path,
                {
                    "turns": turns,
                    "run_id": "test-trace",
                    "force": True,
                    "confidentiality": "N1",
                },
            )
            trace = tmp_path / "test-trace" / "trace.jsonl"
            assert trace.exists()
            events = [json.loads(line) for line in trace.read_text().splitlines()]
            assert any(e["event"] == "context.summarized" for e in events)

        asyncio.run(run())

    def test_summarize_missing_run_id_returns_error(self, tmp_path: Path) -> None:
        """Missing run_id must return an error dict."""

        async def run() -> None:
            turns = _make_turns(4)
            result = await _direct_summarize(
                tmp_path,
                {"turns": turns},  # no run_id
            )
            assert "error" in result

        asyncio.run(run())

    def test_summarize_confidentiality_caller_below_resource_denied(
        self, tmp_path: Path
    ) -> None:
        """N1 caller cannot create summary marked N3 — access denied."""

        async def run() -> None:
            turns = _make_turns(5)
            result = await _direct_summarize(
                tmp_path,
                {
                    "turns": turns,
                    "run_id": "test-403-create",
                    "force": True,
                    "confidentiality": "N3",          # resource level
                    "caller_confidentiality": "N1",   # caller below resource
                },
            )
            assert "error" in result
            assert "403" in result["error"]

        asyncio.run(run())


# ---------------------------------------------------------------------------
# Tests: recall_summary()
# ---------------------------------------------------------------------------


class TestMcpRecallSummary:
    async def _setup_summary_async(
        self, tmp_path: Path, run_id: str, confidentiality: str = "N1"
    ) -> str:
        """Create a real summary file and return its summary_id (async)."""
        turns = _make_turns(6)
        result = await _direct_summarize(
            tmp_path,
            {
                "turns": turns,
                "run_id": run_id,
                "force": True,
                "confidentiality": confidentiality,
                "caller_confidentiality": confidentiality,
            },
        )
        assert result["triggered"] is True
        return result["summary_id"]

    def test_recall_latest_summary(self, tmp_path: Path) -> None:
        """recall_summary returns the latest summary when no summary_id given."""

        async def run() -> None:
            await self._setup_summary_async(tmp_path, "recall-run-01")
            result = await _direct_recall(
                tmp_path,
                {"run_id": "recall-run-01", "caller_confidentiality": "N1"},
            )
            assert "summary_v1" in result
            assert "_meta" in result

        asyncio.run(run())

    def test_recall_specific_summary_id(self, tmp_path: Path) -> None:
        """recall_summary with explicit summary_id returns that summary."""

        async def run() -> None:
            sid = await self._setup_summary_async(tmp_path, "recall-run-02")
            result = await _direct_recall(
                tmp_path,
                {
                    "run_id": "recall-run-02",
                    "summary_id": sid,
                    "caller_confidentiality": "N1",
                },
            )
            assert "_meta" in result
            assert result["_meta"]["index"] == 1

        asyncio.run(run())

    def test_recall_not_found_returns_error(self, tmp_path: Path) -> None:
        """Non-existent run_id returns an error dict."""

        async def run() -> None:
            result = await _direct_recall(
                tmp_path,
                {"run_id": "does-not-exist", "caller_confidentiality": "N1"},
            )
            assert "error" in result

        asyncio.run(run())

    def test_recall_n3_summary_from_n1_caller_returns_403(self, tmp_path: Path) -> None:
        """Summary with confidentiality=N3 MUST NOT be accessible from N1 context.

        Spec §2.8: summary de flow N3 NO accesible desde N1.
        Canonical confidentiality AC from Slice 2.
        """

        async def run() -> None:
            await self._setup_summary_async(tmp_path, "n3-run", confidentiality="N3")
            result = await _direct_recall(
                tmp_path,
                {"run_id": "n3-run", "caller_confidentiality": "N1"},
            )
            assert "error" in result
            assert "403" in result["error"], f"Expected 403 Forbidden, got: {result}"

        asyncio.run(run())

    def test_recall_n3_summary_from_n3_caller_succeeds(self, tmp_path: Path) -> None:
        """N3 caller CAN access N3 summary — same level is allowed."""

        async def run() -> None:
            await self._setup_summary_async(tmp_path, "n3-allowed-run", confidentiality="N3")
            result = await _direct_recall(
                tmp_path,
                {"run_id": "n3-allowed-run", "caller_confidentiality": "N3"},
            )
            assert "summary_v1" in result

        asyncio.run(run())

    def test_recall_missing_run_id_returns_error(self, tmp_path: Path) -> None:
        """Missing run_id argument returns an error dict."""

        async def run() -> None:
            result = await _direct_recall(tmp_path, {})
            assert "error" in result

        asyncio.run(run())


# ---------------------------------------------------------------------------
# E2E: 15-node flow simulation without context overflow
# ---------------------------------------------------------------------------


class TestE2EFlowSimulation:
    """
    Spec §4 Slice 2 AC: flow de 15 nodos con outputs voluminosos NO choca
    con context limit.

    Uses forced summarization (force=True) to trigger on every checkpoint,
    simulating what would happen with threshold_pct=1 (immediate trigger).
    Each 'node' adds a voluminous turn (200 words). After 5 nodes we trigger
    a summarization checkpoint; final accumulated context stays small.
    """

    def test_15_node_flow_no_overflow(self, tmp_path: Path) -> None:
        """15-node flow with periodic summarization stays within simulated budget."""

        async def run() -> None:
            NODES = 15
            WORDS_PER_NODE = 200
            CHECKPOINT_EVERY = 5  # summarize every 5 nodes

            accumulated_turns: list[dict[str, Any]] = []
            summary_count = 0

            for node_idx in range(NODES):
                # Simulate node output as a voluminous turn
                accumulated_turns.append(
                    {
                        "role": "assistant",
                        "content": " ".join(["token"] * WORDS_PER_NODE),
                        "timestamp": f"2026-05-09T{node_idx:02d}:00:00Z",
                        "is_artifact": False,
                    }
                )

                # Checkpoint: summarize and compact
                if (node_idx + 1) % CHECKPOINT_EVERY == 0:
                    result = await _direct_summarize(
                        tmp_path,
                        {
                            "turns": accumulated_turns,
                            "run_id": "e2e-15-node-flow",
                            "force": True,
                            "confidentiality": "N1",
                            "recent_turns": 2,
                        },
                    )
                    assert result["triggered"] is True, (
                        f"Expected summarization at node {node_idx}"
                    )
                    summary_count += 1

                    # Compact: keep only recent 2 turns + a lightweight summary placeholder
                    summary_placeholder = {
                        "role": "system",
                        "content": (
                            f"[Summary {result['summary_id']}] "
                            f"tokens_before={result['tokens_before']} "
                            f"tokens_after={result['tokens_after']}"
                        ),
                        "is_artifact": False,
                    }
                    accumulated_turns = [summary_placeholder] + accumulated_turns[-2:]

            # Verify: 3 checkpoints fired for 15 nodes at every 5
            assert summary_count == NODES // CHECKPOINT_EVERY == 3, (
                f"Expected 3 summaries, got {summary_count}"
            )

            # Verify: accumulated context is compact (placeholder + 2 recent per checkpoint)
            # After 3 compactions we have: 3 placeholders + up to 2 recent turns = small
            assert len(accumulated_turns) <= 10, (
                f"Context should be compact after summarization, got {len(accumulated_turns)} turns"
            )

            # Verify: all summaries are on disk
            from scripts.lib.context_guard.store import SummaryStore

            store = SummaryStore(base_dir=tmp_path, confidentiality="N1")
            stored = store.list_summaries("e2e-15-node-flow")
            assert len(stored) == 3, f"Expected 3 stored summaries, got {stored}"

        asyncio.run(run())
