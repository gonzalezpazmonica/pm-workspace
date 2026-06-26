"""
SPEC-154 Slice 3 — Adapter ad-hoc text → PriorityInput.

Accepts high/medium/low/critical + S/M/L/XL effort.
confidence < 1.0 always (these are heuristic approximations).
stdlib only.
"""
from __future__ import annotations

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from score import PriorityInput, PriorityEffort

# Confidence levels for ad-hoc mapping
ADHOC_CONFIDENCE = 0.65  # AC: adhoc_to_vue has confidence < 1.0

PRIORITY_TABLE = {
    "critical": {"value": 90, "urgency": 95},
    "high":     {"value": 75, "urgency": 70},
    "medium":   {"value": 55, "urgency": 45},
    "low":      {"value": 35, "urgency": 25},
}

EFFORT_TABLE = {
    "xs": {"human_review_hours": 0.5, "regression_risk": 1, "cognitive_complexity": 1},
    "s":  {"human_review_hours": 2.0, "regression_risk": 1, "cognitive_complexity": 2},
    "m":  {"human_review_hours": 8.0, "regression_risk": 2, "cognitive_complexity": 3},
    "l":  {"human_review_hours": 24.0, "regression_risk": 3, "cognitive_complexity": 4},
    "xl": {"human_review_hours": 40.0, "regression_risk": 4, "cognitive_complexity": 5},
}


def adhoc_to_vue(
    priority: str,
    effort: str,
    item_id: str = "",
    context: str = "",
) -> PriorityInput:
    """
    Convert ad-hoc priority+effort labels to PriorityInput.

    Args:
        priority:  "critical" | "high" | "medium" | "low"
        effort:    "xs" | "s" | "m" | "l" | "xl"
        item_id:   Optional identifier
        context:   Optional context string

    Returns:
        PriorityInput with confidence < 1.0 (heuristic approximation).
        Caller should treat the output as indicative, not definitive.

    Warning: if priority or effort are unrecognized, raises ValueError.
    """
    p_key = priority.strip().lower()
    e_key = effort.strip().lower()

    if p_key not in PRIORITY_TABLE:
        raise ValueError(
            f"Unknown priority '{priority}'. Valid: {list(PRIORITY_TABLE.keys())}"
        )
    if e_key not in EFFORT_TABLE:
        raise ValueError(
            f"Unknown effort '{effort}'. Valid: {list(EFFORT_TABLE.keys())}"
        )

    p_vals = PRIORITY_TABLE[p_key]
    e_vals = EFFORT_TABLE[e_key]

    # Apply confidence dampening (AC: confidence < 1.0)
    value = max(1, int(p_vals["value"] * ADHOC_CONFIDENCE))
    urgency = max(1, int(p_vals["urgency"] * ADHOC_CONFIDENCE))

    effort_obj = PriorityEffort(
        tokens=0,
        human_review_hours=e_vals["human_review_hours"],
        regression_risk=e_vals["regression_risk"],
        cognitive_complexity=e_vals["cognitive_complexity"],
    )

    ctx_parts = [
        f"adhoc: priority={priority}/effort={effort}/confidence={ADHOC_CONFIDENCE}",
        "WARNING: heuristic mapping. Refine with V/U/E direct input when possible.",
    ]
    if context:
        ctx_parts.append(context)

    return PriorityInput(
        value=value,
        urgency=urgency,
        effort=effort_obj,
        item_id=item_id,
        context=" ".join(ctx_parts),
    )
