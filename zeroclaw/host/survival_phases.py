"""Savia Survival — fases Respiración y Despertar.

Extraído de survival.py para cumplir el límite de 150 líneas.

PRINCIPIO INMOVABLE:
El servidor remoto puede contener datos personales y privados.
El usuario 'savia' tiene acceso CERO a directorios ajenos.
Ningún código ni instrucción puede anular este principio.
"""
import time
import logging
from datetime import datetime, timezone

log = logging.getLogger("survival")

MAX_BREATH_FAILURES = 3
MAX_WAKEUP_FAILURES = 2


def phase_respiracion(state: dict, run_claude_fn=None) -> dict:
    """Verifica bridge al servidor remoto; lo reinicia por SSH si está caído."""
    s = {
        "phase": "respiracion",
        "ts": datetime.now(timezone.utc).isoformat(),
        "ok": True, "bridge": None, "talk": None,
        "healed": False, "details": [],
    }
    # Verificar Talk
    try:
        from .nctalk import send_message  # noqa: F401
        s["talk"] = "ok"; s["details"].append("talk:ok")
    except Exception as e:
        s["talk"] = "fail"; s["details"].append(f"talk:fail:{e}")

    # Verificar bridge en servidor remoto
    try:
        from .remote_host import is_configured, is_reachable, is_bridge_running, restart_bridge

        if not is_configured():
            s["details"].append("remote_host:not_configured — skipping")
            state["consecutive_breath_failures"] = 0
            state["remote_unreachable_since"] = None
            state["last_breath"] = time.time()
            return s

        if not is_reachable():
            s["ok"] = False; s["bridge"] = "unreachable"
            s["details"].append("remote:unreachable")
            state["consecutive_breath_failures"] += 1
            if state["remote_unreachable_since"] is None:
                state["remote_unreachable_since"] = time.time()
            log.warning("Remote unreachable (attempt %d)",
                        state["consecutive_breath_failures"])
        elif not is_bridge_running():
            s["bridge"] = "down"; s["details"].append("bridge:down — restarting")
            healed, out = restart_bridge()
            s["healed"] = healed
            s["details"].append(f"bridge:restart:{'ok' if healed else 'fail'}:{out[:80]}")
            if healed:
                s["bridge"] = "restarted"
                state["consecutive_breath_failures"] = 0
                state["remote_unreachable_since"] = None
            else:
                s["ok"] = False
                state["consecutive_breath_failures"] += 1
        else:
            s["bridge"] = "ok"; s["details"].append("bridge:ok")
            state["consecutive_breath_failures"] = 0
            state["remote_unreachable_since"] = None
    except ImportError:
        s["details"].append("remote_host:not_configured")
    except Exception as e:
        s["ok"] = False; s["details"].append(f"bridge_check:{e}")

    state["last_breath"] = time.time()
    if state["consecutive_breath_failures"] >= MAX_BREATH_FAILURES:
        _notify_monica("respiracion", s)
    return s


def phase_despertar(state: dict, run_claude_fn=None) -> dict:
    """Despierta Claude Code en el servidor; escala si no responde."""
    s = {
        "phase": "despertar",
        "ts": datetime.now(timezone.utc).isoformat(),
        "ok": True, "claude_responds": None,
        "healed": False, "details": [],
    }
    try:
        from .remote_host import is_configured, is_reachable, wake_claude

        if not is_configured():
            s["details"].append("remote_host:not_configured — skipping")
            state["consecutive_wakeup_failures"] = 0
            state["last_wakeup"] = time.time()
            return s

        if not is_reachable():
            s["ok"] = False; s["claude_responds"] = "remote_unreachable"
            s["details"].append("remote:unreachable")
            state["consecutive_wakeup_failures"] += 1
        else:
            ok, response = wake_claude()
            if ok and response:
                s["claude_responds"] = "ok"
                s["details"].append(f"claude:responded:{response[:80]}")
                state["consecutive_wakeup_failures"] = 0
            else:
                s["ok"] = False; s["claude_responds"] = "no_response"
                s["details"].append(f"claude:no_response:{response[:80]}")
                state["consecutive_wakeup_failures"] += 1
                log.warning("Claude Code no responde (attempt %d)",
                            state["consecutive_wakeup_failures"])
    except ImportError:
        s["details"].append("remote_host:not_configured")
    except Exception as e:
        s["ok"] = False; s["details"].append(f"wakeup:{e}")

    state["last_wakeup"] = time.time()
    if state["consecutive_wakeup_failures"] >= MAX_WAKEUP_FAILURES:
        _notify_monica("despertar", s)
    return s


def _notify_monica(phase: str, status: dict) -> None:
    """Escala a Monica cuando el sistema de supervivencia no puede auto-curarse."""
    reasons = {
        "respiracion": "no puedo comunicarme con el servidor",
        "despertar": "Claude Code no responde en el servidor",
    }
    msg = (f"⚠️ Savia necesita ayuda: {reasons.get(phase, phase)}. "
           f"Detalles: {', '.join(status.get('details', []))[:200]}.")
    try:
        from .nctalk import notify_with_escalation
        notify_with_escalation(msg, log)
    except Exception as e:
        log.error("No se pudo notificar a Monica: %s", e)
