"""
SPEC-154 — Función pura canónica V×U/E.
stdlib only. Same input ⇒ same output (AC-01).
"""
from __future__ import annotations
from dataclasses import dataclass, field


@dataclass
class PriorityEffort:
    tokens: int = 0
    human_review_hours: float = 1.0
    regression_risk: int = 1   # 1-5
    cognitive_complexity: int = 1  # 1-5


@dataclass
class PriorityInput:
    value: int          # 1-100
    urgency: int        # 1-100
    effort: PriorityEffort
    item_id: str = ""
    context: str = ""


@dataclass
class PriorityOutput:
    priority_score: float    # (value * urgency) / effort_normalized
    value: int
    urgency: int
    effort_normalized: int   # 1-100, composición ponderada 4 sub-factores
    decision_trail: str
    counterfactual: str


def normalize_effort(effort: PriorityEffort) -> int:
    """
    Pesos: human_review_hours 40%, regression_risk 30%,
           cognitive_complexity 20%, tokens 10%.
    Cada sub-factor normalizado a 1-100.
    """
    # tokens: 0-50 000 → 1-100  (cada 500 tokens = 1 punto)
    tokens_norm = min(100, max(1, effort.tokens // 500))
    # hours: 1 h → 12.5, 8 h → 100
    hrs_norm = min(100, max(1, int(effort.human_review_hours * 12.5)))
    # risk 1-5 → 20-100
    risk_norm = min(100, max(1, effort.regression_risk * 20))
    # complexity 1-5 → 20-100
    cog_norm = min(100, max(1, effort.cognitive_complexity * 20))
    result = int(0.4 * hrs_norm + 0.3 * risk_norm + 0.2 * cog_norm + 0.1 * tokens_norm)
    return min(100, max(1, result))


def score(item: PriorityInput) -> PriorityOutput:
    """
    Prioridad canónica V×U/E.

    Args:
        item.value:   1-100 (impacto absoluto, ver priority-canonical-formula.md)
        item.urgency: 1-100 (degradación temporal, NO ansiedad)
        item.effort:  PriorityEffort (4 sub-factores)

    Returns:
        PriorityOutput con priority_score, decision_trail y counterfactual.
        AC-07: nunca inventa campos. Si item_id/context están vacíos los omite.
    """
    en = normalize_effort(item.effort)
    raw = (item.value * item.urgency) / max(1, en)
    ps = round(raw, 1)

    parts = [f"V={item.value}/U={item.urgency}/E={en} → score={ps}"]
    if item.item_id:
        parts.insert(0, f"[{item.item_id}]")
    if item.context:
        parts.append(item.context)
    trail = ". ".join(parts)

    # Counterfactual: effort +20%
    en_up = max(1, int(en * 1.2))
    score_up = round((item.value * item.urgency) / max(1, en_up), 1)
    counterfactual = f"Si effort sube 20%: score={score_up}"

    return PriorityOutput(
        priority_score=ps,
        value=item.value,
        urgency=item.urgency,
        effort_normalized=en,
        decision_trail=trail,
        counterfactual=counterfactual,
    )
