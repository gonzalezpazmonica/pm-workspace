#!/usr/bin/env python3
"""
scripts/agent-rca-analyzer.py -- SPEC-108 (light): Agent Root Cause Analysis

Analyzes an agent error and produces a structured RCA report without Sentry.
Builds on semantic-fault-handlers.py classification for root cause inference.

CLI:
    python3 scripts/agent-rca-analyzer.py \
        --error "timeout after 30s calling auth API" \
        --context "dotnet-developer agent"

Output JSON:
    {root_cause, category, fix_suggestion, confidence, rca_layer}
"""
from __future__ import annotations
import argparse, json, sys
from pathlib import Path

ROOT = Path(__file__).parent.parent

def _load_fault_handlers():
    """Import semantic-fault-handlers inline to avoid module-cache conflicts."""
    script = ROOT / "scripts" / "semantic-fault-handlers.py"
    if not script.exists():
        return None
    try:
        import importlib.util as _ilu
        spec = _ilu.spec_from_file_location("_sfh_rca", script)
        mod = _ilu.module_from_spec(spec)
        # Register with unique name to avoid dataclass __module__ conflicts
        sys.modules.setdefault("_sfh_rca", mod)
        spec.loader.exec_module(sys.modules["_sfh_rca"])
        return sys.modules["_sfh_rca"]
    except Exception:
        return None

_RCA_RULES: dict[str, tuple[str, str, str]] = {
    "LOGIC": (
        "Agent produced incorrect output - logic or algorithm error in the implementation.",
        "Trigger spec re-review: verify acceptance criteria match implementation. "
        "Use /court-orchestrator to run Code Review Court.",
        "SPEC_REVIEW",
    ),
    "CAPACITY": (
        "Agent exceeded context window or token budget.",
        "Prune context: remove redundant loaded files, compact conversation history. "
        "Use context-optimized-dev skill or split via task-decomposer.py.",
        "CONTEXT_PRUNING",
    ),
    "SCOPE": (
        "Agent modified files outside the allowed scope boundary.",
        "Decompose task into atomic subtasks using task-decomposer.py. "
        "Ensure each subtask touches at most 3 files.",
        "TASK_DECOMPOSITION",
    ),
    "FORMAT": (
        "Agent produced malformed output - schema or JSON structure error.",
        "Add explicit output format examples to the agent prompt. "
        "Use trace-prompt-optimizer.py to audit for no_output_format issues.",
        "PROMPT_FIX",
    ),
    "VALIDATION": (
        "Agent completed but output failed acceptance criteria or tests.",
        "Review failing ACs. Re-run with test context injected. "
        "Use test-runner agent with full test output as context.",
        "AC_REVIEW",
    ),
    "TRANSIENT": (
        "Transient infrastructure error - network timeout, rate limit, or service unavailable.",
        "Retry with exponential backoff. Check API health and quota if recurring.",
        "RETRY",
    ),
}

_UNKNOWN_RCA = (
    "Unable to determine root cause from error text alone.",
    "Provide more context. Check agent logs and escalate to tech-lead if unresolved.",
    "ESCALATE",
)


def analyze(error: str, context: str = "") -> dict:
    sfh = _load_fault_handlers()

    if sfh is not None:
        try:
            classification = sfh.classify(error, context)
            category = classification.category
            base_confidence = classification.confidence
        except Exception:
            sfh = None

    if sfh is None:
        err_lower = (error + " " + context).lower()
        if any(k in err_lower for k in ("timeout", "rate limit", "unavailable", "503", "429")):
            category, base_confidence = "TRANSIENT", 0.85
        elif any(k in err_lower for k in ("context window", "token", "context exceeded")):
            category, base_confidence = "CAPACITY", 0.85
        elif any(k in err_lower for k in ("scope", "outside", "modified", "files instead")):
            category, base_confidence = "SCOPE", 0.80
        elif any(k in err_lower for k in ("ac-", "acceptance criteria", "test fail", "tests fail")):
            category, base_confidence = "VALIDATION", 0.80
        elif any(k in err_lower for k in ("json", "format", "parse", "schema", "malformed")):
            category, base_confidence = "FORMAT", 0.80
        else:
            category, base_confidence = "LOGIC", 0.50

    root_cause_tmpl, fix_suggestion, rca_layer = _RCA_RULES.get(category, _UNKNOWN_RCA)
    error_excerpt = error[:120].strip()
    root_cause = f"{root_cause_tmpl} Signal: \"{error_excerpt}\""
    confidence = round(base_confidence * (1.0 if context else 0.85), 4)

    return {
        "root_cause": root_cause,
        "category": category,
        "fix_suggestion": fix_suggestion,
        "confidence": confidence,
        "rca_layer": rca_layer,
    }


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="agent-rca-analyzer.py",
                                description="SPEC-108: Agent Root Cause Analysis")
    p.add_argument("--error", required=True, metavar="TEXT")
    p.add_argument("--context", default="", metavar="TEXT")
    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    result = analyze(args.error, args.context)
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
