#!/usr/bin/env python3
"""decision-trace-writer.py — SPEC-188 Phase 3 — Decision Trace Artifact (P5)

Writes a structured JSON decision trace artefact capturing the reasoning behind
an agent architectural or technical decision.

Usage:
    python3 scripts/decision-trace-writer.py \
        --agent sdd-spec-writer \
        --decision "Elegir PostgreSQL sobre SQLite" \
        --rationale "Necesitamos transacciones concurrentes y row-level locking" \
        --confidence 0.85 \
        --alternatives "SQLite (descartado: concurrencia), MongoDB (descartado: joins complejos)" \
        --output output/decision-traces/

Output JSON saved to output/decision-traces/{ts}-{agent}-{hash}.json:
    {
        "ts": "ISO-8601",
        "agent": "sdd-spec-writer",
        "decision": "Elegir PostgreSQL sobre SQLite",
        "rationale": "Necesitamos transacciones concurrentes y row-level locking",
        "confidence": 0.85,
        "alternatives": "SQLite (descartado: ...), MongoDB (descartado: ...)",
        "causal_chain": [],
        "spec_ref": ""
    }

Feature flag: SAVIA_DECISION_TRACE=on (default off) — when off, no file is written.

Ref: SPEC-188 P5 — docs/propuestas/SPEC-188-root-cause-investigation-architecture.md
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

DEFAULT_OUTPUT_DIR = Path("output/decision-traces")


def _feature_flag_enabled() -> bool:
    """Return True when SAVIA_DECISION_TRACE=on."""
    val = os.environ.get("SAVIA_DECISION_TRACE", "off").strip().lower()
    return val == "on"


def _make_hash(agent: str, decision: str, ts: str) -> str:
    """Short 8-char hash for filename uniqueness."""
    raw = f"{agent}:{decision}:{ts}"
    return hashlib.sha256(raw.encode()).hexdigest()[:8]


def _ts_filename_prefix(ts: str) -> str:
    """Convert ISO-8601 ts to safe filename prefix YYYYMMDDTHHMMSS."""
    return ts.replace(":", "").replace("-", "").replace(".", "")[:15]


def build_trace(
    agent: str,
    decision: str,
    rationale: str,
    confidence: float,
    alternatives: str,
    spec_ref: str = "",
    causal_chain: list | None = None,
) -> dict[str, Any]:
    """Build a decision trace dict."""
    ts = datetime.now(timezone.utc).isoformat()
    return {
        "ts": ts,
        "agent": agent,
        "decision": decision,
        "rationale": rationale,
        "confidence": round(float(confidence), 4),
        "alternatives": alternatives,
        "causal_chain": causal_chain if causal_chain is not None else [],
        "spec_ref": spec_ref,
    }


def write_trace(trace: dict[str, Any], output_dir: Path) -> Path:
    """Persist trace to JSON file; return the path written."""
    output_dir.mkdir(parents=True, exist_ok=True)
    ts_prefix = _ts_filename_prefix(trace["ts"])
    agent_slug = trace["agent"].replace("/", "-").replace(" ", "_")[:32]
    file_hash = _make_hash(trace["agent"], trace["decision"], trace["ts"])
    filename = f"{ts_prefix}-{agent_slug}-{file_hash}.json"
    out_path = output_dir / filename
    out_path.write_text(
        json.dumps(trace, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    return out_path


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(
        description="Write a decision trace artefact (SPEC-188 P5 Decision Trace)"
    )
    p.add_argument("--agent", required=True, help="Agent identifier making the decision")
    p.add_argument("--decision", required=True, help="Short description of the decision made")
    p.add_argument("--rationale", required=True, help="Why this decision was made")
    p.add_argument(
        "--confidence",
        type=float,
        default=0.5,
        help="Confidence in [0.0, 1.0] (default 0.5)",
    )
    p.add_argument(
        "--alternatives",
        default="",
        help="Discarded alternatives, free-text (e.g. 'SQLite (descartado: concurrencia)')",
    )
    p.add_argument(
        "--spec-ref",
        default="",
        dest="spec_ref",
        help="Optional spec reference (e.g. SPEC-188)",
    )
    p.add_argument(
        "--output",
        default=str(DEFAULT_OUTPUT_DIR),
        help=f"Output directory (default: {DEFAULT_OUTPUT_DIR})",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        default=False,
        help="Print trace JSON without writing to disk",
    )
    args = p.parse_args(argv)

    # Validate confidence range
    if not (0.0 <= args.confidence <= 1.0):
        print(
            f"ERROR: --confidence must be in [0.0, 1.0], got {args.confidence}",
            file=sys.stderr,
        )
        return 1

    trace = build_trace(
        agent=args.agent,
        decision=args.decision,
        rationale=args.rationale,
        confidence=args.confidence,
        alternatives=args.alternatives,
        spec_ref=args.spec_ref,
    )

    # Feature flag check — unless --dry-run forces output
    if not args.dry_run and not _feature_flag_enabled():
        # Silent skip: flag is off. Print status to stderr for diagnostics only.
        print(
            "SAVIA_DECISION_TRACE is off — trace not written (set SAVIA_DECISION_TRACE=on to enable)",
            file=sys.stderr,
        )
        # Still output the trace JSON to stdout for piping / testing
        print(json.dumps(trace, indent=2, ensure_ascii=False))
        return 0

    if args.dry_run:
        print(json.dumps(trace, indent=2, ensure_ascii=False))
        return 0

    out_dir = Path(args.output)
    out_path = write_trace(trace, out_dir)
    result = {"status": "written", "path": str(out_path), "trace": trace}
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
