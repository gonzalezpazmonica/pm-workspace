#!/usr/bin/env python3
"""cognitive-debt-monitor.py — SPEC-107 Phase 1 measurement tool.

Calculates a cognitive-load-score (0-100) from observable proxies:
  - session_hours > 4        → +30 (MIT crossover threshold)
  - verification_rate < 0.5  → +25 (MS/CMU skip-verification pattern)
  - tasks_completed > 15/h   → +20 (velocity anomaly without verification)
  - hour_of_day > 20         → +15 (nocturnal work, higher fatigue)

Privacy: CD-03. No external telemetry. No team/manager exposure.
Reference: SPEC-107, MIT arXiv 2506.08872, MS-CMU CHI 2025.
"""

import argparse
import datetime
import json
import sys
from dataclasses import dataclass, field
from typing import Literal

RiskLevel = Literal["low", "medium", "high", "critical"]


@dataclass
class CognitiveLoadResult:
    cognitive_load_score: int
    risk_level: RiskLevel
    recommendations: list[str]
    breakdown: dict[str, int] = field(default_factory=dict)


def compute_score(
    session_hours: float,
    verification_rate: float,
    tasks_completed: int,
    hour_of_day: int,
) -> CognitiveLoadResult:
    """Compute cognitive-load score from observable proxies.

    Each contributor is capped at its stated weight; total capped at 100.
    """
    score = 0
    breakdown: dict[str, int] = {}

    # Contributor 1 — long session (MIT crossover at 4h)
    if session_hours > 4:
        contribution = 30
        score += contribution
        breakdown["long_session"] = contribution

    # Contributor 2 — low verification rate (MS/CMU: users skip under pressure)
    if verification_rate < 0.5:
        contribution = 25
        score += contribution
        breakdown["low_verification"] = contribution

    # Contributor 3 — anomalous velocity (tasks/h > 15 without verification)
    if session_hours > 0:
        tasks_per_hour = tasks_completed / session_hours
    else:
        tasks_per_hour = 0.0

    if tasks_per_hour > 15 and verification_rate < 0.5:
        contribution = 20
        score += contribution
        breakdown["velocity_anomaly"] = contribution

    # Contributor 4 — nocturnal work (fatigue amplifier)
    if hour_of_day > 20:
        contribution = 15
        score += contribution
        breakdown["nocturnal"] = contribution

    score = min(score, 100)

    risk_level = _risk_level(score)
    recommendations = _recommendations(score, session_hours, verification_rate, tasks_per_hour, hour_of_day)

    return CognitiveLoadResult(
        cognitive_load_score=score,
        risk_level=risk_level,
        recommendations=recommendations,
        breakdown=breakdown,
    )


def _risk_level(score: int) -> RiskLevel:
    if score >= 76:
        return "critical"
    if score >= 51:
        return "high"
    if score >= 26:
        return "medium"
    return "low"


def _recommendations(
    score: int,
    session_hours: float,
    verification_rate: float,
    tasks_per_hour: float,
    hour_of_day: int,
) -> list[str]:
    recs: list[str] = []

    if score == 0:
        return recs

    if session_hours > 4:
        recs.append(
            "Sesión activa >4h. Toma un descanso de 15min antes de continuar (MIT crossover threshold)."
        )
    if verification_rate < 0.5:
        recs.append(
            "Verification rate baja (<50%). Revisa los últimos outputs antes de aceptarlos — "
            "MS/CMU: el skip de verificación bajo presión es el principal predictor de cognitive debt."
        )
    if tasks_per_hour > 15 and verification_rate < 0.5:
        recs.append(
            f"Velocidad anómala ({tasks_per_hour:.1f} tareas/h) combinada con baja verificación. "
            "Ralentiza y valida un output antes de continuar al siguiente."
        )
    if hour_of_day > 20:
        recs.append(
            "Trabajo nocturno detectado. La fatiga amplifica el cognitive debt. "
            "Considera posponer tareas críticas a mañana."
        )
    if score >= 51:
        recs.append(
            "Score elevado. Activa double-checking explícito: antes de cada aceptación, "
            "articula en voz alta por qué el output es correcto (teach-back — SPEC-107 I2)."
        )
    if score >= 76:
        recs.append(
            "Score CRÍTICO. Revisión humana obligatoria del trabajo de esta sesión antes de merge. "
            "Programa una sesión de 20min sin IA para retrieval activo (Karpicke 2006)."
        )

    return recs


def format_report(result: CognitiveLoadResult, session_hours: float, verification_rate: float) -> str:
    lines = [
        "═══════════════════════════════════════════",
        "  COGNITIVE LOAD MONITOR — SPEC-107",
        "═══════════════════════════════════════════",
        f"  Score:        {result.cognitive_load_score}/100",
        f"  Risk level:   {result.risk_level.upper()}",
        "───────────────────────────────────────────",
    ]

    if result.breakdown:
        lines.append("  Contribuidores activos:")
        labels = {
            "long_session": f"  • Sesión larga (>{4}h)         +30",
            "low_verification": "  • Verificación baja (<50%)      +25",
            "velocity_anomaly": "  • Velocidad anómala (>15/h)     +20",
            "nocturnal": "  • Trabajo nocturno (>20h)       +15",
        }
        for key in result.breakdown:
            lines.append(labels.get(key, f"  • {key}"))
    else:
        lines.append("  Sin contribuidores activos.")

    if result.recommendations:
        lines.append("───────────────────────────────────────────")
        lines.append("  Recomendaciones:")
        for rec in result.recommendations:
            # wrap at 60 chars
            words = rec.split()
            line = "  • "
            for word in words:
                if len(line) + len(word) + 1 > 63:
                    lines.append(line.rstrip())
                    line = "    "
                line += word + " "
            lines.append(line.rstrip())

    lines.append("═══════════════════════════════════════════")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Cognitive load monitor — SPEC-107 Phase 1 measurement.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--session-hours", type=float, default=0.0, metavar="N",
                        help="Active session duration in hours (default: 0)")
    parser.add_argument("--tasks-completed", type=int, default=0, metavar="N",
                        help="Number of tasks completed in this session (default: 0)")
    parser.add_argument("--verification-rate", type=float, default=1.0, metavar="0.0-1.0",
                        help="Fraction of AI outputs explicitly verified (default: 1.0)")
    parser.add_argument("--hour-of-day", type=int, default=None, metavar="0-23",
                        help="Current hour (0-23). Defaults to system hour.")
    parser.add_argument("--json", action="store_true",
                        help="Output JSON instead of formatted report")
    parser.add_argument("--report", action="store_true",
                        help="Output formatted text report (default when --json not set)")

    args = parser.parse_args()

    # Validate inputs
    if not (0.0 <= args.verification_rate <= 1.0):
        print("ERROR: --verification-rate must be between 0.0 and 1.0", file=sys.stderr)
        sys.exit(1)

    hour = args.hour_of_day if args.hour_of_day is not None else datetime.datetime.now().hour

    result = compute_score(
        session_hours=args.session_hours,
        verification_rate=args.verification_rate,
        tasks_completed=args.tasks_completed,
        hour_of_day=hour,
    )

    if args.json:
        output = {
            "cognitive_load_score": result.cognitive_load_score,
            "risk_level": result.risk_level,
            "recommendations": result.recommendations,
            "breakdown": result.breakdown,
        }
        print(json.dumps(output, ensure_ascii=False, indent=2))
    else:
        print(format_report(result, args.session_hours, args.verification_rate))


if __name__ == "__main__":
    main()
