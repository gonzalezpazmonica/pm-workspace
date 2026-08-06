"""PipeWire / PulseAudio monitor-source discovery via `pactl`.

PortAudio's behavior on Linux varies wildly: the ALSA backend often hides
monitor sources, the JACK backend renames them by application instead of by
device. Neither is reliable. Instead we shell out to `pactl list short sources`
which talks to whatever sound server is actually running (Pulse, PipeWire-pulse).
The names returned can be passed directly to `parec --device=…` to record from.
"""

from __future__ import annotations

import shutil
import subprocess
from typing import Any


# We reserve a sentinel id range for pactl monitor sources so they round-trip
# through the RPC layer (which expects int ids) and are routed to ParecAudioSource
# at start time. The controller keeps a session map from id → source name.
PULSE_ID_BASE = 1_000_000


def pactl_available() -> bool:
    return shutil.which("pactl") is not None and shutil.which("parec") is not None


def list_pulse_monitor_sources() -> list[dict[str, Any]]:
    """Return monitor sources reported by `pactl list short sources`.

    Each result has the AudioSource shape the frontend expects, with `id` in
    the PULSE_ID_BASE+ range and an extra `pulseSourceName` field so the
    controller knows which name to hand to `parec`.
    """
    if not pactl_available():
        return []

    try:
        proc = subprocess.run(
            ["pactl", "list", "short", "sources"],
            capture_output=True, text=True, timeout=2,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return []
    if proc.returncode != 0:
        return []

    default_sink = _get_default_sink()
    default_monitor = f"{default_sink}.monitor" if default_sink else None

    out: list[dict[str, Any]] = []
    for line in proc.stdout.splitlines():
        cols = line.split("\t")
        if len(cols) < 2:
            continue
        name = cols[1].strip()
        if ".monitor" not in name.lower():
            continue
        friendly = _friendly_name(name)
        out.append({
            "id": PULSE_ID_BASE + len(out),
            "name": friendly,
            "kind": "loopback",
            "hostApi": "PipeWire / PulseAudio",
            "isDefault": name == default_monitor,
            # Internal: not in the AudioSource frontend type; the controller
            # uses it when opening a ParecAudioSource.
            "pulseSourceName": name,
        })
    # Surface the default monitor first.
    out.sort(key=lambda d: (not d["isDefault"], d["name"]))
    return out


def _get_default_sink() -> str | None:
    try:
        proc = subprocess.run(
            ["pactl", "get-default-sink"],
            capture_output=True, text=True, timeout=1,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None
    if proc.returncode != 0:
        return None
    return proc.stdout.strip() or None


def _friendly_name(monitor_name: str) -> str:
    """Turn `bluez_output.58:18:62:26:C0:33.monitor` into 'Bluetooth output',
    `alsa_output.pci-0000_07_00.6.analog-stereo.monitor` into 'Analog speakers',
    etc. Falls back to the raw name when nothing matches."""
    name = monitor_name.replace(".monitor", "")
    lower = name.lower()
    if lower.startswith("bluez_output"):
        return "Bluetooth headphones / speakers"
    if "hdmi" in lower:
        return "HDMI output"
    if "analog" in lower:
        return "Built-in speakers"
    if "usb" in lower:
        return "USB audio output"
    return name
