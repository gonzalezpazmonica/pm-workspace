"""
SPEC-154 Slice 3 — Adapter WSJF → PriorityInput.

WSJF (Weighted Shortest Job First):
  CoD = business_value + time_criticality + risk_reduction
  WSJF = CoD / job_size
Maps to V×U/E. stdlib only.
"""
from __future__ import annotations

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from score import PriorityInput, PriorityEffort


def wsjf_to_vue(
    business_value: int,
    time_criticality: int,
    risk_reduction: int,
    job_size: int,
    item_id: str = "",
    context: str = "",
) -> PriorityInput:
    """
    Convert WSJF inputs to PriorityInput.

    Args:
        business_value:    1-100 (economic benefit or business impact)
        time_criticality:  1-100 (cost of delay due to time sensitivity)
        risk_reduction:    1-100 (value of risk/opportunity enablement)
        job_size:          1-100 (relative effort/size, normalized)
        item_id:           Optional identifier
        context:           Optional context

    Returns:
        PriorityInput compatible with score()

    WSJF semantics → V×U/E:
        CoD (Cost of Delay) = business_value + time_criticality + risk_reduction
        value   = business_value + risk_reduction (impact component of CoD), capped 1-100
        urgency = time_criticality (temporal decay component), capped 1-100
        effort  = job_size → PriorityEffort
    """
    for name, val in [("business_value", business_value), ("time_criticality", time_criticality),
                       ("risk_reduction", risk_reduction), ("job_size", job_size)]:
        if not (1 <= val <= 100):
            raise ValueError(f"{name} must be in [1, 100], got {val}")

    # CoD components map to value and urgency
    # value = weighted average of business_value (60%) and risk_reduction (40%)
    value = max(1, min(100, int(business_value * 0.6 + risk_reduction * 0.4)))
    urgency = max(1, min(100, time_criticality))

    # job_size 1-100 → effort components
    # 1-20 → XS effort, 21-40 → S, 41-60 → M, 61-80 → L, 81-100 → XL
    review_hours = job_size / 100 * 40.0  # max 40h review
    regression_risk = max(1, min(5, job_size // 20 + 1))
    cog = max(1, min(5, job_size // 20 + 1))

    effort = PriorityEffort(
        tokens=0,
        human_review_hours=review_hours,
        regression_risk=regression_risk,
        cognitive_complexity=cog,
    )

    ctx_parts = [
        f"WSJF: bv={business_value}/tc={time_criticality}/rr={risk_reduction}/size={job_size}"
    ]
    if context:
        ctx_parts.append(context)

    return PriorityInput(
        value=value,
        urgency=urgency,
        effort=effort,
        item_id=item_id,
        context=". ".join(ctx_parts),
    )
