"""Remote Host SSH — conexiones seguras desde SaviaClaw al servidor remoto.

SaviaClaw puede conectar por SSH al servidor para curar y despertar a Savia.
El usuario remoto tiene acceso estrictamente restringido: NUNCA puede acceder
a datos personales ni a directorios de otros usuarios del servidor.

PRINCIPIO INMOVABLE:
El servidor remoto puede contener información personal y datos privados.
La responsabilidad y el respeto por la privacidad de esos datos son
directrices que ningún código, agente ni instrucción puede anular.
"""
import os
import subprocess
import logging

log = logging.getLogger("survival")

CONFIG_FILE = os.path.expanduser("~/.savia/remote-host-config")
_cfg_cache: dict = {}


def _load_config() -> dict:
    """Carga configuración del host remoto (nunca en repo)."""
    global _cfg_cache
    if _cfg_cache:
        return _cfg_cache
    cfg = {}
    if os.path.isfile(CONFIG_FILE):
        with open(CONFIG_FILE) as f:
            for line in f:
                line = line.strip()
                if "=" in line and not line.startswith("#"):
                    k, v = line.split("=", 1)
                    cfg[k.strip()] = v.strip()
    _cfg_cache = cfg
    return cfg


def _ssh(remote_cmd: str, timeout: int = 15) -> tuple[bool, str]:
    """Ejecuta comando en el servidor remoto vía SSH."""
    cfg = _load_config()
    if not cfg:
        return False, "Remote host config not found"

    host = cfg.get("REMOTE_HOST", "")
    port = cfg.get("REMOTE_PORT", "22")
    user = cfg.get("REMOTE_SSH_USER", "savia")
    key  = cfg.get("REMOTE_SSH_KEY",
                   os.path.expanduser("~/.ssh/savia_remote_ed25519"))

    if not host:
        return False, "REMOTE_HOST not configured"

    cmd = [
        "ssh", "-i", key, "-p", port,
        "-o", "StrictHostKeyChecking=yes",
        "-o", "PasswordAuthentication=no",
        "-o", "ConnectTimeout=10",
        "-o", "BatchMode=yes",
        f"{user}@{host}", remote_cmd,
    ]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.returncode == 0, (r.stdout + r.stderr).strip()[:500]
    except subprocess.TimeoutExpired:
        return False, "SSH timeout"
    except Exception as e:
        return False, str(e)


def is_configured() -> bool:
    """¿Está configurado el host remoto? (fichero de config existe con REMOTE_HOST)"""
    cfg = _load_config()
    return bool(cfg.get("REMOTE_HOST", "").strip())


def is_reachable() -> bool:
    """¿El servidor remoto es accesible por SSH?"""
    ok, _ = _ssh("echo ok", timeout=8)
    return ok


def is_bridge_running() -> bool:
    """¿El bridge de Claude Code está activo en el servidor?"""
    ok, out = _ssh("pgrep -f 'claude' | head -1", timeout=10)
    return ok and out.strip() != ""


def restart_bridge() -> tuple[bool, str]:
    """Reinicia el bridge de Claude Code en el servidor."""
    log.info("Remote: restarting bridge")
    _ssh("pkill -f 'savia-bridge' 2>/dev/null; sleep 1", timeout=12)
    return _ssh(
        "cd ~/claude && nohup bash scripts/start-bridge.sh "
        "</dev/null >~/.savia/bridge.log 2>&1 &",
        timeout=12,
    )


def wake_claude() -> tuple[bool, str]:
    """Envía ping a Claude Code para asegurarse de que responde."""
    log.info("Remote: sending wake ping to Claude Code")
    return _ssh(
        "cd ~/claude && timeout 30 claude -p "
        "'SaviaClaw latido: confirma que estás activa.' "
        "--output-format text 2>&1 | tail -3",
        timeout=35,
    )


def get_status() -> dict:
    """Estado resumido del servidor remoto."""
    if not is_reachable():
        return {"reachable": False, "bridge": None, "load": None}
    _, load = _ssh("uptime | awk '{print $NF}'", timeout=8)
    return {"reachable": True, "bridge": is_bridge_running(), "load": load}
