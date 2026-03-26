"""Savia Consciousness — notification + comms helpers.
Extracted from consciousness.py to stay within the 150-line limit.
"""
import logging

_log = logging.getLogger("consciousness")


def notify(msg):
    try:
        from .nctalk import notify_with_escalation
        notify_with_escalation(msg, _log)
    except Exception:
        pass


_SILENT_TASKS = {"memory-consolidate"}  # tasks that fail silently (known broken)

_FAILURE_MSGS = {
    "check-talk":   "No pude revisar Talk ahora. Lo intentaré de nuevo en un momento.",
    "check-gmail":  "No pude revisar el correo ahora. Lo intentaré pronto.",
    "gdrive-sync":  "No pude sincronizar Drive ahora. Lo reintentaré más tarde.",
    "git-status":   "No pude leer el estado de git. Sin conexión al repo.",
    "sensor-check": "No recibí datos de los sensores. ¿El dispositivo está conectado?",
    "heartbeat":    None,  # never notify
}


def notify_failure(name):
    if name in _SILENT_TASKS:
        return
    msg = _FAILURE_MSGS.get(name)
    if msg is None:
        return
    if msg:
        notify(msg)


def notify_success(name, result):
    """Human-readable success notification for tasks with notify=True."""
    if name == "gdrive-sync":
        try:
            import json as _j
            r = _j.loads(result) if isinstance(result, str) else result
            synced = r.get("synced", 0)
            failed = r.get("failed", 0)
            if failed:
                msg = f"Drive sincronizado: {synced} archivo(s) guardado(s), {failed} con error."
            else:
                msg = f"Drive sincronizado: {synced} archivo(s) guardado(s)."
        except Exception:
            msg = "Drive sincronizado correctamente."
    else:
        msg = f"Tarea completada: {name}."
    notify(msg)


def poll_talk(run_claude_fn):
    try:
        from .nctalk import poll_and_respond, check_escalations
        poll_and_respond(run_claude_fn, _log)
        check_escalations(_log)
    except Exception as e:
        _log.error("Talk poll: %s", e)


def check_gmail(run_claude_fn):
    try:
        from .gmail_check import check_and_notify
        check_and_notify(run_claude_fn, notify, _log)
    except Exception as e:
        _log.error("Gmail check: %s", e)
