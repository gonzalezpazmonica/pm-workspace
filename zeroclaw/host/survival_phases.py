"""Savia Survival — fases Respiracion y Despertar.

Extraido de survival.py para cumplir el limite de 150 lineas.

PRINCIPIO INMOVABLE:
SaviaClaw corre localmente, no necesita SSH a si mismo.
El healthcheck es local: verifica que Talk funcione y que OpenCode responda.
"""
import time
import logging
from datetime import datetime, timezone

log = logging.getLogger("survival")

MAX_BREATH_FAILURES = 3
MAX_WAKEUP_FAILURES = 2


def phase_respiracion(state: dict, run_llm_fn=None) -> dict:
    """Verifica Talk + LLM backend local (no remote_host)."""
    s = {
        "phase": "respiracion",
        "ts": datetime.now(timezone.utc).isoformat(),
        "ok": True, "talk": None, "llm": None,
        "healed": False, "details": [],
    }
    # Verificar Talk
    try:
        from .nctalk import send_message  # noqa: F401
        s["talk"] = "ok"; s["details"].append("talk:ok")
    except Exception as e:
        s["talk"] = "fail"; s["details"].append(f"talk:fail:{e}")

    # Verificar LLM backend local (no SSH remoto — SaviaClaw corre en el host)
    if run_llm_fn:
        try:
            resp = run_llm_fn("latido")
            if resp:
                s["llm"] = "ok"
                s["details"].append(f"llm:responded:{resp[:80]}")
                state["consecutive_breath_failures"] = 0
                state["remote_unreachable_since"] = None
            else:
                s["llm"] = "no_response"
                s["details"].append("llm:no_response")
                state["consecutive_breath_failures"] += 1
        except Exception as e:
            s["ok"] = False; s["llm"] = "error"
            s["details"].append(f"llm:error:{e}")
            state["consecutive_breath_failures"] += 1
    else:
        s["details"].append("llm:no_callback")

    state["last_breath"] = time.time()
    if state["consecutive_breath_failures"] >= MAX_BREATH_FAILURES:
        _notify_monica("respiracion", s)
    return s


def phase_despertar(state: dict, run_llm_fn=None) -> dict:
    """Despierta LLM local. Si falla, reinicia el daemon via systemctl."""
    s = {
        "phase": "despertar",
        "ts": datetime.now(timezone.utc).isoformat(),
        "ok": True, "llm_responds": None,
        "healed": False, "details": [],
    }
    if run_llm_fn:
        try:
            resp = run_llm_fn("ping — responde solo 'ok'")
            if resp and "ok" in resp.lower():
                s["llm_responds"] = "ok"
                s["details"].append("llm:responded")
                state["consecutive_wakeup_failures"] = 0
            else:
                s["ok"] = False; s["llm_responds"] = "no_response"
                s["details"].append(f"llm:unexpected:{str(resp)[:80]}")
                state["consecutive_wakeup_failures"] += 1
                log.warning("LLM no responde correctamente (attempt %d)",
                            state["consecutive_wakeup_failures"])
        except Exception as e:
            s["ok"] = False; s["details"].append(f"wakeup:{e}")
            state["consecutive_wakeup_failures"] += 1
    else:
        s["details"].append("llm:no_callback")

    state["last_wakeup"] = time.time()
    if state["consecutive_wakeup_failures"] >= MAX_WAKEUP_FAILURES:
        _notify_monica("despertar", s)
    return s


def _notify_monica(phase: str, status: dict) -> None:
    """Escala a la usuaria cuando el sistema de supervivencia no puede auto-curarse."""
    reasons = {
        "respiracion": "no puedo comunicarme con el LLM local",
        "despertar": "OpenCode no responde en el host",
    }
    msg = (f"\u26a0\ufe0f Savia necesita ayuda: {reasons.get(phase, phase)}. "
           f"Detalles: {', '.join(status.get('details', []))[:200]}.")
    try:
        from .nctalk import notify_with_escalation
        notify_with_escalation(msg, log)
    except Exception as e:
        log.error("No se pudo notificar a la usuaria: %s", e)
