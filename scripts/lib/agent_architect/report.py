"""Report generation — markdown reports for human consumption.

Two report types:
- single: detail of one agent.
- aggregate: ranking + per-agent details for `--all`.
"""
from __future__ import annotations

from datetime import date
from typing import List

from .detector import AnalysisResult


_LEVEL_BADGE = {"info": "ℹ️", "warn": "⚠️", "alert": "🛑"}


def _render_signal_row(r: AnalysisResult, name: str) -> str:
    sig = next((s for s in r.signals if s.name == name), None)
    if sig is None:
        return "—"
    return f"{sig.value} {_LEVEL_BADGE.get(sig.level, '')}"


def render_aggregate(results: List[AnalysisResult]) -> str:
    today = date.today().isoformat()
    candidates = [r for r in results if r.is_candidate]
    lines = [f"# Agent Architect — Reporte {today}", ""]
    lines.append(f"**Total agentes analizados:** {len(results)}")
    lines.append(f"**Candidatos a descomposición (≥ 2 alerts):** {len(candidates)}")
    lines.append("")
    if candidates:
        lines.append("## Candidatos a descomposición")
        lines.append("")
        lines.append("| Agente | Líneas | Resp. | Tools | Contrad. | Roleplay | Edad |")
        lines.append("|---|---|---|---|---|---|---|")
        for r in candidates:
            lines.append(
                "| {id} | {ln} | {rs} | {tl} | {ct} | {rp} | {ag} |".format(
                    id=r.agent_id,
                    ln=_render_signal_row(r, "length"),
                    rs=_render_signal_row(r, "responsibilities"),
                    tl=_render_signal_row(r, "tools"),
                    ct=_render_signal_row(r, "contradictions"),
                    rp=_render_signal_row(r, "roleplay_depth"),
                    ag=_render_signal_row(r, "age_days"),
                )
            )
        lines.append("")
    lines.append("## Análisis individuales")
    lines.append("")
    for r in results:
        lines.append(render_single(r, header_level=3))
        lines.append("")
    return "\n".join(lines)


def render_single(r: AnalysisResult, header_level: int = 1) -> str:
    h = "#" * max(1, min(6, header_level))
    h2 = "#" * max(1, min(6, header_level + 1))
    lines = [f"{h} {r.agent_id}"]
    lines.append("")
    lines.append(f"- **Path:** `{r.path}`")
    lines.append(f"- **Alerts:** {r.alerts}  ·  **Warns:** {r.warns}  ·  **Candidato:** {'sí' if r.is_candidate else 'no'}")
    if r.parse_errors:
        lines.append(f"- **Parse errors:** {'; '.join(r.parse_errors)}")
    lines.append("")
    lines.append(f"{h2} Señales")
    lines.append("")
    for s in r.signals:
        badge = _LEVEL_BADGE.get(s.level, "")
        lines.append(f"- **{s.name}** {badge} `{s.level}` — value=`{s.value}` (warn={s.threshold_warn}, alert={s.threshold_alert})")
        for ev in s.evidence:
            lines.append(f"  - _{ev}_")
        if s.note:
            lines.append(f"  - note: {s.note}")
    return "\n".join(lines)
