"""Context Guard — Store module.

Persists summaries to output/context-guard/{run_id}/summary-{N}.yaml
and writes context.summarized events to the JSONL trace.

Spec §2.4: output/context-guard/{run_id}/summary-{N}.yaml
Spec §2.2: evento context.summarized en traza JSONL.
Spec §2.8: confidencialidad — summary hereda nivel N del flow/agente.
Rule #26: Python for structured logic.
"""

from __future__ import annotations

import json
import logging
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Literal

import yaml

from scripts.lib.context_guard.summarizer import SummarizationResult, SummaryV1

logger = logging.getLogger(__name__)

CONFIDENTIALITY_LEVEL = Literal["N1", "N2", "N3", "N4", "N4b"]

_VALID_RUN_ID = re.compile(r"^[a-zA-Z0-9_\-]{1,128}$")


def _validate_run_id(run_id: str) -> None:
    if not _VALID_RUN_ID.match(run_id):
        raise ValueError(
            f"Invalid run_id '{run_id}'. Must match [a-zA-Z0-9_-]{{1,128}}."
        )


class SummaryStore:
    """Persists context guard summaries and trace events.

    Directory layout (Spec §2.4)::

        output/context-guard/{run_id}/summary-001.yaml
        output/context-guard/{run_id}/summary-002.yaml
        output/context-guard/{run_id}/trace.jsonl

    Confidentiality (Spec §2.8):
        When ``confidentiality`` is "N4" or "N4b", summaries are stored under::

            output/context-guard/N4/{run_id}/...

        so that existing data-sovereignty hooks protect them automatically.

    Args:
        base_dir: Root directory for all context-guard output.
            Defaults to ``<repo_root>/output/context-guard``.
        confidentiality: Inherited from the originating agent/flow.
    """

    _SENSITIVE_LEVELS = {"N4", "N4b"}

    def __init__(
        self,
        base_dir: Path,
        confidentiality: CONFIDENTIALITY_LEVEL = "N1",
    ) -> None:
        self._base_dir = base_dir
        self._confidentiality = confidentiality

    def _run_dir(self, run_id: str) -> Path:
        _validate_run_id(run_id)
        if self._confidentiality in self._SENSITIVE_LEVELS:
            return self._base_dir / self._confidentiality / run_id
        return self._base_dir / run_id

    def _next_summary_index(self, run_dir: Path) -> int:
        """Return 1-based index for the next summary file."""
        existing = sorted(run_dir.glob("summary-*.yaml"))
        return len(existing) + 1

    def _summary_path(self, run_dir: Path, index: int) -> Path:
        return run_dir / f"summary-{index:03d}.yaml"

    def save(
        self,
        run_id: str,
        result: SummarizationResult,
    ) -> Path:
        """Persist a summarization result to disk.

        Creates the run directory if it doesn't exist.

        Returns the path to the written YAML file.
        """
        run_dir = self._run_dir(run_id)
        run_dir.mkdir(parents=True, exist_ok=True)

        index = self._next_summary_index(run_dir)
        summary_path = self._summary_path(run_dir, index)

        payload = {
            "summary_v1": result.summary.model_dump(),
            "_meta": {
                "run_id": run_id,
                "index": index,
                "tier_used": result.tier_used,
                "retried": result.retried,
                "tokens_before": result.tokens_before,
                "tokens_after": result.tokens_after,
                "confidentiality": self._confidentiality,
                "saved_at": _utcnow_iso(),
            },
        }

        summary_path.write_text(yaml.dump(payload, allow_unicode=True), encoding="utf-8")
        logger.info(
            "SummaryStore: saved summary-%03d for run_id='%s' at %s.",
            index,
            run_id,
            summary_path,
        )
        return summary_path

    def write_trace_event(
        self,
        run_id: str,
        result: SummarizationResult,
        summary_path: Path,
    ) -> Path:
        """Append a context.summarized event to the JSONL trace.

        Spec §2.2: evento context.summarized con tokens_before, tokens_after,
        summarizer_tier, summary_id.

        Returns the path to the trace file.
        """
        run_dir = self._run_dir(run_id)
        run_dir.mkdir(parents=True, exist_ok=True)
        trace_path = run_dir / "trace.jsonl"

        summary_id = summary_path.stem  # e.g. "summary-001"

        event = {
            "event": "context.summarized",
            "run_id": run_id,
            "summary_id": summary_id,
            "tokens_before": result.tokens_before,
            "tokens_after": result.tokens_after,
            "summarizer_tier": result.tier_used,
            "retried": result.retried,
            "confidentiality": self._confidentiality,
            "ts": _utcnow_iso(),
        }

        with trace_path.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(event, ensure_ascii=False) + "\n")

        logger.info(
            "SummaryStore: trace event context.summarized written for run_id='%s'.",
            run_id,
        )
        return trace_path

    def load(self, run_id: str, summary_id: str | None = None) -> dict:
        """Load a summary by run_id and optional summary_id.

        If summary_id is None, loads the latest summary.

        Spec §2.5: recall_summary(run_id, summary_id?) → SummaryV1.
        """
        run_dir = self._run_dir(run_id)
        if not run_dir.exists():
            raise FileNotFoundError(
                f"No context-guard data for run_id='{run_id}' at {run_dir}."
            )

        if summary_id is None:
            files = sorted(run_dir.glob("summary-*.yaml"))
            if not files:
                raise FileNotFoundError(
                    f"No summaries found for run_id='{run_id}'."
                )
            target = files[-1]
        else:
            target = run_dir / f"{summary_id}.yaml"
            if not target.exists():
                raise FileNotFoundError(
                    f"Summary '{summary_id}' not found for run_id='{run_id}'."
                )

        data = yaml.safe_load(target.read_text(encoding="utf-8"))
        return data

    def list_summaries(self, run_id: str) -> list[str]:
        """Return sorted list of summary_ids for a run."""
        run_dir = self._run_dir(run_id)
        if not run_dir.exists():
            return []
        return sorted(p.stem for p in run_dir.glob("summary-*.yaml"))


def _utcnow_iso() -> str:
    return datetime.now(tz=timezone.utc).isoformat(timespec="seconds")
