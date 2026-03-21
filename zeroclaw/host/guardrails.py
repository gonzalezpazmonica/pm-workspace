"""ZeroClaw Guardrails — deterministic security gates for sensory data.

These are HARD CODE GATES, not LLM instructions. They execute as Python
functions that BLOCK data flow if conditions aren't met. No agent can
override them — they run before any LLM sees the data.
"""
import os
import time

from .guardrails_pii import (
    gate_pii, gate_raw_cleanup, gate_storage, audit_log, MAX_RAW_DIR_MB)

# ── Gate 1: Data size limits (prevent DoS / memory exhaustion) ──

MAX_AUDIO_BYTES = 5 * 1024 * 1024   # 5MB (~160s at 16kHz/16bit)
MAX_IMAGE_BYTES = 2 * 1024 * 1024   # 2MB
MAX_SENSOR_BYTES = 4096              # 4KB


def gate_size(data_bytes, data_type):
    """BLOCK if data exceeds size limit. Returns (ok, reason)."""
    limits = {"audio": MAX_AUDIO_BYTES, "image": MAX_IMAGE_BYTES,
              "sensor": MAX_SENSOR_BYTES}
    limit = limits.get(data_type, MAX_SENSOR_BYTES)
    size = len(data_bytes) if isinstance(data_bytes, (bytes, bytearray)) else 0
    if size > limit:
        return False, f"BLOCKED: {data_type} size {size}B exceeds {limit}B"
    return True, "ok"


# ── Gate 2: Rate limiting (prevent flooding) ──

_rate_log = {}
RATE_LIMITS = {
    "audio": (5, 60), "image": (10, 60),
    "sensor": (60, 60), "command": (30, 60),
}


def gate_rate(data_type):
    """BLOCK if rate limit exceeded. Returns (ok, reason)."""
    max_count, window_sec = RATE_LIMITS.get(data_type, (30, 60))
    now = time.time()
    if data_type not in _rate_log:
        _rate_log[data_type] = []
    _rate_log[data_type] = [t for t in _rate_log[data_type] if now - t < window_sec]
    if len(_rate_log[data_type]) >= max_count:
        return False, f"BLOCKED: {data_type} rate limit ({max_count}/{window_sec}s)"
    _rate_log[data_type].append(now)
    return True, "ok"


# ── Gate 6: Command allowlist (only known commands pass) ──

ALLOWED_COMMANDS = {
    "ping", "led", "info", "sensors", "gpio", "help",
    "capture_image", "capture_audio", "speak", "set_led",
    "play_tone", "status",
}


def gate_command(cmd):
    """BLOCK unknown commands. Returns (ok, reason)."""
    if cmd in ALLOWED_COMMANDS:
        return True, "ok"
    return False, f"BLOCKED: unknown command '{cmd}'"


# ── Master gate: run all gates on incoming data ──

def validate_incoming(data_bytes, data_type, command=None):
    """Run ALL gates on incoming data. Returns (ok, reasons).

    Single entry point. ALL sensory data MUST pass through here.
    """
    reasons = []

    ok, reason = gate_size(data_bytes, data_type)
    if not ok:
        reasons.append(reason)

    ok, reason = gate_rate(data_type)
    if not ok:
        reasons.append(reason)

    ok, reason = gate_storage(os.path.expanduser("~/.savia/zeroclaw"))
    if not ok:
        reasons.append(reason)

    if command:
        ok, reason = gate_command(command)
        if not ok:
            reasons.append(reason)

    audit_log("incoming", {
        "type": data_type,
        "size": len(data_bytes) if isinstance(data_bytes, (bytes, bytearray)) else 0,
        "blocked": len(reasons) > 0,
        "reasons": reasons,
    })

    return len(reasons) == 0, reasons
