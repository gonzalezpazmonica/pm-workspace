"""
SPEC-154 Slice 3 — Adapter RICE → PriorityInput.

RICE: Reach × Impact × Confidence / Effort
Maps to V×U/E preserving relative ranking (AC-04: Spearman > 0.8).
stdlib only.
"""
from __future__ import annotations

import math
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from score import PriorityInput, PriorityEffort


def rice_to_vue(
    reach: int,
    impact: float,
    confidence: float,
    effort_weeks: float,
    item_id: str = "",
    context: str = "",
) -> PriorityInput:
    """
    Convert RICE inputs to PriorityInput.

    Args:
        reach:          Estimated users/items affected (e.g. 1000)
        impact:         Impact multiplier: 0.25 (minimal) | 0.5 (low) | 1 (medium) | 2 (high) | 3 (massive)
        confidence:     0.0-1.0 (how sure are we about estimates)
        effort_weeks:   Effort in person-weeks
        item_id:        Optional identifier
        context:        Optional context string

    Returns:
        PriorityInput compatible with score()

    AC-04: ranking correlation with native RICE > 0.8 Spearman.
    """
    if reach < 0:
        raise ValueError("reach must be >= 0")
    if not (0.0 <= confidence <= 1.0):
        raise ValueError("confidence must be in [0.0, 1.0]")
    if effort_weeks <= 0:
        raise ValueError("effort_weeks must be > 0")
    if impact < 0:
        raise ValueError("impact must be >= 0")

    # reach → value: log-normalize. reach=1 → ~1, reach=10000 → ~95
    if reach == 0:
        value = 1
    else:
        log_reach = math.log10(max(1, reach))
        # log10(1)=0 → 1, log10(10000)=4 → ~100
        value = max(1, min(100, int(log_reach * 25)))

    # impact (0.25-3) modulates value, confidence modulates further
    # impact=1 is neutral, impact=3 boosts by 50%, impact=0.25 reduces by 50%
    impact_factor = (impact / 1.0)  # normalize to neutral=1
    adjusted_value = int(value * impact_factor * confidence)
    adjusted_value = max(1, min(100, adjusted_value))

    # urgency: confidence modulates — high confidence means we can act now
    # Base urgency from impact
    urgency = max(1, min(100, int(impact * 30 * confidence)))

    # effort: weeks → human_review_hours (1 week ≈ 8h review)
    review_hours = effort_weeks * 8.0

    # regression_risk: larger effort → higher risk
    regression_risk = min(5, max(1, int(effort_weeks)))

    # cognitive_complexity: heuristic from effort+impact
    cog = min(5, max(1, int(effort_weeks * impact / 2)))

    effort = PriorityEffort(
        tokens=0,
        human_review_hours=review_hours,
        regression_risk=regression_risk,
        cognitive_complexity=cog,
    )

    ctx_parts = [f"RICE: reach={reach}/impact={impact}/confidence={confidence}/effort={effort_weeks}w"]
    if context:
        ctx_parts.append(context)

    return PriorityInput(
        value=adjusted_value,
        urgency=urgency,
        effort=effort,
        item_id=item_id,
        context=". ".join(ctx_parts),
    )
