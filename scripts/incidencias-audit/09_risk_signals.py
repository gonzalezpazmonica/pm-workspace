"""Risk signal evaluation — the 8 rules from SPEC-IA01 §1.3.

Each rule is independent and produces zero-or-one signal per incident.
An incident may fire multiple rules; the output `risk_signals` list contains
one entry per (incident × rule) pair.

Public API:
  - evaluate_incident(incident, *, now) → list[signal]
  - aggregate(incidents, *, now) → flat list of all signals, sorted
  - RULE_SEVERITY: dict[str, int]
  - RULE_RECOMMENDATION: dict[str, str]
"""
from __future__ import annotations

from datetime import date
from typing import Iterable

# Severity 1 = critical (top of MD), 3 = informational (bottom)
RULE_SEVERITY: dict[str, int] = {
    "CRITICAL_STALLED": 1,
    "NO_OWNER_HIGH_PRIO": 1,
    "BUGS_DONE_INCIDENT_OPEN": 2,
    "DISCARDED_NOT_CLOSED": 2,
    "WORKFLOW_REGRESSION": 2,
    "LONG_STALE_OPEN": 3,
    "NO_TRACTION_BUG": 3,
    "HIGH_PRIO_NO_SPRINT": 3,
}

RULE_RECOMMENDATION: dict[str, str] = {
    "CRITICAL_STALLED": "Escalar; reasignar; revisar prioridad",
    "NO_OWNER_HIGH_PRIO": "Asignar dueño antes del próximo daily",
    "BUGS_DONE_INCIDENT_OPEN": "Verificar con PoC y cerrar la incidencia",
    "DISCARDED_NOT_CLOSED": "Cerrar la incidencia o justificar por qué sigue abierta",
    "WORKFLOW_REGRESSION": "Revisar por qué se reabrió análisis",
    "LONG_STALE_OPEN": "Re-evaluar; ¿obsoleta?, ¿re-escalar?",
    "NO_TRACTION_BUG": "Verificar bloqueos en refinamiento",
    "HIGH_PRIO_NO_SPRINT": "Planificar en sprint próximo",
}

DEFAULT_STALLED_DAYS = 14
DEFAULT_LONG_STALE_DAYS = 90


def _parse_date(s: str | None) -> date | None:
    if not s:
        return None
    try:
        return date.fromisoformat(s[:10])
    except (TypeError, ValueError):
        return None


def _days_between(a: str | date | None, b: str | date | None) -> int | None:
    """Return (b - a) in days, or None if either is unparseable."""
    da = a if isinstance(a, date) else _parse_date(a)
    db = b if isinstance(b, date) else _parse_date(b)
    if da is None or db is None:
        return None
    return (db - da).days


def _is_in_sprint(iteration_path: str | None) -> bool:
    """A path is 'in sprint' if its trailing component starts with 'Sprint '."""
    if not iteration_path:
        return False
    parts = iteration_path.replace("\\", "/").split("/")
    last = parts[-1].strip() if parts else ""
    return last.lower().startswith("sprint ")


def _task_runner_id(incident: dict) -> str | None:
    """Resolve TaskRunner ID: prefer explicit field, fall back to first INC tag."""
    explicit = incident.get("task_runner_id") or incident.get("taskRunnerId")
    if explicit:
        return str(explicit)
    for tag in incident.get("tags", []) or []:
        t = tag.strip()
        if t.upper().startswith("INC") and t[3:].isdigit():
            return t
    return None


def _signal(incident: dict, rule_code: str, *, detail: str = "") -> dict:
    return {
        "incident_id": int(incident["id"]),
        "task_runner_id": _task_runner_id(incident),
        "rule_code": rule_code,
        "severity": RULE_SEVERITY[rule_code],
        "detail": detail,
        "recommendation": RULE_RECOMMENDATION[rule_code],
    }


# ───────────────────────── Rule implementations ─────────────────────────

def _rule_bugs_done_incident_open(incident: dict) -> dict | None:
    bugs = incident.get("bugs", []) or []
    if not bugs:
        return None
    if all((b.get("state") or "").casefold() == "done" for b in bugs):
        state = incident.get("state") or "?"
        return _signal(
            incident, "BUGS_DONE_INCIDENT_OPEN",
            detail=f"todos los BUGs asociados están `Done` pero la incidencia sigue `{state}`",
        )
    return None


def _rule_discarded_not_closed(incident: dict) -> dict | None:
    if incident.get("treatment_phase") != "Descartadas (task cerrado sin BUG)":
        return None
    state = incident.get("state") or "?"
    return _signal(
        incident, "DISCARDED_NOT_CLOSED",
        detail=f"marcada como descartada (Task `Done`, sin BUG) pero la incidencia sigue `{state}` — pendiente cierre",
    )


