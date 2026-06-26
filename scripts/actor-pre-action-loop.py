#!/usr/bin/env python3
"""actor-pre-action-loop.py — SPEC-168: Actor iterative pre-action inner loop.

Uses the world-model-simulator (SPEC-165) to evaluate proposed actions before
execution. Iterates up to --max-iterations times, refining the action if
confidence is below the threshold.

Usage:
  python3 scripts/actor-pre-action-loop.py \
      --action "descripción acción" \
      --context "contexto actual" \
      --max-iterations 3 \
      --confidence-threshold 0.7

Output JSON:
  {
    "approved_action": str,
    "final_confidence": float,
    "iterations": int,
    "simulation_history": [{"action": str, "confidence": float, "outcome": str}],
    "verdict": "approved" | "best_effort" | "blocked"
  }

Master switch: SAVIA_ACTOR_PRE_ACTION=on|off (default off)
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SIMULATOR_PATH = REPO_ROOT / "scripts" / "world-model-simulator.py"

# ── Load world-model-simulator ────────────────────────────────────────────────

def _load_simulator():
    """Dynamically load world-model-simulator module."""
    spec = importlib.util.spec_from_file_location("world_model_simulator", SIMULATOR_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ── Action refinement ─────────────────────────────────────────────────────────

def _refine_action(action: str, context: str, outcome: str) -> str:
    """Generate a refined action based on the world model's likely outcome.

    Strategy: prepend safety/caution signals based on the outcome description
    to steer the action toward a safer variant.
    """
    action_lower = action.lower()
    outcome_lower = outcome.lower()

    refinements = []

    if any(kw in outcome_lower for kw in ("rejection", "hook", "fail", "block")):
        refinements.append("validate hooks before")
    if any(kw in outcome_lower for kw in ("warning", "lint", "minor")):
        refinements.append("fix lint issues then")
    if any(kw in outcome_lower for kw in ("partial", "skip", "skipped")):
        refinements.append("ensure complete")
    if any(kw in outcome_lower for kw in ("ref", "import", "depend", "downstream")):
        refinements.append("update dependents after")
    if any(kw in outcome_lower for kw in ("rollback", "disruption", "fails")):
        refinements.append("add rollback plan for")

    if refinements:
        prefix = ", ".join(refinements)
        return f"{prefix}: {action}"

    # Generic fallback: add a safe-context qualifier
    return f"carefully {action} (refined from: {action[:50]})"


# ── Core loop ─────────────────────────────────────────────────────────────────

def run_pre_action_loop(
    action: str,
    context: str,
    max_iterations: int,
    confidence_threshold: float,
    simulator_mod,
) -> dict:
    """Execute the iterative pre-action inner loop.

    Returns the result dict with approved_action, final_confidence, iterations,
    simulation_history, and verdict.
    """
    history = []
    best_action = action
    best_confidence = 0.0
    current_action = action

    for i in range(1, max_iterations + 1):
        simulation = simulator_mod.simulate(current_action, context)
        confidence = simulation["simulation_confidence"]

        # Extract the "likely" outcome description for refinement hints
        likely_outcome = ""
        for outcome in simulation.get("outcomes", []):
            if outcome.get("scenario") == "likely":
                likely_outcome = outcome.get("description", "")
                break

        history.append({
            "action": current_action,
            "confidence": confidence,
            "outcome": likely_outcome,
        })

        if confidence > best_confidence:
            best_confidence = confidence
            best_action = current_action

        if confidence >= confidence_threshold:
            # Approved on this iteration
            return {
                "approved_action": current_action,
                "final_confidence": confidence,
                "iterations": i,
                "simulation_history": history,
                "verdict": "approved",
            }

        # Below threshold — refine unless we are on the last iteration
        if i < max_iterations:
            current_action = _refine_action(current_action, context, likely_outcome)

    # Exhausted iterations — return best found
    verdict = "best_effort" if best_confidence > 0.0 else "blocked"
    return {
        "approved_action": best_action,
        "final_confidence": best_confidence,
        "iterations": max_iterations,
        "simulation_history": history,
        "verdict": verdict,
    }


# ── Bypass (master switch off) ────────────────────────────────────────────────

def _bypass_result(action: str) -> dict:
    """Return immediately without simulation when the master switch is off."""
    return {
        "approved_action": action,
        "final_confidence": 1.0,
        "iterations": 0,
        "simulation_history": [],
        "verdict": "approved",
    }


# ── CLI ───────────────────────────────────────────────────────────────────────

def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="SPEC-168 actor iterative pre-action loop"
    )
    p.add_argument("--action", required=True, help="Proposed action description")
    p.add_argument("--context", default="", help="Current context")
    p.add_argument(
        "--max-iterations", type=int, default=3,
        help="Maximum refinement iterations (default 3)"
    )
    p.add_argument(
        "--confidence-threshold", type=float, default=0.7,
        help="Minimum confidence to approve action (default 0.7)"
    )
    p.add_argument("--quiet", action="store_true", help="Suppress stderr diagnostics")
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)

    master_switch = os.environ.get("SAVIA_ACTOR_PRE_ACTION", "off").lower()
    if master_switch != "on":
        result = _bypass_result(args.action)
        print(json.dumps(result, indent=2))
        return 0

    if not SIMULATOR_PATH.exists():
        print(
            json.dumps({
                "error": f"world-model-simulator.py not found at {SIMULATOR_PATH}",
                "approved_action": args.action,
                "final_confidence": 0.0,
                "iterations": 0,
                "simulation_history": [],
                "verdict": "blocked",
            }, indent=2)
        )
        return 1

    simulator_mod = _load_simulator()
    result = run_pre_action_loop(
        action=args.action,
        context=args.context,
        max_iterations=args.max_iterations,
        confidence_threshold=args.confidence_threshold,
        simulator_mod=simulator_mod,
    )

    print(json.dumps(result, indent=2))
    if not args.quiet:
        print(
            f"verdict={result['verdict']} "
            f"iterations={result['iterations']} "
            f"confidence={result['final_confidence']}",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
