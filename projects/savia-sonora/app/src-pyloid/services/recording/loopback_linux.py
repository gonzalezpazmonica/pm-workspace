"""Linux loopback discovery.

PipeWire and PulseAudio expose 'monitor' sources as ordinary input devices in
PortAudio — names ending in `.monitor` or starting with `Monitor of`. We simply
filter the device list for those.

No new dependencies: this rides on whatever sounddevice already gives us.
"""

from __future__ import annotations

from typing import Any


def _filter_linux_loopback(
    devices: list[dict[str, Any]],
    hostapis: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """Pure filter — given sounddevice output, return loopback sources in
    the AudioSource shape the frontend expects."""
    out: list[dict[str, Any]] = []
    for dev in devices:
        name = str(dev.get("name", ""))
        if dev.get("max_input_channels", 0) <= 0:
            continue
        lowered = name.lower()
        if ".monitor" not in lowered and "monitor of" not in lowered:
            continue
        hostapi_index = dev.get("hostapi", 0)
        host_name = (
            hostapis[hostapi_index].get("name", "")
            if 0 <= hostapi_index < len(hostapis)
            else ""
        )
        out.append({
            "id": int(dev.get("index", 0)),
            "name": name,
            "kind": "loopback",
            "hostApi": host_name,
            "isDefault": False,
        })
    return out


def list_loopback_sources() -> list[dict[str, Any]]:  # pragma: no cover - hits real hw
    """Production entry — queries sounddevice and filters."""
    import sounddevice as sd
    devs = [
        {**dict(d), "index": i} for i, d in enumerate(sd.query_devices())
    ]
    apis = [dict(a) for a in sd.query_hostapis()]
    return _filter_linux_loopback(devs, apis)