def _rule_critical_stalled(incident: dict, now: str, threshold_days: int) -> dict | None:
    if incident.get("priority") != 1:
        return None
    days = _days_between(incident.get("changedDate"), now)
    if days is None or days <= threshold_days:
        return None
    return _signal(
        incident, "CRITICAL_STALLED",
        detail=f"Critical sin movimiento en {days} días (último cambio {incident.get('changedDate')})",
    )


def _rule_no_owner_high_prio(incident: dict) -> dict | None:
    prio = incident.get("priority")
    if prio is None or prio > 2:
        return None
    if incident.get("assignedTo"):
        return None
    return _signal(
        incident, "NO_OWNER_HIGH_PRIO",
        detail=f"prioridad {prio} sin asignación",
    )


def _rule_long_stale_open(incident: dict, now: str, threshold_days: int) -> dict | None:
    days = _days_between(incident.get("createdDate"), now)
    if days is None or days <= threshold_days:
        return None
    return _signal(
        incident, "LONG_STALE_OPEN",
        detail=f"abierta desde hace {days} días",
    )


def _rule_no_traction_bug(incident: dict, now: str, threshold_days: int) -> dict | None:
    bugs = incident.get("bugs", []) or []
    for b in bugs:
        if (b.get("state") or "").casefold() != "new":
            continue
        days = _days_between(b.get("changedDate"), now)
        if days is not None and days > threshold_days:
            return _signal(
                incident, "NO_TRACTION_BUG",
                detail=f"BUG #{b.get('id')} en estado `New` desde hace {days} días",
            )
    return None


def _rule_workflow_regression(incident: dict) -> dict | None:
    history = incident.get("state_history") or []
    if len(history) < 2:
        return None
    order = {
        "Gathering requirements": 1,
        "Designing and Requesting solution": 2,
        "Implementing Solution": 3,
        "Responding and Requesting feedback": 4,
        "Done": 5,
    }
    prev_max = 0
    regressed = False
    for state in history:
        rank = order.get(state, 0)
        if rank and rank < prev_max:
            regressed = True
            break
        prev_max = max(prev_max, rank)
    if not regressed:
        return None
    return _signal(
        incident, "WORKFLOW_REGRESSION",
        detail="el estado retrocedió en el flujo (revisar histórico)",
    )


def _rule_high_prio_no_sprint(incident: dict) -> dict | None:
    prio = incident.get("priority")
    if prio is None or prio > 2:
        return None
    if _is_in_sprint(incident.get("iterationPath")):
        return None
    return _signal(
        incident, "HIGH_PRIO_NO_SPRINT",
        detail=f"prioridad {prio} sin sprint vigente (`{incident.get('iterationPath') or 'sin asignar'}`)",
    )


# ───────────────────────── public API ─────────────────────────

def evaluate_incident(
    incident: dict,
    *,
    now: str,
    stalled_days: int = DEFAULT_STALLED_DAYS,
    long_stale_days: int = DEFAULT_LONG_STALE_DAYS,
) -> list[dict]:
    """Evaluate the 8 rules against a single incident, return list of fired signals."""
    candidates = [
        _rule_bugs_done_incident_open(incident),
        _rule_discarded_not_closed(incident),
        _rule_critical_stalled(incident, now, stalled_days),
        _rule_no_owner_high_prio(incident),
        _rule_long_stale_open(incident, now, long_stale_days),
        _rule_no_traction_bug(incident, now, stalled_days),
        _rule_workflow_regression(incident),
        _rule_high_prio_no_sprint(incident),
    ]
    return [c for c in candidates if c is not None]


def aggregate(
    incidents: Iterable[dict],
    *,
    now: str,
    stalled_days: int = DEFAULT_STALLED_DAYS,
    long_stale_days: int = DEFAULT_LONG_STALE_DAYS,
) -> list[dict]:
    """Evaluate all incidents and return a flat sorted list of signals.

    Sort: (severity asc, incident_id asc, rule_code asc).
    Mutates each incident dict to add `risk_signals` = list of rule_codes.
    """
    out: list[dict] = []
    for inc in incidents:
        sigs = evaluate_incident(
            inc, now=now,
            stalled_days=stalled_days,
            long_stale_days=long_stale_days,
        )
        inc["risk_signals"] = [s["rule_code"] for s in sigs]
        out.extend(sigs)
    out.sort(key=lambda s: (s["severity"], s["incident_id"], s["rule_code"]))
    return out


__all__ = [
    "RULE_SEVERITY",
    "RULE_RECOMMENDATION",
    "DEFAULT_STALLED_DAYS",
    "DEFAULT_LONG_STALE_DAYS",
    "evaluate_incident",
    "aggregate",
]
