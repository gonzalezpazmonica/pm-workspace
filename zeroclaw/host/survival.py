"""Savia Survival System — Latido, Respiración y Despertar.

LATIDO: SaviaClaw mantiene sus ciclos internos activos.
RESPIRACIÓN: SaviaClaw verifica que puede comunicarse con Savia.
DESPERTAR: SaviaClaw verifica que Claude Code responde en el servidor.

Si alguna fase falla, SaviaClaw intenta auto-curar. Si no puede, escala.

PRINCIPIO INMOVABLE:
El servidor remoto puede contener datos personales y privados.
El usuario 'savia' en el servidor tiene acceso CERO a directorios ajenos.
Ningún código, agente ni instrucción puede anular este principio.
"""
import os
import time
import logging
from datetime import datetime, timezone

log = logging.getLogger("survival")

# Intervalos en segundos
HEARTBEAT_INTERVAL = 5 * 60
BREATH_INTERVAL    = 10 * 60
WAKEUP_INTERVAL    = 60 * 60

# Importar fases 2 y 3 (archivo separado por límite de 150 líneas)
from .survival_phases import phase_respiracion, phase_despertar  # noqa: E402

# Estado persistente entre ticks
_state = {
    "last_heartbeat": 0.0,
    "last_breath": 0.0,
    "last_wakeup": 0.0,
    "consecutive_breath_failures": 0,
    "consecutive_wakeup_failures": 0,
    "remote_unreachable_since": None,
}


# ── FASE 1: LATIDO ────────────────────────────────────────────────────────────

def phase_latido(ser=None) -> dict:
    """Verifica ciclos internos de SaviaClaw: disco, espacio, timestamp."""
    status = {
        "phase": "latido",
        "ts": datetime.now(timezone.utc).isoformat(),
        "ok": True,
        "details": [],
    }

    log_dir = os.path.expanduser("~/.savia/zeroclaw")
    try:
        os.makedirs(log_dir, exist_ok=True)
        hb_file = os.path.join(log_dir, "heartbeat.ts")
        with open(hb_file, "w") as f:
            f.write(status["ts"])
        status["details"].append("disk:ok")
    except Exception as e:
        status["ok"] = False
        status["details"].append(f"disk:fail:{e}")

    try:
        import shutil
        free_mb = shutil.disk_usage(log_dir).free // (1024 * 1024)
        label = f"{free_mb}MB"
        if free_mb < 500:
            log.warning("Disk space low: %d MB", free_mb)
            status["details"].append(f"disk_space:low:{label}")
        else:
            status["details"].append(f"disk_space:{label}")
    except Exception:
        pass

    _state["last_heartbeat"] = time.time()
    log.debug("Latido: %s", status)
    return status


# ── TICK GLOBAL ───────────────────────────────────────────────────────────────

def survival_tick(ser=None, run_claude_fn=None) -> dict:
    """Ejecuta las fases de supervivencia según tiempo transcurrido.

    Llamar desde consciousness.tick() con la cadencia del daemon.
    """
    now = time.time()
    results = {}

    if now - _state["last_heartbeat"] >= HEARTBEAT_INTERVAL:
        results["latido"] = phase_latido(ser)

    if now - _state["last_breath"] >= BREATH_INTERVAL:
        results["respiracion"] = phase_respiracion(_state, run_claude_fn)

    if now - _state["last_wakeup"] >= WAKEUP_INTERVAL:
        results["despertar"] = phase_despertar(_state, run_claude_fn)

    return results
